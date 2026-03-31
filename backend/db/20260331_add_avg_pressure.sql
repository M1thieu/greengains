-- Add avg_pressure column to both aggregate tables
-- Previously Pressure sensor was incorrectly mapped to avg_gyro_rms (gyroscope RMS)
-- Real pressure data (hPa) is extracted from batch_json.summary.pressure.avg

ALTER TABLE sensor_aggregates_5m
  ADD COLUMN IF NOT EXISTS avg_pressure DOUBLE PRECISION;

ALTER TABLE sensor_aggregates_daily
  ADD COLUMN IF NOT EXISTS avg_pressure DOUBLE PRECISION;
