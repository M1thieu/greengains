-- Migration: Add H3 Geospatial Indexes
-- Date: 2026-02-15
-- Purpose: Replace geohash with H3 hexagonal hierarchical spatial indexing
--
-- H3 provides:
-- - Better coverage visualization (hexagons > rectangles)
-- - Hierarchical zoom levels (parent/child relationships)
-- - More accurate neighbor queries
-- - Industry standard for geospatial heatmaps
--
-- IMPORTANT: Run this migration, then run the data migration script to populate h3_index
-- from existing lat/lon data. Only after verification, drop the geohash column.

-- Add H3 index column to sensor_aggregates_5m table
ALTER TABLE sensor_aggregates_5m
ADD COLUMN IF NOT EXISTS h3_index TEXT;

-- Add H3 index column to sensor_aggregates_daily table
ALTER TABLE sensor_aggregates_daily
ADD COLUMN IF NOT EXISTS h3_index TEXT;

-- Add H3 index column to sensor_batches table (for future use)
ALTER TABLE sensor_batches
ADD COLUMN IF NOT EXISTS h3_index TEXT;

-- Create indexes for efficient H3 queries
CREATE INDEX IF NOT EXISTS idx_sensor_aggregates_5m_h3
ON sensor_aggregates_5m(h3_index, window_start DESC);

CREATE INDEX IF NOT EXISTS idx_sensor_aggregates_daily_h3
ON sensor_aggregates_daily(h3_index, day DESC);

CREATE INDEX IF NOT EXISTS idx_sensor_batches_h3
ON sensor_batches(h3_index, timestamp_utc DESC);

-- NOTE: After running this migration, you need to:
-- 1. Run data migration to populate h3_index from lat/lon in batch_json
-- 2. Verify data looks correct
-- 3. Update backend code to use h3_index instead of geohash
-- 4. Monitor for a few days
-- 5. Then optionally drop geohash columns (but keep for safety initially)

-- Future cleanup (DO NOT RUN YET - wait for verification):
-- ALTER TABLE sensor_aggregates_5m DROP COLUMN geohash;
-- ALTER TABLE sensor_aggregates_daily DROP COLUMN geohash;
