-- ═══════════════════════════════════════════════════════════════
--  POPPY — Migration 02: Indexes
--  File: supabase/migrations/02_indexes.sql
-- ──────────────────────────────────────────────────────────────
--  Optimizes common queries for sorting and filtering.
--  Search is performed client-side on decrypted data.
-- ═══════════════════════════════════════════════════════════════

-- Main home screen query: sort entries by date for a specific user.
create index if not exists entries_user_date_idx
  on public.entries(user_id, entry_date desc);

-- Color tag pre-filtering before client-side decryption.
create index if not exists entries_color_tag_idx
  on public.entries(user_id, color_tag);

-- Photo lookup for an entry in display order.
create index if not exists photos_entry_order_idx
  on public.photos(entry_id, order_index asc);

-- Bulk deletion optimization during account removal.
create index if not exists photos_user_idx
  on public.photos(user_id);
