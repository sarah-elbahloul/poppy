-- ═══════════════════════════════════════════════════════════════
--  POPPY — Migration 01: Tables
--  File: supabase/migrations/01_tables.sql
--
--  Run this first. Creates all tables with their columns,
--  constraints, and default values.
--  Run order: 01 → 02 → 03 → 04
-- ═══════════════════════════════════════════════════════════════


-- ──────────────────────────────────────────────────────────────
--  Drop existing tables (reverse dependency order)
--  Safe to run on a fresh database — IF EXISTS prevents errors.
-- ──────────────────────────────────────────────────────────────

drop table if exists public.photos   cascade;
drop table if exists public.entries  cascade;
drop table if exists public.profiles cascade;


-- ──────────────────────────────────────────────────────────────
--  profiles
--  One row per user. Auto-created by trigger in 04_functions.sql
--  when a new user signs up via Supabase Auth.
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
--  Core diary entries table.
--
--  Columns:
--    id            — UUID primary key, auto-generated
--    user_id       — owner, foreign key to auth.users
--    title         — entry title, can be empty
--    content       — full diary text
--    color_tag     — one of: poppy, iris, lily, marigold,
--                    lavender, stone (default)
--    word_count    — cached word count, updated on save
--    entry_date    — the date the user assigned to the entry
--                    (may differ from created_at)
--    created_at    — when the DB row was first created
--    updated_at    — auto-updated by trigger in 04_functions.sql
--    search_vector — full-text index, auto-computed from
--                    title + content (never write to this)
--
--  Constraints:
--    entries_content_length — 60,000 chars ≈ 10,000 words
--    valid_color_tag        — only accepted tag values
-- ──────────────────────────────────────────────────────────────

create table public.entries (
  id             uuid        primary key default gen_random_uuid(),
  user_id        uuid        not null
                             references auth.users(id)
                             on delete cascade,
  title          text        not null default '',
  content        text        not null default '',
  color_tag      text        not null default 'stone',
  word_count     integer     not null default 0,
  entry_date     date        not null default current_date,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),

  search_vector  tsvector    generated always as (
    to_tsvector('english',
      coalesce(title,   '') || ' ' ||
      coalesce(content, '')
    )
  ) stored,

  constraint entries_content_length
    check (char_length(content) <= 60000),

  constraint valid_color_tag
    check (color_tag in (
      'poppy', 'iris', 'lily', 'marigold', 'lavender', 'stone'
    ))
);


-- ──────────────────────────────────────────────────────────────
--  photos
--  Photos attached to entries. Actual image files are stored
--  in Supabase Storage (bucket: entry-photos). This table
--  only holds the storage path and display order.
--
--  Columns:
--    storage_path — path inside the entry-photos bucket,
--                   format: {user_id}/{entry_id}/{filename}
--    order_index  — 0-based display order in the photo strip
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