import 'package:flutter/material.dart';
import 'package:poppy/core/core.dart';
import 'package:poppy/features/journal/data/models/entry_tag.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Profile Model
// ─────────────────────────────────────────────────────────────

/// Represents the user's profile, including account details and 
/// theme preferences that are synced across devices.
class Profile {
  final String id;
  final String email;
  final String displayName;

  // Fonts
  final PoppyFont fontTitle;
  final PoppyFont fontBody;

  // Theme Colors (stored as ARGB32 integers in DB, same as tag colours)
  final Color colorAccent;
  final Color colorAccentLight;
  final Color colorAccentMuted;
  final Color colorSurface;
  final Color colorBackground;
  final Color colorTextPrimary;
  final Color colorTextSecondary;
  final Color colorTextTertiary;
  final Color colorBorder;

  final List<TagColorData> tags;
  final bool pinEnabled;
  final DateTime? createdAt;

  Profile({
    required this.id,
    required this.email,
    required this.displayName,
    this.fontTitle = PoppyFont.lora,
    this.fontBody = PoppyFont.inter,
    this.colorAccent = AppColors.accent,
    this.colorAccentLight = AppColors.accentLight,
    this.colorAccentMuted = AppColors.accentMuted,
    this.colorSurface = AppColors.surface,
    this.colorBackground = AppColors.background,
    this.colorTextPrimary = AppColors.textPrimary,
    this.colorTextSecondary = AppColors.textSecondary,
    this.colorTextTertiary = AppColors.textTertiary,
    this.colorBorder = AppColors.border,
    this.tags = EntryTags.defaults,
    this.pinEnabled = false,
    this.createdAt,
  });

