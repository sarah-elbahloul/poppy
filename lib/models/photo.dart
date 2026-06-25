import 'package:poppy/core/constants.dart';
import 'package:poppy/services/local_db_service.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Photo Model
//  Location: lib/models/photo.dart
// ─────────────────────────────────────────────────────────────

/// Represents a photo attached to a journal entry.
///
/// Supports offline-first by tracking [localPath] for immediate display
/// and [uploaded] status for synchronization.
class Photo {
  /// Unique identifier for the photo.
  final String id;

  /// The ID of the entry this photo belongs to.
  final String entryId;

  /// The ID of the user who owns this photo.
  final String userId;
  
  /// The path in Supabase Storage. Null if not yet uploaded.
  final String? storagePath;

  /// The path on the local device filesystem for offline access.
  final String? localPath;

  /// Whether the photo has been successfully uploaded to cloud storage.
  final bool uploaded;

  /// Timestamp when the photo was added.
  final DateTime createdAt;

  /// Synchronization state (e.g., 'synced', 'pending_create').
  final String syncStatus;

  /// A temporary signed URL for remote display (not persisted).
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

  // ─────────────────────────────────────────────────────────────
  //  Factory & Conversions
  // ─────────────────────────────────────────────────────────────

  /// Creates a [Photo] instance from a database map.
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

  /// Converts the photo metadata to a map for local database insertion.
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

  // ─────────────────────────────────────────────────────────────
  //  Utilities
  // ─────────────────────────────────────────────────────────────

  /// Constructs a standardized cloud storage path: `{userId}/{entryId}/{filename}`.
  static String buildStoragePath({
    required String userId,
    required String entryId,
    required String filename,
  }) {
    return '$userId/$entryId/$filename';
  }

  /// Generates a unique filename for a new photo based on the current timestamp.
  static String generateFilename() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return 'photo_$ts.jpg';
  }

  /// Creates a copy of this photo with the given fields replaced.
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
