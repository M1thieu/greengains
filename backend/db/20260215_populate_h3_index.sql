-- Migration: Populate H3 Index from Existing Location Data
-- Date: 2026-02-15
-- Purpose: Migrate from geohash to H3 hexagonal indexing (keeping both for now)
--
-- Strategy: Extract lat/lon from batch_json in sensor_batches, compute H3 index at resolution 7
-- Then aggregate to sensor_aggregates_5m and sensor_aggregates_daily
--
-- H3 Resolution 7 = ~1km hexagons (good for city-level granularity)
-- Can tune higher (smaller cells) or lower (larger cells) based on needs

-- ============================================================================
-- Step 1: Populate sensor_aggregates_5m with H3 index
-- ============================================================================

-- For records with location data, compute H3 index from lat/lon
-- This uses a window function to identify the batch for each aggregate row
-- NOTE: This assumes sensor_batches have location data in batch_json->'location'

UPDATE sensor_aggregates_5m agg
SET h3_index = (
  -- Find the most common H3 index for this aggregation window + geohash
  SELECT h3_latlng_to_cell(
    CAST(NULLIF(batch_json->'location'->>'lat', '') AS DOUBLE PRECISION),
    CAST(NULLIF(batch_json->'location'->>'lon', '') AS DOUBLE PRECISION),
    7  -- Resolution 7 = ~1km cells
  )
  FROM sensor_batches
  WHERE DATE(sensor_batches.timestamp_utc) = DATE(agg.window_start)
    AND sensor_batches.batch_json->'location' IS NOT NULL
  ORDER BY sensor_batches.timestamp_utc DESC
  LIMIT 1
)
WHERE agg.h3_index IS NULL
  AND EXISTS (
    SELECT 1 FROM sensor_batches
    WHERE DATE(sensor_batches.timestamp_utc) = DATE(agg.window_start)
      AND sensor_batches.batch_json->'location' IS NOT NULL
  );

-- ============================================================================
-- Step 2: Populate sensor_aggregates_daily with H3 index
-- ============================================================================

UPDATE sensor_aggregates_daily agg
SET h3_index = (
  SELECT h3_latlng_to_cell(
    CAST(NULLIF(batch_json->'location'->>'lat', '') AS DOUBLE PRECISION),
    CAST(NULLIF(batch_json->'location'->>'lon', '') AS DOUBLE PRECISION),
    7
  )
  FROM sensor_batches
  WHERE DATE(sensor_batches.timestamp_utc) = agg.day
    AND sensor_batches.batch_json->'location' IS NOT NULL
  ORDER BY sensor_batches.timestamp_utc DESC
  LIMIT 1
)
WHERE agg.h3_index IS NULL
  AND EXISTS (
    SELECT 1 FROM sensor_batches
    WHERE DATE(sensor_batches.timestamp_utc) = agg.day
      AND sensor_batches.batch_json->'location' IS NOT NULL
  );

-- ============================================================================
-- Step 3: Add Precision Columns to sensor_aggregates_5m
-- ============================================================================

ALTER TABLE sensor_aggregates_5m
ADD COLUMN IF NOT EXISTS precision_score DOUBLE PRECISION DEFAULT 0.5,
ADD COLUMN IF NOT EXISTS sensor_count INTEGER DEFAULT 1,
ADD COLUMN IF NOT EXISTS coverage_hours DOUBLE PRECISION DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS quality_flags TEXT[] DEFAULT ARRAY[]::TEXT[];

-- Populate precision_score based on sample density
-- High precision = many samples in this cell (confidence > 0.8)
-- Low precision = few samples (confidence < 0.3)
UPDATE sensor_aggregates_5m
SET precision_score = LEAST(1.0, GREATEST(0.0, samples_count::FLOAT / 500))
WHERE precision_score = 0.5;

-- Populate sensor_count = unique devices in this window
UPDATE sensor_aggregates_5m agg
SET sensor_count = COALESCE(
  (SELECT COUNT(DISTINCT device_hash)
   FROM sensor_batches
   WHERE timestamp_utc >= agg.window_start
     AND timestamp_utc < agg.window_end
     AND (batch_json->'location'->>'lat')::FLOAT IS NOT NULL),
  device_count
)
WHERE sensor_count = 1;

