-- Migration: Organizations & Subscriptions
-- Date: 2026-02-15
-- Purpose: Multi-tenant support + subscription tier management for B2B RSE customers

-- ============================================================================
-- Table: organizations
-- ============================================================================
-- Represents a company/team using GreenGains
-- Each org has multiple users (members) and can have multiple subscriptions

CREATE TABLE IF NOT EXISTS organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  slug VARCHAR(100) UNIQUE NOT NULL,  -- For URLs: /orgs/{slug}
  description TEXT,
  logo_url VARCHAR(512),
  created_by UUID NOT NULL,  -- Reference to users table (Firebase UID)
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,  -- Soft delete

  UNIQUE (slug)
);

CREATE INDEX idx_organizations_created_by ON organizations(created_by);
CREATE INDEX idx_organizations_slug ON organizations(slug) WHERE deleted_at IS NULL;
CREATE INDEX idx_organizations_created_at ON organizations(created_at DESC);

-- ============================================================================
-- Table: organization_members
-- ============================================================================
-- Join table: users to organizations
-- Tracks role (admin, editor, viewer) + invitation status

CREATE TABLE IF NOT EXISTS organization_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  user_id VARCHAR(255) NOT NULL,  -- Firebase UID
  email VARCHAR(255) NOT NULL,
  role VARCHAR(50) NOT NULL DEFAULT 'viewer',  -- admin, editor, viewer
  invited_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  accepted_at TIMESTAMPTZ,  -- NULL = pending invitation
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (organization_id, user_id),
  CONSTRAINT valid_role CHECK (role IN ('admin', 'editor', 'viewer'))
);

CREATE INDEX idx_organization_members_org ON organization_members(organization_id);
CREATE INDEX idx_organization_members_user ON organization_members(user_id);
CREATE INDEX idx_organization_members_accepted ON organization_members(accepted_at) WHERE accepted_at IS NULL;

-- ============================================================================
-- Table: subscriptions
-- ============================================================================
-- Subscription tier + billing info per organization

CREATE TABLE IF NOT EXISTS subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL UNIQUE REFERENCES organizations(id) ON DELETE CASCADE,
  tier VARCHAR(50) NOT NULL DEFAULT 'free',  -- free, pro, enterprise
  status VARCHAR(50) NOT NULL DEFAULT 'active',  -- active, canceled, past_due
  stripe_customer_id VARCHAR(255) UNIQUE,  -- Stripe customer ID
  stripe_subscription_id VARCHAR(255) UNIQUE,  -- Stripe subscription ID
  billing_email VARCHAR(255),
  billing_period_start TIMESTAMPTZ,
  billing_period_end TIMESTAMPTZ,
  current_period_start TIMESTAMPTZ,
  current_period_end TIMESTAMPTZ,
  cancel_at_period_end BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT valid_tier CHECK (tier IN ('free', 'pro', 'enterprise')),
  CONSTRAINT valid_status CHECK (status IN ('active', 'canceled', 'past_due', 'inactive'))
);

CREATE INDEX idx_subscriptions_org ON subscriptions(organization_id);
CREATE INDEX idx_subscriptions_tier ON subscriptions(tier);
CREATE INDEX idx_subscriptions_stripe_customer ON subscriptions(stripe_customer_id);
CREATE INDEX idx_subscriptions_updated_at ON subscriptions(updated_at DESC);

-- ============================================================================
-- Table: subscription_features
-- ============================================================================
-- Defines what features each tier has
-- Denormalized for fast permission checks

CREATE TABLE IF NOT EXISTS subscription_features (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
  feature_name VARCHAR(100) NOT NULL,  -- data_retention_days, max_exports_per_month, etc.
  feature_value VARCHAR(255) NOT NULL,  -- "7", "100", "true", etc.
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (subscription_id, feature_name)
);

CREATE INDEX idx_subscription_features_sub ON subscription_features(subscription_id);

-- ============================================================================
-- Table: api_keys
-- ============================================================================
-- API keys for organizations (for programmatic dashboard access)

CREATE TABLE IF NOT EXISTS api_keys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  key_hash VARCHAR(255) NOT NULL,  -- SHA-256 hash of actual key
  key_preview VARCHAR(20) NOT NULL,  -- "sk_live_abc123..." (last 4 chars)
  last_used_at TIMESTAMPTZ,
  created_by UUID NOT NULL,  -- User who created it
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  is_active BOOLEAN DEFAULT TRUE,

  UNIQUE (organization_id, key_hash)
);

CREATE INDEX idx_api_keys_org ON api_keys(organization_id);
CREATE INDEX idx_api_keys_hash ON api_keys(key_hash);
CREATE INDEX idx_api_keys_active ON api_keys(is_active) WHERE is_active = TRUE;

