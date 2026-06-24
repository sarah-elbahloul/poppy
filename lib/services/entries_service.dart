import 'dart:async';
import 'dart:convert';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/supabase_client.dart';
import 'package:poppy/models/entry.dart';
import 'package:poppy/services/encryption_service.dart';
import 'package:poppy/services/local_db_service.dart';
import 'package:poppy/services/sync_service.dart';
import 'package:uuid/uuid.dart';

/// Manages journal entries with an offline-first approach.
class EntriesService {
  final _enc = EncryptionService.instance;
  final _local = LocalDbService.instance;
  final _sync = SyncService.instance;
  final _uuid = const Uuid();

  // --- Fetching ---

  /// Retrieves all entries for the current user from the local database.
  Future<List<Entry>> fetchAll() async {
    final userId = SupabaseConfig.userId;
    final rows = await _local.getAllEntries(userId);
    return _decryptList(rows);
  }

  // --- Persistence ---

  /// Creates a new entry, encrypting it before saving locally.
  ///
  /// **Does NOT trigger sync here.** Sync is initiated by the provider's
  /// [fetchEntries], connectivity changes, or the next explicit sync call.
  /// Triggering sync from within create/update caused a race condition:
  /// the background sync would mark the entry as "synced" and then
  /// [_refreshFromServer] would delete it before [getEntryById] could
  /// read it back, returning null and producing an empty entry.
  ///
  /// Returns the caller's entry with the generated [id], [createdAt], and
  /// [updatedAt] filled in — no round-trip read from SQLite.
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
    // Sync is NOT triggered here — see doc comment above.

    // [LocalDbService.insertEntry] always stamps newly-inserted rows with
    // SyncStatus.pendingCreate. Reflect that on the returned entry too —
    // otherwise the in-memory/UI copy still shows the caller's default
    // (SyncStatus.synced), so the pending-sync dot on the entry card stays
    // hidden until the next full fetchEntries() reload.
    return entry.copyWith(
      id: id,
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.pendingCreate,
    );
  }

  /// Updates an existing entry locally.
  ///
  /// **Does NOT trigger sync here** (see [create] for rationale).
  ///
  /// Returns the caller's entry with [updatedAt] refreshed — no round-trip
  /// read from SQLite, which eliminates the race condition that was
  /// wiping title and content.
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
    // Sync is NOT triggered here — see [create] doc comment.

    // Mirror [LocalDbService.updateEntry]'s status transition so the
    // returned entry's syncStatus matches what was actually persisted:
    // an entry that was never synced (pendingCreate) stays pendingCreate;
    // anything else becomes pendingUpdate. Without this, the in-memory
    // copy keeps the caller's old syncStatus (often "synced"), so the
    // pending-sync dot doesn't appear immediately after an edit.
    final newStatus = entry.syncStatus == SyncStatus.pendingCreate
        ? SyncStatus.pendingCreate
        : SyncStatus.pendingUpdate;

    return entry.copyWith(
      updatedAt: DateTime.parse(now),
      syncStatus: newStatus,
    );
  }

  /// Marks an entry for deletion locally and triggers a cloud sync.
  ///
  /// Safe to trigger sync here because there is no read-back after the
  /// write — the provider already did an optimistic in-memory removal.
  Future<void> delete(String entryId) async {
    await _local.markEntryDeleted(entryId);
    unawaited(_sync.syncNow());
  }

  /// Marks multiple entries for deletion locally and triggers a cloud sync.
  Future<void> deleteBatch(List<String> entryIds) async {
    await _local.markEntriesDeleted(entryIds);
    unawaited(_sync.syncNow());
  }

  // --- Search & Filter ---

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