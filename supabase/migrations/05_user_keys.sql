-- ═══════════════════════════════════════════════════════════════
--  POPPY — Migration 05: User Keys Table
--  File: supabase/migrations/05_user_keys.sql
--
--  Run after 04_functions_triggers.sql.
--
--  PURPOSE
--  ───────
--  Implements Option D key architecture:
--
--    1. On sign-up the app generates a random 32-byte DATA KEY.
--       This key encrypts all entries and NEVER changes.
--
--    2. The data key is wrapped (encrypted) in two ways and
--       stored here:
--
--       a) encrypted_data_key
--          Data key wrapped with a key derived from the user's
--          PASSWORD via PBKDF2.
--          Updated on every password change — no entries touched.
--
--       b) recovery_encrypted_data_key
--          Data key wrapped with a key derived from the user's
--          RECOVERY CODE via PBKDF2.
--          Set once at sign-up, never changes unless the user
--          explicitly regenerates their recovery code.
--
--  RECOVERY FLOW
--  ─────────────
--  Forgot password (no old password available):
--    1. User provides recovery code + new password
--    2. App fetches recovery_encrypted_data_key for this user
--    3. Derives recovery key from recovery code, unwraps data key
--    4. Re-wraps data key with new password-derived key
--    5. Updates encrypted_data_key in this table
--    6. Sends Supabase password reset email (or uses admin API)
--
--  Neither Supabase nor Poppy servers ever see the data key in
--  plaintext — it is always wrapped before upload.
--
--  RLS: each user can only read/write their own row.
-- ═══════════════════════════════════════════════════════════════


-- ──────────────────────────────────────────────────────────────
--  Table
-- ──────────────────────────────────────────────────────────────

create table if not exists public.user_keys (
  user_id                       uuid        primary key
                                            references auth.users(id)
                                            on delete cascade,

  -- Data key wrapped with PBKDF2(password).
  -- JSONB format: {"c":"<b64>","n":"<b64>","m":"<b64>"}
  -- Updated on every password change.
  encrypted_data_key            jsonb       not null,

  -- Data key wrapped with PBKDF2(recovery_code).
  -- Set once at sign-up. Updated only when user regenerates
  -- their recovery code (future feature).
  recovery_encrypted_data_key   jsonb       not null,

  created_at                    timestamptz not null default now(),
  updated_at                    timestamptz not null default now()
);


-- ──────────────────────────────────────────────────────────────
--  RLS
-- ──────────────────────────────────────────────────────────────

alter table public.user_keys enable row level security;

drop policy if exists "user_keys: own row" on public.user_keys;
create policy "user_keys: own row"
  on public.user_keys
  for all
  using  (auth.uid() = user_id)
  with check (auth.uid() = user_id);


-- ──────────────────────────────────────────────────────────────
--  updated_at trigger (reuse the same function from 04)
-- ──────────────────────────────────────────────────────────────

drop trigger if exists user_keys_updated_at on public.user_keys;

create trigger user_keys_updated_at
  before update on public.user_keys
  for each row
  execute function public.update_updated_at();


-- ──────────────────────────────────────────────────────────────
--  Index: fast lookup by user_id (primary key already covers
--  this, but explicit for clarity)
-- ──────────────────────────────────────────────────────────────

-- primary key is already a btree index — no extra index needed.