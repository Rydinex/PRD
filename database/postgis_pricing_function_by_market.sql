-- Parameterized quote function with market/city rates + weather surge
-- Run after schema_postgres_postgis.sql and postgis_distance_fare_toolkit.sql

---------------------------------------------------------
-- MARKET RATE CONFIG TABLE
---------------------------------------------------------
CREATE TABLE IF NOT EXISTS market_pricing (
  market_code VARCHAR(30) PRIMARY KEY,
  base_fare NUMERIC(10,2) NOT NULL,
  per_km_rate NUMERIC(10,2) NOT NULL,
  per_min_rate NUMERIC(10,2) NOT NULL,
  avg_speed_kmh NUMERIC(6,2) NOT NULL DEFAULT 30.00,
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Starter markets (idempotent)
INSERT INTO market_pricing (market_code, base_fare, per_km_rate, per_min_rate, avg_speed_kmh)
VALUES
  ('default', 2.00, 0.75, 0.20, 30.00),
  ('chicago', 2.50, 0.85, 0.25, 28.00),
  ('nyc', 3.25, 1.20, 0.45, 22.00)
ON CONFLICT (market_code) DO UPDATE
SET
  base_fare = EXCLUDED.base_fare,
  per_km_rate = EXCLUDED.per_km_rate,
  per_min_rate = EXCLUDED.per_min_rate,
  avg_speed_kmh = EXCLUDED.avg_speed_kmh,
  updated_at = NOW();

---------------------------------------------------------
-- API FUNCTION: QUOTE REQUEST BY MARKET
-- Inputs:
--   p_request_id  : ride request UUID
--   p_market_code : e.g. 'chicago', 'nyc' (falls back to 'default')
--   p_weather     : normal/rain/snow/storm (mapped by weather_surge_multiplier)
--   p_override_*  : optional overrides for dynamic experiments
---------------------------------------------------------
CREATE OR REPLACE FUNCTION quote_request_by_market(
  p_request_id UUID,
  p_market_code TEXT DEFAULT 'default',
  p_weather TEXT DEFAULT 'normal',
  p_override_base NUMERIC DEFAULT NULL,
  p_override_per_km NUMERIC DEFAULT NULL,
  p_override_per_min NUMERIC DEFAULT NULL,
  p_override_avg_speed_kmh NUMERIC DEFAULT NULL
)
RETURNS TABLE (
  request_id UUID,
  market_code TEXT,
  weather_condition TEXT,
  surge_multiplier NUMERIC,
  distance_meters DOUBLE PRECISION,
  distance_km DOUBLE PRECISION,
  estimated_duration_min INT,
  base_fare NUMERIC,
  per_km_rate NUMERIC,
  per_min_rate NUMERIC,
  estimated_fare NUMERIC,
  final_fare NUMERIC
)
LANGUAGE sql
STABLE
AS $$
  WITH req AS (
    SELECT
      rr.id,
      ST_Distance(rr.pickup_location, rr.destination_location) AS distance_m,
      ST_Distance(rr.pickup_location, rr.destination_location) / 1000.0 AS distance_km
    FROM ride_requests rr
    WHERE rr.id = p_request_id
  ),
  rate_pick AS (
    SELECT
      COALESCE(NULLIF(TRIM(LOWER(p_market_code)), ''), 'default') AS requested_market,
      COALESCE(
        (
          SELECT mp.market_code
          FROM market_pricing mp
          WHERE mp.market_code = COALESCE(NULLIF(TRIM(LOWER(p_market_code)), ''), 'default')
        ),
        'default'
      ) AS resolved_market
  ),
  r AS (
    SELECT
      rp.resolved_market,
      COALESCE(p_override_base, mp.base_fare) AS base_fare,
      COALESCE(p_override_per_km, mp.per_km_rate) AS per_km_rate,
      COALESCE(p_override_per_min, mp.per_min_rate) AS per_min_rate,
      COALESCE(p_override_avg_speed_kmh, mp.avg_speed_kmh) AS avg_speed_kmh
    FROM rate_pick rp
    JOIN market_pricing mp ON mp.market_code = rp.resolved_market
  )
  SELECT
    req.id AS request_id,
    r.resolved_market::TEXT AS market_code,
    LOWER(TRIM(COALESCE(p_weather, 'normal')))::TEXT AS weather_condition,
    weather_surge_multiplier(p_weather) AS surge_multiplier,
    req.distance_m AS distance_meters,
    req.distance_km AS distance_km,
    GREATEST(1, CEIL((req.distance_km / NULLIF(r.avg_speed_kmh, 0)) * 60.0))::INT AS estimated_duration_min,
    r.base_fare,
    r.per_km_rate,
    r.per_min_rate,
    ROUND(
      (
        r.base_fare
        + (req.distance_km * r.per_km_rate)
        + (GREATEST(1, CEIL((req.distance_km / NULLIF(r.avg_speed_kmh, 0)) * 60.0)) * r.per_min_rate)
      )::NUMERIC,
      2
    ) AS estimated_fare,
    ROUND(
      (
        (
          r.base_fare
          + (req.distance_km * r.per_km_rate)
          + (GREATEST(1, CEIL((req.distance_km / NULLIF(r.avg_speed_kmh, 0)) * 60.0)) * r.per_min_rate)
        ) * weather_surge_multiplier(p_weather)
      )::NUMERIC,
      2
    ) AS final_fare
  FROM req
  CROSS JOIN r;
$$;

-- Example calls:
-- SELECT * FROM quote_request_by_market('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1');
-- SELECT * FROM quote_request_by_market('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1', 'chicago', 'rain');
-- SELECT * FROM quote_request_by_market('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1', 'nyc', 'storm', 4.00, 1.35, 0.55, 20.00);
