-- Add sensor_flags bitmask to sensor_batches.
-- LIGHT=1, MOTION=2, PRESSURE=4, GYRO=8, MAGNETIC=16
-- Enables B2B tier filtering (e.g. only full-sensor batches) and device capability analytics.
ALTER TABLE sensor_batches
  ADD COLUMN IF NOT EXISTS sensor_flags smallint NOT NULL DEFAULT 0;

-- Index for queries that filter by sensor availability (e.g. "only pressure data")
CREATE INDEX IF NOT EXISTS idx_sensor_batches_sensor_flags
  ON sensor_batches (sensor_flags)
  WHERE sensor_flags > 0;
