import 'package:poppy/core/core.dart';
import 'package:poppy/features/journal/data/models/entry_tag.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Entry Model
// ─────────────────────────────────────────────────────────────

/// Represents a single journal entry in the application.
class Entry {
  /// Unique identifier for the entry.
  final String id;

  /// The ID of the user who owns this entry.
  final String userId;

  /// The title of the journal entry.
  final String title;

  /// The main body text of the journal entry.
  final String content;

  /// The color tag/category assigned to this entry.
  final TagColorData colorTag;

  /// Total number of words in the [content].
  final int wordCount;

  /// The date this entry is associated with in the journal.
  final DateTime entryDate;

  /// The timestamp when the entry was first created.
  final DateTime createdAt;

  /// The timestamp when the entry was last updated.
  final DateTime updatedAt;

  /// List of URLs for photos attached to this entry.
  final List<String> photoUrls;

  /// The current synchronization status with the remote server.
  final String syncStatus;

  /// Whether this entry has been marked for deletion.
  final bool isDeleted;

  /// Creates an [Entry] instance.
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

  /// Creates an [Entry] instance from a Map (usually from a database row).
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

  /// Converts the [Entry] to a Map format suitable for exporting data.
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

  /// Returns true if the entry has local changes that haven't been synced.
  bool get isPending => syncStatus != SyncStatus.synced;

  /// Returns a short preview of the entry content.
  ///
  /// Takes the first non-empty line and truncates it if it's too long.
  String get contentPreview {
    final firstLine = content.split('\n').firstWhere(
          (l) => l.trim().isNotEmpty,
      orElse: () => '',
    );
    return firstLine.length > 120
        ? '${firstLine.substring(0, 120)}…'
        : firstLine;
  }

  /// Counts the number of words in the given [text].
  static int countWords(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }

  /// Creates a copy of this [Entry] with updated fields.
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