-- ============================================================================
-- Table: audit_log
-- ============================================================================
-- Track who did what and when (compliance + debugging)

CREATE TABLE IF NOT EXISTS audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE SET NULL,
  user_id VARCHAR(255),
  action VARCHAR(100) NOT NULL,  -- export_requested, api_key_created, member_invited, etc.
  resource_type VARCHAR(50),  -- subscription, api_key, member, data_export
  resource_id VARCHAR(255),
  details JSONB,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_log_org ON audit_log(organization_id, created_at DESC);
CREATE INDEX idx_audit_log_user ON audit_log(user_id, created_at DESC);
CREATE INDEX idx_audit_log_action ON audit_log(action, created_at DESC);

-- ============================================================================
-- Default Tier Definitions
-- ============================================================================
-- These insert feature rows for each tier
-- Run after subscriptions table is created

-- Tier: FREE
INSERT INTO subscription_features (subscription_id, feature_name, feature_value)
SELECT subscriptions.id, 'data_retention_days', '7'
FROM subscriptions WHERE tier = 'free'
ON CONFLICT (subscription_id, feature_name) DO NOTHING;

INSERT INTO subscription_features (subscription_id, feature_name, feature_value)
SELECT subscriptions.id, 'max_exports_per_month', '5'
FROM subscriptions WHERE tier = 'free'
ON CONFLICT (subscription_id, feature_name) DO NOTHING;

INSERT INTO subscription_features (subscription_id, feature_name, feature_value)
SELECT subscriptions.id, 'api_access', 'false'
FROM subscriptions WHERE tier = 'free'
ON CONFLICT (subscription_id, feature_name) DO NOTHING;

-- Tier: PRO
INSERT INTO subscription_features (subscription_id, feature_name, feature_value)
SELECT subscriptions.id, 'data_retention_days', '90'
FROM subscriptions WHERE tier = 'pro'
ON CONFLICT (subscription_id, feature_name) DO NOTHING;

INSERT INTO subscription_features (subscription_id, feature_name, feature_value)
SELECT subscriptions.id, 'max_exports_per_month', '100'
FROM subscriptions WHERE tier = 'pro'
ON CONFLICT (subscription_id, feature_name) DO NOTHING;

INSERT INTO subscription_features (subscription_id, feature_name, feature_value)
SELECT subscriptions.id, 'api_access', 'true'
FROM subscriptions WHERE tier = 'pro'
ON CONFLICT (subscription_id, feature_name) DO NOTHING;

INSERT INTO subscription_features (subscription_id, feature_name, feature_value)
SELECT subscriptions.id, 'esg_reports', 'true'
FROM subscriptions WHERE tier = 'pro'
ON CONFLICT (subscription_id, feature_name) DO NOTHING;

-- Tier: ENTERPRISE
INSERT INTO subscription_features (subscription_id, feature_name, feature_value)
SELECT subscriptions.id, 'data_retention_days', '365'
FROM subscriptions WHERE tier = 'enterprise'
ON CONFLICT (subscription_id, feature_name) DO NOTHING;

INSERT INTO subscription_features (subscription_id, feature_name, feature_value)
SELECT subscriptions.id, 'max_exports_per_month', 'unlimited'
FROM subscriptions WHERE tier = 'enterprise'
ON CONFLICT (subscription_id, feature_name) DO NOTHING;

INSERT INTO subscription_features (subscription_id, feature_name, feature_value)
SELECT subscriptions.id, 'api_access', 'true'
FROM subscriptions WHERE tier = 'enterprise'
ON CONFLICT (subscription_id, feature_name) DO NOTHING;

INSERT INTO subscription_features (subscription_id, feature_name, feature_value)
SELECT subscriptions.id, 'esg_reports', 'true'
FROM subscriptions WHERE tier = 'enterprise'
ON CONFLICT (subscription_id, feature_name) DO NOTHING;

INSERT INTO subscription_features (subscription_id, feature_name, feature_value)
SELECT subscriptions.id, 'sso', 'true'
FROM subscriptions WHERE tier = 'enterprise'
ON CONFLICT (subscription_id, feature_name) DO NOTHING;

INSERT INTO subscription_features (subscription_id, feature_name, feature_value)
SELECT subscriptions.id, 'dedicated_support', 'true'
FROM subscriptions WHERE tier = 'enterprise'
ON CONFLICT (subscription_id, feature_name) DO NOTHING;

-- ============================================================================
-- Verify Schema
-- ============================================================================

SELECT
  tablename,
  ROUND(pg_total_relation_size('organizations'::regclass) / 1024.0 / 1024, 2) as size_mb
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN (
    'organizations', 'organization_members', 'subscriptions',
    'subscription_features', 'api_keys', 'audit_log'
  );
