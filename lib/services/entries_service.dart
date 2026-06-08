import 'dart:convert';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/supabase_client.dart';
import 'package:poppy/models/entry.dart';
import 'package:poppy/services/encryption_service.dart';
import 'package:poppy/services/local_db_service.dart';
import 'package:poppy/services/sync_service.dart';
import 'package:uuid/uuid.dart';

/// Manages journal entries with an offline-first approach.
///
/// **Read Path:** Reads from the local SQLite database for instantaneous UI feedback,
/// while triggering background synchronization with Supabase.
///
/// **Write Path:** Encrypts content, persists to the local database in a pending state,
/// and notifies the synchronization service to push changes to the cloud.
class EntriesService {
  final _enc = EncryptionService.instance;
  final _local = LocalDbService.instance;
  final _sync = SyncService.instance;
  final _uuid = const Uuid();

  // --- Fetching ---

  /// Retrieves all entries for the current user from the local database.
  ///
  /// Entries are automatically decrypted before being returned.
  Future<List<Entry>> fetchAll() async {
    final userId = SupabaseConfig.userId;
    final rows = await _local.getAll(userId);
    return _decryptList(rows);
  }

  // --- Persistence ---

  /// Creates a new entry, encrypting it before saving locally and triggering sync.
  ///
  /// If [entry.id] is empty, a new UUID is generated.
  Future<Entry> create(Entry entry) async {
    final userId = SupabaseConfig.userId;
    final encrypted = await _buildEncryptedMap(entry);

    final id = entry.id.isEmpty ? _uuid.v4() : entry.id;
    final now = DateTime.now().toIso8601String();
    final row = {
      DBColumn.id: id,
      DBColumn.userId: userId,
      DBColumn.titleEnc: encrypted[DBColumn.titleEnc],
      DBColumn.contentEnc: encrypted[DBColumn.contentEnc],
      DBColumn.colorTag: entry.colorTag.dbValue,
      DBColumn.wordCount: entry.wordCount,
      DBColumn.entryDate: entry.entryDate.toIso8601String().substring(0, 10),
      DBColumn.createdAt: now,
      DBColumn.updatedAt: now,
    };

    await _local.insertPending(row);
    _sync.syncNow();

    return _decryptSingle({...row});
  }

  /// Updates an existing entry locally and triggers a cloud sync.
  Future<Entry> update(Entry entry) async {
    final encrypted = await _buildEncryptedMap(entry);
    final now = DateTime.now().toIso8601String();

    final fields = {
      DBColumn.titleEnc: encrypted[DBColumn.titleEnc],
      DBColumn.contentEnc: encrypted[DBColumn.contentEnc],
      DBColumn.colorTag: entry.colorTag.dbValue,
      DBColumn.wordCount: entry.wordCount,
      DBColumn.entryDate: entry.entryDate.toIso8601String().substring(0, 10),
      DBColumn.updatedAt: now,
    };

    await _local.updatePending(entry.id, fields);
    _sync.syncNow();

    final updated = await _local.getById(entry.id);
    return _decryptSingle({...?updated});
  }

  /// Marks an entry for deletion locally and triggers a cloud sync.
  Future<void> delete(String entryId) async {
    await _local.markDeletePending(entryId);
    _sync.syncNow();
  }

  /// Marks multiple entries for deletion locally and triggers a cloud sync.
  Future<void> deleteBatch(List<String> entryIds) async {
    await _local.markDeleteBatchPending(entryIds);
    _sync.syncNow();
  }

  // --- Search & Filter ---

  /// Performs a client-side search across decrypted entries.
  ///
  /// Supports filtering by keyword [query], [colorTag], and date range ([fromDate] to [toDate]).
  Future<List<Entry>> search({
    String? query,
    String? colorTag,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    var entries = await fetchAll();

    if (colorTag != null && colorTag.isNotEmpty) {
      entries = entries.where((e) => e.colorTag.dbValue == colorTag).toList();
    }
    if (fromDate != null) {
      entries = entries.where((e) => !e.entryDate.isBefore(fromDate)).toList();
    }
    if (toDate != null) {
      final inclusive = toDate.add(const Duration(days: 1));
      entries = entries.where((e) => e.entryDate.isBefore(inclusive)).toList();
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

  // --- Internal Encryption ---

  /// Encrypts the title and content of an [entry] for persistence.
  Future<Map<String, dynamic>> _buildEncryptedMap(Entry entry) async {
    final encrypted = await _enc.encryptEntry(
      title: entry.title,
      content: entry.content,
    );
    return {
      DBColumn.titleEnc: encrypted.titleJson,
      DBColumn.contentEnc: encrypted.contentJson,
      DBColumn.colorTag: entry.colorTag.dbValue,
      DBColumn.wordCount: entry.wordCount,
      DBColumn.entryDate: entry.entryDate.toIso8601String().substring(0, 10),
    };
  }

  /// Decrypts a single database [row] and returns an [Entry] object.
  Future<Entry> _decryptSingle(Map<String, dynamic> row) async {
    final titleJson = _toJsonString(row[DBColumn.titleEnc]);
    final contentJson = _toJsonString(row[DBColumn.contentEnc]);

    final decrypted = await _enc.decryptEntry(
      titleJson: titleJson,
      contentJson: contentJson,
    );

    final mutable = Map<String, dynamic>.from(row);
    mutable['title'] = decrypted.title;
    mutable['content'] = decrypted.content;

    return Entry.fromMap(mutable);
  }

  /// Decrypts a list of database [rows] concurrently.
  Future<List<Entry>> _decryptList(List<Map<String, dynamic>> rows) async {
    return Future.wait(rows.map(_decryptSingle));
  }

  /// Ensures dynamic database values are correctly formatted as JSON strings.
  String? _toJsonString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Map) return jsonEncode(value);
    return null;
  }
}
