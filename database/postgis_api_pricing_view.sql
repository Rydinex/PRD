-- API-ready pricing view for ride requests
-- Run after:
-- 1) schema_postgres_postgis.sql
-- 2) postgis_distance_fare_toolkit.sql

CREATE OR REPLACE VIEW v_request_pricing_summary AS
WITH request_calc AS (
  SELECT
    rr.id AS request_id,
    rr.rider_id,
    rr.status,
    rr.created_at,
    ST_Distance(rr.pickup_location, rr.destination_location) AS distance_meters,
    ST_Distance(rr.pickup_location, rr.destination_location) / 1000.0 AS distance_km,
    GREATEST(
      1,
      CEIL(((ST_Distance(rr.pickup_location, rr.destination_location) / 1000.0) / 30.0) * 60.0)
    )::INT AS estimated_duration_min,
    nd.driver_id AS nearest_driver_id,
    nd.distance_to_pickup_meters
  FROM ride_requests rr
  LEFT JOIN LATERAL (
    SELECT
      dl.driver_id,
      ST_Distance(dl.location, rr.pickup_location) AS distance_to_pickup_meters
    FROM driver_locations dl
    ORDER BY dl.location <-> rr.pickup_location
    LIMIT 1
  ) nd ON TRUE
),
pricing AS (
  SELECT
    rc.*,
    2.00::NUMERIC(10,2) AS base_fare,
    0.75::NUMERIC(10,2) AS per_km_rate,
    0.20::NUMERIC(10,2) AS per_min_rate,
    'normal'::TEXT AS weather_condition,
    1.00::NUMERIC(10,2) AS surge_multiplier
  FROM request_calc rc
)
SELECT
  p.request_id,
  p.rider_id,
  p.status,
  p.created_at,
  ROUND(p.distance_meters::NUMERIC, 2) AS distance_meters,
  ROUND(p.distance_km::NUMERIC, 3) AS distance_km,
  p.estimated_duration_min,
  p.nearest_driver_id,
  ROUND(COALESCE(p.distance_to_pickup_meters, 0)::NUMERIC, 2) AS nearest_driver_distance_meters,
  p.base_fare,
  p.per_km_rate,
  p.per_min_rate,
  p.weather_condition,
  p.surge_multiplier,
  ROUND(
    (p.base_fare + (p.distance_km * p.per_km_rate) + (p.estimated_duration_min * p.per_min_rate))::NUMERIC,
    2
  ) AS estimated_fare,
  ROUND(
    (
      (p.base_fare + (p.distance_km * p.per_km_rate) + (p.estimated_duration_min * p.per_min_rate))
      * p.surge_multiplier
    )::NUMERIC,
    2
  ) AS final_fare
FROM pricing p;

-- Example usage:
-- SELECT * FROM v_request_pricing_summary ORDER BY created_at DESC;
-- SELECT * FROM v_request_pricing_summary WHERE request_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1';
