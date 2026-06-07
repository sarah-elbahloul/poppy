import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:poppy/core/supabase_client.dart';
import 'package:poppy/services/local_db_service.dart';

/// Manages synchronization between the local database and the remote Supabase backend.
///
/// **Responsibilities:**
/// - Listens for network connectivity changes and initiates sync when online.
/// - Drains the local pending queue by pushing created, updated, or deleted records to the cloud.
/// - Fetches the latest server state to refresh the local cache.
/// - Notifies subscribers via [onSyncComplete] when a synchronization cycle finishes.
///
/// **Conflict Resolution:**
/// Uses a "last-write-wins" strategy. This is deemed acceptable for a personal diary
/// application where concurrent multi-device editing of the same entry is rare.
class SyncService {
  SyncService._();

  /// Singleton instance of [SyncService].
  static final SyncService instance = SyncService._();

  final _local = LocalDbService.instance;
  final _client = SupabaseConfig.client;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  /// Callback triggered after a successful synchronization cycle.
  VoidCallback? onSyncComplete;

  bool _isSyncing = false;

  // --- Lifecycle Management ---

  /// Starts monitoring network connectivity.
  ///
  /// Should be called after the user is authenticated and encryption keys are ready.
  void startListening() {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen(
      (results) {
        final hasNetwork = results.any((r) => r != ConnectivityResult.none);
        if (hasNetwork) _triggerSync();
      },
    );
  }

  /// Stops monitoring network connectivity and cleans up resources.
  void stopListening() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  // --- Synchronization API ---

  /// Manually triggers a synchronization cycle.
  ///
  /// Safe to call concurrently; subsequent calls while a sync is in progress are ignored.
  Future<void> syncNow() async => _triggerSync();

  // --- Internal Sync Logic ---

  /// Internal implementation of the synchronization process.
  Future<void> _triggerSync() async {
    if (_isSyncing) return;
    final userId = SupabaseConfig.currentUser?.id;
    if (userId == null) return;

    _isSyncing = true;
    try {
      await _drainQueue(userId);
      await _refreshFromServer(userId);
      onSyncComplete?.call();
    } catch (_) {
      // Sync failures are silent; the app continues to operate on local data.
    } finally {
      _isSyncing = false;
    }
  }

  /// Pushes all pending local changes to the remote server.
  Future<void> _drainQueue(String userId) async {
    final pending = await _local.getPending(userId);
    if (pending.isEmpty) return;

    for (final row in pending) {
      final status = row['sync_status'] as String;
      final id = row['id'] as String;

      try {
        switch (status) {
          case SyncStatus.pendingCreate:
            await _pushCreate(row, userId);
            await _local.markSynced(id);
            break;

          case SyncStatus.pendingUpdate:
            await _pushUpdate(row, userId);
            await _local.markSynced(id);
            break;

          case SyncStatus.pendingDelete:
            await _pushDelete(id, userId);
            await _local.hardDelete(id);
            break;
        }
      } catch (_) {
        // Continue attempting to sync other rows if one fails.
        continue;
      }
    }
  }

  /// Pushes a new entry to the server.
  Future<void> _pushCreate(Map<String, dynamic> row, String userId) async {
    final payload = _toServerPayload(row, userId);
    await _client.from('entries').upsert(payload);
  }

  /// Pushes an updated entry to the server.
  Future<void> _pushUpdate(Map<String, dynamic> row, String userId) async {
    final payload = _toServerPayload(row, userId);
    // Ensure created_at is never overwritten on update.
    payload.remove('created_at');
    await _client
        .from('entries')
        .update(payload)
        .eq('id', row['id'] as String)
        .eq('user_id', userId);
  }

  /// Removes an entry from the server.
  Future<void> _pushDelete(String id, String userId) async {
    await _client
        .from('entries')
        .delete()
        .eq('id', id)
        .eq('user_id', userId);
  }

  /// Refetches all entries from the server and updates the local cache.
  Future<void> _refreshFromServer(String userId) async {
    final response = await _client
        .from('entries')
        .select()
        .eq('user_id', userId)
        .order('entry_date', ascending: false);

    await _local.refreshFromServer(userId, response as List<Map<String, dynamic>>);
  }

  // --- Serialization Helpers ---

  /// Maps a local database row to the payload format expected by Supabase.
  static Map<String, dynamic> _toServerPayload(Map<String, dynamic> row, String userId) {
    return {
      'id': row['id'],
      'user_id': userId,
      'title_enc': _parseJsonField(row['title_enc']),
      'content_enc': _parseJsonField(row['content_enc']),
      'color_tag': row['color_tag'],
      'word_count': row['word_count'],
      'entry_date': row['entry_date'],
      'created_at': row['created_at'],
      'updated_at': row['updated_at'],
    };
  }

  /// Ensures that JSON fields stored as strings in SQLite are decoded before transmission.
  static dynamic _parseJsonField(dynamic value) {
    if (value == null) return null;
    if (value is Map) return value;
    if (value is String) {
      try {
        return jsonDecode(value);
      } catch (_) {}
    }
    return value;
  }
}
