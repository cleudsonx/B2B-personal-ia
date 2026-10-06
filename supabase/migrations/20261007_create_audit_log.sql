-- 20261007_create_audit_log.sql
-- Migration to add audit_log table for tracking invitation events

CREATE TABLE IF NOT EXISTS audit_log (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type    text NOT NULL,  -- 'invite_created', 'invite_sent', 'invite_consumed', 'invite_failed', 'invite_purged'
  token         text NOT NULL,
  trainer_id    uuid NOT NULL REFERENCES profiles(id),
  target_email  text,
  target_phone  text,
  channel       text NOT NULL CHECK (channel IN ('email','whatsapp')),
  ip_address    inet,
  user_agent    text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  details       jsonb DEFAULT '{}'::jsonb
);

-- Índices para buscas rápidas
CREATE INDEX IF NOT EXISTS idx_audit_log_token   ON audit_log(token);
CREATE INDEX IF NOT EXISTS idx_audit_log_created ON audit_log(created_at);
