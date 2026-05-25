-- ═══════════════════════════════════════════════════════════════
--  POPPY — Migration 01: Tables
--  File: supabase/migrations/01_tables.sql
--
--  Clean schema — only columns actually used by the app.
--  No legacy columns, no unused indexes.
--  Run order: 01 → 02 → 03 → 04
-- ═══════════════════════════════════════════════════════════════


-- ──────────────────────────────────────────────────────────────
--  Drop existing (safe on a fresh database)
-- ──────────────────────────────────────────────────────────────

drop table if exists public.photos   cascade;
drop table if exists public.entries  cascade;
drop table if exists public.profiles cascade;
drop table if exists public.user_keys cascade;


-- ──────────────────────────────────────────────────────────────
--  profiles
--  One row per user. Auto-created by trigger in 04_functions.sql
-- ──────────────────────────────────────────────────────────────

create table public.profiles (
  id          uuid        primary key
                          references auth.users(id)
                          on delete cascade,
  theme       text        not null default 'poppy',
  pin_enabled boolean     not null default false,
  created_at  timestamptz not null default now()
);


-- ──────────────────────────────────────────────────────────────
--  entries
--
--  title_enc / content_enc:
--    AES-256-GCM ciphertext stored as JSONB.
--    Format: {"c":"<base64 ciphertext>",
--             "n":"<base64 nonce>",
--             "m":"<base64 mac>"}
--    Encrypted on the client BEFORE upload.
--    Supabase never sees plaintext title or content.
--
--  word_count:
--    Computed from plaintext before encryption.
--    Stored unencrypted so the home screen card can show
--    it without decrypting the full entry.
--
--  entry_date:
--    The date the user assigned to the entry.
--    Stored unencrypted — needed for sorting the home list.
--
--  color_tag:
--    Stored unencrypted — needed for filtering in search.
-- ──────────────────────────────────────────────────────────────

create table public.entries (
  id           uuid        primary key default gen_random_uuid(),
  user_id      uuid        not null
                           references auth.users(id)
                           on delete cascade,
  title_enc    jsonb       not null default '{}',
  content_enc  jsonb       not null default '{}',
  color_tag    text        not null default 'stone',
  word_count   integer     not null default 0,
  entry_date   date        not null default current_date,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),

  constraint valid_color_tag check (color_tag in (
    'poppy', 'iris', 'lily', 'marigold', 'lavender', 'stone'
  ))

);


-- ──────────────────────────────────────────────────────────────
--  photos
--  Stores the Supabase Storage path and display order.
--  Actual image files live in the entry-photos bucket.
--  Path format: {user_id}/{entry_id}/{filename}
-- ──────────────────────────────────────────────────────────────

create table public.photos (
  id            uuid        primary key default gen_random_uuid(),
  entry_id      uuid        not null
                            references public.entries(id)
                            on delete cascade,
  user_id       uuid        not null
                            references auth.users(id)
                            on delete cascade,
  storage_path  text        not null,
  order_index   integer     not null default 0,
  created_at    timestamptz not null default now()
);


-- ═══════════════════════════════════════════════════════════════
--  User Keys Table
--  Stores one row per user: the data key wrapped (AES-256-GCM)
--  with a key derived from the user's password (PBKDF2).
--
--  The data key is random, generated at sign-up, and NEVER
--  changes.  Only the wrapping changes when the password changes.
--
--  No recovery_encrypted_data_key column — recovery is handled
--  by the standard Supabase password-reset email flow.
-- ═══════════════════════════════════════════════════════════════

create table public.user_keys (
  user_id           uuid        primary key
                                references auth.users(id)
                                on delete cascade,
  encrypted_data_key jsonb      not null,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
