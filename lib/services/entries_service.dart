import 'package:poppy/core/constants.dart';
import 'package:poppy/core/supabase_client.dart';
import 'package:poppy/models/entry.dart';

class EntriesService {
  final _client = SupabaseConfig.client;

  Future<List<Entry>> fetchAll() async {
    final response = await _client
        .from(DBTable.entries)
        .select()
        .order(DBColumn.entryDate, ascending: false);
    return (response as List)
        .map((map) => Entry.fromMap(map as Map<String, dynamic>))
        .toList();
  }

  Future<Entry> create(Entry entry) async {
    final map = entry.toInsertMap();
    map[DBColumn.userId] = SupabaseConfig.userId;
    final response =
        await _client.from(DBTable.entries).insert(map).select().single();
    return Entry.fromMap(response as Map<String, dynamic>);
  }

  Future<Entry> update(Entry entry) async {
    final response = await _client
        .from(DBTable.entries)
        .update(entry.toUpdateMap())
        .eq(DBColumn.id, entry.id)
        .eq(DBColumn.userId, SupabaseConfig.userId)
        .select();

    if ((response as List).isEmpty) {
      throw Exception(
        'Update failed: entry not found or permission denied.',
      );
    }

    return Entry.fromMap(response.first as Map<String, dynamic>);
  }

  Future<void> delete(String entryId) async {
    await _client
        .from(DBTable.entries)
        .delete()
        .eq(DBColumn.id, entryId)
        .eq(DBColumn.userId, SupabaseConfig.userId);
  }

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

    if (query != null && query.trim().isNotEmpty) {
      builder = builder.textSearch(
        'search_vector',
        query.trim(),
        config: 'english',
      );
    }
    if (colorTag != null && colorTag.isNotEmpty) {
      builder = builder.eq(DBColumn.colorTag, colorTag);
    }
    if (fromDate != null) {
      builder = builder.gte(DBColumn.createdAt, fromDate.toIso8601String());
    }
    if (toDate != null) {
      final inclusive = toDate.add(const Duration(days: 1));
      builder = builder.lt(DBColumn.createdAt, inclusive.toIso8601String());
    }

    final response = await builder.order(DBColumn.entryDate, ascending: false);
    return (response as List)
        .map((map) => Entry.fromMap(map as Map<String, dynamic>))
        .toList();
  }
}
