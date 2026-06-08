import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Supported synchronization states for local database records.
class SyncStatus {
  SyncStatus._();

  /// Record is fully synchronized with the remote backend.
  static const String synced = 'synced';

  /// Record was created locally and has not yet been sent to the server.
  static const String pendingCreate = 'pending_create';

  /// Record was updated locally and the changes are pending synchronization.
  static const String pendingUpdate = 'pending_update';

  /// Record was marked for deletion locally and is awaiting remote removal.
  static const String pendingDelete = 'pending_delete';
}

/// Manages the local SQLite database for offline-first journal entries.
///
/// This service stores encrypted entry blobs to maintain privacy at rest.
/// It uses a [SyncStatus] to track and manage data consistency between
/// the local cache and the remote Supabase backend.
class LocalDbService {
  LocalDbService._();

  /// Singleton instance of [LocalDbService].
  static final LocalDbService instance = LocalDbService._();

  Database? _db;

  /// Initializes the local database and sets up the schema.
  ///
  /// This must be called before any data access operations.
  Future<void> init() async {
    if (_db != null) return;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'poppy_local.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  /// Creates the database tables and indexes.
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE entries (
        id           TEXT    PRIMARY KEY,
        user_id      TEXT    NOT NULL,
        title_enc    TEXT,
        content_enc  TEXT,
        color_tag    TEXT    NOT NULL DEFAULT 'stone',
        word_count   INTEGER NOT NULL DEFAULT 0,
        entry_date   TEXT    NOT NULL,
        created_at   TEXT    NOT NULL,
        updated_at   TEXT    NOT NULL,
        sync_status  TEXT    NOT NULL DEFAULT '${SyncStatus.synced}'
      )
    ''');

    await db.execute('CREATE INDEX idx_entries_user ON entries (user_id)');
    await db.execute('CREATE INDEX idx_entries_sync ON entries (sync_status)');
  }

  /// Internal getter for the database instance, ensuring it is initialized.
  Database get _database {
    assert(_db != null, 'LocalDbService.init() was not called.');
    return _db!;
  }

  // --- Querying ---

  /// Retrieves all entries for a specific [userId], excluding those marked for deletion.
  ///
  /// Entries are returned ordered by date (descending).
  Future<List<Map<String, dynamic>>> getAll(String userId) async {
    return _database.query(
      'entries',
      where: 'user_id = ? AND sync_status != ?',
      whereArgs: [userId, SyncStatus.pendingDelete],
      orderBy: 'entry_date DESC, created_at DESC',
    );
  }

  /// Retrieves a single entry by its unique [id].
  Future<Map<String, dynamic>?> getById(String id) async {
    final rows = await _database.query(
      'entries',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  // --- Local Writes ---

  /// Inserts a new entry locally, marking it as [SyncStatus.pendingCreate].
  Future<void> insertPending(Map<String, dynamic> row) async {
    final data = Map<String, dynamic>.from(row);
    data['sync_status'] = SyncStatus.pendingCreate;
    await _database.insert(
      'entries',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Updates an entry locally.
  ///
  /// If the entry is not already [SyncStatus.pendingCreate], it is marked as
  /// [SyncStatus.pendingUpdate].
  Future<void> updatePending(String id, Map<String, dynamic> fields) async {
    final existing = await getById(id);
    final currentStatus = existing?['sync_status'] as String? ?? SyncStatus.synced;

    final data = Map<String, dynamic>.from(fields);
    if (currentStatus != SyncStatus.pendingCreate) {
      data['sync_status'] = SyncStatus.pendingUpdate;
    }
    await _database.update(
      'entries',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Marks an entry for deletion.
  ///
  /// If the entry was never synced ([SyncStatus.pendingCreate]), it is permanently
  /// removed immediately. Otherwise, its status is changed to [SyncStatus.pendingDelete].
  Future<void> markDeletePending(String id) async {
    final existing = await getById(id);
    final currentStatus = existing?['sync_status'] as String? ?? SyncStatus.synced;

    if (currentStatus == SyncStatus.pendingCreate) {
      await _database.delete(
        'entries',
        where: 'id = ?',
        whereArgs: [id],
      );
    } else {
      await _database.update(
        'entries',
        {'sync_status': SyncStatus.pendingDelete},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  /// Marks multiple entries for deletion in a single batch.
  Future<void> markDeleteBatchPending(List<String> ids) async {
    if (ids.isEmpty) return;

    final batch = _database.batch();
    
    // Fetch statuses for all targeted IDs to decide on hard vs soft delete.
    final placeholders = List.filled(ids.length, '?').join(',');
    final existing = await _database.query(
      'entries',
      columns: ['id', 'sync_status'],
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );

    final statusMap = {
      for (final row in existing) 
        row['id'] as String: row['sync_status'] as String
    };

    for (final id in ids) {
      final status = statusMap[id] ?? SyncStatus.synced;
      if (status == SyncStatus.pendingCreate) {
        batch.delete('entries', where: 'id = ?', whereArgs: [id]);
      } else {
        batch.update(
          'entries',
          {'sync_status': SyncStatus.pendingDelete},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }

    await batch.commit(noResult: true);
  }

  // --- Sync Management ---

  /// Returns all records for a [userId] that have pending local changes.
  Future<List<Map<String, dynamic>>> getPending(String userId) async {
    return _database.query(
      'entries',
      where: 'user_id = ? AND sync_status != ?',
      whereArgs: [userId, SyncStatus.synced],
    );
  }

  /// Updates the status of an entry to [SyncStatus.synced].
  Future<void> markSynced(String id) async {
    await _database.update(
      'entries',
      {'sync_status': SyncStatus.synced},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Permanently removes a record from the local database.
  Future<void> hardDelete(String id) async {
    await _database.delete(
      'entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Reconciles local data with fresh results from the server.
  ///
  /// This replaces all currently synced local records with the provided [serverRows].
  /// Entries with pending local changes are preserved.
  Future<void> refreshFromServer(
    String userId,
    List<Map<String, dynamic>> serverRows,
  ) async {
    final batch = _database.batch();

    // Remove existing synced records to avoid stale data.
    final synced = await _database.query(
      'entries',
      columns: ['id'],
      where: 'user_id = ? AND sync_status = ?',
      whereArgs: [userId, SyncStatus.synced],
    );
    for (final row in synced) {
      batch.delete(
        'entries',
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }

    // Insert new records from the server.
    for (final row in serverRows) {
      final data = _serverRowToLocal(row, userId);
      data['sync_status'] = SyncStatus.synced;
      batch.insert(
        'entries',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  // --- Helpers ---

  /// Maps a row from the Supabase response to a format suitable for the local SQLite table.
  static Map<String, dynamic> _serverRowToLocal(
    Map<String, dynamic> row,
    String userId,
  ) {
    return {
      'id': row['id'] as String,
      'user_id': userId,
      'title_enc': _toJsonString(row['title_enc']),
      'content_enc': _toJsonString(row['content_enc']),
      'color_tag': row['color_tag'] as String? ?? 'stone',
      'word_count': row['word_count'] as int? ?? 0,
      'entry_date': row['entry_date'] as String,
      'created_at': row['created_at'] as String,
      'updated_at': row['updated_at'] as String,
    };
  }

  /// Ensures that dynamic JSON values from the server are stored as strings locally.
  static String? _toJsonString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Map) return jsonEncode(value);
    return null;
  }

  /// Wipes all local entries for a specific user.
  Future<void> clearForUser(String userId) async {
    await _database.delete(
      'entries',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  /// Closes the database connection.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
