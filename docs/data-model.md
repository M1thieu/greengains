# GreenGains world data: what is stored and what it means

Reference for anything that consumes GreenGains measurements outside the app
(dashboard, B2B export, a simulation or game engine). No API is promised here;
this describes the data as it sits in the database.

## Unit of observation: one H3 cell, one 5-minute window

Table `sensor_aggregates_5m`, one row per (`window_start`, cell).

| Column | Unit | Meaning |
|---|---|---|
| `window_start`, `window_end` | UTC timestamp | 5-minute window |
| `h3_index` | H3 res 9 (~174 m) | Where. `geohash` is the legacy key |
| `samples_count` | readings | How many readings went into the cell |
| `device_count` | phones | How many distinct phones (independent sources) |
| `avg_pressure` | hPa | Station pressure (as measured, not reduced to sea level), lightly blended with neighbouring cells |
| `pressure_sigma_hpa` | hPa, 1-sigma | Uncertainty of `avg_pressure`: reading noise plus ~1 hPa per-phone bias, divided across phones |
| `pressure_anomaly_hpa` | hPa | `avg_pressure` minus Open-Meteo surface pressure for the same place and time: the local signal once weather is removed |
| `weather_temp_c` | °C | Regional 2 m air temperature (Open-Meteo), context only; phones do not measure it |
| `avg_light`, `avg_light_min`, `avg_light_max` | lux | Ambient light, outliers filtered, readings from pockets and face-down phones excluded at collection |
| `movement_score` | 0-1 | How much motion the readings imply |
| `vibration_score` | 0-1 | Surface roughness proxy (accelerometer spread) |
| `quality_valid_ratio`, `quality_pocket_ratio` | 0-1 | Share of readings that passed quality checks / looked pocketed |

A daily rollup (`sensor_aggregates_daily`) carries the same fields per day.

## Accuracy, from the literature and the pipeline

- Pressure: excellent relative precision (~0.1 hPa), ~±1 hPa absolute per
  uncalibrated phone. `pressure_sigma_hpa` encodes this. Per-model calibration
  (raw batches carry `device_model`) is the next step to lower it.
- Light: per-model bias up to ±60 % uncalibrated; treat as relative within a
  cell over time until per-model factors exist.
- Vibration / movement: good for comparing places and times; correlation with
  reference road-roughness instruments ~0.7 single pass, ~0.85+ with repeats.
- Position: cells are assigned from fixes with ≤50 m accuracy (≤150 m when
  still); a cell (~174 m) is the finest meaningful unit.

## Privacy guarantees a consumer can rely on

- Aggregates carry no user id and no device id.
- Raw batches store location rounded to ~110 m, never a precise trail.
- Raw batches are kept 90 days; aggregates are kept and stay anonymous after an
  account is deleted (`DELETE /api/user/account` removes everything else).

## For a simulation or game engine

Treat each row as an observation `(cell, time, value, sigma, sources)` to blend
with the engine's own model (data assimilation), not as ground truth that
overwrites it. Cells without phones have no rows: the engine fills them.
