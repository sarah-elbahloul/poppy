-- ═══════════════════════════════════════════════════════════════
--  POPPY — Migration 02: Indexes
--  File: supabase/migrations/02_indexes.sql
--
--  Run after 01_tables.sql.
--  Creates indexes for performance-critical queries.
-- ═══════════════════════════════════════════════════════════════


-- Full-text search on entries (title + content)
-- Used by the search screen's PostgreSQL text search query.
create index if not exists entries_search_idx
  on public.entries using gin(search_vector);


-- Primary sort index: list all entries for a user newest first.
-- This is the main home screen query — must be fast.
-- Sorts by entry_date (user-chosen date) not created_at.
create index if not exists entries_user_date_idx
  on public.entries(user_id, entry_date desc);


-- Photos lookup: all photos for an entry in display order.
create index if not exists photos_entry_order_idx
  on public.photos(entry_id, order_index asc);


-- Photos by user: used when deleting a user account to
-- find all their photos for storage cleanup.
create index if not exists photos_user_idx
  on public.photos(user_id);