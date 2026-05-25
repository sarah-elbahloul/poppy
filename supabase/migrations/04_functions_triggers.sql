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
drop trigger if exists user_keys_updated_at on public.user_keys;


-- ──────────────────────────────────────────────────────────────
--  Drop existing functions
-- ──────────────────────────────────────────────────────────────

drop function if exists public.update_updated_at() cascade;
drop function if exists public.handle_new_user()   cascade;
drop function if exists public.update_data_key(jsonb);
drop function if exists public.public.delete_user_account();


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


-- ──────────────────────────────────────────────────────────────
--  FUNCTION: delete_user_account
--
--  Permanently deletes all user-owned app data.
--
--  NOTE:
--  This does NOT delete the auth.users row itself because
--  Postgres functions cannot call auth.admin.deleteUser().
--  The actual auth account deletion is handled separately
--  by the Edge Function using the service role key.
--
--  SECURITY DEFINER is required so the function can delete
--  across all user-owned tables safely under RLS.
-- ──────────────────────────────────────────────────────────────

create or replace function public.delete_user_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid;
begin
  uid := auth.uid();

  if uid is null then
    raise exception 'Not authenticated';
  end if;

  -- Delete child rows first
  delete from public.photos
  where user_id = uid;

  delete from public.entries
  where user_id = uid;

  delete from public.user_keys
  where user_id = uid;

  delete from public.profiles
  where id = uid;

end;
$$;

grant execute on function public.delete_user_account()
to authenticated;

-- ──────────────────────────────────────────────────────────────
--  FUNCTION: update_data_key
--
--  Called by the client after a password change (both from
--  settings AND from the reset-email one-time session).
--  Takes only the new wrapped key — the caller already has
--  a valid session so auth.uid() identifies the row to update.
--
--  SECURITY DEFINER is not needed here because the policy
--  already allows the authenticated user to update their own
--  row.  We use a function purely for a clean single call.
-- ──────────────────────────────────────────────────────────────

create or replace function public.update_data_key(new_wrapped_key jsonb)
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  update public.user_keys
  set    encrypted_data_key = new_wrapped_key
  where  user_id = auth.uid();
end;
$$;

grant execute on function public.update_data_key(jsonb)
  to authenticated;

-- ──────────────────────────────────────────────────────────────
--  TRIGGER: user_keys_updated_at
-- ──────────────────────────────────────────────────────────────

create trigger user_keys_updated_at
  before update on public.user_keys
  for each row
  execute function public.update_updated_at();

