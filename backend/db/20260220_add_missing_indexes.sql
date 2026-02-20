-- Migration: Add missing performance indexes for user-scoped queries
-- Safe to re-run (IF NOT EXISTS on all)

-- Speeds up GET /api/user/profile which aggregates stats per user_id
-- and ORDER BY last_upload_at DESC for device leaderboard
CREATE INDEX IF NOT EXISTS idx_user_stats_user_id
  ON user_stats(user_id, last_upload_at DESC);

-- Speeds up GET /api/user/tiles which queries sensor_batches by user_id
-- and also joins with device_hash for per-device breakdown
CREATE INDEX IF NOT EXISTS idx_sensor_batches_user_device
  ON sensor_batches(user_id, device_hash);
