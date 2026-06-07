-- ═══════════════════════════════════════════════════════════════
--  POPPY — Migration 01: Tables
--  File: supabase/migrations/01_tables.sql
-- ──────────────────────────────────────────────────────────────
--  Defines the core database schema.
--  Run order: 01 → 02 → 03 → 04
-- ═══════════════════════════════════════════════════════════════

-- ─── Cleanup ───

drop table if exists public.photos    cascade;
drop table if exists public.entries   cascade;
drop table if exists public.profiles  cascade;
drop table if exists public.user_keys cascade;

-- ─── Profiles ───
-- Extended user data, auto-created via trigger on sign-up.

create table public.profiles (
  id          uuid        primary key
                          references auth.users(id)
                          on delete cascade,
  theme       text        not null default 'poppy',
  pin_enabled boolean     not null default false,
  created_at  timestamptz not null default now()
);

-- ─── Entries ───
-- Encrypted journal entries. Only metadata (date, color, count)
-- is stored as plaintext for sorting and filtering.

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

-- ─── Photos ───
-- Metadata for images stored in the 'entry-photos' bucket.

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

-- ─── User Keys ───
-- Stores the wrapped encryption data key for each user.

create table public.user_keys (
  user_id               uuid        primary key
                                    references auth.users(id)
                                    on delete cascade,
  encrypted_data_key    jsonb       not null,
  recovery_enc_data_key jsonb       not null,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);
