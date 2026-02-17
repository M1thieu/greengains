-- Data Migration: Populate H3 indexes from existing geohash data
-- IMPORTANT: This is a ONE-TIME data migration after adding h3_index columns
--
-- This migration extracts lat/lon from batch_json in sensor_batches,
-- then updates aggregation tables with corresponding H3 indexes.
--
-- RUN THIS MANUALLY after deploying 20260215_add_h3_indexes.sql

-- Step 1: Update sensor_batches with H3 indexes
-- (This requires backend script since H3 calculation needs h3-js library)
-- Backend will:
--   1. SELECT id, batch_json FROM sensor_batches WHERE h3_index IS NULL
--   2. Extract location.lat, location.lon from batch_json
--   3. Calculate H3 index using h3-js
--   4. UPDATE sensor_batches SET h3_index = <calculated> WHERE id = <id>

-- Step 2: Update sensor_aggregates_5m using geohash mapping
-- Since we don't have direct lat/lon in aggregates, we'll use existing geohash
-- to find corresponding sensor_batches and copy their h3_index

UPDATE sensor_aggregates_5m agg
SET h3_index = (
  SELECT DISTINCT sb.h3_index
  FROM sensor_batches sb
  WHERE sb.batch_json->>'geohash' = agg.geohash
    AND sb.h3_index IS NOT NULL
  LIMIT 1
)
WHERE agg.h3_index IS NULL
  AND agg.geohash IS NOT NULL;

-- Step 3: Update sensor_aggregates_daily using same approach
UPDATE sensor_aggregates_daily agg
SET h3_index = (
  SELECT DISTINCT sb.h3_index
  FROM sensor_batches sb
  WHERE sb.batch_json->>'geohash' = agg.geohash
    AND sb.h3_index IS NOT NULL
  LIMIT 1
)
WHERE agg.h3_index IS NULL
  AND agg.geohash IS NOT NULL;

-- Verify migration results
SELECT
  'sensor_aggregates_5m' as table_name,
  COUNT(*) as total_rows,
  COUNT(h3_index) as h3_populated,
  COUNT(geohash) as geohash_populated,
  COUNT(*) - COUNT(h3_index) as missing_h3
FROM sensor_aggregates_5m

UNION ALL

SELECT
  'sensor_aggregates_daily' as table_name,
  COUNT(*) as total_rows,
  COUNT(h3_index) as h3_populated,
  COUNT(geohash) as geohash_populated,
  COUNT(*) - COUNT(h3_index) as missing_h3
FROM sensor_aggregates_daily

UNION ALL

SELECT
  'sensor_batches' as table_name,
  COUNT(*) as total_rows,
  COUNT(h3_index) as h3_populated,
  COUNT(batch_json->>'geohash') as geohash_populated,
  COUNT(*) - COUNT(h3_index) as missing_h3
FROM sensor_batches;

-- Expected result: All rows should have h3_index populated
-- If missing_h3 > 0, investigate those rows
