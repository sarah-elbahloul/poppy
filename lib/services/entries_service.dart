import 'dart:convert';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/supabase_client.dart';
import 'package:poppy/models/entry.dart';
import 'package:poppy/services/encryption_service.dart';

/// Poppy — Entries Service
///
/// Handles the lifecycle of journal entries, including storage and retrieval 
/// from Supabase.
/// 
/// **Data Flow:**
/// - **Write:** Plaintext is encrypted with the user's data key before being 
///   sent to the database.
/// - **Read:** Encrypted data is fetched and then decrypted locally before 
///   being converted into [Entry] models.
/// - **Search:** Performed client-side on decrypted data to ensure privacy 
///   while maintaining full-text search capabilities.
class EntriesService {
  final _client = SupabaseConfig.client;
  final _enc    = EncryptionService.instance;

  /// Fetches all entries for the current user, ordered by date descending.
  Future<List<Entry>> fetchAll() async {
    final response = await _client
        .from(DBTable.entries)
        .select()
        .order(DBColumn.entryDate, ascending: false);

    return _decryptList(response as List);
  }

  /// Creates a new journal entry.
  Future<Entry> create(Entry entry) async {
    final map = await _buildEncryptedMap(entry);
    map[DBColumn.userId] = SupabaseConfig.userId;

    final response = await _client
        .from(DBTable.entries)
        .insert(map)
        .select()
        .single();

    return _decryptSingle(response as Map<String, dynamic>);
  }

  /// Updates an existing journal entry.
  Future<Entry> update(Entry entry) async {
    final map = await _buildEncryptedMap(entry);
    map[DBColumn.updatedAt] = DateTime.now().toIso8601String();

    final response = await _client
        .from(DBTable.entries)
        .update(map)
        .eq(DBColumn.id,     entry.id)
        .eq(DBColumn.userId, SupabaseConfig.userId)
        .select()
        .single();

    return _decryptSingle(response as Map<String, dynamic>);
  }

  /// Deletes an entry by its ID.
  Future<void> delete(String entryId) async {
    await _client
        .from(DBTable.entries)
        .delete()
        .eq(DBColumn.id,     entryId)
        .eq(DBColumn.userId, SupabaseConfig.userId);
  }

  /// Searches and filters entries client-side.
  Future<List<Entry>> search({
    String?   query,
    String?   colorTag,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    var entries = await fetchAll();

    if (colorTag != null && colorTag.isNotEmpty) {
      entries = entries
          .where((e) => e.colorTag.dbValue == colorTag)
          .toList();
    }
    if (fromDate != null) {
      entries = entries
          .where((e) => !e.entryDate.isBefore(fromDate))
          .toList();
    }
    if (toDate != null) {
      final inclusive = toDate.add(const Duration(days: 1));
      entries = entries
          .where((e) => e.entryDate.isBefore(inclusive))
          .toList();
    }
    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      entries = entries
          .where((e) =>
      e.title.toLowerCase().contains(q) ||
          e.content.toLowerCase().contains(q))
          .toList();
    }

    return entries;
  }

  // --- Encryption Helpers ---

  Future<Map<String, dynamic>> _buildEncryptedMap(Entry entry) async {
    final encrypted = await _enc.encryptEntry(
      title:   entry.title,
      content: entry.content,
    );
    return {
      DBColumn.titleEnc:   encrypted.titleJson,
      DBColumn.contentEnc: encrypted.contentJson,
      DBColumn.colorTag:   entry.colorTag.dbValue,
      DBColumn.wordCount:  entry.wordCount,
      DBColumn.entryDate:  entry.entryDate
          .toIso8601String()
          .substring(0, 10),
    };
  }

  Future<Entry> _decryptSingle(Map<String, dynamic> row) async {
    final titleJson   = _toJsonString(row[DBColumn.titleEnc]);
    final contentJson = _toJsonString(row[DBColumn.contentEnc]);

    final decrypted = await _enc.decryptEntry(
      titleJson:   titleJson,
      contentJson: contentJson,
    );

    final mutable      = Map<String, dynamic>.from(row);
    mutable['title']   = decrypted.title;
    mutable['content'] = decrypted.content;

    return Entry.fromMap(mutable);
  }

  Future<List<Entry>> _decryptList(List rows) async {
    return Future.wait(
      rows.map((r) => _decryptSingle(r as Map<String, dynamic>)),
    );
  }

  String? _toJsonString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Map)    return jsonEncode(value);
    return null;
  }
}
