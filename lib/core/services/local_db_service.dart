import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:poppy/core/constants.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Local Database Service
//  Location: lib/core/services/local_db_service.dart
// ─────────────────────────────────────────────────────────────

class SyncStatus {
  SyncStatus._();
  static const String synced = 'synced';
  static const String pendingCreate = 'pending_create';
  static const String pendingUpdate = 'pending_update';
  static const String pendingDelete = 'pending_delete';
  static const String failed = 'failed';
}

class SyncOp {
  SyncOp._();
  static const String create = 'create';
  static const String update = 'update';
  static const String delete = 'delete';
}

class LocalDbService {
  LocalDbService._();
  static final LocalDbService instance = LocalDbService._();

  Database? _db;

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

  Future<void> _onCreate(Database db, int version) async {
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

    await db.execute('''
      CREATE TABLE sync_queue (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type  TEXT    NOT NULL,
        entity_id    TEXT    NOT NULL,
        operation    TEXT    NOT NULL,
        created_at   TEXT    NOT NULL
      )
    ''');

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

  Future<void> _enqueue(Batch batch, String type, String id, String op) async {
    batch.insert('sync_queue', {
      'entity_type': type,
      'entity_id': id,
      'operation': op,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getSyncQueue({int limit = 50}) async {
    return _database.query('sync_queue', orderBy: 'created_at ASC', limit: limit);
  }

  Future<void> dequeue(int queueId) async {
    await _database.delete('sync_queue', where: 'id = ?', whereArgs: [queueId]);
  }

  Future<List<Map<String, dynamic>>> getAllEntries(String userId) async {
    return _database.query('entries', 
      where: '${DBColumn.userId} = ? AND ${DBColumn.isDeleted} = 0', 
      whereArgs: [userId], 
      orderBy: '${DBColumn.entryDate} DESC, ${DBColumn.createdAt} DESC'
    );
  }

  Future<Map<String, dynamic>?> getEntryById(String id) async {
    final rows = await _database.query('entries', where: '${DBColumn.id} = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> insertEntry(Map<String, dynamic> row) async {
    final data = Map<String, dynamic>.from(row);
    data[DBColumn.syncStatus] = SyncStatus.pendingCreate;
    data[DBColumn.isDeleted] = 0;
    final batch = _database.batch();
    batch.insert('entries', data, conflictAlgorithm: ConflictAlgorithm.replace);
    await _enqueue(batch, 'entry', data[DBColumn.id] as String, SyncOp.create);
    await batch.commit(noResult: true);
  }

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

  Future<void> markEntrySynced(String id) async {
    await _database.update('entries', {DBColumn.syncStatus: SyncStatus.synced}, where: '${DBColumn.id} = ?', whereArgs: [id]);
  }

  Future<void> hardDeleteEntry(String id) async {
    await _database.delete('entries', where: '${DBColumn.id} = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getPhotosForEntry(String entryId) async {
    return _database.query('photos', 
      where: '${DBColumn.entryId} = ? AND ${DBColumn.syncStatus} != ?', 
      whereArgs: [entryId, SyncStatus.pendingDelete], 
      orderBy: '${DBColumn.orderIndex} ASC'
    );
  }

  Future<Map<String, dynamic>?> getPhotoById(String id) async {
    final rows = await _database.query('photos', where: '${DBColumn.id} = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> insertPhoto(Map<String, dynamic> row) async {
    final data = Map<String, dynamic>.from(row);
    data[DBColumn.syncStatus] = SyncStatus.pendingCreate;
    data[DBColumn.uploaded] = 0;
    final batch = _database.batch();
    batch.insert('photos', data, conflictAlgorithm: ConflictAlgorithm.replace);
    await _enqueue(batch, 'photo', data[DBColumn.id] as String, SyncOp.create);
    await batch.commit(noResult: true);
  }

  Future<void> markPhotoDeleted(String id) async {
    final existing = await getPhotoById(id);
    if (existing == null) return;
    final batch = _database.batch();
    if (existing[DBColumn.syncStatus] == SyncStatus.pendingCreate) {
      batch.delete('photos', where: '${DBColumn.id} = ?', whereArgs: [id]);
      batch.delete('sync_queue', where: 'entity_id = ? AND entity_type = ?', whereArgs: [id, 'photo']);
    } else {
      batch.update('photos', {DBColumn.syncStatus: SyncStatus.pendingDelete}, where: '${DBColumn.id} = ?', whereArgs: [id]);
      await _enqueue(batch, 'photo', id, SyncOp.delete);
    }
    await batch.commit(noResult: true);
  }

  Future<void> markPhotoSynced(String id, String storagePath) async {
    await _database.update('photos', {
      DBColumn.syncStatus: SyncStatus.synced, 
      DBColumn.uploaded: 1, 
      DBColumn.storagePath: storagePath
    }, where: '${DBColumn.id} = ?', whereArgs: [id]);
  }

  Future<void> hardDeletePhoto(String id) async {
    await _database.delete('photos', where: '${DBColumn.id} = ?', whereArgs: [id]);
  }

  Future<void> refreshFromServer(
      String userId,
      List<Map<String, dynamic>> serverRows, {
        Set<String>? excludeIds,
      }) async {
    final batch = _database.batch();

    for (final row in serverRows) {
      final id = row[DBColumn.id] as String;

      // Don't overwrite entries that were just synced in this cycle.
      if (excludeIds?.contains(id) ?? false) {
        continue;
      }

      batch.insert(
        'entries',
        _serverToLocal(row, userId),
        conflictAlgorithm: ConflictAlgorithm.replace,
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

  Future<void> clearForUser(String userId) async {
    final batch = _database.batch();
    batch.delete('entries', where: '${DBColumn.userId} = ?', whereArgs: [userId]);
    batch.delete('photos', where: '${DBColumn.userId} = ?', whereArgs: [userId]);
    batch.delete('sync_queue');
    await batch.commit(noResult: true);
  }
}
