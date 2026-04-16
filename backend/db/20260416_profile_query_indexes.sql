-- Performance: covering indexes for /api/user/profile
-- Date: 2026-04-16
-- Run in Supabase SQL editor. All use IF NOT EXISTS — safe to re-run.
--
-- Problem: COUNT(DISTINCT h3_res9) in the profile query does a sequential scan
-- over all rows for a user because the existing idx_sb_user_created is on
-- (user_id, created_at) — h3_res9 is not covered.
-- The streak CTE also reads all distinct dates for a user with no date index.
--
-- Fix 1: covering index for coverage_cells count + daily aggregation
CREATE INDEX IF NOT EXISTS idx_sb_user_h3
  ON sensor_batches (user_id, h3_res9)
  WHERE user_id IS NOT NULL AND h3_res9 IS NOT NULL;

-- Fix 2: covering index for days_active + streak CTE (DATE(timestamp_utc) per user)
-- Postgres can derive DATE(timestamp_utc) from timestamp_utc with this index.
CREATE INDEX IF NOT EXISTS idx_sb_user_date
  ON sensor_batches (user_id, timestamp_utc)
  WHERE user_id IS NOT NULL;
