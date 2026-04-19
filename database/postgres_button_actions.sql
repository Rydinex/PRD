-- PostgreSQL button action pack for Rydinex
-- Run after schema_postgres_postgis.sql

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS postgis;

---------------------------------------------------------
-- SUPPORTING TABLES / COLUMNS
---------------------------------------------------------
ALTER TABLE users ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT NOW();
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP NULL;

ALTER TABLE drivers ADD COLUMN IF NOT EXISTS verification_status VARCHAR(20) DEFAULT 'pending';
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT NOW();

ALTER TABLE vehicles ADD COLUMN IF NOT EXISTS color VARCHAR(30);
ALTER TABLE vehicles ADD COLUMN IF NOT EXISTS photo_url TEXT;
ALTER TABLE vehicles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT NOW();

ALTER TABLE ride_requests ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT NOW();
ALTER TABLE ride_requests ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMP NULL;
ALTER TABLE ride_requests ADD COLUMN IF NOT EXISTS fare_estimate NUMERIC(10,2);

ALTER TABLE rides ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT NOW();
ALTER TABLE rides ADD COLUMN IF NOT EXISTS started_at TIMESTAMP NULL;
ALTER TABLE rides ADD COLUMN IF NOT EXISTS completed_at TIMESTAMP NULL;

ALTER TABLE ratings ADD COLUMN IF NOT EXISTS rater_user_id UUID;
ALTER TABLE ratings ADD COLUMN IF NOT EXISTS rated_user_id UUID;
ALTER TABLE ratings ADD COLUMN IF NOT EXISTS rated_role VARCHAR(20) CHECK (rated_role IN ('rider', 'driver'));
ALTER TABLE ratings ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT NOW();

CREATE TABLE IF NOT EXISTS user_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  session_token TEXT UNIQUE NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMP NOT NULL,
  revoked_at TIMESTAMP NULL
);

CREATE TABLE IF NOT EXISTS driver_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES drivers(id),
  doc_type VARCHAR(30) NOT NULL,
  file_url TEXT NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'pending',
  uploaded_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_payment_methods (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  method_type VARCHAR(20) NOT NULL CHECK (method_type IN ('card', 'cash', 'wallet')),
  provider_token TEXT,
  last4 VARCHAR(4),
  is_default BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS promo_codes (
  code VARCHAR(30) PRIMARY KEY,
  discount_type VARCHAR(20) NOT NULL CHECK (discount_type IN ('flat', 'percent')),
  discount_value NUMERIC(10,2) NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  expires_at TIMESTAMP NULL
);

CREATE TABLE IF NOT EXISTS ride_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id UUID NOT NULL REFERENCES rides(id),
  sender_id UUID NOT NULL REFERENCES users(id),
  message TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS trip_shares (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id UUID NOT NULL REFERENCES rides(id),
  shared_with VARCHAR(150) NOT NULL,
  share_token UUID NOT NULL DEFAULT gen_random_uuid(),
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

---------------------------------------------------------
-- 1) USERS TABLE -> ACCOUNT & PROFILE BUTTONS
---------------------------------------------------------

-- Create Account
CREATE OR REPLACE FUNCTION create_account(
  p_full_name VARCHAR,
  p_email VARCHAR,
  p_phone VARCHAR,
  p_role VARCHAR,
  p_password_hash TEXT
) RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE v_user_id UUID;
BEGIN
  INSERT INTO users (full_name, email, phone, role, password_hash)
  VALUES (p_full_name, LOWER(TRIM(p_email)), p_phone, p_role, p_password_hash)
  RETURNING id INTO v_user_id;
  RETURN v_user_id;
END;
$$;

-- Login
CREATE OR REPLACE FUNCTION login_user(
  p_email VARCHAR,
  p_password_hash TEXT,
  p_session_minutes INT DEFAULT 1440
) RETURNS TABLE (user_id UUID, role VARCHAR, session_token TEXT, expires_at TIMESTAMP)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH u AS (
    SELECT id, users.role
    FROM users
    WHERE email = LOWER(TRIM(p_email))
      AND password_hash = p_password_hash
      AND is_active = TRUE
      AND deleted_at IS NULL
    LIMIT 1
  ), s AS (
    INSERT INTO user_sessions (user_id, session_token, expires_at)
    SELECT u.id, encode(gen_random_bytes(24), 'hex'), NOW() + (p_session_minutes || ' minutes')::INTERVAL
    FROM u
    RETURNING user_id, session_token, user_sessions.expires_at
  )
  SELECT s.user_id, u.role, s.session_token, s.expires_at
  FROM s
  JOIN u ON u.id = s.user_id;
END;
$$;

-- Logout
CREATE OR REPLACE FUNCTION logout_user(p_session_token TEXT) RETURNS BOOLEAN
LANGUAGE sql
AS $$
  UPDATE user_sessions
  SET revoked_at = NOW()
  WHERE session_token = p_session_token
    AND revoked_at IS NULL
  RETURNING TRUE;
$$;

-- Edit Profile / Contact update
CREATE OR REPLACE FUNCTION edit_profile(
  p_user_id UUID,
  p_full_name VARCHAR,
  p_email VARCHAR,
  p_phone VARCHAR
) RETURNS BOOLEAN
LANGUAGE sql
AS $$
  UPDATE users
  SET
    full_name = COALESCE(p_full_name, full_name),
    email = COALESCE(LOWER(TRIM(p_email)), email),
    phone = COALESCE(p_phone, phone),
    updated_at = NOW()
  WHERE id = p_user_id
    AND deleted_at IS NULL
  RETURNING TRUE;
$$;

-- Change Password
CREATE OR REPLACE FUNCTION change_password(
  p_user_id UUID,
  p_old_password_hash TEXT,
  p_new_password_hash TEXT
) RETURNS BOOLEAN
LANGUAGE sql
AS $$
  UPDATE users
  SET password_hash = p_new_password_hash, updated_at = NOW()
  WHERE id = p_user_id
    AND password_hash = p_old_password_hash
    AND deleted_at IS NULL
  RETURNING TRUE;
$$;

-- Delete Account (soft delete)
CREATE OR REPLACE FUNCTION delete_account(p_user_id UUID) RETURNS BOOLEAN
LANGUAGE sql
AS $$
  UPDATE users
  SET is_active = FALSE, deleted_at = NOW(), updated_at = NOW()
  WHERE id = p_user_id
    AND deleted_at IS NULL
  RETURNING TRUE;
$$;

---------------------------------------------------------
-- 2) DRIVERS TABLE -> DRIVER VERIFICATION BUTTONS
---------------------------------------------------------

