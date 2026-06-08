import 'package:flutter/material.dart';

/// Defines the central color palette, entry tag colors, and dynamic 
/// customization palettes used throughout the application.
class AppColors {
  AppColors._();

  // --- Poppy Defaults (Base Theme) ---
  static const accent = Color(0xFFC94040);
  static const accentLight = Color(0xFFFBEAEA);
  static const accentMuted = Color(0xFFE8A0A0);
  static const surface = Color(0xFFFDF8F8);
  static const background = Color(0xFFFFFBFB);
  static const textPrimary = Color(0xFF2B0E0E);
  static const textSecondary = Color(0xFF5C4444);
  static const textTertiary = Color(0xFFAA8888);
  static const border = Color(0xFFEDD8D8);

  // --- Entry Color Tag Strip Colors ---
  static const tagPoppy = Color(0xFFC94040);
  static const tagIris = Color(0xFF5C7FC4);
  static const tagLily = Color(0xFF4FAD74);
  static const tagMarigold = Color(0xFFB87030);
  static const tagLavender = Color(0xFF9050A8);
  static const tagStone = Color(0xFF888888);

  // --- Semantic & Absolute ---
// Success
  static const success = Color(0xFF2E7D32);
  static const successLight = Color(0xFFEAF7EC);
  static const successMuted = Color(0xFFA5D6A7);

// Warning
  static const warning = Color(0xFFF57F17);
  static const warningLight = Color(0xFFFFF4E5);
  static const warningMuted = Color(0xFFFFCC80);

// Error
  static const error = Color(0xFFB00020);
  static const errorLight = Color(0xFFFDECEC);
  static const errorMuted = Color(0xFFF5A3B1);

  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);
  static const transparent = Colors.transparent;

  // --- Brand & Assets ---
  static const photoViewerBg = Color(0xFF000000);
  static const logoCentre = Color(0xFF2D1B0E);
  static const logoHighlight = Color(0xFFF2D100);

  /// A collection of colors used for custom theme generation.
  static const colorPalette = [
    // Reds
    Color(0xFFFFF5F5), Color(0xFFFFEBEB), Color(0xFFFFCDD2),
    Color(0xFFEF9A9A), Color(0xFFE53935), Color(0xFFC62828),
    Color(0xFFB71C1C), Color(0xFF8B0000), Color(0xFF5C0000),

    // Pinks
    Color(0xFFFFF5F9), Color(0xFFFCE4EC), Color(0xFFF8BBD0),
    Color(0xFFF48FB1), Color(0xFFE91E63), Color(0xFFAD1457),
    Color(0xFF880E4F), Color(0xFF560027), Color(0xFF3A001A),

    // Purples
    Color(0xFFF9F5FC), Color(0xFFF3E5F5), Color(0xFFE1BEE7),
    Color(0xFFCE93D8), Color(0xFF9C27B0), Color(0xFF6A1B9A),
    Color(0xFF4A148C), Color(0xFF2E0054), Color(0xFF1A0030),

    // Blues
    Color(0xFFF5F9FF), Color(0xFFE3F2FD), Color(0xFFBBDEFB),
    Color(0xFF90CAF9), Color(0xFF2196F3), Color(0xFF1565C0),
    Color(0xFF0D47A1), Color(0xFF08306B), Color(0xFF041E3D),

    // Teals
    Color(0xFFF5FFFE), Color(0xFFE0F2F1), Color(0xFFB2DFDB),
    Color(0xFF80CBC4), Color(0xFF009688), Color(0xFF00695C),
    Color(0xFF004D40), Color(0xFF002820), Color(0xFF001510),

    // Ambers
    Color(0xFFFFFCF5), Color(0xFFFFF8E1), Color(0xFFFFECB3),
    Color(0xFFFFE082), Color(0xFFFFC107), Color(0xFFFF8F00),
    Color(0xFFE65100), Color(0xFFBF360C), Color(0xFF7F2408),

    // Neutrals
    Color(0xFFFFFFFF), Color(0xFFF5F5F5), Color(0xFFEEEEEE),
    Color(0xFFE0E0E0), Color(0xFF9E9E9E), Color(0xFF616161),
    Color(0xFF424242), Color(0xFF212121), Color(0xFF121212),

    // Warm Neutrals
    Color(0xFFFCFAF7), Color(0xFFFFFBF8), Color(0xFFF5EBE0),
    Color(0xFFE8D5C0), Color(0xFFA08060), Color(0xFF7D5A3C),
    Color(0xFF5C3D20), Color(0xFF3E2010), Color(0xFF1E0F06),
  ];
}

/// Provides descriptive colors for each month of the year.
class MonthColors {
  MonthColors._();

  /// Mapping of month numbers (1-12) to their representative colors.
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

  /// Returns the color associated with the given [month] (1-12).
  static Color of(int month) => colors[month] ?? Colors.grey;
}

/// Identifiers for entry color tags.
enum EntryColor { poppy, iris, lily, marigold, lavender, stone }

/// Data structure representing an entry color tag.
class EntryColorData {
  /// The unique identifier for the entry color.
  final EntryColor id;

  /// The display name of the color.
  final String name;

  /// The [Color] value.
  final Color color;

  /// The string value used for database persistence.
  final String dbValue;

  const EntryColorData({
    required this.id,
    required this.name,
    required this.color,
    required this.dbValue,
  });
}

/// Central registry for entry color tags.
class EntryColors {
  EntryColors._();

  static const poppy = EntryColorData(id: EntryColor.poppy, name: 'Poppy', color: AppColors.tagPoppy, dbValue: 'poppy');
  static const iris = EntryColorData(id: EntryColor.iris, name: 'Iris', color: AppColors.tagIris, dbValue: 'iris');
  static const lily = EntryColorData(id: EntryColor.lily, name: 'Lily', color: AppColors.tagLily, dbValue: 'lily');
  static const marigold = EntryColorData(id: EntryColor.marigold, name: 'Marigold', color: AppColors.tagMarigold, dbValue: 'marigold');
  static const lavender = EntryColorData(id: EntryColor.lavender, name: 'Lavender', color: AppColors.tagLavender, dbValue: 'lavender');
  static const stone = EntryColorData(id: EntryColor.stone, name: 'Stone', color: AppColors.tagStone, dbValue: 'stone');

  /// List of all available entry color tags.
  static const all = [poppy, iris, lily, marigold, lavender, stone];

  /// The default entry color tag.
  static const defaultColor = stone;

  /// Retrieves [EntryColorData] from its [dbValue].
  static EntryColorData fromDbValue(String value) =>
      all.firstWhere((c) => c.dbValue == value, orElse: () => stone);

  /// Retrieves [EntryColorData] from its [id].
  static EntryColorData fromId(EntryColor id) =>
      all.firstWhere((c) => c.id == id);
}
