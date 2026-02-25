-- ============================================================
-- Unify referral_codes + referral_events into a single `referrals` table.
--
-- event_type discriminator:
--   'code'    — one row per user, holds their stable referral code
--   'invite'  — logged each time the owner copies/shares their link
--   'convert' — logged when a new user signs up via a referral link
--
-- Replaces:
--   referral_codes  (from 20260225_add_referral_codes_and_attribution.sql)
--   referral_events (from 20260221_add_referrals.sql)
--
-- Safe to run regardless of which prior migrations were applied:
--   • Fresh DB (neither old table exists)            → creates referrals, skips inserts
--   • Only 20260221 ran (no referral_codes, no inviter_uid col) → migrates referral_events only
--   • Both 20260221 + 20260225 ran                   → full migration
--   • Already migrated (referrals exists, old tables gone) → no-ops throughout
-- ============================================================

CREATE TABLE IF NOT EXISTS referrals (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type    TEXT        NOT NULL CHECK (event_type IN ('code', 'invite', 'convert')),
  referral_code TEXT        NOT NULL,
  owner_uid     TEXT        NOT NULL,   -- always the code owner (inviter)
  actor_uid     TEXT,                   -- only set for 'convert': the invitee's uid
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- One code allocation per user
CREATE UNIQUE INDEX IF NOT EXISTS idx_referrals_one_code_per_user
  ON referrals (owner_uid) WHERE event_type = 'code';

-- Referral code is globally unique (only enforced on 'code' rows)
CREATE UNIQUE INDEX IF NOT EXISTS idx_referrals_code_unique
  ON referrals (referral_code) WHERE event_type = 'code';

-- One conversion per invitee (dedup — prevents double-counting)
CREATE UNIQUE INDEX IF NOT EXISTS idx_referrals_one_convert_per_invitee
  ON referrals (actor_uid) WHERE event_type = 'convert';

-- Query performance
CREATE INDEX IF NOT EXISTS idx_referrals_owner ON referrals (owner_uid);
CREATE INDEX IF NOT EXISTS idx_referrals_code  ON referrals (referral_code);

-- ── Migrate existing data ────────────────────────────────────────────────────

-- referral_codes → 'code' rows (only if table exists — requires 20260225)
DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'referral_codes'
  ) THEN
    INSERT INTO referrals (event_type, referral_code, owner_uid, created_at)
    SELECT 'code', referral_code, user_id, created_at
    FROM referral_codes
    ON CONFLICT DO NOTHING;
  END IF;
END $$;

-- referral_events → 'invite' / 'convert' rows (only if table exists — requires 20260221)
-- Two sub-cases: with inviter_uid column (20260225 ran) vs without (20260221 only)
DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'referral_events'
  ) THEN
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'referral_events'
        AND column_name = 'inviter_uid'
    ) THEN
      -- Full path: inviter_uid available (20260225 was applied)
      INSERT INTO referrals (event_type, referral_code, owner_uid, actor_uid, created_at)
      SELECT
        event_type,
        referral_code,
        COALESCE(inviter_uid, actor_uid)                              AS owner_uid,
        CASE WHEN event_type = 'convert' THEN actor_uid ELSE NULL END AS actor_uid,
        created_at
      FROM referral_events
      ON CONFLICT DO NOTHING;
    ELSE
      -- Fallback path: no inviter_uid column (only 20260221 was applied)
      INSERT INTO referrals (event_type, referral_code, owner_uid, actor_uid, created_at)
      SELECT
        event_type,
        referral_code,
        actor_uid                                                     AS owner_uid,
        CASE WHEN event_type = 'convert' THEN actor_uid ELSE NULL END AS actor_uid,
        created_at
      FROM referral_events
      ON CONFLICT DO NOTHING;
    END IF;
  END IF;
END $$;

-- ── Drop old tables (safe — data is in referrals now, IF EXISTS is a no-op if missing) ─
DROP TABLE IF EXISTS referral_events;
DROP TABLE IF EXISTS referral_codes;
