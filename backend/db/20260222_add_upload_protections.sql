-- ============================================================
-- Upload abuse prevention: deduplication unique index
-- ============================================================
-- Prevents duplicate batch submissions. A device uploading the same
-- batch twice (e.g. on retry after network timeout) will be silently
-- ignored by the ON CONFLICT DO NOTHING clause in upload.ts.
--
-- Also blocks an attacker from filling the table with identical timestamps
-- under the same device_hash. Safe to re-run (IF NOT EXISTS).
-- ============================================================

CREATE UNIQUE INDEX IF NOT EXISTS idx_sensor_batches_dedup
  ON sensor_batches (device_hash, timestamp_utc);
