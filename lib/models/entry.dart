import 'package:poppy/core/constants.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Entry Model
//  Location: lib/models/entry.dart
// ─────────────────────────────────────────────────────────────

class Entry {
  final String id;
  final String userId;
  final String title;
  final String content;
  final EntryColorData colorTag;
  final int wordCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Photos are loaded separately and attached after fetch
  // so they don't block the entry list from rendering.
  final List<String> photoUrls;

  const Entry({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    required this.colorTag,
    required this.wordCount,
    required this.createdAt,
    required this.updatedAt,
    this.photoUrls = const [],
  });

  // ── Supabase → Dart ────────────────────────────────────────

  factory Entry.fromMap(Map<String, dynamic> map) {
    return Entry(
      id:        map[DBColumn.id] as String,
      userId:    map[DBColumn.userId] as String,
      title:     map[DBColumn.title] as String? ?? '',
      content:   map[DBColumn.content] as String? ?? '',
      colorTag:  EntryColors.fromDbValue(
        map[DBColumn.colorTag] as String? ?? 'stone',
      ),
      wordCount: map[DBColumn.wordCount] as int? ?? 0,
      createdAt: DateTime.parse(map[DBColumn.createdAt] as String),
      updatedAt: DateTime.parse(map[DBColumn.updatedAt] as String),
    );
  }

  // ── Dart → Supabase ────────────────────────────────────────
  // id, userId, createdAt are set by the database — not included
  // in insert maps. updatedAt is handled by a DB trigger.

  Map<String, dynamic> toInsertMap() {
    return {
      DBColumn.title:     title,
      DBColumn.content:   content,
      DBColumn.colorTag:  colorTag.dbValue,
      DBColumn.wordCount: wordCount,
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      DBColumn.title:     title,
      DBColumn.content:   content,
      DBColumn.colorTag:  colorTag.dbValue,
      DBColumn.wordCount: wordCount,
      DBColumn.updatedAt: DateTime.now().toIso8601String(),
    };
  }

  // ── Utilities ──────────────────────────────────────────────

  /// Returns the first line of content — used in entry cards.
  String get contentPreview {
    final firstLine = content.split('\n').firstWhere(
          (line) => line.trim().isNotEmpty,
      orElse: () => '',
    );
    return firstLine.length > 120
        ? '${firstLine.substring(0, 120)}…'
        : firstLine;
  }

  /// Counts words in a string — called before saving.
  static int countWords(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }

  // ── CopyWith ───────────────────────────────────────────────

  Entry copyWith({
    String? id,
    String? userId,
    String? title,
    String? content,
    EntryColorData? colorTag,
    int? wordCount,
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      photoUrls: photoUrls ?? this.photoUrls,
    );
  }

  // ── Export / Import ────────────────────────────────────────
  // Used by export_service.dart when writing the JSON file.

  Map<String, dynamic> toExportMap() {
    return {
      'id':         id,
      'title':      title,
      'content':    content,
      'color_tag':  colorTag.dbValue,
      'word_count': wordCount,
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
      colorTag:  EntryColors.fromDbValue(map['color_tag'] as String? ?? 'stone'),
      wordCount: map['word_count'] as int? ?? 0,
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