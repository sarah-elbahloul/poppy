import 'package:poppy/core/constants.dart';
import 'package:poppy/core/style/style.dart';

/// Represents a journal entry in the Poppy app.
///
/// **Encryption Contract:**
/// This model always holds DECRYPTED values in memory. It never touches ciphertext directly.
/// [Entry.fromMap] is called by the service layer after decryption.
/// [toInsertMap] and [toUpdateMap] return plain text; encryption is handled by the service layer
/// before persisting to the database.
class Entry {
  final String         id;
  final String         userId;
  final String         title;
  final String         content;
  final EntryColorData colorTag;
  final int            wordCount;
  final DateTime       entryDate;
  final DateTime       createdAt;
  final DateTime       updatedAt;
  final List<String>   photoUrls;

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

  /// Creates an [Entry] from a database map.
  /// Expects 'title' and 'content' to be already decrypted and injected into the map.
  factory Entry.fromMap(Map<String, dynamic> map) {
    return Entry(
      id:        map[DBColumn.id]        as String,
      userId:    map[DBColumn.userId]    as String,
      title:     map['title']            as String? ?? '',
      content:   map['content']          as String? ?? '',
      colorTag:  EntryColors.fromDbValue(
          map[DBColumn.colorTag]         as String? ?? 'stone'),
      wordCount: map[DBColumn.wordCount] as int?    ?? 0,
      entryDate: DateTime.parse(
          map[DBColumn.entryDate]        as String? ??
              map[DBColumn.createdAt]    as String),
      createdAt: DateTime.parse(map[DBColumn.createdAt] as String),
      updatedAt: DateTime.parse(map[DBColumn.updatedAt] as String),
    );
  }

  /// Returns a map representation for insertion. 
  /// Note: The service layer replaces title/content with encrypted versions.
  Map<String, dynamic> toInsertMap() => {
    DBColumn.titleEnc:   title,
    DBColumn.contentEnc: content,
    DBColumn.colorTag:   colorTag.dbValue,
    DBColumn.wordCount:  wordCount,
    DBColumn.entryDate:  entryDate.toIso8601String().substring(0, 10),
  };

  /// Returns a map representation for updates.
  /// Note: The service layer replaces title/content with encrypted versions.
  Map<String, dynamic> toUpdateMap() => {
    DBColumn.titleEnc:   title,
    DBColumn.contentEnc: content,
    DBColumn.colorTag:   colorTag.dbValue,
    DBColumn.wordCount:  wordCount,
    DBColumn.entryDate:  entryDate.toIso8601String().substring(0, 10),
    DBColumn.updatedAt:  DateTime.now().toIso8601String(),
  };

  /// Returns a short preview of the content, limited to the first non-empty line.
  String get contentPreview {
    final firstLine = content.split('\n').firstWhere(
          (l) => l.trim().isNotEmpty, orElse: () => '',
    );
    return firstLine.length > 120
        ? '${firstLine.substring(0, 120)}…'
        : firstLine;
  }

  /// Utility method to count words in a string.
  static int countWords(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }

  /// Creates a copy of this entry with the given fields replaced.
  Entry copyWith({
    String? id, String? userId, String? title, String? content,
    EntryColorData? colorTag, int? wordCount, DateTime? entryDate,
    DateTime? createdAt, DateTime? updatedAt, List<String>? photoUrls,
  }) => Entry(
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

  /// Converts the entry to a map for data export.
  Map<String, dynamic> toExportMap() => {
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

  /// Creates an [Entry] from a map exported via [toExportMap].
  factory Entry.fromExportMap(Map<String, dynamic> map, String userId) =>
      Entry(
        id:        map['id']        as String,
        userId:    userId,
        title:     map['title']     as String? ?? '',
        content:   map['content']   as String? ?? '',
        colorTag:  EntryColors.fromDbValue(
            map['color_tag']        as String? ?? 'stone'),
        wordCount: map['word_count'] as int?   ?? 0,
        entryDate: DateTime.parse(
            map['entry_date']       as String? ??
                map['created_at']   as String),
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
        photoUrls: List<String>.from(map['photo_urls'] as List? ?? []),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Entry && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Entry(id: $id, title: $title)';
}
