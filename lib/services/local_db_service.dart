import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:poppy/core/constants.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Local Database Service
//  Location: lib/services/local_db_service.dart
// ─────────────────────────────────────────────────────────────

/// Represents the synchronization state of a record in the local database.
class SyncStatus {
  SyncStatus._();
  static const String synced = 'synced';
  static const String pendingCreate = 'pending_create';
  static const String pendingUpdate = 'pending_update';
  static const String pendingDelete = 'pending_delete';
  static const String failed = 'failed';
}

/// Operations that can be queued for cloud synchronization.
class SyncOp {
  SyncOp._();
  static const String create = 'create';
  static const String update = 'update';
  static const String delete = 'delete';
}

/// Manages the local SQLite database for offline-first data persistence.
/// 
/// This service handles:
/// - Database schema creation and migrations.
/// - CRUD operations for entries and photos.
/// - Maintaining a `sync_queue` for background cloud synchronization.
class LocalDbService {
  LocalDbService._();
  static final LocalDbService instance = LocalDbService._();

  Database? _db;

  /// Initializes the SQLite database.
  Future<void> init() async {
    if (_db != null) return;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'poppy_local.db');

    _db = await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Schema Management
  // ─────────────────────────────────────────────────────────────

  Future<void> _onCreate(Database db, int version) async {
    // Journal Entries Table
    await db.execute('''
      CREATE TABLE entries (
        ${DBColumn.id}           TEXT    PRIMARY KEY,
        ${DBColumn.userId}       TEXT    NOT NULL,
        ${DBColumn.titleEnc}     TEXT,
        ${DBColumn.contentEnc}   TEXT,
        ${DBColumn.colorTag}     TEXT    NOT NULL DEFAULT 'stone',
        ${DBColumn.wordCount}    INTEGER NOT NULL DEFAULT 0,
        ${DBColumn.entryDate}    TEXT    NOT NULL,
        ${DBColumn.createdAt}    TEXT    NOT NULL,
        ${DBColumn.updatedAt}    TEXT    NOT NULL,
        ${DBColumn.syncStatus}   TEXT    NOT NULL DEFAULT '${SyncStatus.synced}',
        ${DBColumn.isDeleted}    INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Photo Attachments Table
    await db.execute('''
      CREATE TABLE photos (
        ${DBColumn.id}           TEXT    PRIMARY KEY,
        ${DBColumn.entryId}      TEXT    NOT NULL,
        ${DBColumn.userId}       TEXT    NOT NULL,
        ${DBColumn.storagePath}  TEXT,
        ${DBColumn.localPath}    TEXT,
        ${DBColumn.orderIndex}   INTEGER NOT NULL DEFAULT 0,
        ${DBColumn.uploaded}     INTEGER NOT NULL DEFAULT 0,
        ${DBColumn.createdAt}    TEXT    NOT NULL,
        ${DBColumn.syncStatus}   TEXT    NOT NULL DEFAULT '${SyncStatus.synced}'
      )
    ''');

    // Outbound Synchronization Queue
    await db.execute('''
      CREATE TABLE sync_queue (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type  TEXT    NOT NULL,
        entity_id    TEXT    NOT NULL,
        operation    TEXT    NOT NULL,
        created_at   TEXT    NOT NULL
      )
    ''');

    // Indexes for performance
    await db.execute('CREATE INDEX idx_entries_user ON entries (${DBColumn.userId})');
    await db.execute('CREATE INDEX idx_entries_sync ON entries (${DBColumn.syncStatus})');
    await db.execute('CREATE INDEX idx_photos_entry ON photos (${DBColumn.entryId})');
    await db.execute('CREATE INDEX idx_sync_queue_created ON sync_queue (created_at)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try { await db.execute('ALTER TABLE entries ADD COLUMN ${DBColumn.isDeleted} INTEGER NOT NULL DEFAULT 0'); } catch (_) {}
      try { await db.execute('ALTER TABLE entries ADD COLUMN ${DBColumn.syncStatus} TEXT NOT NULL DEFAULT "${SyncStatus.synced}"'); } catch (_) {}
      
      await db.execute('''
        CREATE TABLE IF NOT EXISTS photos (
          ${DBColumn.id}           TEXT    PRIMARY KEY,
          ${DBColumn.entryId}      TEXT    NOT NULL,
          ${DBColumn.userId}       TEXT    NOT NULL,
          ${DBColumn.storagePath}  TEXT,
          ${DBColumn.localPath}    TEXT,
          ${DBColumn.orderIndex}   INTEGER NOT NULL DEFAULT 0,
          ${DBColumn.uploaded}     INTEGER NOT NULL DEFAULT 0,
          ${DBColumn.createdAt}    TEXT    NOT NULL,
          ${DBColumn.syncStatus}   TEXT    NOT NULL DEFAULT '${SyncStatus.synced}'
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_queue (
          id           INTEGER PRIMARY KEY AUTOINCREMENT,
          entity_type  TEXT    NOT NULL,
          entity_id    TEXT    NOT NULL,
          operation    TEXT    NOT NULL,
          created_at   TEXT    NOT NULL
        )
      ''');
    }
  }

  Database get _database {
    assert(_db != null, 'LocalDbService.init() was not called.');
    return _db!;
  }

  // ─────────────────────────────────────────────────────────────
  //  Sync Queue Management
  // ─────────────────────────────────────────────────────────────

  /// Enqueues a sync operation within an existing database [batch].
  Future<void> _enqueue(Batch batch, String type, String id, String op) async {
    batch.insert('sync_queue', {
      'entity_type': type,
      'entity_id': id,
      'operation': op,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Retrieves the oldest pending operations from the sync queue.
  Future<List<Map<String, dynamic>>> getSyncQueue({int limit = 50}) async {
    return _database.query('sync_queue', orderBy: 'created_at ASC', limit: limit);
  }

  /// Removes a processed item from the sync queue.
  Future<void> dequeue(int queueId) async {
    await _database.delete('sync_queue', where: 'id = ?', whereArgs: [queueId]);
  }

  // ─────────────────────────────────────────────────────────────
  //  Entry Operations
  // ─────────────────────────────────────────────────────────────

  /// Fetches all active entries for a user, sorted by date.
  Future<List<Map<String, dynamic>>> getAllEntries(String userId) async {
    return _database.query('entries', 
      where: '${DBColumn.userId} = ? AND ${DBColumn.isDeleted} = 0', 
      whereArgs: [userId], 
      orderBy: '${DBColumn.entryDate} DESC, ${DBColumn.createdAt} DESC'
    );
  }

  /// Fetches a single entry by its unique ID.
  Future<Map<String, dynamic>?> getEntryById(String id) async {
    final rows = await _database.query('entries', where: '${DBColumn.id} = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  /// Inserts a new entry and automatically enqueues it for creation in the cloud.
  Future<void> insertEntry(Map<String, dynamic> row) async {
    final data = Map<String, dynamic>.from(row);
    data[DBColumn.syncStatus] = SyncStatus.pendingCreate;
    data[DBColumn.isDeleted] = 0;
    final batch = _database.batch();
    batch.insert('entries', data, conflictAlgorithm: ConflictAlgorithm.replace);
    await _enqueue(batch, 'entry', data[DBColumn.id] as String, SyncOp.create);
    await batch.commit(noResult: true);
  }

  /// Updates an entry's fields and enqueues the change for synchronization.
  Future<void> updateEntry(String id, Map<String, dynamic> fields) async {
    final existing = await getEntryById(id);
    if (existing == null) return;
    final data = Map<String, dynamic>.from(fields);
    if (existing[DBColumn.syncStatus] != SyncStatus.pendingCreate) {
      data[DBColumn.syncStatus] = SyncStatus.pendingUpdate;
    }
    final batch = _database.batch();
    batch.update('entries', data, where: '${DBColumn.id} = ?', whereArgs: [id]);
    await _enqueue(batch, 'entry', id, SyncOp.update);
    await batch.commit(noResult: true);
  }

  /// Marks an entry as deleted. If it hasn't been synced yet, it is removed entirely.
  Future<void> markEntryDeleted(String id) async {
    final existing = await getEntryById(id);
    if (existing == null) return;
    final batch = _database.batch();
    if (existing[DBColumn.syncStatus] == SyncStatus.pendingCreate) {
      batch.delete('entries', where: '${DBColumn.id} = ?', whereArgs: [id]);
      batch.delete('sync_queue', where: 'entity_id = ? AND entity_type = ?', whereArgs: [id, 'entry']);
    } else {
      batch.update('entries', {DBColumn.syncStatus: SyncStatus.pendingDelete, DBColumn.isDeleted: 1}, where: '${DBColumn.id} = ?', whereArgs: [id]);
      await _enqueue(batch, 'entry', id, SyncOp.delete);
    }
    await batch.commit(noResult: true);
  }

  /// Batch version of [markEntryDeleted].
  Future<void> markEntriesDeleted(List<String> ids) async {
    final batch = _database.batch();
    for (final id in ids) {
      final existing = await getEntryById(id);
      if (existing == null) continue;
      if (existing[DBColumn.syncStatus] == SyncStatus.pendingCreate) {
        batch.delete('entries', where: '${DBColumn.id} = ?', whereArgs: [id]);
        batch.delete('sync_queue', where: 'entity_id = ? AND entity_type = ?', whereArgs: [id, 'entry']);
      } else {
        batch.update('entries', {DBColumn.syncStatus: SyncStatus.pendingDelete, DBColumn.isDeleted: 1}, where: '${DBColumn.id} = ?', whereArgs: [id]);
        batch.insert('sync_queue', {
          'entity_type': 'entry',
          'entity_id': id,
          'operation': SyncOp.delete,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
    }
    await batch.commit(noResult: true);
  }

  /// Updates an entry's status to [SyncStatus.synced].
  Future<void> markEntrySynced(String id) async {
    await _database.update('entries', {DBColumn.syncStatus: SyncStatus.synced}, where: '${DBColumn.id} = ?', whereArgs: [id]);
  }

  /// Permanently removes an entry from the local database.
  Future<void> hardDeleteEntry(String id) async {
    await _database.delete('entries', where: '${DBColumn.id} = ?', whereArgs: [id]);
  }

  // ─────────────────────────────────────────────────────────────
  //  Photo Operations
  // ─────────────────────────────────────────────────────────────

  /// Retrieves photo metadata associated with a specific entry.
  Future<List<Map<String, dynamic>>> getPhotosForEntry(String entryId) async {
    return _database.query('photos', 
      where: '${DBColumn.entryId} = ? AND ${DBColumn.syncStatus} != ?', 
      whereArgs: [entryId, SyncStatus.pendingDelete], 
      orderBy: '${DBColumn.orderIndex} ASC'
    );
  }

  /// Fetches a single photo by its unique ID.
  Future<Map<String, dynamic>?> getPhotoById(String id) async {
    final rows = await _database.query('photos', where: '${DBColumn.id} = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  /// Inserts a photo record and enqueues it for synchronization.
  Future<void> insertPhoto(Map<String, dynamic> row) async {
    final data = Map<String, dynamic>.from(row);
    data[DBColumn.syncStatus] = SyncStatus.pendingCreate;
    data[DBColumn.uploaded] = 0;
    final batch = _database.batch();
    batch.insert('photos', data, conflictAlgorithm: ConflictAlgorithm.replace);
    await _enqueue(batch, 'photo', data[DBColumn.id] as String, SyncOp.create);
    await batch.commit(noResult: true);
  }

  /// Marks a photo for deletion locally and enqueues the request.
  Future<void> markPhotoDeleted(String id) async {
    final existing = await getPhotoById(id);
    if (existing == null) return;
    final batch = _database.batch();
    if (existing[DBStatus.syncStatus] == SyncStatus.pendingCreate) {
      batch.delete('photos', where: '${DBColumn.id} = ?', whereArgs: [id]);
      batch.delete('sync_queue', where: 'entity_id = ? AND entity_type = ?', whereArgs: [id, 'photo']);
    } else {
      batch.update('photos', {DBColumn.syncStatus: SyncStatus.pendingDelete}, where: '${DBColumn.id} = ?', whereArgs: [id]);
      await _enqueue(batch, 'photo', id, SyncOp.delete);
    }
    await batch.commit(noResult: true);
  }

  /// Updates a photo's cloud storage path and sync status.
  Future<void> markPhotoSynced(String id, String storagePath) async {
    await _database.update('photos', {
      DBColumn.syncStatus: SyncStatus.synced, 
      DBColumn.uploaded: 1, 
      DBColumn.storagePath: storagePath
    }, where: '${DBColumn.id} = ?', whereArgs: [id]);
  }

  /// Permanently removes a photo from the local database.
  Future<void> hardDeletePhoto(String id) async {
    await _database.delete('photos', where: '${DBColumn.id} = ?', whereArgs: [id]);
  }

  // ─────────────────────────────────────────────────────────────
  //  Server Reconciliation
  // ─────────────────────────────────────────────────────────────

  /// Clears fully-synced local records and replaces them with fresh data from the server.
  /// 
  /// [excludeIds] can be used to protect records that were just uploaded from being overwritten.
  Future<void> refreshFromServer(
      String userId,
      List<Map<String, dynamic>> serverRows, {
        Set<String>? excludeIds,
      }) async {
    final batch = _database.batch();

    if (excludeIds != null && excludeIds.isNotEmpty) {
      final placeholders = List.filled(excludeIds.length, '?').join(', ');
      batch.delete(
        'entries',
        where: '${DBColumn.userId} = ? AND ${DBColumn.syncStatus} = ? '
            'AND ${DBColumn.id} NOT IN ($placeholders)',
        whereArgs: [userId, SyncStatus.synced, ...excludeIds],
      );
    } else {
      batch.delete(
        'entries',
        where: '${DBColumn.userId} = ? AND ${DBColumn.syncStatus} = ?',
        whereArgs: [userId, SyncStatus.synced],
      );
    }

    for (final row in serverRows) {
      batch.insert(
        'entries',
        _serverToLocal(row, userId),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    await batch.commit(noResult: true);
  }

  Map<String, dynamic> _serverToLocal(Map<String, dynamic> row, String userId) {
    return {
      DBColumn.id: row[DBColumn.id],
      DBColumn.userId: userId,
      DBColumn.titleEnc: row[DBColumn.titleEnc] is Map ? jsonEncode(row[DBColumn.titleEnc]) : row[DBColumn.titleEnc],
      DBColumn.contentEnc: row[DBColumn.contentEnc] is Map ? jsonEncode(row[DBColumn.contentEnc]) : row[DBColumn.contentEnc],
      DBColumn.colorTag: row[DBColumn.colorTag] ?? 'stone',
      DBColumn.wordCount: row[DBColumn.wordCount] ?? 0,
      DBColumn.entryDate: row[DBColumn.entryDate],
      DBColumn.createdAt: row[DBColumn.createdAt],
      DBColumn.updatedAt: row[DBColumn.updatedAt],
      DBColumn.syncStatus: SyncStatus.synced,
      DBColumn.isDeleted: 0,
    };
  }

  /// Purges all user-specific data from the local database.
  Future<void> clearForUser(String userId) async {
    final batch = _database.batch();
    batch.delete('entries', where: '${DBColumn.userId} = ?', whereArgs: [userId]);
    batch.delete('photos', where: '${DBColumn.userId} = ?', whereArgs: [userId]);
    batch.delete('sync_queue');
    await batch.commit(noResult: true);
  }
}
