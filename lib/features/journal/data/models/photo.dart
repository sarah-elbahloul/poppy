import 'package:poppy/core/core.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Photo Model
// ─────────────────────────────────────────────────────────────

/// Represents a photo associated with a journal entry.
class Photo {
  /// Unique identifier for the photo.
  final String id;

  /// The ID of the journal entry this photo belongs to.
  final String entryId;

  /// The ID of the user who owns this photo.
  final String userId;

  /// The path where the photo is stored in remote storage.
  final String? storagePath;

  /// The local file system path where the photo is stored.
  final String? localPath;

  /// Whether the photo has been successfully uploaded to remote storage.
  final bool uploaded;

  /// The date and time when the photo was created.
  final DateTime createdAt;

  /// The current synchronization status of the photo.
  final String syncStatus;

  /// A temporary signed URL for accessing the photo from remote storage.
  final String? signedUrl;

  /// Creates a [Photo] instance.
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

  /// Creates a [Photo] instance from a Map (usually from a database row).
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

  /// Converts the [Photo] instance to a Map for database storage.
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

  /// Builds a storage path string for a photo.
  ///
  /// Format: `userId/entryId/filename`
  static String buildStoragePath({
    required String userId,
    required String entryId,
    required String filename,
  }) {
    return '$userId/$entryId/$filename';
  }

  /// Generates a unique filename for a photo based on the current timestamp.
  static String generateFilename() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return 'photo_$ts.jpg';
  }

  /// Creates a copy of this [Photo] with updated fields.
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