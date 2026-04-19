-- Rider All-in-One request flow (PostgreSQL-first)
-- This script keeps all rider-request screen actions in SQL.
-- Run after:
-- 1) schema_postgres_postgis.sql
-- 2) postgis_distance_fare_toolkit.sql
-- 3) postgis_pricing_function_by_market.sql
-- 4) postgres_button_actions.sql

---------------------------------------------------------
-- Ride type catalog and pricing multipliers
---------------------------------------------------------
CREATE TABLE IF NOT EXISTS ride_types (
  code VARCHAR(30) PRIMARY KEY,
  label VARCHAR(60) NOT NULL,
  fare_multiplier NUMERIC(6,3) NOT NULL DEFAULT 1.000,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

INSERT INTO ride_types (code, label, fare_multiplier)
VALUES
  ('black', 'Rydinex Black', 1.80),
  ('blacksuv', 'Rydinex BlackSUV', 2.20),
  ('regular', 'Rydinex Regular', 1.00),
  ('comfort', 'Rydinex Comfort', 1.30),
  ('xl', 'Rydinex XL', 1.50),
  ('economy', 'Rydinex Economy', 1.10)
ON CONFLICT (code) DO UPDATE
SET
  label = EXCLUDED.label,
  fare_multiplier = EXCLUDED.fare_multiplier,
  active = TRUE,
  updated_at = NOW();

ALTER TABLE ride_requests ADD COLUMN IF NOT EXISTS ride_type_code VARCHAR(30);
ALTER TABLE ride_requests ADD COLUMN IF NOT EXISTS payment_method_id UUID;
ALTER TABLE ride_requests ADD COLUMN IF NOT EXISTS promo_code VARCHAR(30);

---------------------------------------------------------
-- 1) Set Pickup Location button
---------------------------------------------------------
CREATE OR REPLACE FUNCTION rider_set_pickup(
  p_request_id UUID,
  p_lon DOUBLE PRECISION,
  p_lat DOUBLE PRECISION
) RETURNS BOOLEAN
LANGUAGE sql
AS $$
  SELECT set_pickup_location(p_request_id, p_lon, p_lat);
$$;

---------------------------------------------------------
-- 2) Set Destination button
---------------------------------------------------------
CREATE OR REPLACE FUNCTION rider_set_destination(
  p_request_id UUID,
  p_lon DOUBLE PRECISION,
  p_lat DOUBLE PRECISION
) RETURNS BOOLEAN
LANGUAGE sql
AS $$
  SELECT set_destination_location(p_request_id, p_lon, p_lat);
$$;

---------------------------------------------------------
-- 3) Use Current Location button (alias to pickup update)
---------------------------------------------------------
CREATE OR REPLACE FUNCTION rider_use_current_location(
  p_request_id UUID,
  p_current_lon DOUBLE PRECISION,
  p_current_lat DOUBLE PRECISION
) RETURNS BOOLEAN
LANGUAGE sql
AS $$
  SELECT set_pickup_location(p_request_id, p_current_lon, p_current_lat);
$$;

---------------------------------------------------------
-- 4) Ride type selector button
---------------------------------------------------------
CREATE OR REPLACE FUNCTION rider_set_ride_type(
  p_request_id UUID,
  p_ride_type_code VARCHAR
) RETURNS BOOLEAN
LANGUAGE sql
AS $$
  UPDATE ride_requests
  SET ride_type_code = LOWER(TRIM(p_ride_type_code)),
      updated_at = NOW()
  WHERE id = p_request_id
  RETURNING TRUE;
$$;

