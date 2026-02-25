-- Stable referral code ownership per user.
-- Server-generated and unique; no client-side hash derivation.
CREATE TABLE IF NOT EXISTS referral_codes (
  user_id       TEXT        PRIMARY KEY,
  referral_code TEXT        NOT NULL UNIQUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_referral_codes_code
  ON referral_codes (referral_code);

-- Attribution owner on referral events.
-- inviter_uid = owner of referral_code.
ALTER TABLE referral_events
  ADD COLUMN IF NOT EXISTS inviter_uid TEXT;

-- Backfill historical invite events where actor_uid was the inviter.
UPDATE referral_events
SET inviter_uid = actor_uid
WHERE event_type = 'invite'
  AND inviter_uid IS NULL;

CREATE INDEX IF NOT EXISTS idx_referral_events_inviter
  ON referral_events (inviter_uid);
