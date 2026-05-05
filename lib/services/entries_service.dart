import 'package:poppy/core/constants.dart';
import 'package:poppy/core/supabase_client.dart';
import 'package:poppy/models/entry.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Entries Service
//  Location: lib/services/entries_service.dart
//
//  All database operations for diary entries.
//  Called only by EntriesProvider — never directly by UI.
// ─────────────────────────────────────────────────────────────

class EntriesService {
  final _client = SupabaseConfig.client;

  // ── Fetch all ─────────────────────────────────────────────

  Future<List<Entry>> fetchAll() async {
    final response = await _client
        .from(DBTable.entries)
        .select()
        .order(DBColumn.createdAt, ascending: false);

    return (response as List)
        .map((map) => Entry.fromMap(map as Map<String, dynamic>))
        .toList();
  }

  // ── Create ────────────────────────────────────────────────

  Future<Entry> create(Entry entry) async {
    final map = entry.toInsertMap();
    map[DBColumn.userId] = SupabaseConfig.userId;

    final response = await _client
        .from(DBTable.entries)
        .insert(map)
        .select()
        .single();

    return Entry.fromMap(response as Map<String, dynamic>);
  }

  // ── Update ────────────────────────────────────────────────

  Future<Entry> update(Entry entry) async {
    final response = await _client
        .from(DBTable.entries)
        .update(entry.toUpdateMap())
        .eq(DBColumn.id, entry.id)
        .eq(DBColumn.userId, SupabaseConfig.userId)
        .select()
        .single();

    return Entry.fromMap(response as Map<String, dynamic>);
  }

  // ── Delete ────────────────────────────────────────────────

  Future<void> delete(String entryId) async {
    await _client
        .from(DBTable.entries)
        .delete()
        .eq(DBColumn.id, entryId)
        .eq(DBColumn.userId, SupabaseConfig.userId);
  }

  // ── Search ────────────────────────────────────────────────
  // Uses PostgreSQL full-text search for title + content.
  // Color tag and date range are applied as additional filters.

  Future<List<Entry>> search({
    String? query,
    String? colorTag,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    var builder = _client
        .from(DBTable.entries)
        .select()
        .eq(DBColumn.userId, SupabaseConfig.userId);

    // Full-text search across title and content
    if (query != null && query.trim().isNotEmpty) {
      builder = builder.textSearch(
        'search_vector',
        query.trim(),
        config: 'english',
      );
    }

    // Filter by color tag
    if (colorTag != null && colorTag.isNotEmpty) {
      builder = builder.eq(DBColumn.colorTag, colorTag);
    }

    // Filter by date range
    if (fromDate != null) {
      builder = builder.gte(
        DBColumn.createdAt,
        fromDate.toIso8601String(),
      );
    }
    if (toDate != null) {
      // Add one day so toDate is inclusive
      final inclusive = toDate.add(const Duration(days: 1));
      builder = builder.lt(
        DBColumn.createdAt,
        inclusive.toIso8601String(),
      );
    }

    final response = await builder.order(
      DBColumn.createdAt,
      ascending: false,
    );

    return (response as List)
        .map((map) => Entry.fromMap(map as Map<String, dynamic>))
        .toList();
  }
}