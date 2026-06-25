import 'package:poppy/core/constants.dart';
import 'package:poppy/core/style/style.dart';
import 'package:poppy/services/local_db_service.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Entry Model
//  Location: lib/models/entry.dart
// ─────────────────────────────────────────────────────────────

/// Represents a journal entry in the application.
///
/// **Encryption Contract:**
/// This model always holds decrypted values in memory. It does not handle ciphertext directly.
/// Decryption is handled by the service layer before instantiation via [Entry.fromMap].
///
/// **Offline-First:**
/// Uses [syncStatus] and [isDeleted] to manage local-first CRUD operations
/// and background synchronization with Supabase.
class Entry {
  /// Unique identifier for the entry.
  final String id;

  /// The ID of the user who owns this entry.
  final String userId;

  /// The plaintext title of the entry.
  final String title;

  /// The plaintext content/body of the entry.
  final String content;

  /// Visual category or mood tag associated with the entry.
  final TagColorData colorTag;

  /// Total number of words in the [content].
  final int wordCount;

  /// The user-assigned date for the journal entry.
  final DateTime entryDate;

  /// Timestamp when the entry was first created.
  final DateTime createdAt;

  /// Timestamp when the entry was last modified.
  final DateTime updatedAt;

  /// List of URLs pointing to attached photos.
  final List<String> photoUrls;

  /// Local synchronization state (e.g., 'synced', 'pending_create', 'pending_update').
  final String syncStatus;

  /// Whether the entry is marked for deletion locally but not yet synced.
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

  // ─────────────────────────────────────────────────────────────
  //  Factory & Conversions
  // ─────────────────────────────────────────────────────────────

  /// Creates an [Entry] from a database map.
  ///
  /// Expects the map to contain decrypted 'title' and 'content' fields.
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

  /// Converts the entry to a map suitable for data export.
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

  // ─────────────────────────────────────────────────────────────
  //  Getters & Utilities
  // ─────────────────────────────────────────────────────────────

  /// Returns true if the entry has local changes that haven't been synced to the server.
  bool get isPending => syncStatus != SyncStatus.synced;

  /// Returns a short preview of the entry content (first non-empty line).
  String get contentPreview {
    final firstLine = content.split('\n').firstWhere(
          (l) => l.trim().isNotEmpty,
      orElse: () => '',
    );
    return firstLine.length > 120
        ? '${firstLine.substring(0, 120)}…'
        : firstLine;
  }

  /// Calculates the word count for a given string based on whitespace separators.
  static int countWords(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }

  /// Creates a copy of this entry with the given fields replaced.
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
