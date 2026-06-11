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
  tags        jsonb       not null default '[{"id": "poppy", "name": "Poppy", "color": 4291346496, "isBuiltIn": true}, {"id": "iris", "name": "Iris", "color": 4284247232, "isBuiltIn": true}, {"id": "lily", "name": "Lily", "color": 4288498789, "isBuiltIn": true}, {"id": "marigold", "name": "Marigold", "color": 4294947584, "isBuiltIn": true}, {"id": "lavender", "name": "Lavender", "color": 4290373832, "isBuiltIn": true}, {"id": "stone", "name": "Stone", "color": 4287636654, "isBuiltIn": true}]',
  pin_enabled boolean     not null default false,
  created_at  timestamptz not null default now(),

  constraint tags_count_check check (jsonb_array_length(tags) >= 3 and jsonb_array_length(tags) <= 12)
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
  updated_at   timestamptz not null default now()
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
