-- Fix Supabase security linter findings (2026-04-08)
-- ─────────────────────────────────────────────────────────────────────────────

-- ── ERRORs: RLS not enabled ───────────────────────────────────────────────────
-- These tables exist in prod but were missed in 20260403_enable_rls_all_tables.sql

-- referrals: backend-only (postgres/BYPASSRLS). Block all PostgREST access.
ALTER TABLE IF EXISTS referrals             ENABLE ROW LEVEL SECURITY;

-- audit_log: backend writes only. Never expose via PostgREST.
ALTER TABLE IF EXISTS audit_log             ENABLE ROW LEVEL SECURITY;

-- schema_migrations: internal tracking table — must never be user-facing.
-- REVOKE is the cleanest fix; RLS is belt-and-suspenders.
REVOKE SELECT ON schema_migrations FROM anon, authenticated;
ALTER TABLE IF EXISTS schema_migrations     ENABLE ROW LEVEL SECURITY;

-- ── WARNs: functions with mutable search_path ────────────────────────────────
-- Setting search_path = '' forces fully-qualified names, preventing
-- search_path injection attacks (a known PostgreSQL privilege escalation vector).

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
             WHERE n.nspname = 'public' AND p.proname = 'update_daily_pots_timestamp') THEN
    ALTER FUNCTION public.update_daily_pots_timestamp() SET search_path = '';
  END IF;

  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
             WHERE n.nspname = 'public' AND p.proname = 'update_updated_at_column') THEN
    ALTER FUNCTION public.update_updated_at_column() SET search_path = '';
  END IF;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- INFOs (rls_enabled_no_policy) on sensor_batches, sensor_aggregates_*,
-- user_stats, user_tiers, device_secrets, user_consent_agreements:
-- INTENTIONAL — no policies = deny-all for anon/authenticated via PostgREST.
-- Backend uses postgres role (BYPASSRLS) — unaffected.
-- See 20260403_enable_rls_all_tables.sql for rationale.
-- ─────────────────────────────────────────────────────────────────────────────
