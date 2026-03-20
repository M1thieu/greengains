-- Add H3 index columns for native spatial queries
-- Date: 2026-03-15
-- Purpose: Compute H3 cells at ingest (stored as TEXT columns), eliminating JSONB
--          extraction + client-side geo decoding at tile query time.
--          Industry pattern: Helium, Nodle, Hivemapper all index by H3 at ingest.

-- sensor_batches: h3_res9 (personal tiles) and h3_res8 (global tiles)
-- Populated at upload time via h3-js. Old rows backfilled by h3-backfill.ts on startup.
ALTER TABLE sensor_batches
  ADD COLUMN IF NOT EXISTS h3_res9 TEXT,
  ADD COLUMN IF NOT EXISTS h3_res8 TEXT;

-- User tile queries: WHERE user_id = $1 AND timestamp > $2 AND h3_res9 IS NOT NULL
CREATE INDEX IF NOT EXISTS idx_sb_user_h3_time
  ON sensor_batches (user_id, timestamp_utc DESC, h3_res9)
  WHERE user_id IS NOT NULL AND h3_res9 IS NOT NULL;

-- Global batch queries by h3_res8 over time range
CREATE INDEX IF NOT EXISTS idx_sb_h3r8_time
  ON sensor_batches (h3_res8, timestamp_utc DESC)
  WHERE h3_res8 IS NOT NULL;

-- H3 annotation on aggregate tables (written by aggregator, backfilled from geohash at startup)
ALTER TABLE sensor_aggregates_5m
  ADD COLUMN IF NOT EXISTS h3_index TEXT;

ALTER TABLE sensor_aggregates_daily
  ADD COLUMN IF NOT EXISTS h3_index TEXT;

-- Global tile queries on aggregates: WHERE h3_index IS NOT NULL + time range
CREATE INDEX IF NOT EXISTS idx_agg5m_h3_time
  ON sensor_aggregates_5m (h3_index, window_start DESC)
  WHERE h3_index IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_aggd_h3_day
  ON sensor_aggregates_daily (h3_index, day DESC)
  WHERE h3_index IS NOT NULL;