-- Become a Driver
CREATE OR REPLACE FUNCTION become_driver(p_user_id UUID, p_license_number VARCHAR) RETURNS BOOLEAN
LANGUAGE sql
AS $$
  INSERT INTO drivers (id, license_number, verification_status)
  VALUES (p_user_id, p_license_number, 'pending')
  ON CONFLICT (id) DO UPDATE
  SET license_number = EXCLUDED.license_number,
      updated_at = NOW()
  RETURNING TRUE;
$$;

-- Upload License / Upload Documents
CREATE OR REPLACE FUNCTION upload_driver_document(
  p_driver_id UUID,
  p_doc_type VARCHAR,
  p_file_url TEXT
) RETURNS UUID
LANGUAGE sql
AS $$
  INSERT INTO driver_documents (driver_id, doc_type, file_url)
  VALUES (p_driver_id, p_doc_type, p_file_url)
  RETURNING id;
$$;

-- Update Vehicle Info
CREATE OR REPLACE FUNCTION update_driver_vehicle_info(
  p_driver_id UUID,
  p_vehicle_id UUID
) RETURNS BOOLEAN
LANGUAGE sql
AS $$
  UPDATE drivers
  SET vehicle_id = p_vehicle_id,
      updated_at = NOW()
  WHERE id = p_driver_id
  RETURNING TRUE;
$$;

-- View Driver Rating
CREATE OR REPLACE FUNCTION view_driver_rating(p_driver_id UUID)
RETURNS TABLE (driver_id UUID, current_rating FLOAT)
LANGUAGE sql
AS $$
  SELECT id, rating FROM drivers WHERE id = p_driver_id;
$$;

---------------------------------------------------------
-- 3) VEHICLES TABLE -> VEHICLE MANAGEMENT BUTTONS
---------------------------------------------------------

-- Add Vehicle
CREATE OR REPLACE FUNCTION add_vehicle(
  p_driver_id UUID,
  p_make VARCHAR,
  p_model VARCHAR,
  p_year INT,
  p_plate_number VARCHAR,
  p_color VARCHAR DEFAULT NULL,
  p_photo_url TEXT DEFAULT NULL
) RETURNS UUID
LANGUAGE sql
AS $$
  INSERT INTO vehicles (driver_id, make, model, year, plate_number, color, photo_url)
  VALUES (p_driver_id, p_make, p_model, p_year, p_plate_number, p_color, p_photo_url)
  RETURNING id;
