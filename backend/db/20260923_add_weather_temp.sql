-- Add weather_temp_c to the 5-minute aggregate table.
-- Regional air temperature at 2m (Open-Meteo) at the window's centroid/time.
-- Stored raw, not as an anomaly: phones have no reliable ambient thermometer,
-- so there is no local measurement to difference it against. This is context
-- for the cell/window, and the background field any future temperature model
-- would need. Comes from the same weather fetch that already backs
-- pressure_anomaly_hpa, so it costs no extra API call.
-- Null when the weather lookup failed.
-- Safe to re-run: IF NOT EXISTS.

ALTER TABLE sensor_aggregates_5m
  ADD COLUMN IF NOT EXISTS weather_temp_c double precision;