  Profile copyWith({
    String? id,
    String? email,
    String? displayName,
    PoppyFont? fontTitle,
    PoppyFont? fontBody,
    Color? colorAccent,
    Color? colorAccentLight,
    Color? colorAccentMuted,
    Color? colorSurface,
    Color? colorBackground,
    Color? colorTextPrimary,
    Color? colorTextSecondary,
    Color? colorTextTertiary,
    Color? colorBorder,
    List<TagColorData>? tags,
    bool? pinEnabled,
    DateTime? createdAt,
  }) {
    return Profile(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      fontTitle: fontTitle ?? this.fontTitle,
      fontBody: fontBody ?? this.fontBody,
      colorAccent: colorAccent ?? this.colorAccent,
      colorAccentLight: colorAccentLight ?? this.colorAccentLight,
      colorAccentMuted: colorAccentMuted ?? this.colorAccentMuted,
      colorSurface: colorSurface ?? this.colorSurface,
      colorBackground: colorBackground ?? this.colorBackground,
      colorTextPrimary: colorTextPrimary ?? this.colorTextPrimary,
      colorTextSecondary: colorTextSecondary ?? this.colorTextSecondary,
      colorTextTertiary: colorTextTertiary ?? this.colorTextTertiary,
      colorBorder: colorBorder ?? this.colorBorder,
      tags: tags ?? this.tags,
      pinEnabled: pinEnabled ?? this.pinEnabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Parse font enum from string
  static PoppyFont _parseFont(String? name, PoppyFont fallback) {
    if (name == null) return fallback;
    return PoppyFont.values.firstWhere(
          (f) => f.name == name,
      orElse: () => fallback,
    );
  }

  /// Parse colours from a JSON map — values are ARGB32 integers (same as tags)
  static Map<String, Color> _parseThemeColors(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return {};

    final colors = <String, Color>{};
    const keys = [
      'colorAccent', 'colorAccentLight', 'colorAccentMuted',
      'colorSurface', 'colorBackground',
      'colorTextPrimary', 'colorTextSecondary', 'colorTextTertiary',
      'colorBorder',
    ];

    for (final key in keys) {
      final value = json[key];
      if (value is int) {
        colors[key] = Color(value);
      }
    }
    return colors;
  }

  /// Convert colours to a JSON map — values are ARGB32 integers (same as tags)
  static Map<String, int> _themeColorsToJson({
    required Color colorAccent,
    required Color colorAccentLight,
    required Color colorAccentMuted,
    required Color colorSurface,
    required Color colorBackground,
    required Color colorTextPrimary,
    required Color colorTextSecondary,
    required Color colorTextTertiary,
    required Color colorBorder,
  }) {
    return {
      'colorAccent': colorAccent.toARGB32(),
      'colorAccentLight': colorAccentLight.toARGB32(),
      'colorAccentMuted': colorAccentMuted.toARGB32(),
      'colorSurface': colorSurface.toARGB32(),
      'colorBackground': colorBackground.toARGB32(),
      'colorTextPrimary': colorTextPrimary.toARGB32(),
      'colorTextSecondary': colorTextSecondary.toARGB32(),
      'colorTextTertiary': colorTextTertiary.toARGB32(),
      'colorBorder': colorBorder.toARGB32(),
    };
  }

  factory Profile.fromMap(Map<String, dynamic> map, User user) {
    // Parse tags
    final tagsRaw = map[DBColumn.tags];
    List<TagColorData> parsedTags = EntryTags.defaults;
    if (tagsRaw != null) {
      final List list = tagsRaw is List ? tagsRaw : [];
      if (list.isNotEmpty) {
        parsedTags = list
            .map((t) => TagColorData.fromMap(t as Map<String, dynamic>))
            .toList();
      }
    }

    // Parse display name
    String displayName = '';
    final meta = user.userMetadata;
    if (meta != null) {
      final name = meta['display_name'] as String?;
      if (name != null && name.trim().isNotEmpty) {
        displayName = name.trim();
      } else {
        final full = meta['full_name'] as String?;
        if (full != null && full.trim().isNotEmpty) {
          displayName = full.trim();
        }
      }
    }
    if (displayName.isEmpty) {
      final email = user.email ?? '';
      displayName = email.contains('@') ? email.split('@')[0] : email;
    }

    // Parse theme colours from JSON map (ARGB32 integers)
    final themeColorsJson = map[DBColumn.themeColors] as Map<String, dynamic>?;
    final themeColors = _parseThemeColors(themeColorsJson);

    return Profile(
      id: map[DBColumn.id] as String,
      email: user.email ?? '',
      displayName: displayName,
      fontTitle: _parseFont(map[DBColumn.fontTitle], PoppyFont.lora),
      fontBody: _parseFont(map[DBColumn.fontBody], PoppyFont.inter),
      colorAccent: themeColors['colorAccent'] ?? AppColors.accent,
      colorAccentLight: themeColors['colorAccentLight'] ?? AppColors.accentLight,
      colorAccentMuted: themeColors['colorAccentMuted'] ?? AppColors.accentMuted,
      colorSurface: themeColors['colorSurface'] ?? AppColors.surface,
      colorBackground: themeColors['colorBackground'] ?? AppColors.background,
      colorTextPrimary: themeColors['colorTextPrimary'] ?? AppColors.textPrimary,
      colorTextSecondary: themeColors['colorTextSecondary'] ?? AppColors.textSecondary,
      colorTextTertiary: themeColors['colorTextTertiary'] ?? AppColors.textTertiary,
      colorBorder: themeColors['colorBorder'] ?? AppColors.border,
      tags: parsedTags,
      pinEnabled: map[DBColumn.pinEnabled] as bool? ?? false,
      createdAt: map[DBColumn.createdAt] != null
          ? DateTime.parse(map[DBColumn.createdAt] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      DBColumn.id: id,
      DBColumn.fontTitle: fontTitle.name,
      DBColumn.fontBody: fontBody.name,
      DBColumn.themeColors: _themeColorsToJson(
        colorAccent: colorAccent,
        colorAccentLight: colorAccentLight,
        colorAccentMuted: colorAccentMuted,
        colorSurface: colorSurface,
        colorBackground: colorBackground,
        colorTextPrimary: colorTextPrimary,
        colorTextSecondary: colorTextSecondary,
        colorTextTertiary: colorTextTertiary,
        colorBorder: colorBorder,
      ),
      DBColumn.tags: tags.map((t) => t.toMap()).toList(),
      DBColumn.pinEnabled: pinEnabled,
    };
  }
}