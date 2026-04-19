-- Rydinex seed data for PostgreSQL + PostGIS
-- Run after schema_postgres_postgis.sql
-- Idempotent inserts using fixed UUIDs and ON CONFLICT

BEGIN;

-- Fixed IDs for stable references
-- users
-- rider:            11111111-1111-1111-1111-111111111111
-- driver standard:  22222222-2222-2222-2222-222222222222
-- driver pro:       33333333-3333-3333-3333-333333333333
-- admin:            44444444-4444-4444-4444-444444444444
-- vehicles
-- standard vehicle: aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1
-- pro vehicle:      aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2
-- ride_request:     bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1
-- ride:             cccccccc-cccc-cccc-cccc-ccccccccccc1
-- payment:          dddddddd-dddd-dddd-dddd-ddddddddddd1
-- rating:           eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee1

---------------------------------------------------------
-- USERS
---------------------------------------------------------
INSERT INTO users (id, full_name, email, phone, role, password_hash)
VALUES
  (
    '11111111-1111-1111-1111-111111111111',
    'Rider Demo',
    'rider@rydinex.com',
    '111-111-1111',
    'rider',
    '$2b$10$demo_hash_replace_in_prod'
  ),
  (
    '22222222-2222-2222-2222-222222222222',
    'Standard Driver',
    'standard@rydinex.com',
    '000-000-000',
    'driver',
    '$2b$10$demo_hash_for_password'
  ),
  (
    '33333333-3333-3333-3333-333333333333',
    'Pro Driver',
    'pro@rydinex.com',
    '333-333-3333',
    'driver',
    '$2b$10$demo_hash_for_password'
  ),
  (
    '44444444-4444-4444-4444-444444444444',
    'Admin Demo',
    'admin@rydinex.com',
    '444-444-4444',
    'admin',
    '$2b$10$demo_hash_for_password'
  )
ON CONFLICT (id) DO UPDATE
SET
  full_name = EXCLUDED.full_name,
  email = EXCLUDED.email,
  phone = EXCLUDED.phone,
  role = EXCLUDED.role,
  password_hash = EXCLUDED.password_hash;

---------------------------------------------------------
-- VEHICLES
---------------------------------------------------------
INSERT INTO vehicles (id, driver_id, make, model, year, plate_number)
VALUES
  (
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
    '22222222-2222-2222-2222-222222222222',
    'Toyota',
    'Camry',
    2022,
    'STD-2222'
  ),
  (
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2',
    '33333333-3333-3333-3333-333333333333',
    'Cadillac',
    'Escalade',
    2023,
    'PRO-3333'
  )
ON CONFLICT (id) DO UPDATE
SET
  driver_id = EXCLUDED.driver_id,
  make = EXCLUDED.make,
  model = EXCLUDED.model,
  year = EXCLUDED.year,
  plate_number = EXCLUDED.plate_number;

---------------------------------------------------------
-- DRIVERS
---------------------------------------------------------
INSERT INTO drivers (id, license_number, vehicle_id, rating)
VALUES
  (
    '22222222-2222-2222-2222-222222222222',
    'LIC-STD-2222',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
    4.8
  ),
  (
    '33333333-3333-3333-3333-333333333333',
    'LIC-PRO-3333',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2',
    4.95
  )
ON CONFLICT (id) DO UPDATE
SET
  license_number = EXCLUDED.license_number,
  vehicle_id = EXCLUDED.vehicle_id,
  rating = EXCLUDED.rating;

---------------------------------------------------------
-- RIDE REQUEST
---------------------------------------------------------
INSERT INTO ride_requests (id, rider_id, pickup_location, destination_location, status)
VALUES (
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
  '11111111-1111-1111-1111-111111111111',
  ST_GeogFromText('POINT(-87.6298 41.8781)'),
  ST_GeogFromText('POINT(-87.9073 41.9742)'),
  'matched'
)
ON CONFLICT (id) DO UPDATE
SET
  rider_id = EXCLUDED.rider_id,
  pickup_location = EXCLUDED.pickup_location,
  destination_location = EXCLUDED.destination_location,
  status = EXCLUDED.status;

---------------------------------------------------------
-- RIDE
---------------------------------------------------------
INSERT INTO rides (id, rider_id, driver_id, start_location, end_location, status, fare_estimate, fare_final)
VALUES (
  'cccccccc-cccc-cccc-cccc-ccccccccccc1',
  '11111111-1111-1111-1111-111111111111',
  '22222222-2222-2222-2222-222222222222',
  ST_GeogFromText('POINT(-87.6298 41.8781)'),
  ST_GeogFromText('POINT(-87.9073 41.9742)'),
  'completed',
  38.50,
  41.20
)
ON CONFLICT (id) DO UPDATE
SET
  rider_id = EXCLUDED.rider_id,
  driver_id = EXCLUDED.driver_id,
  start_location = EXCLUDED.start_location,
  end_location = EXCLUDED.end_location,
  status = EXCLUDED.status,
  fare_estimate = EXCLUDED.fare_estimate,
  fare_final = EXCLUDED.fare_final;

---------------------------------------------------------
-- PAYMENT
---------------------------------------------------------
INSERT INTO payments (id, ride_id, amount, method, status)
VALUES (
  'dddddddd-dddd-dddd-dddd-ddddddddddd1',
  'cccccccc-cccc-cccc-cccc-ccccccccccc1',
  41.20,
  'card',
  'paid'
)
ON CONFLICT (id) DO UPDATE
SET
  ride_id = EXCLUDED.ride_id,
  amount = EXCLUDED.amount,
  method = EXCLUDED.method,
  status = EXCLUDED.status;

---------------------------------------------------------
-- DRIVER LIVE LOCATIONS
---------------------------------------------------------
INSERT INTO driver_locations (driver_id, location)
VALUES
  (
    '22222222-2222-2222-2222-222222222222',
    ST_GeogFromText('POINT(-87.6354 41.8881)')
  ),
  (
    '33333333-3333-3333-3333-333333333333',
    ST_GeogFromText('POINT(-87.6244 41.8819)')
  )
ON CONFLICT (driver_id) DO UPDATE
SET
  location = EXCLUDED.location,
  updated_at = NOW();

---------------------------------------------------------
-- RATING
---------------------------------------------------------
INSERT INTO ratings (id, ride_id, rating, comment)
VALUES (
  'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee1',
  'cccccccc-cccc-cccc-cccc-ccccccccccc1',
  5,
  'Smooth ride and great communication.'
)
ON CONFLICT (id) DO UPDATE
SET
  ride_id = EXCLUDED.ride_id,
  rating = EXCLUDED.rating,
  comment = EXCLUDED.comment;

COMMIT;
