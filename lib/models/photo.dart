import 'package:poppy/core/constants.dart';

class Photo {
  final String id;
  final String entryId;
  final String userId;
  final String storagePath; // saved in the way: userid/entryid/photo
  final int orderIndex;
  final DateTime createdAt;
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

  Map<String, dynamic> toInsertMap() {
    return {
      DBColumn.entryId:     entryId,
      DBColumn.userId:      userId,
      DBColumn.storagePath: storagePath,
      DBColumn.orderIndex:  orderIndex,
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