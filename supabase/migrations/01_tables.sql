-- ═══════════════════════════════════════════════════════════════
--  POPPY — Migration 01: Tables
--  File: supabase/migrations/01_tables.sql
-- ──────────────────────────────────────────────────────────────
--  Defines the core database schema with explicit theme settings.
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
  id                   uuid        primary key
                                   references auth.users(id)
                                   on delete cascade,
  
  -- Explicit Theme Settings (Synced across devices)
  font_title           text        not null default 'lora',
  font_body            text        not null default 'inter',
  theme_colors         jsonb       not null default '{"colorAccent": 4291379264,"colorAccentLight": 4294699754,"colorAccentMuted": 4293435552,"colorSurface": 4294834424,"colorBackground": 4294966267,"colorTextPrimary": 4281011726,"colorTextSecondary": 4284236868,"colorTextTertiary": 4288633434,"colorBorder": 4293777624}',
  tags                 jsonb       not null default '[{"id": "poppy", "name": "Poppy", "color": 4291379264, "isBuiltIn": true}, {"id": "iris", "name": "Iris", "color": 4284246976, "isBuiltIn": true}, {"id": "lily", "name": "Lily", "color": 4288466021, "isBuiltIn": true}, {"id": "marigold", "name": "Marigold", "color": 4294947584, "isBuiltIn": true}, {"id": "lavender", "name": "Lavender", "color": 4290406600, "isBuiltIn": true}, {"id": "stone", "name": "Stone", "color": 4287669422, "isBuiltIn": true}]',
  pin_enabled          boolean     not null default false,
  created_at           timestamptz not null default now(),

  constraint tags_count_check check (jsonb_array_length(tags) >= 3 and jsonb_array_length(tags) <= 12)
);

-- ─── Entries ───
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
create table public.user_keys (
  user_id               uuid        primary key
                                    references auth.users(id)
                                    on delete cascade,
  encrypted_data_key    jsonb       not null,
  recovery_enc_data_key jsonb       not null,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);