$$;

-- Edit Vehicle
CREATE OR REPLACE FUNCTION edit_vehicle(
  p_vehicle_id UUID,
  p_make VARCHAR DEFAULT NULL,
  p_model VARCHAR DEFAULT NULL,
  p_year INT DEFAULT NULL,
  p_plate_number VARCHAR DEFAULT NULL,
  p_color VARCHAR DEFAULT NULL,
  p_photo_url TEXT DEFAULT NULL
) RETURNS BOOLEAN
LANGUAGE sql
AS $$
  UPDATE vehicles
  SET
    make = COALESCE(p_make, make),
    model = COALESCE(p_model, model),
    year = COALESCE(p_year, year),
    plate_number = COALESCE(p_plate_number, plate_number),
    color = COALESCE(p_color, color),
    photo_url = COALESCE(p_photo_url, photo_url),
    updated_at = NOW()
  WHERE id = p_vehicle_id
  RETURNING TRUE;
$$;

-- Remove Vehicle
CREATE OR REPLACE FUNCTION remove_vehicle(p_vehicle_id UUID) RETURNS BOOLEAN
LANGUAGE sql
AS $$
  UPDATE drivers SET vehicle_id = NULL WHERE vehicle_id = p_vehicle_id;
  DELETE FROM vehicles WHERE id = p_vehicle_id RETURNING TRUE;
$$;

---------------------------------------------------------
-- 4) RIDE_REQUESTS TABLE -> REQUEST RIDE BUTTONS
---------------------------------------------------------

-- Set Pickup Location
CREATE OR REPLACE FUNCTION set_pickup_location(
  p_request_id UUID,
  p_lon DOUBLE PRECISION,
  p_lat DOUBLE PRECISION
) RETURNS BOOLEAN
LANGUAGE sql
AS $$
  UPDATE ride_requests
  SET pickup_location = ST_SetSRID(ST_MakePoint(p_lon, p_lat), 4326)::geography,
      updated_at = NOW()
  WHERE id = p_request_id
  RETURNING TRUE;
$$;

-- Set Destination
CREATE OR REPLACE FUNCTION set_destination_location(
  p_request_id UUID,
  p_lon DOUBLE PRECISION,
  p_lat DOUBLE PRECISION
) RETURNS BOOLEAN
LANGUAGE sql
AS $$
  UPDATE ride_requests
  SET destination_location = ST_SetSRID(ST_MakePoint(p_lon, p_lat), 4326)::geography,
      updated_at = NOW()
  WHERE id = p_request_id
  RETURNING TRUE;
$$;

-- Request Ride
CREATE OR REPLACE FUNCTION request_ride(
  p_rider_id UUID,
  p_pickup_lon DOUBLE PRECISION,
  p_pickup_lat DOUBLE PRECISION,
  p_dest_lon DOUBLE PRECISION,
  p_dest_lat DOUBLE PRECISION
) RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE v_request_id UUID;
BEGIN
  INSERT INTO ride_requests (rider_id, pickup_location, destination_location, status)
  VALUES (
    p_rider_id,
    ST_SetSRID(ST_MakePoint(p_pickup_lon, p_pickup_lat), 4326)::geography,
    ST_SetSRID(ST_MakePoint(p_dest_lon, p_dest_lat), 4326)::geography,
    'pending'
  )
  RETURNING id INTO v_request_id;

  RETURN v_request_id;
END;
$$;

-- Cancel Request
CREATE OR REPLACE FUNCTION cancel_request(p_request_id UUID) RETURNS BOOLEAN
LANGUAGE sql
AS $$
  UPDATE ride_requests
  SET status = 'expired', cancelled_at = NOW(), updated_at = NOW()
  WHERE id = p_request_id
    AND status IN ('pending', 'matched')
  RETURNING TRUE;
$$;

---------------------------------------------------------
-- 5) RIDES TABLE -> LIVE RIDE BUTTONS
---------------------------------------------------------

-- Driver Accept Ride
CREATE OR REPLACE FUNCTION accept_ride(p_request_id UUID, p_driver_id UUID) RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
  v_ride_id UUID;
  v_rider_id UUID;
  v_pickup GEOGRAPHY(Point,4326);
  v_dest GEOGRAPHY(Point,4326);
