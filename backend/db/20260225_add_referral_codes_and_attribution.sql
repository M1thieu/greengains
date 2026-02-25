-- Stable referral code ownership per user.
-- Server-generated and unique; no client-side hash derivation.
CREATE TABLE IF NOT EXISTS referral_codes (
  user_id       TEXT        PRIMARY KEY,
  referral_code TEXT        NOT NULL UNIQUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_referral_codes_code
  ON referral_codes (referral_code);

-- Attribution owner on referral events (only if the old table exists).
-- Safe no-op if referral_events was never created or has already been dropped
-- by the 20260226_unify_referrals.sql migration.
DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'referral_events'
  ) THEN
    ALTER TABLE referral_events
      ADD COLUMN IF NOT EXISTS inviter_uid TEXT;

    UPDATE referral_events
    SET inviter_uid = actor_uid
    WHERE event_type = 'invite'
      AND inviter_uid IS NULL;

    CREATE INDEX IF NOT EXISTS idx_referral_events_inviter
      ON referral_events (inviter_uid);
  END IF;
END $$;
