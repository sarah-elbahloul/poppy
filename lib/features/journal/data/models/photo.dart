import 'package:poppy/core/core.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Photo Model
//  Location: lib/features/journal/data/models/photo.dart
// ─────────────────────────────────────────────────────────────

class Photo {
  final String id;
  final String entryId;
  final String userId;
  final String? storagePath;
  final String? localPath;
  final bool uploaded;
  final DateTime createdAt;
  final String syncStatus;
  final String? signedUrl;

  const Photo({
    required this.id,
    required this.entryId,
    required this.userId,
    this.storagePath,
    this.localPath,
    this.uploaded = false,
    required this.createdAt,
    this.syncStatus = SyncStatus.synced,
    this.signedUrl,
  });

  factory Photo.fromMap(Map<String, dynamic> map) {
    return Photo(
      id: map[DBColumn.id] as String,
      entryId: map[DBColumn.entryId] as String,
      userId: map[DBColumn.userId] as String,
      storagePath: map[DBColumn.storagePath] as String?,
      localPath: map[DBColumn.localPath] as String?,
      uploaded: (map[DBColumn.uploaded] as int? ?? 0) == 1,
      createdAt: DateTime.parse(map[DBColumn.createdAt] as String),
      syncStatus: map[DBColumn.syncStatus] as String? ?? SyncStatus.synced,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      DBColumn.id: id,
      DBColumn.entryId: entryId,
      DBColumn.userId: userId,
      DBColumn.storagePath: storagePath,
      DBColumn.localPath: localPath,
      DBColumn.uploaded: uploaded ? 1 : 0,
      DBColumn.createdAt: createdAt.toIso8601String(),
      DBColumn.syncStatus: syncStatus,
    };
  }

  static String buildStoragePath({
    required String userId,
    required String entryId,
    required String filename,
  }) {
    return '$userId/$entryId/$filename';
  }

  static String generateFilename() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return 'photo_$ts.jpg';
  }

  Photo copyWith({
    String? id,
    String? entryId,
    String? userId,
    String? storagePath,
    String? localPath,
    bool? uploaded,
    DateTime? createdAt,
    String? syncStatus,
    String? signedUrl,
  }) {
    return Photo(
      id: id ?? this.id,
      entryId: entryId ?? this.entryId,
      userId: userId ?? this.userId,
      storagePath: storagePath ?? this.storagePath,
      localPath: localPath ?? this.localPath,
      uploaded: uploaded ?? this.uploaded,
      createdAt: createdAt ?? this.createdAt,
      syncStatus: syncStatus ?? this.syncStatus,
      signedUrl: signedUrl ?? this.signedUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Photo && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
