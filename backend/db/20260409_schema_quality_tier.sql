-- Schema improvements — April 2026
-- Run in Supabase SQL editor. All use IF NOT EXISTS / DO $$ — safe to re-run.
--
-- 1. Add quality_tier computed column on sensor_aggregates_daily
--    Materializes the tier at aggregation time so tile queries don't need
--    to compute it at read time. Tier: 'excellent' | 'good' | 'fair'
--
-- 2. Add last_upload_at to users table (denormalized for profile screen)
--    Avoids a MAX(timestamp_utc) scan on sensor_batches for the profile page.
--
-- 3. Add upload_count to users table (running counter, incremented at upload)
--    Eliminates COUNT(*) on sensor_batches for the review prompt threshold.
--
-- 4. Partial index: recent sensor_batches for tile queries (30d window)
--    The user/tiles endpoint only looks at the last 30 days for personal tiles.

-- ── 1. quality_tier on sensor_aggregates_daily ────────────────────────────────
ALTER TABLE sensor_aggregates_daily
  ADD COLUMN IF NOT EXISTS quality_tier TEXT
    GENERATED ALWAYS AS (
      CASE
        WHEN quality_valid_ratio >= 0.75 THEN 'excellent'
        WHEN quality_valid_ratio >= 0.50 THEN 'good'
        ELSE 'fair'
      END
    ) STORED;

-- Index for tier-filtered queries (future: filter by quality in tile endpoints)
CREATE INDEX IF NOT EXISTS idx_aggd_quality_tier
  ON sensor_aggregates_daily (quality_tier, day DESC)
  WHERE quality_tier IS NOT NULL;

-- ── 2 & 3. users table — last_upload_at + upload_count ───────────────────────
-- user_stats already exists; add columns if not present.
ALTER TABLE user_stats
  ADD COLUMN IF NOT EXISTS last_upload_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS upload_count   INT NOT NULL DEFAULT 0;

-- Backfill from sensor_batches (one-time)
UPDATE user_stats us
SET
  last_upload_at = sub.last_upload,
  upload_count   = sub.cnt
FROM (
  SELECT
    user_id,
    MAX(timestamp_utc) AS last_upload,
    COUNT(*)::int      AS cnt
  FROM sensor_batches
  WHERE user_id IS NOT NULL
  GROUP BY user_id
) sub
WHERE us.user_id = sub.user_id
  AND us.last_upload_at IS NULL;  -- only backfill rows not yet populated

-- ── 4. Partial index for recent batches (tile + aggregator queries) ───────────
-- Personal tile query: WHERE user_id = $1 AND timestamp_utc > (now - 90d)
-- Existing idx_sb_user_h3_time covers this for migrated rows.
-- Add a complementary index for the recency filter on all rows.
CREATE INDEX IF NOT EXISTS idx_sb_user_recent
  ON sensor_batches (user_id, timestamp_utc DESC)
  WHERE user_id IS NOT NULL
    AND timestamp_utc > NOW() - INTERVAL '90 days';
