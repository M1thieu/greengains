-- Migration: Backfill user_id into sensor_batches/user_stats from device_secrets
-- Date: 2026-03-20
--
-- Root cause: user_stats.user_id can be NULL when:
--   1. Device uploaded before /register-device was called with a Firebase token
--   2. ANDROID_ID changed across app reinstalls (signing key change in Android 8+)
--
-- This migration links all unattributed data to the correct user_id via device_secrets,
-- and ensures the profile endpoint can use user_stats as a fast cache again.

-- Step 1: Propagate user_id from device_secrets → sensor_batches
-- (only rows where device_hash matches and user_id is currently NULL)
UPDATE sensor_batches sb
SET user_id = ds.user_id
FROM device_secrets ds
WHERE sb.device_hash = encode(sha256(ds.device_id::bytea), 'hex')
  AND sb.user_id IS NULL
  AND ds.user_id IS NOT NULL;

-- Step 2: Propagate user_id from device_secrets → user_stats
UPDATE user_stats us
SET user_id = ds.user_id
FROM device_secrets ds
WHERE us.device_hash = encode(sha256(ds.device_id::bytea), 'hex')
  AND us.user_id IS NULL
  AND ds.user_id IS NOT NULL;

-- Step 3: Also propagate from sensor_batches → user_stats for any remaining gaps
-- (catches cases where device_secrets row was deleted but sensor_batches has user_id)
UPDATE user_stats us
SET user_id = sb.user_id
FROM (
  SELECT DISTINCT device_hash, user_id
  FROM sensor_batches
  WHERE user_id IS NOT NULL
) sb
WHERE us.device_hash = sb.device_hash
  AND us.user_id IS NULL;

-- Step 4: Rebuild user_stats totals for devices that now have a user_id
-- (recalculates samples_count from sensor_batches so the cache is accurate)
-- Run this only for devices that were just fixed (safe to re-run, uses ON CONFLICT)
INSERT INTO user_stats (device_hash, user_id, samples_count, last_upload_at)
SELECT
  sb.device_hash,
  sb.user_id,
  COUNT(*)                   AS samples_count,
  MAX(sb.timestamp_utc)      AS last_upload_at
FROM sensor_batches sb
WHERE sb.user_id IS NOT NULL
GROUP BY sb.device_hash, sb.user_id
ON CONFLICT (device_hash) DO UPDATE SET
  user_id        = EXCLUDED.user_id,
  samples_count  = EXCLUDED.samples_count,
  last_upload_at = GREATEST(user_stats.last_upload_at, EXCLUDED.last_upload_at),
  updated_at     = NOW();
