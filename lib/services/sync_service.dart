import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/supabase_client.dart';
import 'package:poppy/models/photo.dart';
import 'package:poppy/services/local_db_service.dart';
import 'package:path/path.dart' as p;

// ─────────────────────────────────────────────────────────────
//  POPPY — Sync Service
//  Location: lib/services/sync_service.dart
// ─────────────────────────────────────────────────────────────

/// Manages background synchronization for entries and photos between local SQLite and Supabase.
/// 
/// This service implements the "Offline-First" synchronization logic:
/// 1. Monitors connectivity changes.
/// 2. Processes a local `sync_queue` table for pending creates/updates/deletes.
/// 3. Refreshes local state from the server to pull down changes from other devices.
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  final _local = LocalDbService.instance;
  final _client = SupabaseConfig.client;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  
  /// Callback triggered when a full sync cycle completes successfully.
  VoidCallback? onSyncComplete;
  
  bool _isSyncing = false;

  // ─────────────────────────────────────────────────────────────
  //  Lifecycle Management
  // ─────────────────────────────────────────────────────────────

  /// Starts listening to network connectivity changes to trigger auto-sync.
  void startListening() {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) syncNow();
    });
  }

  /// Stops network monitoring.
  void stopListening() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  // ─────────────────────────────────────────────────────────────
  //  Core Sync Logic
  // ─────────────────────────────────────────────────────────────

  /// Orchestrates a full synchronization cycle: Uploading local changes followed by downloading remote ones.
  Future<void> syncNow() async {
    if (_isSyncing) return;
    final userId = SupabaseConfig.userId;
    if (userId.isEmpty) return;

    _isSyncing = true;
    try {
      // 1. Process local changes first (Upload)
      final justSyncedEntryIds = await _processQueue(userId);
      
      // 2. Pull remote changes (Download), excluding what we just sent
      await _refreshFromServer(userId, excludeIds: justSyncedEntryIds);
      
      onSyncComplete?.call();
    } catch (e) {
      debugPrint('Sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Iterates through the local sync queue and attempts to process each operation.
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

  // ─────────────────────────────────────────────────────────────
  //  Entity Synchronization
  // ─────────────────────────────────────────────────────────────

  /// Syncs a single entry to the cloud.
  Future<void> _syncEntry(String id, String userId, String op) async {
    if (op == SyncOp.delete) {
      await _client.from(DBTable.entries).delete().eq(DBColumn.id, id).eq(DBColumn.userId, userId);
      await _local.hardDeleteEntry(id);
      return;
    }

    final row = await _local.getEntryById(id);
    if (row == null) return;

    // We send raw encrypted JSON strings directly to avoid re-encoding issues.
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

  /// Syncs a photo attachment, including binary upload to storage if needed.
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

    // Handle binary file upload if not yet in the cloud
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

    // Upsert metadata to DB
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

  // ─────────────────────────────────────────────────────────────
  //  Server Refresh
  // ─────────────────────────────────────────────────────────────

  /// Pulls the latest entries for the user from Supabase and reconciles them with local SQLite.
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
