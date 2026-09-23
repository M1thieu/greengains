-- Recompute movement_score under the gravity-agnostic rule.
--
-- accel_rms arrives under two conventions: linear acceleration (gravity removed,
-- ~0 at rest) or raw accelerometer (gravity included, ~9.81 at rest). The old
-- score assumed the second unconditionally, which inverted every reading of the
-- first kind — a motionless phone scored 1.0. 1134 of 1532 rows (74%) were
-- saturated at maximum movement as a result.
--
-- New rule (mirrors movementScore() in jobs/aggregator.ts): evaluate both
-- interpretations and keep whichever implies less motion. Each convention's
-- resting case reads correctly under its own interpretation, so the minimum
-- always picks the right one.
--
-- Fully recomputable in either direction from avg_accel_rms, which is retained,
-- so this is reversible.
-- Safe to re-run: the expression is idempotent given avg_accel_rms.

UPDATE sensor_aggregates_5m
SET movement_score = LEAST(1.0, GREATEST(0.0,
      LEAST(ABS(avg_accel_rms), ABS(avg_accel_rms - 9.81)) / 5.0))
WHERE avg_accel_rms IS NOT NULL;

UPDATE sensor_aggregates_daily
SET movement_score = LEAST(1.0, GREATEST(0.0,
      LEAST(ABS(avg_accel_rms), ABS(avg_accel_rms - 9.81)) / 5.0))
WHERE avg_accel_rms IS NOT NULL;
