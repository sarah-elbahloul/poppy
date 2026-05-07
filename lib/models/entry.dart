import 'package:poppy/core/constants.dart';
import 'package:poppy/core/style/style.dart';

class Entry {
  final String id;
  final String userId;
  final String title;
  final String content;
  final EntryColorData colorTag;
  final int wordCount;
  final DateTime entryDate;   // ← user-chosen date, used for display & sorting
  final DateTime createdAt;   // ← when the DB record was created, never changes
  final DateTime updatedAt;
  final List<String> photoUrls;

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
  });

  factory Entry.fromMap(Map<String, dynamic> map) {
    return Entry(
      id:        map[DBColumn.id] as String,
      userId:    map[DBColumn.userId] as String,
      title:     map[DBColumn.title] as String? ?? '',
      content:   map[DBColumn.content] as String? ?? '',
      colorTag:  EntryColors.fromDbValue(
          map[DBColumn.colorTag] as String? ?? 'stone'),
      wordCount: map[DBColumn.wordCount] as int? ?? 0,
      entryDate: DateTime.parse(
          map[DBColumn.entryDate] as String? ??
              map[DBColumn.createdAt] as String),
      createdAt: DateTime.parse(map[DBColumn.createdAt] as String),
      updatedAt: DateTime.parse(map[DBColumn.updatedAt] as String),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      DBColumn.title:     title,
      DBColumn.content:   content,
      DBColumn.colorTag:  colorTag.dbValue,
      DBColumn.wordCount: wordCount,
      DBColumn.entryDate: entryDate.toIso8601String().substring(0, 10),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      DBColumn.title:     title,
      DBColumn.content:   content,
      DBColumn.colorTag:  colorTag.dbValue,
      DBColumn.wordCount: wordCount,
      DBColumn.entryDate: entryDate.toIso8601String().substring(0, 10),
      DBColumn.updatedAt: DateTime.now().toIso8601String(),
    };
  }

  String get contentPreview {
    final firstLine = content.split('\n').firstWhere(
          (line) => line.trim().isNotEmpty,
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
    EntryColorData? colorTag,
    int? wordCount,
    DateTime? entryDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? photoUrls,
  }) {
    return Entry(
      id:        id        ?? this.id,
      userId:    userId    ?? this.userId,
      title:     title     ?? this.title,
      content:   content   ?? this.content,
      colorTag:  colorTag  ?? this.colorTag,
      wordCount: wordCount ?? this.wordCount,
      entryDate: entryDate ?? this.entryDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      photoUrls: photoUrls ?? this.photoUrls,
    );
  }

  Map<String, dynamic> toExportMap() {
    return {
      'id':         id,
      'title':      title,
      'content':    content,
      'color_tag':  colorTag.dbValue,
      'word_count': wordCount,
      'entry_date': entryDate.toIso8601String().substring(0, 10),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'photo_urls': photoUrls,
    };
  }

  factory Entry.fromExportMap(Map<String, dynamic> map, String userId) {
    return Entry(
      id:        map['id'] as String,
      userId:    userId,
      title:     map['title'] as String? ?? '',
      content:   map['content'] as String? ?? '',
      colorTag:  EntryColors.fromDbValue(
          map['color_tag'] as String? ?? 'stone'),
      wordCount: map['word_count'] as int? ?? 0,
      entryDate: DateTime.parse(
          map['entry_date'] as String? ??
              map['created_at'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      photoUrls: List<String>.from(map['photo_urls'] as List? ?? []),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Entry && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Entry(id: $id, title: $title)';
}