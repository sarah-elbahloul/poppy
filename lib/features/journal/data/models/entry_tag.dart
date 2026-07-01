// Color tagging for journal entries.
//
// This is journal domain data (which colors an entry can be tagged with),
// not a generic design-system token — that's why it lives here instead of
// core/style. The concept of an "entry tag" is specific to this app's
// journal feature, even though the color values themselves echo the
// design system's palette.

import 'package:flutter/material.dart';

/// A single selectable color tag that can be applied to a journal entry.
class TagColorData {
  /// Unique identifier for the tag, also used as its database value.
  final String id;

  /// The display name shown to the user.
  final String name;

  /// The color associated with this tag.
  final Color color;

  /// Whether this tag ships with the app by default (vs. user-created).
  final bool isBuiltIn;

  const TagColorData({
    required this.id,
    required this.name,
    required this.color,
    this.isBuiltIn = false,
  });

  /// Alias for [id], used when mapping to a database column.
  String get dbValue => id;

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'color': color.toARGB32(),
    'isBuiltIn': isBuiltIn,
  };

  factory TagColorData.fromMap(Map<String, dynamic> map) {
    return TagColorData(
      id: map['id'] as String,
      name: map['name'] as String,
      color: Color(map['color'] as int),
      isBuiltIn: map['isBuiltIn'] as bool? ?? false,
    );
  }

  TagColorData copyWith({
    String? id,
    String? name,
    Color? color,
    bool? isBuiltIn,
  }) {
    return TagColorData(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is TagColorData && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// Central registry of entry color tags, including the user's customizations.
///
/// The registry starts out populated with [defaults] and is updated at
/// runtime (via [updateRegistry]) once the user's saved tags are loaded —
/// see `ThemeProvider`, which owns persistence for this list.
class EntryTags {
  EntryTags._();

  /// The minimum number of tags a user must keep.
  static const int minTags = 3;

  /// The maximum number of tags a user may create.
  static const int maxTags = 12;

  /// The built-in tag set every new account starts with.
  static const List<TagColorData> defaults = [
    TagColorData(id: 'poppy', name: 'Poppy', color: Color(0xFFC94040), isBuiltIn: true),
    TagColorData(id: 'iris', name: 'Iris', color: Color(0xFF5C6BC0), isBuiltIn: true),
    TagColorData(id: 'lily', name: 'Lily', color: Color(0xFF9CCC65), isBuiltIn: true),
    TagColorData(id: 'marigold', name: 'Marigold', color: Color(0xFFFFB300), isBuiltIn: true),
    TagColorData(id: 'lavender', name: 'Lavender', color: Color(0xFFBA68C8), isBuiltIn: true),
    TagColorData(id: 'stone', name: 'Stone', color: Color(0xFF90A4AE), isBuiltIn: true),
  ];

  static List<TagColorData> _registry = defaults;

  /// All currently available entry color tags (defaults + user customizations).
  static List<TagColorData> get all => _registry;

  /// The tag used when an entry doesn't specify one.
  static final defaultColor = all[0];

  /// Replaces the registry with the user's saved tags.
  ///
  /// Called once on app start after loading persisted preferences, and
  /// again whenever the user edits their tag set.
  static void updateRegistry(List<TagColorData> tags) {
    _registry = tags;
  }

  /// Looks up a [TagColorData] by its database [id], falling back to the
  /// built-in defaults and finally to [defaultColor] if nothing matches.
  static TagColorData fromDbValue(String id) {
    return _registry.firstWhere(
          (c) => c.id == id,
      orElse: () => defaults.firstWhere(
            (d) => d.id == id,
        orElse: () => defaultColor,
      ),
    );
  }
}

/// Maps each calendar month to a representative accent color, used to
/// decorate the journal's date markers (e.g. in [EntryCard]).
class MonthColors {
  MonthColors._();

  static const Map<int, Color> colors = {
    1: Color(0xFF90A4AE),
    2: Color(0xFFE57373),
    3: Color(0xFF81C784),
    4: Color(0xFF64B5F6),
    5: Color(0xFFFFD54F),
    6: Color(0xFFBA68C8),
    7: Color(0xFFFF8A65),
    8: Color(0xFFFFB74D),
    9: Color(0xFFA1887F),
    10: Color(0xFFFF7043),
    11: Color(0xFF7986CB),
    12: Color(0xFF4DB6AC),
  };

  /// Returns the accent color for the given [month] (1–12), or grey if out
  /// of range.
  static Color of(int month) => colors[month] ?? Colors.grey;
}