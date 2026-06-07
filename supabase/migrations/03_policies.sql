-- ═══════════════════════════════════════════════════════════════
--  POPPY — Migration 03: Row Level Security Policies
--  File: supabase/migrations/03_policies.sql
-- ──────────────────────────────────────────────────────────────
--  Enforces strict data isolation. Users can only access their
--  own profiles, entries, photos, and encryption keys.
-- ═══════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────
--  Enable RLS
-- ──────────────────────────────────────────────────────────────

alter table public.profiles  enable row level security;
alter table public.entries   enable row level security;
alter table public.photos    enable row level security;
alter table public.user_keys enable row level security;

-- ──────────────────────────────────────────────────────────────
--  profiles
-- ──────────────────────────────────────────────────────────────

-- Allow users to view and manage their own profile.
drop policy if exists "profiles: own row" on public.profiles;
create policy "profiles: own row"
  on public.profiles
  for all
  using (auth.uid() = id);

-- Allow profile creation during sign-up.
drop policy if exists "profiles: insert on signup" on public.profiles;
create policy "profiles: insert on signup"
  on public.profiles
  for insert
  with check (true);

-- ──────────────────────────────────────────────────────────────
--  entries
-- ──────────────────────────────────────────────────────────────

-- Users have full CRUD access to their own journal entries.
drop policy if exists "entries: own rows" on public.entries;
create policy "entries: own rows"
  on public.entries
  for all
  using  (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ──────────────────────────────────────────────────────────────
--  photos
-- ──────────────────────────────────────────────────────────────

-- Users can only manage metadata for photos they uploaded.
drop policy if exists "photos: own rows" on public.photos;
create policy "photos: own rows"
  on public.photos
  for all
  using  (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ──────────────────────────────────────────────────────────────
--  user_keys
-- ──────────────────────────────────────────────────────────────

-- Strict isolation for encryption keys.
drop policy if exists "user_keys: own row" on public.user_keys;
create policy "user_keys: own row"
  on public.user_keys
  for all
  using  (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ──────────────────────────────────────────────────────────────
--  Storage (entry-photos bucket)
--  Path: {user_id}/{entry_id}/{filename}
-- ──────────────────────────────────────────────────────────────

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
