-- Match + quote helper
-- Run after:
-- 1) schema_postgres_postgis.sql
-- 2) postgis_distance_fare_toolkit.sql
-- 3) postgis_pricing_function_by_market.sql

---------------------------------------------------------
-- Direct distance_km query (requested)
---------------------------------------------------------
-- SELECT
--     ST_Distance(
--         pickup_location::geography,
--         destination_location::geography
--     ) / 1000 AS distance_km
-- FROM ride_requests
-- WHERE id = 'your_ride_request_id';
-- Output example: distance_km = 5.432

---------------------------------------------------------
-- TOP-N NEAREST DRIVERS + ETA + QUOTE
---------------------------------------------------------
CREATE OR REPLACE FUNCTION match_quote_top_drivers(
  p_request_id UUID,
  p_market_code TEXT DEFAULT 'default',
  p_weather TEXT DEFAULT 'normal',
  p_top_n INT DEFAULT 3,
  p_avg_driver_speed_kmh NUMERIC DEFAULT 25.0
)
RETURNS TABLE (
  request_id UUID,
  driver_id UUID,
  distance_to_pickup_meters DOUBLE PRECISION,
  eta_to_pickup_min INT,
  trip_distance_km DOUBLE PRECISION,
  estimated_duration_min INT,
  estimated_fare NUMERIC,
  final_fare NUMERIC,
  market_code TEXT,
  weather_condition TEXT,
  surge_multiplier NUMERIC
)
LANGUAGE sql
STABLE
AS $$
  WITH quote AS (
    SELECT *
    FROM quote_request_by_market(
      p_request_id,
      p_market_code,
      p_weather,
      NULL,
      NULL,
      NULL,
      NULL
    )
  ),
  ranked_drivers AS (
    SELECT
      dl.driver_id,
      ST_Distance(dl.location, rr.pickup_location) AS distance_to_pickup_meters
    FROM ride_requests rr
    JOIN driver_locations dl ON TRUE
    WHERE rr.id = p_request_id
    ORDER BY dl.location <-> rr.pickup_location
    LIMIT GREATEST(1, p_top_n)
  )
  SELECT
    q.request_id,
    rd.driver_id,
    rd.distance_to_pickup_meters,
    GREATEST(
      1,
      CEIL(((rd.distance_to_pickup_meters / 1000.0) / NULLIF(p_avg_driver_speed_kmh, 0)) * 60.0)
    )::INT AS eta_to_pickup_min,
    q.distance_km,
    q.estimated_duration_min,
    q.estimated_fare,
    q.final_fare,
    q.market_code,
    q.weather_condition,
    q.surge_multiplier
  FROM ranked_drivers rd
  CROSS JOIN quote q
  ORDER BY rd.distance_to_pickup_meters ASC;
$$;

-- Example calls:
-- SELECT * FROM match_quote_top_drivers('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1');
-- SELECT * FROM match_quote_top_drivers('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1', 'chicago', 'rain', 3, 22.0);
