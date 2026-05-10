-- Add vibration_score to aggregate tables.
-- Derived from accel std dev at ingest — higher = rougher surface / more vibration.
-- Normalized 0–1 (threshold: 5 m/s² std dev = 1.0).
-- Safe to re-run: IF NOT EXISTS.

ALTER TABLE sensor_aggregates_5m
  ADD COLUMN IF NOT EXISTS vibration_score double precision;

ALTER TABLE sensor_aggregates_daily
  ADD COLUMN IF NOT EXISTS vibration_score double precision;

CREATE INDEX IF NOT EXISTS idx_aggregates_5m_vibration
  ON sensor_aggregates_5m (vibration_score)
  WHERE vibration_score IS NOT NULL;
