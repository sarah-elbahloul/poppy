-- ═══════════════════════════════════════════════════════════════
--  POPPY — Migration 04: Functions & Triggers
--  File: supabase/migrations/04_functions_triggers.sql
-- ──────────────────────────────────────────────────────────────
--  Contains server-side logic for profile automation,
--  timestamp management, and account deletion.
-- ═══════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────
--  Cleanup
-- ──────────────────────────────────────────────────────────────

drop trigger  if exists entries_updated_at   on public.entries;
drop trigger  if exists on_auth_user_created on auth.users;
drop trigger  if exists user_keys_updated_at on public.user_keys;

drop function if exists public.update_updated_at() cascade;
drop function if exists public.handle_new_user()   cascade;
drop function if exists public.update_data_key(jsonb, jsonb);
drop function if exists public.delete_user_account();

-- ──────────────────────────────────────────────────────────────
--  Timestamps
-- ──────────────────────────────────────────────────────────────

-- Automatically updates the updated_at column on row changes.
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

create trigger user_keys_updated_at
  before update on public.user_keys
  for each row
  execute function public.update_updated_at();

-- ──────────────────────────────────────────────────────────────
--  Profile Automation
-- ──────────────────────────────────────────────────────────────

-- Creates a corresponding public.profiles row when a new user signs up.
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

create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute function public.handle_new_user();

-- ──────────────────────────────────────────────────────────────
--  Account Management
-- ──────────────────────────────────────────────────────────────

-- Permanently deletes all app-related data for the authenticated user.
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

  delete from public.photos    where user_id = uid;
  delete from public.entries   where user_id = uid;
  delete from public.user_keys where user_id = uid;
  delete from public.profiles  where id = uid;
end;
$$;

grant execute on function public.delete_user_account() to authenticated;

-- ──────────────────────────────────────────────────────────────
--  Encryption Keys
-- ──────────────────────────────────────────────────────────────

-- Updates the wrapped encryption keys for the user.
create or replace function public.update_data_key(
  new_wrapped_key          jsonb,
  new_recovery_wrapped_key jsonb default null
)
returns void
language plpgsql
security definer
as $$
begin
  update user_keys
  set
    encrypted_data_key      = new_wrapped_key,
    recovery_enc_data_key   = coalesce(new_recovery_wrapped_key, recovery_enc_data_key),
    updated_at              = now()
  where user_id = auth.uid();
end;
$$;

grant execute on function public.update_data_key(jsonb, jsonb) to authenticated;