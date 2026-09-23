-- Add pressure_anomaly_hpa to the 5-minute aggregate table.
-- Local avg_pressure minus regional weather background (Open-Meteo surface_pressure)
-- at the window's centroid/time — isolates local effects (elevation, tunnels,
-- microclimate) from passing weather systems. Optimal-Interpolation-style
-- "observation minus background". Null when the weather lookup failed or no
-- pressure data was available for the window.
-- Not added to sensor_aggregates_daily: averaging a day's worth of anomalies
-- against a single background value would conflate real day-long weather
-- swings with local effects — needs its own per-hour treatment, deferred.
-- Safe to re-run: IF NOT EXISTS.

ALTER TABLE sensor_aggregates_5m
  ADD COLUMN IF NOT EXISTS pressure_anomaly_hpa double precision;
