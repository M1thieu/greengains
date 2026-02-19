-- Migration: Add magnetic field and proximity sensor columns
-- Date: 2026-02-19
-- Purpose: Store aggregated magnetometer summary in 5m/daily aggregate tables.
--          Raw magnetic [x,y,z,magnitude] is already stored in the JSON batch blob.
--          Adding dedicated aggregate columns enables efficient SQL queries for:
--            - Indoor/outdoor environment detection (elevated magnetic field → indoor)
--            - Magnetic anomaly mapping (power lines, transformers, industrial zones)
--            - Environmental data API responses without JSON parsing
--
-- No changes needed to sensor_batches — batch JSON already stores new fields as-is.
-- No changes needed to schema_migrations — this file is applied via Supabase SQL editor.

BEGIN;

-- ── sensor_aggregates_5m ─────────────────────────────────────────────────────

ALTER TABLE sensor_aggregates_5m
  ADD COLUMN IF NOT EXISTS avg_magnetic_magnitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS min_magnetic_magnitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS max_magnetic_magnitude DOUBLE PRECISION;

COMMENT ON COLUMN sensor_aggregates_5m.avg_magnetic_magnitude IS
  'Average total magnetic field magnitude (µT) over 5-minute window. >80 µT suggests indoor/near-electronics.';

-- ── sensor_aggregates_daily ──────────────────────────────────────────────────

ALTER TABLE sensor_aggregates_daily
  ADD COLUMN IF NOT EXISTS avg_magnetic_magnitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS min_magnetic_magnitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS max_magnetic_magnitude DOUBLE PRECISION;

COMMENT ON COLUMN sensor_aggregates_daily.avg_magnetic_magnitude IS
  'Average total magnetic field magnitude (µT) for the day. Useful for environment classification.';

COMMIT;
