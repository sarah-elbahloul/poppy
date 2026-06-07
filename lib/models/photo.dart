import 'package:poppy/core/constants.dart';

/// Represents a photo attached to a journal entry.
class Photo {
  final String id;
  final String entryId;
  final String userId;
  
  /// The path in Supabase Storage: `userid/entryid/filename`.
  final String storagePath;
  final int orderIndex;
  final DateTime createdAt;
  
  /// A temporary signed URL for displaying the private image.
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

  /// Creates a [Photo] from a database map.
  factory Photo.fromMap(Map<String, dynamic> map) {
    return Photo(
      id:          map[DBColumn.id] as String,
      entryId:     map[DBColumn.entryId] as String,
      userId:      map[DBColumn.userId] as String,
      storagePath: map[DBColumn.storagePath] as String,
      orderIndex:  map[DBColumn.orderIndex] as int? ?? 0,
      createdAt:   DateTime.parse(map[DBColumn.createdAt] as String),
    );
  }

  /// Returns a map representation for database insertion.
  Map<String, dynamic> toInsertMap() {
    return {
      DBColumn.entryId:     entryId,
      DBColumn.userId:      userId,
      DBColumn.storagePath: storagePath,
      DBColumn.orderIndex:  orderIndex,
    };
  }

  /// Constructs the storage path for a photo.
  static String buildStoragePath({
    required String userId,
    required String entryId,
    required String filename,
  }) {
    return '$userId/$entryId/$filename';
  }

  /// Generates a unique filename for a new photo.
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
      id:          id          ?? this.id,
      entryId:     entryId     ?? this.entryId,
      userId:      userId      ?? this.userId,
      storagePath: storagePath ?? this.storagePath,
      orderIndex:  orderIndex  ?? this.orderIndex,
      createdAt:   createdAt   ?? this.createdAt,
      signedUrl:   signedUrl   ?? this.signedUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Photo && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
