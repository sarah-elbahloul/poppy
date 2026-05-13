-- ═══════════════════════════════════════════════════════════════
--  POPPY — Migration 03: Row Level Security Policies
--  File: supabase/migrations/03_policies.sql
--
--  Run after 01_tables.sql.
--  Enables RLS on all tables and creates policies so that
--  every user can only access their own data.
--
--  The handle_new_user trigger (04_functions.sql) inserts
--  the first profile row using security definer, which
--  bypasses RLS — so we need a separate INSERT policy
--  on profiles that allows that insert to succeed.
-- ═══════════════════════════════════════════════════════════════


-- ──────────────────────────────────────────────────────────────
--  Enable RLS
-- ──────────────────────────────────────────────────────────────

alter table public.profiles enable row level security;
alter table public.entries  enable row level security;
alter table public.photos   enable row level security;


-- ──────────────────────────────────────────────────────────────
--  profiles policies
-- ──────────────────────────────────────────────────────────────

-- Users can select and update their own profile row.
-- The trigger that creates the row uses security definer
-- so it bypasses this policy — that is intentional.
drop policy if exists "profiles: own row" on public.profiles;
create policy "profiles: own row"
  on public.profiles
  for all
  using (auth.uid() = id);

-- Allow the trigger (security definer function) to insert
-- a new profile row when a user signs up.
-- Without this policy the insert inside handle_new_user()
-- would be blocked by RLS even though the function is
-- declared as security definer.
drop policy if exists "profiles: insert on signup" on public.profiles;
create policy "profiles: insert on signup"
  on public.profiles
  for insert
  with check (true);


-- ──────────────────────────────────────────────────────────────
--  entries policies
-- ──────────────────────────────────────────────────────────────

-- Full CRUD — users can only touch their own entries.
-- The upsert used during import also passes this policy
-- because we always set user_id = auth.uid() in the app.
drop policy if exists "entries: own rows" on public.entries;
create policy "entries: own rows"
  on public.entries
  for all
  using  (auth.uid() = user_id)
  with check (auth.uid() = user_id);


-- ──────────────────────────────────────────────────────────────
--  photos policies
-- ──────────────────────────────────────────────────────────────

drop policy if exists "photos: own rows" on public.photos;
create policy "photos: own rows"
  on public.photos
  for all
  using  (auth.uid() = user_id)
  with check (auth.uid() = user_id);


-- ──────────────────────────────────────────────────────────────
--  Storage bucket policy (entry-photos)
--
--  Before running this section you must create the bucket
--  manually in the Supabase dashboard:
--    Storage → New bucket
--    Name: entry-photos
--    Public: OFF (private)
--
--  Storage path format enforced by the policy:
--    {user_id}/{entry_id}/{filename}
--  The policy checks that the first folder segment matches
--  the authenticated user's UUID.
-- ──────────────────────────────────────────────────────────────

drop policy if exists "photos storage: own folder"
  on storage.objects;

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