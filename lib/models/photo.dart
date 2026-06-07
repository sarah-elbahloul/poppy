import 'package:poppy/core/constants.dart';

/// Represents a photo attached to a journal entry.
///
/// Photo files are stored in Supabase Storage, while metadata is maintained
/// in the database's 'photos' table.
class Photo {
  /// Unique identifier for the photo record.
  final String id;

  /// The ID of the entry this photo belongs to.
  final String entryId;

  /// The ID of the user who owns the photo.
  final String userId;

  /// The full path in Supabase Storage (e.g., `{userId}/{entryId}/{filename}`).
  final String storagePath;

  /// The display order of the photo within the entry.
  final int orderIndex;

  /// Timestamp when the photo record was created.
  final DateTime createdAt;

  /// A temporary, short-lived signed URL used for displaying the private image.
  final String? signedUrl;

  const Photo({
    required this.id,
    required this.entryId,
    required this.userId,
    required this.storagePath,
    required this.orderIndex,
    required this.createdAt,
    this.signedUrl,
  });

  /// Creates a [Photo] instance from a database map.
  factory Photo.fromMap(Map<String, dynamic> map) {
    return Photo(
      id: map[DBColumn.id] as String,
      entryId: map[DBColumn.entryId] as String,
      userId: map[DBColumn.userId] as String,
      storagePath: map[DBColumn.storagePath] as String,
      orderIndex: map[DBColumn.orderIndex] as int? ?? 0,
      createdAt: DateTime.parse(map[DBColumn.createdAt] as String),
    );
  }

  /// Converts the photo metadata to a map suitable for database insertion.
  Map<String, dynamic> toInsertMap() {
    return {
      DBColumn.entryId: entryId,
      DBColumn.userId: userId,
      DBColumn.storagePath: storagePath,
      DBColumn.orderIndex: orderIndex,
    };
  }

  // --- Utilities ---

  /// Constructs a standardized storage path for an entry photo.
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
    int? orderIndex,
    DateTime? createdAt,
    String? signedUrl,
  }) {
    return Photo(
      id: id ?? this.id,
      entryId: entryId ?? this.entryId,
      userId: userId ?? this.userId,
      storagePath: storagePath ?? this.storagePath,
      orderIndex: orderIndex ?? this.orderIndex,
      createdAt: createdAt ?? this.createdAt,
      signedUrl: signedUrl ?? this.signedUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Photo && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