---------------------------------------------------------
-- 5) Refresh Estimate button (distance + fare)
-- Uses market quote + ride-type multiplier + optional promo
---------------------------------------------------------
CREATE OR REPLACE FUNCTION rider_refresh_estimate(
  p_request_id UUID,
  p_market_code TEXT DEFAULT 'default',
  p_weather TEXT DEFAULT 'normal',
  p_promo_code VARCHAR DEFAULT NULL
)
RETURNS TABLE (
  request_id UUID,
  ride_type_code VARCHAR,
  distance_km DOUBLE PRECISION,
  estimated_duration_min INT,
  base_estimated_fare NUMERIC,
  ride_type_multiplier NUMERIC,
  promo_code VARCHAR,
  final_estimated_fare NUMERIC
)
LANGUAGE sql
STABLE
AS $$
  WITH q AS (
    SELECT * FROM quote_request_by_market(p_request_id, p_market_code, p_weather, NULL, NULL, NULL, NULL)
  ), rt AS (
    SELECT COALESCE(rr.ride_type_code, 'regular') AS code
    FROM ride_requests rr
    WHERE rr.id = p_request_id
  ), mult AS (
    SELECT COALESCE((SELECT fare_multiplier FROM ride_types WHERE code = rt.code AND active = TRUE), 1.00) AS m
    FROM rt
  ), priced AS (
    SELECT
      q.request_id,
      rt.code AS ride_type_code,
      q.distance_km,
      q.estimated_duration_min,
      q.final_fare::NUMERIC(10,2) AS base_estimated_fare,
      mult.m::NUMERIC(10,3) AS ride_type_multiplier,
      p_promo_code AS promo_code,
      (q.final_fare * mult.m)::NUMERIC(10,2) AS ride_type_adjusted
    FROM q
    CROSS JOIN rt
    CROSS JOIN mult
  )
  SELECT
    priced.request_id,
    priced.ride_type_code,
    priced.distance_km,
    priced.estimated_duration_min,
    priced.base_estimated_fare,
    priced.ride_type_multiplier,
    priced.promo_code,
    COALESCE(apply_promo_code(priced.ride_type_adjusted, priced.promo_code), priced.ride_type_adjusted)::NUMERIC(10,2) AS final_estimated_fare
  FROM priced;
$$;

---------------------------------------------------------
-- Request Ride button (all-in-one create)
---------------------------------------------------------
CREATE OR REPLACE FUNCTION rider_request_ride_all_in_one(
  p_rider_id UUID,
  p_pickup_lon DOUBLE PRECISION,
  p_pickup_lat DOUBLE PRECISION,
  p_dest_lon DOUBLE PRECISION,
  p_dest_lat DOUBLE PRECISION,
  p_ride_type_code VARCHAR DEFAULT 'regular',
  p_payment_method_id UUID DEFAULT NULL,
  p_promo_code VARCHAR DEFAULT NULL
) RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE v_request_id UUID;
BEGIN
  v_request_id := request_ride(p_rider_id, p_pickup_lon, p_pickup_lat, p_dest_lon, p_dest_lat);

  UPDATE ride_requests
  SET
    ride_type_code = LOWER(TRIM(COALESCE(p_ride_type_code, 'regular'))),
    payment_method_id = p_payment_method_id,
    promo_code = p_promo_code,
    updated_at = NOW()
  WHERE id = v_request_id;

  RETURN v_request_id;
END;
$$;

---------------------------------------------------------
-- Schedule button (stores a delayed request in pending state)
---------------------------------------------------------
CREATE TABLE IF NOT EXISTS scheduled_ride_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id UUID NOT NULL REFERENCES ride_requests(id),
  rider_id UUID NOT NULL REFERENCES users(id),
  scheduled_for TIMESTAMP NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION rider_schedule_request(
  p_request_id UUID,
  p_rider_id UUID,
  p_scheduled_for TIMESTAMP
) RETURNS UUID
LANGUAGE sql
AS $$
  INSERT INTO scheduled_ride_requests (request_id, rider_id, scheduled_for)
  VALUES (p_request_id, p_rider_id, p_scheduled_for)
  RETURNING id;
$$;

---------------------------------------------------------
-- Apply Promo button
---------------------------------------------------------
CREATE OR REPLACE FUNCTION rider_apply_promo(
  p_request_id UUID,
  p_code VARCHAR
) RETURNS BOOLEAN
LANGUAGE sql
AS $$
  UPDATE ride_requests
  SET promo_code = p_code,
      updated_at = NOW()
  WHERE id = p_request_id
  RETURNING TRUE;
$$;

---------------------------------------------------------
-- Payment Method button
---------------------------------------------------------
CREATE OR REPLACE FUNCTION rider_select_payment_method(
  p_request_id UUID,
  p_payment_method_id UUID
) RETURNS BOOLEAN
LANGUAGE sql
AS $$
  UPDATE ride_requests
  SET payment_method_id = p_payment_method_id,
      updated_at = NOW()
  WHERE id = p_request_id
  RETURNING TRUE;
$$;

---------------------------------------------------------
-- Cancel button
---------------------------------------------------------
CREATE OR REPLACE FUNCTION rider_cancel_request(
  p_request_id UUID
) RETURNS BOOLEAN
LANGUAGE sql
AS $$
  SELECT cancel_request(p_request_id);
$$;

---------------------------------------------------------
-- Distance KM exact query (requested)
---------------------------------------------------------
-- SELECT
--     ST_Distance(
--         pickup_location::geography,
--         destination_location::geography
--     ) / 1000 AS distance_km
-- FROM ride_requests
-- WHERE id = 'your_ride_request_id';
-- Output example: distance_km = 5.432
