-- Phone model ("<manufacturer> <model>") per batch.
-- Phone sensors carry a stable per-model bias (published studies: barometer
-- ±1-2 hPa, ambient light up to ±60 %). Correcting it requires knowing which
-- model produced each reading; until now that was never recorded.
-- Nullable: older app versions do not send it.
-- Safe to re-run: IF NOT EXISTS.

ALTER TABLE sensor_batches
  ADD COLUMN IF NOT EXISTS device_model text;