BEGIN
  SELECT rider_id, pickup_location, destination_location
  INTO v_rider_id, v_pickup, v_dest
  FROM ride_requests
  WHERE id = p_request_id
    AND status IN ('pending', 'matched')
  LIMIT 1;

  IF v_rider_id IS NULL THEN
    RETURN NULL;
  END IF;

  UPDATE ride_requests
  SET status = 'matched', updated_at = NOW()
  WHERE id = p_request_id;

  INSERT INTO rides (rider_id, driver_id, start_location, end_location, status)
  VALUES (v_rider_id, p_driver_id, v_pickup, v_dest, 'accepted')
  RETURNING id INTO v_ride_id;

  RETURN v_ride_id;
END;
$$;

-- Driver Reject Ride
CREATE OR REPLACE FUNCTION reject_ride(p_request_id UUID) RETURNS BOOLEAN
LANGUAGE sql
AS $$
  UPDATE ride_requests
  SET status = 'pending', updated_at = NOW()
  WHERE id = p_request_id
    AND status IN ('pending', 'matched')
  RETURNING TRUE;
$$;

-- Start Ride
CREATE OR REPLACE FUNCTION start_ride(p_ride_id UUID) RETURNS BOOLEAN
LANGUAGE sql
AS $$
  UPDATE rides
  SET status = 'in_progress', started_at = NOW(), updated_at = NOW()
  WHERE id = p_ride_id
    AND status IN ('accepted', 'requested')
  RETURNING TRUE;
$$;

-- End Ride
CREATE OR REPLACE FUNCTION end_ride(p_ride_id UUID, p_fare_final NUMERIC) RETURNS BOOLEAN
LANGUAGE sql
AS $$
  UPDATE rides
  SET status = 'completed', fare_final = p_fare_final, completed_at = NOW(), updated_at = NOW()
  WHERE id = p_ride_id
    AND status = 'in_progress'
  RETURNING TRUE;
$$;

-- Cancel Ride
CREATE OR REPLACE FUNCTION cancel_ride(p_ride_id UUID) RETURNS BOOLEAN
LANGUAGE sql
AS $$
  UPDATE rides
  SET status = 'cancelled', updated_at = NOW()
  WHERE id = p_ride_id
    AND status IN ('requested', 'accepted', 'in_progress')
  RETURNING TRUE;
$$;

-- Message Driver / Rider
CREATE OR REPLACE FUNCTION send_ride_message(
  p_ride_id UUID,
  p_sender_id UUID,
  p_message TEXT
) RETURNS UUID
LANGUAGE sql
AS $$
  INSERT INTO ride_messages (ride_id, sender_id, message)
  VALUES (p_ride_id, p_sender_id, p_message)
  RETURNING id;
$$;

-- Share Trip
CREATE OR REPLACE FUNCTION share_trip(
  p_ride_id UUID,
  p_shared_with VARCHAR
) RETURNS UUID
LANGUAGE sql
AS $$
  INSERT INTO trip_shares (ride_id, shared_with)
  VALUES (p_ride_id, p_shared_with)
  RETURNING share_token;
$$;

---------------------------------------------------------
-- 6) PAYMENTS TABLE -> PAYMENT BUTTONS
---------------------------------------------------------

-- Add Payment Method
CREATE OR REPLACE FUNCTION add_payment_method(
  p_user_id UUID,
  p_method_type VARCHAR,
  p_provider_token TEXT,
  p_last4 VARCHAR,
  p_make_default BOOLEAN DEFAULT TRUE
) RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE v_id UUID;
BEGIN
  IF p_make_default THEN
    UPDATE user_payment_methods SET is_default = FALSE WHERE user_id = p_user_id;
  END IF;

  INSERT INTO user_payment_methods (user_id, method_type, provider_token, last4, is_default)
  VALUES (p_user_id, p_method_type, p_provider_token, p_last4, p_make_default)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

-- Select Payment Method
CREATE OR REPLACE FUNCTION select_payment_method(
  p_user_id UUID,
  p_method_id UUID
) RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE user_payment_methods SET is_default = FALSE WHERE user_id = p_user_id;
  UPDATE user_payment_methods
  SET is_default = TRUE
  WHERE id = p_method_id AND user_id = p_user_id;
  RETURN TRUE;
