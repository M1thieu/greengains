-- Enable Row-Level Security on tables that exist in prod
-- ─────────────────────────────────────────────────────────────────────────────
-- WHY: Supabase exposes tables via PostgREST using the `anon` role. Without
-- RLS anyone with the project URL + anon key can read/write every row.
-- Backend connects via direct PostgreSQL (postgres user → BYPASSRLS), so
-- enabling RLS here has ZERO impact on backend functionality.
--
-- SCOPE: Only tables confirmed to exist in prod. org/referral/billing tables
-- are not yet migrated and are excluded intentionally.
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE sensor_batches            ENABLE ROW LEVEL SECURITY;
ALTER TABLE sensor_aggregates_5m      ENABLE ROW LEVEL SECURITY;
ALTER TABLE sensor_aggregates_daily   ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_stats                ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_tiers                ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_secrets            ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_consent_agreements   ENABLE ROW LEVEL SECURITY;

-- ─────────────────────────────────────────────────────────────────────────────
-- No anon/authenticated policies added — all access goes through the backend
-- (postgres user → BYPASSRLS). Supabase REST API is fully blocked for anon.
-- ─────────────────────────────────────────────────────────────────────────────
