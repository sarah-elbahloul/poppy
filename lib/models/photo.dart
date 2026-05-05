import 'package:poppy/core/constants.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Photo Model
//  Location: lib/models/photo.dart
// ─────────────────────────────────────────────────────────────

class Photo {
  final String id;
  final String entryId;
  final String userId;

  /// Path inside the Supabase Storage bucket.
  /// Format: {userId}/{entryId}/{filename}
  final String storagePath;

  /// Position in the photo strip (0-based).
  final int orderIndex;

  final DateTime createdAt;

  /// Signed URL — populated after fetching from storage.
  /// Not stored in the database.
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

  // ── Supabase → Dart ────────────────────────────────────────

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

  // ── Dart → Supabase ────────────────────────────────────────

  Map<String, dynamic> toInsertMap() {
    return {
      DBColumn.entryId:     entryId,
      DBColumn.userId:      userId,
      DBColumn.storagePath: storagePath,
      DBColumn.orderIndex:  orderIndex,
    };
  }

  // ── Utilities ──────────────────────────────────────────────

  /// Builds the storage path for a new photo upload.
  /// Called by photos_service before uploading.
  static String buildStoragePath({
    required String userId,
    required String entryId,
    required String filename,
  }) {
    return '$userId/$entryId/$filename';
  }

  /// Returns a unique filename based on current timestamp.
  static String generateFilename() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return 'photo_$ts.jpg';
  }

  // ── CopyWith ───────────────────────────────────────────────

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

  @override
  String toString() => 'Photo(id: $id, entryId: $entryId, order: $orderIndex)';
}