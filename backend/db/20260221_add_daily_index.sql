-- Migration: Add missing index on sensor_aggregates_daily(day)
-- Date: 2026-02-21
-- Why: The original schema only indexed sensor_aggregates_daily by geohash.
--      All time-range queries (dashboard 30d/90d coverage, readings) now use
--      WHERE day >= $1 which does a full table scan without this index.
--      This also speeds up the daily aggregation job that upserts by (day, geohash).

CREATE INDEX IF NOT EXISTS idx_sensor_aggregates_daily_day
  ON sensor_aggregates_daily (day DESC);

-- Composite index for the common query pattern: time range + geohash filter
CREATE INDEX IF NOT EXISTS idx_sensor_aggregates_daily_day_geohash
  ON sensor_aggregates_daily (day DESC, geohash);
