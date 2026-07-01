import 'dart:async';
import 'dart:convert';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/services/supabase_client.dart';
import 'package:poppy/features/journal/data/models/entry.dart';
import 'package:poppy/features/auth/data/services/encryption_service.dart';
import 'package:poppy/core/services/local_db_service.dart';
import 'package:poppy/core/services/sync_service.dart';
import 'package:uuid/uuid.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Entries Service
// ─────────────────────────────────────────────────────────────

/// Service responsible for managing journal entries.
///
/// Handles CRUD operations, encryption/decryption, and local database interactions.
class EntriesService {
  final _enc = EncryptionService.instance;
  final _local = LocalDbService.instance;
  final _sync = SyncService.instance;
  final _uuid = const Uuid();

  /// Fetches all journal entries for the current user.
  ///
  /// Decrypts the entries before returning them.
  Future<List<Entry>> fetchAll() async {
    final userId = SupabaseConfig.userId;
    final rows = await _local.getAllEntries(userId);
    return _decryptList(rows);
  }

  /// Searches for entries based on various filters.
  ///
  /// Filters include text [query], [colorTag], [fromDate], and [toDate].
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

  /// Creates a new journal entry.
  ///
  /// Encrypts the title and content before saving to the local database.
  /// Assigns a unique ID and timestamps if not already present.
  Future<Entry> create(Entry entry) async {
    final userId = SupabaseConfig.userId;
    final encrypted = await _buildEncryptedMap(entry);

    final id = entry.id.isEmpty ? _uuid.v4() : entry.id;
    final now = DateTime.now().toUtc();

    final row = {
      DBColumn.id: id,
      DBColumn.userId: userId,
      DBColumn.titleEnc: encrypted[DBColumn.titleEnc],
      DBColumn.contentEnc: encrypted[DBColumn.contentEnc],
      DBColumn.colorTag: entry.colorTag.dbValue,
      DBColumn.wordCount: entry.wordCount,
      DBColumn.entryDate: entry.entryDate.toIso8601String().substring(0, 10),
      DBColumn.createdAt: now.toIso8601String(),
      DBColumn.updatedAt: now.toIso8601String(),
    };

    await _local.insertEntry(row);

    return entry.copyWith(
      id: id,
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.pendingCreate,
    );
  }

  /// Updates an existing journal entry.
  ///
  /// Encrypts updated content and updates the local database.
  Future<Entry> update(Entry entry) async {
    final encrypted = await _buildEncryptedMap(entry);
    final now = DateTime.now().toUtc().toIso8601String();

    final fields = {
      DBColumn.titleEnc: encrypted[DBColumn.titleEnc],
      DBColumn.contentEnc: encrypted[DBColumn.contentEnc],
      DBColumn.colorTag: entry.colorTag.dbValue,
      DBColumn.wordCount: entry.wordCount,
      DBColumn.entryDate: entry.entryDate.toIso8601String().substring(0, 10),
      DBColumn.updatedAt: now,
    };

    await _local.updateEntry(entry.id, fields);

    final newStatus = entry.syncStatus == SyncStatus.pendingCreate
        ? SyncStatus.pendingCreate
        : SyncStatus.pendingUpdate;

    return entry.copyWith(
      updatedAt: DateTime.parse(now),
      syncStatus: newStatus,
    );
  }

  /// Deletes an entry by its [entryId].
  ///
  /// Marks the entry as deleted locally and triggers a background sync.
  Future<void> delete(String entryId) async {
    await _local.markEntryDeleted(entryId);
    unawaited(_sync.syncNow());
  }

  /// Deletes multiple entries specified by [entryIds].
  ///
  /// Marks the entries as deleted locally and triggers a background sync.
  Future<void> deleteBatch(List<String> entryIds) async {
    await _local.markEntriesDeleted(entryIds);
    unawaited(_sync.syncNow());
  }

  Future<Map<String, dynamic>> _buildEncryptedMap(Entry entry) async {
    final encrypted = await _enc.encryptEntry(
      title: entry.title,
      content: entry.content,
    );
    return {
      DBColumn.titleEnc: encrypted.titleJson,
      DBColumn.contentEnc: encrypted.contentJson,
    };
  }

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

  Future<List<Entry>> _decryptList(List<Map<String, dynamic>> rows) async {
    return Future.wait(rows.map(_decryptSingle));
  }

  String? _toJsonString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Map) return jsonEncode(value);
    return null;
  }
}