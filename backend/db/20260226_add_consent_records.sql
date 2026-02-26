-- Migration: user consent audit trail
-- Safe to re-run (all IF NOT EXISTS).
-- Records when a user explicitly accepted the privacy policy + T&C in-app.
-- Used by: B2B buyers (data governance), Apple SensorKit review, GDPR audit.

CREATE TABLE IF NOT EXISTS user_consent_agreements (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     TEXT        NOT NULL,
  agreed_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  pp_version  TEXT        NOT NULL DEFAULT '1.0',  -- privacy policy version
  platform    TEXT,                                 -- 'android' | 'ios'
  app_version TEXT
);

CREATE INDEX IF NOT EXISTS idx_consent_user_id
  ON user_consent_agreements(user_id, agreed_at DESC);