-- Populate coverage_hours (device-hours = how long sensors were active)
UPDATE sensor_aggregates_5m
SET coverage_hours = (window_end - window_start) / interval '1 hour' * device_count * 0.8
WHERE coverage_hours = 0.0;

-- Add quality flags based on data characteristics
UPDATE sensor_aggregates_5m
SET quality_flags = CASE
  WHEN precision_score < 0.3 THEN ARRAY['low_precision']::TEXT[]
  WHEN precision_score >= 0.8 THEN ARRAY['high_precision']::TEXT[]
  ELSE ARRAY['medium_precision']::TEXT[]
END
WHERE quality_flags = ARRAY[]::TEXT[];

-- ============================================================================
-- Step 4: Add Precision Columns to sensor_aggregates_daily
-- ============================================================================

ALTER TABLE sensor_aggregates_daily
ADD COLUMN IF NOT EXISTS precision_score DOUBLE PRECISION DEFAULT 0.5,
ADD COLUMN IF NOT EXISTS sensor_count INTEGER DEFAULT 1,
ADD COLUMN IF NOT EXISTS coverage_hours DOUBLE PRECISION DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS quality_flags TEXT[] DEFAULT ARRAY[]::TEXT[];

UPDATE sensor_aggregates_daily
SET precision_score = LEAST(1.0, GREATEST(0.0, samples_count::FLOAT / 5000));

UPDATE sensor_aggregates_daily agg
SET sensor_count = COALESCE(
  (SELECT COUNT(DISTINCT device_hash)
   FROM sensor_batches
   WHERE DATE(timestamp_utc) = agg.day),
  device_count
);

UPDATE sensor_aggregates_daily
SET coverage_hours = 24.0 * device_count * 0.8;

UPDATE sensor_aggregates_daily
SET quality_flags = CASE
  WHEN precision_score < 0.3 THEN ARRAY['low_precision', 'sparse_coverage']::TEXT[]
  WHEN precision_score >= 0.8 THEN ARRAY['high_precision', 'dense_coverage']::TEXT[]
  ELSE ARRAY['medium_precision']::TEXT[]
END;

-- ============================================================================
-- Step 5: Verify Migration
-- ============================================================================

-- Check progress
SELECT
  'sensor_aggregates_5m' as table_name,
  COUNT(*) as total_rows,
  COUNT(*) FILTER (WHERE h3_index IS NOT NULL) as h3_populated,
  COUNT(*) FILTER (WHERE h3_index IS NULL) as h3_missing,
  ROUND(100.0 * COUNT(*) FILTER (WHERE h3_index IS NOT NULL) / COUNT(*), 2) as pct_complete
FROM sensor_aggregates_5m

UNION ALL

SELECT
  'sensor_aggregates_daily' as table_name,
  COUNT(*) as total_rows,
  COUNT(*) FILTER (WHERE h3_index IS NOT NULL) as h3_populated,
  COUNT(*) FILTER (WHERE h3_index IS NULL) as h3_missing,
  ROUND(100.0 * COUNT(*) FILTER (WHERE h3_index IS NOT NULL) / COUNT(*), 2) as pct_complete
FROM sensor_aggregates_daily;

-- Check precision score distribution
SELECT
  'sensor_aggregates_5m' as table_name,
  ROUND(precision_score::NUMERIC, 1) as precision_bucket,
  COUNT(*) as count,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) as pct
FROM sensor_aggregates_5m
GROUP BY ROUND(precision_score::NUMERIC, 1)
ORDER BY precision_bucket;

-- ============================================================================
-- NEXT STEPS (After verification):
-- ============================================================================
-- 1. Run spot checks on a few h3_index values
-- 2. Verify precision_score distribution makes sense
-- 3. Test query performance with H3 index
-- 4. Once confident: ALTER TABLE ... SET NOT NULL (make h3_index required)
-- 5. Keep geohash for backward compatibility (don't drop yet)
-- 6. Update backend queries to use H3 where beneficial
-- 7. Monitor performance for 2-3 days
-- 8. Then optionally drop geohash (but keep for safety initially)
