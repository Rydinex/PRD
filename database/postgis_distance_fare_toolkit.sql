-- Rydinex PostGIS distance + fare toolkit
-- Run after schema_postgres_postgis.sql

---------------------------------------------------------
-- PERFORMANCE INDEXES FOR SPATIAL LOOKUPS
---------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_ride_requests_pickup_gist
  ON ride_requests USING GIST (pickup_location);

CREATE INDEX IF NOT EXISTS idx_ride_requests_destination_gist
  ON ride_requests USING GIST (destination_location);

CREATE INDEX IF NOT EXISTS idx_driver_locations_location_gist
  ON driver_locations USING GIST (location);

---------------------------------------------------------
-- 1) ACCURATE DISTANCE (GEODESIC) IN METERS
-- Uses geography + ST_Distance for Earth-curved distance
---------------------------------------------------------
CREATE OR REPLACE FUNCTION request_distance_meters(p_request_id UUID)
RETURNS DOUBLE PRECISION
LANGUAGE sql
STABLE
AS $$
  SELECT ST_Distance(rr.pickup_location, rr.destination_location)
  FROM ride_requests rr
  WHERE rr.id = p_request_id;
$$;

---------------------------------------------------------
-- 2) FASTER (SLIGHTLY LESS ACCURATE) DISTANCE
-- ST_DistanceSphere works on geometry (cast from geography)
---------------------------------------------------------
CREATE OR REPLACE FUNCTION request_distance_meters_fast(p_request_id UUID)
RETURNS DOUBLE PRECISION
LANGUAGE sql
STABLE
AS $$
  SELECT ST_DistanceSphere(rr.pickup_location::geometry, rr.destination_location::geometry)
  FROM ride_requests rr
  WHERE rr.id = p_request_id;
$$;

---------------------------------------------------------
-- 3) DISTANCE IN KILOMETERS
---------------------------------------------------------
CREATE OR REPLACE FUNCTION request_distance_km(p_request_id UUID)
RETURNS DOUBLE PRECISION
LANGUAGE sql
STABLE
AS $$
  SELECT ST_Distance(rr.pickup_location, rr.destination_location) / 1000.0
  FROM ride_requests rr
  WHERE rr.id = p_request_id;
$$;

---------------------------------------------------------
-- 4) RYDINEX DISTANCE-BASED ESTIMATED FARE
-- fare = base + (distance_km * per_km) + (duration_min * per_min)
---------------------------------------------------------
CREATE OR REPLACE FUNCTION estimated_fare(
  p_request_id UUID,
  p_duration_min NUMERIC,
  p_base_fare NUMERIC DEFAULT 2.00,
  p_per_km_rate NUMERIC DEFAULT 0.75,
  p_per_min_rate NUMERIC DEFAULT 0.20
)
RETURNS NUMERIC
LANGUAGE sql
STABLE
AS $$
  SELECT (
    p_base_fare
    + ((ST_Distance(rr.pickup_location, rr.destination_location) / 1000.0) * p_per_km_rate)
    + (p_duration_min * p_per_min_rate)
  )::NUMERIC(10,2)
  FROM ride_requests rr
  WHERE rr.id = p_request_id;
$$;

---------------------------------------------------------
-- 5) REAL-TIME NEAREST DRIVERS TO REQUEST PICKUP
---------------------------------------------------------
CREATE OR REPLACE FUNCTION nearest_drivers_to_request(
  p_request_id UUID,
  p_limit INT DEFAULT 5
)
RETURNS TABLE (
  driver_id UUID,
  distance_to_pickup_meters DOUBLE PRECISION
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    dl.driver_id,
    ST_Distance(dl.location, rr.pickup_location) AS distance_to_pickup_meters
  FROM ride_requests rr
  JOIN driver_locations dl ON TRUE
  WHERE rr.id = p_request_id
  ORDER BY dl.location <-> rr.pickup_location
  LIMIT p_limit;
$$;

---------------------------------------------------------
-- 6) OPTIONAL WEATHER SURGE MULTIPLIER
---------------------------------------------------------
CREATE OR REPLACE FUNCTION weather_surge_multiplier(p_weather TEXT)
RETURNS NUMERIC
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE LOWER(TRIM(COALESCE(p_weather, 'normal')))
    WHEN 'rain' THEN 1.20
    WHEN 'storm' THEN 1.50
    WHEN 'snow' THEN 1.40
    ELSE 1.00
  END;
$$;

CREATE OR REPLACE FUNCTION estimated_fare_with_weather(
  p_request_id UUID,
  p_duration_min NUMERIC,
  p_weather TEXT,
  p_base_fare NUMERIC DEFAULT 2.00,
  p_per_km_rate NUMERIC DEFAULT 0.75,
  p_per_min_rate NUMERIC DEFAULT 0.20
)
RETURNS NUMERIC
LANGUAGE sql
STABLE
AS $$
  SELECT (
    estimated_fare(
      p_request_id,
      p_duration_min,
      p_base_fare,
      p_per_km_rate,
      p_per_min_rate
    ) * weather_surge_multiplier(p_weather)
  )::NUMERIC(10,2);
$$;

---------------------------------------------------------
-- EXAMPLE CALLS
---------------------------------------------------------
-- Replace with your request id as needed:
-- bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1 (seed sample)

-- Accurate meters
-- SELECT request_distance_meters('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1');

-- Fast meters
-- SELECT request_distance_meters_fast('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1');

-- Kilometers
-- SELECT request_distance_km('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1');

-- Fare (duration example = 12 min)
-- SELECT estimated_fare('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1', 12);

-- Nearest drivers
-- SELECT * FROM nearest_drivers_to_request('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1', 3);

-- Fare with weather surge
-- SELECT estimated_fare_with_weather('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1', 12, 'rain');
