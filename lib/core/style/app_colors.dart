import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Color System
//  Location: lib/core/style/app_colors.dart
// ─────────────────────────────────────────────────────────────

class AppColors {
  AppColors._();

  // ── Poppy Defaults (Base Theme) ─────────────────────────
  static const accent        = Color(0xFFC94040);
  static const accentLight   = Color(0xFFFBEAEA);
  static const accentMuted   = Color(0xFFE8A0A0);
  static const surface       = Color(0xFFFDF8F8);
  static const background    = Color(0xFFFFFBFB);
  static const textPrimary   = Color(0xFF2B0E0E);
  static const textSecondary = Color(0xFF5C4444);
  static const textTertiary  = Color(0xFFAA8888);
  static const border        = Color(0xFFEDD8D8);

  // ── Entry color tag strip colors ───────────────────────
  static const tagPoppy    = Color(0xFFC94040);
  static const tagIris     = Color(0xFF5C7FC4);
  static const tagLily     = Color(0xFF4FAD74);
  static const tagMarigold = Color(0xFFB87030);
  static const tagLavender = Color(0xFF9050A8);
  static const tagStone    = Color(0xFF888888);

  // ── Semantic & Absolute ────────────────────────────────
  static const error       = Color(0xFFB00020);
  static const success     = Color(0xFF2E7D32);
  static const warning     = Color(0xFFF57F17);
  static const white       = Color(0xFFFFFFFF);
  static const black       = Color(0xFF000000);
  static const transparent = Colors.transparent;

  // ── Brand & Assets ─────────────────────────────────────
  static const photoViewerBg = Color(0xFF000000);
  static const logoCentre    = Color(0xFF2D1B0E);
  static const logoHighlight = Color(0xFFF2D100);

  // ── Customisation Palette ─────────────────────────────
  static const colorPalette = [
    // Reds
    Color(0xFFFFEBEB), Color(0xFFFFCDD2), Color(0xFFEF9A9A),
    Color(0xFFE57373), Color(0xFFEF5350), Color(0xFFE53935),
    Color(0xFFC62828), Color(0xFFB71C1C), Color(0xFF8B0000),
    // Pinks
    Color(0xFFFCE4EC), Color(0xFFF8BBD0), Color(0xFFF48FB1),
    Color(0xFFF06292), Color(0xFFEC407A), Color(0xFFE91E63),
    Color(0xFFAD1457), Color(0xFF880E4F), Color(0xFF560027),
    // Purples
    Color(0xFFF3E5F5), Color(0xFFE1BEE7), Color(0xFFCE93D8),
    Color(0xFFBA68C8), Color(0xFFAB47BC), Color(0xFF9C27B0),
    Color(0xFF6A1B9A), Color(0xFF4A148C), Color(0xFF2E0054),
    // Blues
    Color(0xFFE3F2FD), Color(0xFFBBDEFB), Color(0xFF90CAF9),
    Color(0xFF64B5F6), Color(0xFF42A5F5), Color(0xFF2196F3),
    Color(0xFF1565C0), Color(0xFF0D47A1), Color(0xFF08306B),
    // Teals + Greens
    Color(0xFFE0F2F1), Color(0xFFB2DFDB), Color(0xFF80CBC4),
    Color(0xFF4DB6AC), Color(0xFF26A69A), Color(0xFF009688),
    Color(0xFF00695C), Color(0xFF004D40), Color(0xFF002820),
    // Ambers + Browns
    Color(0xFFFFF8E1), Color(0xFFFFECB3), Color(0xFFFFE082),
    Color(0xFFFFD54F), Color(0xFFFFCA28), Color(0xFFFFC107),
    Color(0xFFFF8F00), Color(0xFFE65100), Color(0xFFBF360C),
    // Neutrals
    Color(0xFFFFFFFF), Color(0xFFF5F5F5), Color(0xFFEEEEEE),
    Color(0xFFE0E0E0), Color(0xFFBDBDBD), Color(0xFF9E9E9E),
    Color(0xFF616161), Color(0xFF212121), Color(0xFF121212),
    // Warm neutrals
    Color(0xFFFFFBF8), Color(0xFFF5EBE0), Color(0xFFE8D5C0),
    Color(0xFFD4B896), Color(0xFFA08060), Color(0xFF7D5A3C),
    Color(0xFF5C3D20), Color(0xFF3E2010), Color(0xFF1E0F06),
  ];
}

class MonthColors {
  MonthColors._();
  static const Map<int, Color> colors = {
    1:  Color(0xFF90A4AE), 2:  Color(0xFFE57373), 3:  Color(0xFF81C784),
    4:  Color(0xFF64B5F6), 5:  Color(0xFFFFD54F), 6:  Color(0xFFBA68C8),
    7:  Color(0xFFFF8A65), 8:  Color(0xFFFFB74D), 9:  Color(0xFFA1887F),
    10: Color(0xFFFF7043), 11: Color(0xFF7986CB), 12: Color(0xFF4DB6AC),
  };
  static Color of(int month) => colors[month] ?? Colors.grey;
}

// ─────────────────────────────────────────────────────────────
//  ENTRY COLOR TAG SYSTEM
// ─────────────────────────────────────────────────────────────

enum EntryColor { poppy, iris, lily, marigold, lavender, stone }

class EntryColorData {
  final EntryColor id;
  final String     name;
  final Color      color;
  final String     dbValue;
  const EntryColorData({
    required this.id,
    required this.name,
    required this.color,
    required this.dbValue,
  });
}

class EntryColors {
  EntryColors._();
  static const poppy    = EntryColorData(id: EntryColor.poppy,    name: 'Poppy',    color: AppColors.tagPoppy,    dbValue: 'poppy');
  static const iris     = EntryColorData(id: EntryColor.iris,     name: 'Iris',     color: AppColors.tagIris,     dbValue: 'iris');
  static const lily     = EntryColorData(id: EntryColor.lily,     name: 'Lily',     color: AppColors.tagLily,     dbValue: 'lily');
  static const marigold = EntryColorData(id: EntryColor.marigold, name: 'Marigold', color: AppColors.tagMarigold, dbValue: 'marigold');
  static const lavender = EntryColorData(id: EntryColor.lavender, name: 'Lavender', color: AppColors.tagLavender, dbValue: 'lavender');
  static const stone    = EntryColorData(id: EntryColor.stone,    name: 'Stone',    color: AppColors.tagStone,    dbValue: 'stone');

  static const all          = [poppy, iris, lily, marigold, lavender, stone];
  static const defaultColor = stone;

  static EntryColorData fromDbValue(String value) =>
      all.firstWhere((c) => c.dbValue == value, orElse: () => stone);
  static EntryColorData fromId(EntryColor id) =>
      all.firstWhere((c) => c.id == id);
}
