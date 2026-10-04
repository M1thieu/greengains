-- 1-sigma uncertainty of avg_pressure (hPa) per 5-minute cell.
-- Combines within-batch noise and the typical per-phone barometer bias
-- (~1 hPa, shrinking with the number of devices). Any consumer that blends
-- these observations with a model (data assimilation, simulation) needs it.
-- Null when the cell had no pressure readings.
-- Safe to re-run: IF NOT EXISTS.

ALTER TABLE sensor_aggregates_5m
  ADD COLUMN IF NOT EXISTS pressure_sigma_hpa double precision;
