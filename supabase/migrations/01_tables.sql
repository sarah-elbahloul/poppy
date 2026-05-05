-- ── PROFILES ──────────────────────────────────────────────────
create table profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  theme       text not null default 'poppy',
  pin_enabled boolean not null default false,
  created_at  timestamptz not null default now()
);

-- ── ENTRIES ───────────────────────────────────────────────────
create table entries (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  title       text not null default '',
  content     text not null default '',
  color_tag   text not null default 'stone',
  word_count  integer not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- ── PHOTOS ────────────────────────────────────────────────────
create table photos (
  id            uuid primary key default gen_random_uuid(),
  entry_id      uuid not null references entries(id) on delete cascade,
  user_id       uuid not null references auth.users(id) on delete cascade,
  storage_path  text not null,
  order_index   integer not null default 0,
  created_at    timestamptz not null default now()
);

-- ── AUTO-UPDATE updated_at on entries ─────────────────────────
create or replace function update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger entries_updated_at
  before update on entries
  for each row execute function update_updated_at();

-- ── AUTO-CREATE profile when user signs up ────────────────────
create or replace function handle_new_user()
returns trigger as $$
begin
  insert into profiles (id)
  values (new.id);
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- ── FULL TEXT SEARCH index on entries ─────────────────────────
alter table entries
  add column search_vector tsvector
  generated always as (
    to_tsvector('english', coalesce(title, '') || ' ' || coalesce(content, ''))
  ) stored;

create index entries_search_idx on entries using gin(search_vector);