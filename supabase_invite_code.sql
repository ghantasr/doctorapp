-- Adds invite_code to tenants for quick lookups from clinic code.
-- Run this in Supabase SQL editor (once).

ALTER TABLE tenants
  ADD COLUMN IF NOT EXISTS invite_code text
  GENERATED ALWAYS AS (upper(substr(id::text, 1, 8))) STORED;

CREATE UNIQUE INDEX IF NOT EXISTS tenants_invite_code_idx
  ON tenants(invite_code);
