-- user_profile_cache: single-row-per-user materialized stats
-- Date: 2026-04-16
--
-- Motivation: /api/user/profile currently runs 3 queries against sensor_batches
-- (scalar stats + streak CTE + weekly), each doing full table scans per user.
-- This table is a write-through cache maintained on every upload, so profile
-- reads become a single primary key lookup instead of 3 aggregate queries.
--
-- The in-memory 60s cache in the app server (Fix 1) means most reads never
-- hit the DB at all. This table is the fallback when the in-memory cache misses.

CREATE TABLE IF NOT EXISTS public.user_profile_cache (
  user_id         TEXT        PRIMARY KEY,
  total_batches   INT         NOT NULL DEFAULT 0,
  coverage_cells  INT         NOT NULL DEFAULT 0,  -- distinct h3_res9 cells
  days_active     INT         NOT NULL DEFAULT 0,  -- distinct upload dates
  current_streak  INT         NOT NULL DEFAULT 0,  -- consecutive days up to today
  longest_streak  INT         NOT NULL DEFAULT 0,
  first_upload_at TIMESTAMPTZ,
  last_upload_at  TIMESTAMPTZ,
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.user_profile_cache IS
  'Write-through cache for per-user profile stats. Refreshed on every upload. '
  'Profile endpoint reads here first; falls back to live sensor_batches queries if row missing.';

-- Backfill from existing sensor_batches data
-- (streak columns left at 0 — acceptable for historical data, live on next upload)
INSERT INTO public.user_profile_cache (
  user_id, total_batches, coverage_cells, days_active,
  first_upload_at, last_upload_at, updated_at
)
SELECT
  user_id,
  COUNT(*)::int                                                     AS total_batches,
  COUNT(DISTINCT h3_res9) FILTER (WHERE h3_res9 IS NOT NULL)::int  AS coverage_cells,
  COUNT(DISTINCT DATE(timestamp_utc))::int                         AS days_active,
  MIN(timestamp_utc)                                               AS first_upload_at,
  MAX(timestamp_utc)                                               AS last_upload_at,
  NOW()                                                            AS updated_at
FROM public.sensor_batches
WHERE user_id IS NOT NULL
GROUP BY user_id
ON CONFLICT (user_id) DO UPDATE SET
  total_batches   = EXCLUDED.total_batches,
  coverage_cells  = EXCLUDED.coverage_cells,
  days_active     = EXCLUDED.days_active,
  first_upload_at = EXCLUDED.first_upload_at,
  last_upload_at  = EXCLUDED.last_upload_at,
  updated_at      = EXCLUDED.updated_at;
