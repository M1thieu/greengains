-- Migration: Performance indexes + schema correctness fixes
-- Date: 2026-02-18
--
-- Fixes:
--   1. Add composite indexes on sensor_aggregates_5m and _daily
--      Primary query pattern: WHERE window_start BETWEEN $1 AND $2 ORDER BY window_start ASC, geohash ASC
--      Single-column indexes on window_start and geohash separately are suboptimal for this.
--   2. Fix organizations.created_by: Firebase UIDs are TEXT, not UUID.
--      The column was declared UUID NOT NULL, which causes a type violation on every org creation.
--   3. Fix audit_log.organization_id: NOT NULL + ON DELETE SET NULL is contradictory.
--      Postgres would error at runtime when an org is deleted because it can't set a NOT NULL column to NULL.

-- ── 1. Composite indexes for primary query pattern ──────────────────────────

-- Covers: WHERE window_start >= $1 AND window_start <= $2 [AND geohash LIKE $3]
--         ORDER BY window_start ASC, geohash ASC
-- Replaces the less efficient pair of single-column indexes for this access pattern.
CREATE INDEX IF NOT EXISTS idx_sensor_aggregates_5m_time_geohash
    ON sensor_aggregates_5m (window_start ASC, geohash ASC);

-- Same for daily rollups (used in bucket=day queries)
CREATE INDEX IF NOT EXISTS idx_sensor_aggregates_daily_day_geohash
    ON sensor_aggregates_daily (day ASC, geohash ASC);

-- Coverage endpoint groups by geohash over a time range — helps GROUP BY after WHERE
CREATE INDEX IF NOT EXISTS idx_sensor_aggregates_5m_geohash_time
    ON sensor_aggregates_5m (geohash, window_start DESC);

-- ── 2. Fix organizations.created_by type (UUID → TEXT) ─────────────────────
-- Wrapped in DO block so this is safe to run even if organizations was already
-- dropped by the 20260219 consolidation migration.

DO $$ BEGIN
    ALTER TABLE organizations ALTER COLUMN created_by TYPE VARCHAR(255);
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

-- ── 3. Fix audit_log.organization_id NOT NULL constraint ───────────────────
-- Wrapped in DO block so this is safe if the column was already dropped.

DO $$ BEGIN
    ALTER TABLE audit_log ALTER COLUMN organization_id DROP NOT NULL;
EXCEPTION WHEN undefined_column THEN NULL;
              WHEN undefined_table THEN NULL;
END $$;
