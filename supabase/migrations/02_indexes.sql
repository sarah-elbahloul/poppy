-- ═══════════════════════════════════════════════════════════════
--  POPPY — Migration 02: Indexes
--  File: supabase/migrations/02_indexes.sql
--
--  Run after 01_tables.sql.
--
--  Note on search:
--  Full-text search (PostgreSQL tsvector) is NOT used because
--  entries are encrypted. Search is done client-side in
--  EntriesService.search() after decrypting all entries.
-- ═══════════════════════════════════════════════════════════════


-- Primary sort index: all entries for a user by entry_date desc.
-- This is the main home screen query.
create index if not exists entries_user_date_idx
  on public.entries(user_id, entry_date desc);


-- Color tag filter: used in client-side search pre-filtering.
-- Even though search is client-side, we can ask Supabase to
-- filter by color_tag before returning rows to reduce payload.
create index if not exists entries_color_tag_idx
  on public.entries(user_id, color_tag);


-- Photos lookup: all photos for an entry in display order.
create index if not exists photos_entry_order_idx
  on public.photos(entry_id, order_index asc);


-- Photos by user: used for bulk delete when account is deleted.
create index if not exists photos_user_idx
  on public.photos(user_id);