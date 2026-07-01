import 'package:poppy/core/core.dart';
import 'package:poppy/features/journal/data/models/entry_tag.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Entry Model
// ─────────────────────────────────────────────────────────────

class Entry {
  final String id;
  final String userId;
  final String title;
  final String content;
  final TagColorData colorTag;
  final int wordCount;
  final DateTime entryDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> photoUrls;
  final String syncStatus;
  final bool isDeleted;

  const Entry({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    required this.colorTag,
    required this.wordCount,
    required this.entryDate,
    required this.createdAt,
    required this.updatedAt,
    this.photoUrls = const [],
    this.syncStatus = SyncStatus.synced,
    this.isDeleted = false,
  });

  factory Entry.fromMap(Map<String, dynamic> map) {
    return Entry(
      id: map[DBColumn.id] as String,
      userId: map[DBColumn.userId] as String,
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      colorTag: EntryTags.fromDbValue(
          map[DBColumn.colorTag] as String? ?? 'stone'),
      wordCount: map[DBColumn.wordCount] as int? ?? 0,
      entryDate: DateTime.parse(
          map[DBColumn.entryDate] as String? ?? map[DBColumn.createdAt] as String),
      createdAt: DateTime.parse(map[DBColumn.createdAt] as String),
      updatedAt: DateTime.parse(map[DBColumn.updatedAt] as String),
      syncStatus: map[DBColumn.syncStatus] as String? ?? SyncStatus.synced,
      isDeleted: (map[DBColumn.isDeleted] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toExportMap() => {
    'id': id,
    'title': title,
    'content': content,
    'color_tag': colorTag.dbValue,
    'word_count': wordCount,
    'entry_date': entryDate.toIso8601String().substring(0, 10),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'photo_urls': photoUrls,
  };

  bool get isPending => syncStatus != SyncStatus.synced;

  String get contentPreview {
    final firstLine = content.split('\n').firstWhere(
          (l) => l.trim().isNotEmpty,
      orElse: () => '',
    );
    return firstLine.length > 120
        ? '${firstLine.substring(0, 120)}…'
        : firstLine;
  }

  static int countWords(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }

  Entry copyWith({
    String? id,
    String? userId,
    String? title,
    String? content,
    TagColorData? colorTag,
    int? wordCount,
    DateTime? entryDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? photoUrls,
    String? syncStatus,
    bool? isDeleted,
  }) =>
      Entry(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        title: title ?? this.title,
        content: content ?? this.content,
        colorTag: colorTag ?? this.colorTag,
        wordCount: wordCount ?? this.wordCount,
        entryDate: entryDate ?? this.entryDate,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        photoUrls: photoUrls ?? this.photoUrls,
        syncStatus: syncStatus ?? this.syncStatus,
        isDeleted: isDeleted ?? this.isDeleted,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Entry && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Entry(id: $id, title: $title, sync: $syncStatus, deleted: $isDeleted)';
}