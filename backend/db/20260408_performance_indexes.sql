-- Performance indexes — April 2026
-- Run in Supabase SQL editor. All use IF NOT EXISTS — safe to re-run.

-- 1. Rate-limit queries filter on created_at but the existing device index uses
--    timestamp_utc. Without these, both COUNT queries on every upload do partial
--    table scans. These cover checkDeviceRateLimit and checkUserRateLimit exactly.
CREATE INDEX IF NOT EXISTS idx_sb_device_created
  ON sensor_batches (device_hash, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_sb_user_created
  ON sensor_batches (user_id, created_at DESC)
  WHERE user_id IS NOT NULL;

-- 2. H3 backfill partial index — runH3Backfill() runs on every startup and
--    queries WHERE h3_res9 IS NULL. Without this it scans the full table even
--    when the backfill is 100% complete.
CREATE INDEX IF NOT EXISTS idx_sb_h3_backfill
  ON sensor_batches (id)
  WHERE h3_res9 IS NULL;
