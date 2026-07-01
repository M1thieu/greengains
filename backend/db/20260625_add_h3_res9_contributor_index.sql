-- Performance: index for /api/user/impact ("only you have ever mapped this" signal)
-- Date: 2026-06-25
-- Run in Supabase SQL editor. Uses IF NOT EXISTS — safe to re-run.
--
-- Existing idx_sb_user_h3 is (user_id, h3_res9) — great for "find this user's
-- cells" but useless for "find every contributor to these cells" since that
-- query has no user_id filter. Without this index it falls back to a
-- sequential scan over sensor_batches whenever a user has any history.
CREATE INDEX IF NOT EXISTS idx_sensor_batches_h3_res9_contributors
  ON sensor_batches (h3_res9, user_id)
  WHERE h3_res9 IS NOT NULL;