END;
$$;

-- Apply Promo Code
CREATE OR REPLACE FUNCTION apply_promo_code(
  p_amount NUMERIC,
  p_code VARCHAR
) RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
  v_type VARCHAR;
  v_value NUMERIC;
  v_final NUMERIC;
BEGIN
  SELECT discount_type, discount_value
  INTO v_type, v_value
  FROM promo_codes
  WHERE code = p_code
    AND is_active = TRUE
    AND (expires_at IS NULL OR expires_at > NOW())
  LIMIT 1;

  IF v_type IS NULL THEN
    RETURN p_amount;
  END IF;

  IF v_type = 'flat' THEN
    v_final := GREATEST(0, p_amount - v_value);
  ELSE
    v_final := GREATEST(0, p_amount - (p_amount * (v_value / 100.0)));
  END IF;

  RETURN ROUND(v_final, 2);
END;
$$;

-- Pay Now
CREATE OR REPLACE FUNCTION pay_now(
  p_ride_id UUID,
  p_amount NUMERIC,
  p_method VARCHAR,
  p_status VARCHAR DEFAULT 'paid'
) RETURNS UUID
LANGUAGE sql
AS $$
  INSERT INTO payments (ride_id, amount, method, status)
  VALUES (p_ride_id, p_amount, p_method, p_status)
  RETURNING id;
$$;

---------------------------------------------------------
-- 7) DRIVER_LOCATIONS TABLE -> REAL-TIME TRACKING
---------------------------------------------------------

-- Go Online / update live location
CREATE OR REPLACE FUNCTION go_online(
  p_driver_id UUID,
  p_lon DOUBLE PRECISION,
  p_lat DOUBLE PRECISION
) RETURNS BOOLEAN
LANGUAGE sql
AS $$
  INSERT INTO driver_locations (driver_id, location, updated_at)
  VALUES (
    p_driver_id,
    ST_SetSRID(ST_MakePoint(p_lon, p_lat), 4326)::geography,
    NOW()
  )
  ON CONFLICT (driver_id)
  DO UPDATE SET
    location = EXCLUDED.location,
    updated_at = NOW()
  RETURNING TRUE;
$$;

-- Go Offline
CREATE OR REPLACE FUNCTION go_offline(p_driver_id UUID) RETURNS BOOLEAN
LANGUAGE sql
AS $$
  DELETE FROM driver_locations
  WHERE driver_id = p_driver_id
  RETURNING TRUE;
$$;

---------------------------------------------------------
-- 8) RATINGS TABLE -> RATING BUTTONS
---------------------------------------------------------

-- Rate Driver / Rate Rider / Leave Feedback
CREATE OR REPLACE FUNCTION submit_rating(
  p_ride_id UUID,
  p_rating INT,
  p_comment TEXT,
  p_rater_user_id UUID,
  p_rated_user_id UUID,
  p_rated_role VARCHAR
) RETURNS UUID
LANGUAGE sql
AS $$
  INSERT INTO ratings (ride_id, rating, comment, rater_user_id, rated_user_id, rated_role)
  VALUES (p_ride_id, p_rating, p_comment, p_rater_user_id, p_rated_user_id, p_rated_role)
  RETURNING id;
$$;

-- Optional helper: review history for a user
CREATE OR REPLACE FUNCTION review_history(p_user_id UUID)
RETURNS TABLE (
  rating_id UUID,
  ride_id UUID,
  rating INT,
  comment TEXT,
  rated_role VARCHAR,
  created_at TIMESTAMP
)
LANGUAGE sql
AS $$
  SELECT id, ratings.ride_id, ratings.rating, ratings.comment, ratings.rated_role, ratings.created_at
  FROM ratings
  WHERE rated_user_id = p_user_id
  ORDER BY ratings.created_at DESC;
$$;

---------------------------------------------------------
-- QUICK EXAMPLES
---------------------------------------------------------
-- SELECT create_account('Standard Driver','standard@rydinex.com','000-000-000','driver','<hash>');
-- SELECT * FROM login_user('standard@rydinex.com','<hash>');
-- SELECT request_ride('11111111-1111-1111-1111-111111111111', -87.6298, 41.8781, -87.9073, 41.9742);
-- SELECT accept_ride('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1', '22222222-2222-2222-2222-222222222222');
-- SELECT go_online('22222222-2222-2222-2222-222222222222', -87.6354, 41.8881);
