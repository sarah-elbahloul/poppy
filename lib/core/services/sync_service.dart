import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/services/supabase_client.dart';
// Pulls in Photo.buildStoragePath() purely for its file-naming convention.
// This is the one spot core/services reaches into a feature model — sync
// logic here is inherently shaped around this app's entries/photos schema,
// so it isn't meant to be a drop-in-portable file like core/style is.
import 'package:poppy/features/journal/data/models/photo.dart';
import 'package:poppy/core/services/local_db_service.dart';
import 'package:path/path.dart' as p;

// ─────────────────────────────────────────────────────────────
//  POPPY — Sync Service
// ─────────────────────────────────────────────────────────────

/// Pushes locally-queued entry/photo changes to Supabase and pulls down
/// remote updates, reconciling them with the local SQLite cache.
class SyncService {
  SyncService._();

  /// Singleton instance of [SyncService].
  static final SyncService instance = SyncService._();

  final _local = LocalDbService.instance;
  final _client = SupabaseConfig.client;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  /// Callback triggered when a sync operation finishes successfully.
  VoidCallback? onSyncComplete;

  bool _isSyncing = false;
  Future<void>? _runningSync;

  /// Starts listening to network connectivity changes to trigger automatic syncs.
  void startListening() {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) syncNow();
    });
  }

  /// Stops listening to connectivity changes.
  void stopListening() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  /// Triggers an immediate synchronization process.
  ///
  /// If a sync is already in progress, it returns the existing future.
  Future<void> syncNow() {
    _runningSync ??= _performSync().whenComplete(() {
      _runningSync = null;
    });

    return _runningSync!;
  }

  Future<void> _performSync() async {
    if (_isSyncing) return;

    final userId = SupabaseConfig.userId;
    if (userId.isEmpty) return;

    _isSyncing = true;

    try {
      final justSyncedEntryIds = await _processQueue(userId);

      await _refreshFromServer(
        userId,
        excludeIds: justSyncedEntryIds,
      );

      onSyncComplete?.call();
    } catch (e) {
      debugPrint('Sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<Set<String>> _processQueue(String userId) async {
    final queue = await _local.getSyncQueue();
    if (queue.isEmpty) return const {};

    final justSyncedEntryIds = <String>{};

    for (final item in queue) {
      final queueId = item['id'] as int;
      final type = item['entity_type'] as String;
      final entityId = item['entity_id'] as String;
      final op = item['operation'] as String;

      try {
        if (type == 'entry') {
          await _syncEntry(entityId, userId, op);
          if (op != SyncOp.delete) {
            justSyncedEntryIds.add(entityId);
          }
        } else if (type == 'photo') {
          await _syncPhoto(entityId, userId, op);
        }
        await _local.dequeue(queueId);
      } catch (e) {
        debugPrint('Failed to sync queue item $queueId ($type): $e');
        continue;
      }
    }

    return justSyncedEntryIds;
  }

  Future<void> _syncEntry(String id, String userId, String op) async {
    if (op == SyncOp.delete) {
      await _client.from(DBTable.entries).delete().eq(DBColumn.id, id).eq(DBColumn.userId, userId);
      await _local.hardDeleteEntry(id);
      return;
    }

    final row = await _local.getEntryById(id);
    if (row == null) return;

    final payload = {
      DBColumn.id: row[DBColumn.id],
      DBColumn.userId: userId,
      DBColumn.titleEnc: row[DBColumn.titleEnc],
      DBColumn.contentEnc: row[DBColumn.contentEnc],
      DBColumn.colorTag: row[DBColumn.colorTag],
      DBColumn.wordCount: row[DBColumn.wordCount],
      DBColumn.entryDate: row[DBColumn.entryDate],
      DBColumn.createdAt: row[DBColumn.createdAt],
      DBColumn.updatedAt: row[DBColumn.updatedAt],
    };

    await _client.from(DBTable.entries).upsert(payload);
    await _local.markEntrySynced(id);
  }

  Future<void> _syncPhoto(String id, String userId, String op) async {
    if (op == SyncOp.delete) {
      final photoRow = await _local.getPhotoById(id);
      if (photoRow != null) {
        final sPath = photoRow[DBColumn.storagePath] as String?;
        if (sPath != null) {
          await _client.storage.from(StorageBucket.photos).remove([sPath]);
        }
      }
      await _client.from(DBTable.photos).delete().eq(DBColumn.id, id).eq(DBColumn.userId, userId);
      await _local.hardDeletePhoto(id);
      return;
    }

    final row = await _local.getPhotoById(id);
    if (row == null) return;

    String? storagePath = row[DBColumn.storagePath] as String?;
    final localPath = row[DBColumn.localPath] as String?;
    final isUploaded = (row[DBColumn.uploaded] as int? ?? 0) == 1;

    if (!isUploaded && localPath != null) {
      final file = File(localPath);
      if (await file.exists()) {
        final entryId = row[DBColumn.entryId] as String;
        final uploadPath = Photo.buildStoragePath(
          userId: userId,
          entryId: entryId,
          filename: p.basename(file.path),
        );
        await _client.storage.from(StorageBucket.photos).upload(uploadPath, file);
        storagePath = uploadPath;
      }
    }

    if (storagePath != null) {
      final payload = {
        DBColumn.id: row[DBColumn.id],
        DBColumn.entryId: row[DBColumn.entryId],
        DBColumn.userId: userId,
        DBColumn.storagePath: storagePath,
        DBColumn.orderIndex: row[DBColumn.orderIndex],
        DBColumn.createdAt: row[DBColumn.createdAt],
      };
      await _client.from(DBTable.photos).upsert(payload);
      await _local.markPhotoSynced(id, storagePath);
    }
  }

  Future<void> _refreshFromServer(String userId, {Set<String>? excludeIds}) async {
    final response = await _client
        .from(DBTable.entries)
        .select()
        .eq(DBColumn.userId, userId)
        .order(DBColumn.entryDate, ascending: false);

    await _local.refreshFromServer(
      userId,
      List<Map<String, dynamic>>.from(response as List),
      excludeIds: excludeIds,
    );
  }
}