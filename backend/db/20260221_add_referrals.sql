-- Referral events: tracks both invite shares and conversion sign-ups
CREATE TABLE IF NOT EXISTS referral_events (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type  TEXT        NOT NULL CHECK (event_type IN ('invite', 'convert')),
  referral_code TEXT      NOT NULL,
  actor_uid   TEXT        NOT NULL,  -- inviter_uid on 'invite', invitee_uid on 'convert'
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_referral_events_code  ON referral_events(referral_code);
CREATE INDEX IF NOT EXISTS idx_referral_events_actor ON referral_events(actor_uid);

-- Enforce idempotency: one conversion event per invitee (partial unique index)
-- This is what makes ON CONFLICT DO NOTHING actually work in the convert endpoint.
-- Invites are unrestricted (users can share as many times as they want).
CREATE UNIQUE INDEX IF NOT EXISTS idx_referral_events_one_convert_per_user
  ON referral_events (actor_uid)
  WHERE event_type = 'convert';
