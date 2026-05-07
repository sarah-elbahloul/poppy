-- ═══════════════════════════════════════════════════════════════
--  POPPY — Complete Database Migration
--  File: supabase/migrations/20240101000000_poppy_init.sql
--
--  Run this in Supabase SQL Editor to set up the entire
--  database from scratch. Safe to re-run — uses IF EXISTS
--  and OR REPLACE throughout.
--
--  Order of operations:
--    1. Tear down (safe drop everything)
--    2. Tables
--    3. Indexes
--    4. Functions & Triggers
--    5. Row Level Security
--    6. Storage bucket policy
-- ═══════════════════════════════════════════════════════════════


-- ──────────────────────────────────────────────────────────────
--  1. TEAR DOWN
--  Drop in reverse dependency order so foreign keys don't block.
-- ──────────────────────────────────────────────────────────────

drop trigger if exists on_auth_user_created   on auth.users;
drop trigger if exists entries_updated_at     on public.entries;

drop function if exists public.handle_new_user()   cascade;
drop function if exists public.update_updated_at() cascade;

drop table if exists public.photos   cascade;
drop table if exists public.entries  cascade;
drop table if exists public.profiles cascade;


-- ──────────────────────────────────────────────────────────────
--  2. TABLES
-- ──────────────────────────────────────────────────────────────

-- profiles ─────────────────────────────────────────────────────
-- One row per user, auto-created by trigger on sign-up.
create table public.profiles (
  id          uuid        primary key references auth.users(id) on delete cascade,
  theme       text        not null default 'poppy',
  pin_enabled boolean     not null default false,
  created_at  timestamptz not null default now()
);

-- entries ──────────────────────────────────────────────────────
create table public.entries (
  id             uuid        primary key default gen_random_uuid(),
  user_id        uuid        not null references auth.users(id) on delete cascade,
  title          text        not null default '',
  content        text        not null default '',
  color_tag      text        not null default 'stone',
  word_count     integer     not null default 0,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),

  -- Full-text search vector — auto-updated, always in sync
  search_vector  tsvector    generated always as (
    to_tsvector('english',
      coalesce(title,   '') || ' ' ||
      coalesce(content, '')
    )
  ) stored
);

-- photos ───────────────────────────────────────────────────────
create table public.photos (
  id            uuid        primary key default gen_random_uuid(),
  entry_id      uuid        not null references public.entries(id) on delete cascade,
  user_id       uuid        not null references auth.users(id)     on delete cascade,
  storage_path  text        not null,
  order_index   integer     not null default 0,
  created_at    timestamptz not null default now()
);


-- ──────────────────────────────────────────────────────────────
--  3. INDEXES
-- ──────────────────────────────────────────────────────────────

-- Full-text search
create index entries_search_idx
  on public.entries using gin(search_vector);

-- Fast lookup of all entries for a user, newest first
create index entries_user_created_idx
  on public.entries(user_id, created_at desc);

-- Fast lookup of photos for an entry in order
create index photos_entry_order_idx
  on public.photos(entry_id, order_index asc);


-- ──────────────────────────────────────────────────────────────
--  4. FUNCTIONS & TRIGGERS
-- ──────────────────────────────────────────────────────────────

-- Auto-update entries.updated_at on every update ───────────────
create or replace function public.update_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger entries_updated_at
  before update on public.entries
  for each row
  execute function public.update_updated_at();


-- Auto-create a profile row when a new user signs up ───────────
-- security definer  → runs with the privileges of the function owner
-- set search_path   → required so the function finds public.profiles
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id)
  values (new.id)
  on conflict (id) do nothing;   -- safe to call multiple times
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute function public.handle_new_user();


-- ──────────────────────────────────────────────────────────────
--  5. ROW LEVEL SECURITY
--  Every user can only see and touch their own rows.
-- ──────────────────────────────────────────────────────────────

alter table public.profiles enable row level security;
alter table public.entries  enable row level security;
alter table public.photos   enable row level security;

-- profiles: user can read and update their own row.
-- INSERT is handled by the trigger (security definer bypasses RLS).
create policy "profiles: own row"
  on public.profiles
  for all
  using (auth.uid() = id);

-- Allow the trigger to insert a new profile on sign-up
create policy "profiles: insert on signup"
  on public.profiles
  for insert
  with check (true);

-- entries: full access to own entries only
create policy "entries: own rows"
  on public.entries
  for all
  using  (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- photos: full access to own photos only
create policy "photos: own rows"
  on public.photos
  for all
  using  (auth.uid() = user_id)
  with check (auth.uid() = user_id);


-- ──────────────────────────────────────────────────────────────
--  6. STORAGE
--  Run this AFTER creating the 'entry-photos' bucket manually
--  in the Supabase dashboard (Storage → New bucket →
--  name: entry-photos, public: OFF).
-- ──────────────────────────────────────────────────────────────

-- Each user can only access files inside their own folder.
-- Folder structure: {user_id}/{entry_id}/{filename}
drop policy if exists "photos storage: own folder" on storage.objects;

create policy "photos storage: own folder"
  on storage.objects
  for all
  using (
    bucket_id = 'entry-photos'
    and auth.uid()::text = (storage.foldername(name))[1]
  )
  with check (
    bucket_id = 'entry-photos'
    and auth.uid()::text = (storage.foldername(name))[1]
  );


-- ──────────────────────────────────────────────────────────────
--  DONE
--  After running this script:
--    ✓ profiles table exists with auto-create trigger
--    ✓ entries table with full-text search index
--    ✓ photos table with ordered index
--    ✓ RLS locked down per user
--    ✓ Storage policy locked to user's own folder
-- ──────────────────────────────────────────────────────────────