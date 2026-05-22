-- ═══════════════════════════════════════════════════════════════
--  POPPY — Migration 05: User Keys Table
--  File: supabase/migrations/05_user_keys.sql
--
--  Stores one row per user: the data key wrapped (AES-256-GCM)
--  with a key derived from the user's password (PBKDF2).
--
--  The data key is random, generated at sign-up, and NEVER
--  changes.  Only the wrapping changes when the password changes.
--
--  No recovery_encrypted_data_key column — recovery is handled
--  by the standard Supabase password-reset email flow.
-- ═══════════════════════════════════════════════════════════════

drop table if exists public.user_keys cascade;

create table public.user_keys (
  user_id           uuid        primary key
                                references auth.users(id)
                                on delete cascade,
  encrypted_data_key jsonb      not null,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

alter table public.user_keys enable row level security;

drop policy if exists "user_keys: own row" on public.user_keys;
create policy "user_keys: own row"
  on public.user_keys
  for all
  using  (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop trigger if exists user_keys_updated_at on public.user_keys;
create trigger user_keys_updated_at
  before update on public.user_keys
  for each row
  execute function public.update_updated_at();


-- ──────────────────────────────────────────────────────────────
--  RPC: update_data_key
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

drop function if exists public.update_data_key(jsonb);

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