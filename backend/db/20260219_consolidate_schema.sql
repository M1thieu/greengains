-- Migration: Consolidate Schema
-- Date: 2026-02-19
-- Purpose: Replace over-engineered 4-table org/subscription system with a single
--          user_tiers table. Drop dormant daily_pots and user_preferences tables.
--          Final table count: sensor_batches, sensor_aggregates_5m,
--          sensor_aggregates_daily, user_stats, device_secrets, api_keys (simplified),
--          user_tiers, audit_log (simplified), schema_migrations.

BEGIN;

-- ============================================================================
-- Step 1: Create user_tiers
-- Simple: one row per user, one tier column. Replaces 4 tables.
-- ============================================================================

CREATE TABLE IF NOT EXISTS user_tiers (
  user_id   TEXT        NOT NULL PRIMARY KEY,
  tier      TEXT        NOT NULL DEFAULT 'free' CHECK (tier IN ('free', 'pro', 'enterprise')),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_tiers_tier ON user_tiers(tier);

-- ============================================================================
-- Step 2: Migrate existing tier data (safe: no-op if org tables don't exist)
-- ============================================================================

DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'organization_members'
  ) THEN
    INSERT INTO user_tiers (user_id, tier)
    SELECT
      om.user_id,
      COALESCE(s.tier, 'free') AS tier
    FROM organization_members om
    LEFT JOIN subscriptions s ON s.organization_id = om.organization_id
    WHERE om.accepted_at IS NOT NULL
    ON CONFLICT (user_id) DO NOTHING;
  END IF;
END $$;

-- ============================================================================
-- Step 3: Fix audit_log — remove FK reference to organizations
-- ============================================================================

ALTER TABLE audit_log DROP CONSTRAINT IF EXISTS audit_log_organization_id_fkey;
ALTER TABLE audit_log DROP COLUMN IF EXISTS organization_id;

-- ============================================================================
-- Step 4: Fix api_keys — remove FK reference to organizations then drop table
-- (api_keys were only useful for org-scoped programmatic access; that feature
--  is removed. The analytics endpoint uses a static env-var key instead.)
-- ============================================================================

DO $$ BEGIN
  ALTER TABLE api_keys DROP CONSTRAINT IF EXISTS api_keys_organization_id_fkey;
EXCEPTION WHEN undefined_table THEN NULL;
END $$;
DROP TABLE IF EXISTS api_keys;

-- ============================================================================
-- Step 5: Drop org/subscription tables (dependency order: children first)
-- ============================================================================

DROP TABLE IF EXISTS subscription_features;
DROP TABLE IF EXISTS subscriptions;
DROP TABLE IF EXISTS organization_members;
DROP TABLE IF EXISTS organizations;

-- ============================================================================
-- Step 6: Drop dormant feature tables
-- ============================================================================

DROP TABLE IF EXISTS daily_pots;
DROP TABLE IF EXISTS user_preferences;

COMMIT;
