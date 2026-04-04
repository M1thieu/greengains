-- Enable Row-Level Security on all public tables
-- ─────────────────────────────────────────────────────────────────────────────
-- WHY: Supabase exposes tables via its REST API (PostgREST) using the `anon`
-- role. Without RLS, anyone with the project URL + anon key can read/write
-- every row. Our backend connects via direct PostgreSQL (postgres user) which
-- has BYPASSRLS, so enabling RLS here has ZERO impact on backend functionality.
--
-- POLICY DESIGN: No permissive policies are added for anon or authenticated
-- roles — the backend never uses Supabase JWT auth, only Firebase via our own
-- middleware. Blocking public REST access entirely is the correct posture.
-- ─────────────────────────────────────────────────────────────────────────────

-- Core sensor data
ALTER TABLE sensor_batches            ENABLE ROW LEVEL SECURITY;
ALTER TABLE sensor_aggregates_5m      ENABLE ROW LEVEL SECURITY;
ALTER TABLE sensor_aggregates_daily   ENABLE ROW LEVEL SECURITY;

-- User data
ALTER TABLE user_stats                ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_tiers                ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_secrets            ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_consent_agreements   ENABLE ROW LEVEL SECURITY;

-- Org & billing
ALTER TABLE organizations             ENABLE ROW LEVEL SECURITY;
ALTER TABLE organization_members      ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions             ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription_features     ENABLE ROW LEVEL SECURITY;
ALTER TABLE api_keys                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log                 ENABLE ROW LEVEL SECURITY;

-- Referrals
ALTER TABLE referral_codes            ENABLE ROW LEVEL SECURITY;
ALTER TABLE referral_events           ENABLE ROW LEVEL SECURITY;
ALTER TABLE referrals                 ENABLE ROW LEVEL SECURITY;

-- Misc
ALTER TABLE daily_pots                ENABLE ROW LEVEL SECURITY;

-- ─────────────────────────────────────────────────────────────────────────────
-- No anon/authenticated policies are added intentionally.
-- All access goes through the backend (postgres user → BYPASSRLS).
-- If Supabase dashboard access is needed, use the service_role key directly.
-- ─────────────────────────────────────────────────────────────────────────────
