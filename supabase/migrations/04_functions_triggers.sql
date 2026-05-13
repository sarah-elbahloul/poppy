-- ═══════════════════════════════════════════════════════════════
--  POPPY — Migration 04: Functions & Triggers
--  File: supabase/migrations/04_functions_triggers.sql
--
--  Run after 01_tables.sql.
--  Order within this file matters — functions before triggers.
-- ═══════════════════════════════════════════════════════════════


-- ──────────────────────────────────────────────────────────────
--  Drop existing triggers first (must drop before functions)
-- ──────────────────────────────────────────────────────────────

drop trigger if exists entries_updated_at   on public.entries;
drop trigger if exists on_auth_user_created on auth.users;


-- ──────────────────────────────────────────────────────────────
--  Drop existing functions
-- ──────────────────────────────────────────────────────────────

drop function if exists public.update_updated_at() cascade;
drop function if exists public.handle_new_user()   cascade;


-- ──────────────────────────────────────────────────────────────
--  FUNCTION: update_updated_at
--
--  Automatically sets updated_at = now() on every UPDATE
--  to the entries table. The app never needs to manually
--  set this column — the trigger handles it.
-- ──────────────────────────────────────────────────────────────

create or replace function public.update_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;


-- ──────────────────────────────────────────────────────────────
--  TRIGGER: entries_updated_at
--
--  Fires BEFORE every UPDATE on entries, calling the
--  update_updated_at() function above.
-- ──────────────────────────────────────────────────────────────

create trigger entries_updated_at
  before update on public.entries
  for each row
  execute function public.update_updated_at();


-- ──────────────────────────────────────────────────────────────
--  FUNCTION: handle_new_user
--
--  Automatically creates a profiles row when a new user
--  signs up via Supabase Auth.
--
--  Why security definer + set search_path = public:
--    - security definer: the function runs with the privileges
--      of the function owner (postgres), not the calling user.
--      This is required to insert into public.profiles even
--      though RLS is enabled on that table.
--    - set search_path = public: without this, the function
--      cannot resolve the table name "profiles" because the
--      default search path inside a trigger function does not
--      include the public schema.
--
--  on conflict (id) do nothing: makes the function idempotent
--  so re-running the trigger (e.g. in tests) never errors.
-- ──────────────────────────────────────────────────────────────

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id)
  values (new.id)
  on conflict (id) do nothing;
  return new;
end;
$$;


-- ──────────────────────────────────────────────────────────────
--  TRIGGER: on_auth_user_created
--
--  Fires AFTER every INSERT on auth.users (i.e. every new
--  sign-up), calling handle_new_user() to create the profile.
--
--  This trigger lives on the auth schema table, not public,
--  which is why it needs security definer to reach public.profiles.
-- ──────────────────────────────────────────────────────────────

create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute function public.handle_new_user();