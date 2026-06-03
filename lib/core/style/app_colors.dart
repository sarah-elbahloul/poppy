import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Raw Color Palette
//  Location: lib/core/style/app_colors.dart
//
//  These are the raw hex values only.
//  Do NOT use these directly in widgets — use PoppyTheme
//  tokens instead (accent, surface, textPrimary, etc.)
//  so the app re-themes correctly.
//
//  Use AppColors only when you need a color that is
//  truly theme-independent (e.g. error red, pure white,
//  the fullscreen photo viewer background).
// ─────────────────────────────────────────────────────────────

class AppColors {
  AppColors._();

  // not using these anymore since enabled user to pick his own but will still keep it here if needed in the future
  // ── Poppy ──────────────────────────────────────────────
  static const poppyAccent      = Color(0xFFC94040);
  static const poppyAccentLight = Color(0xFFFBEAEA);
  static const poppyAccentMuted = Color(0xFFE8A0A0);
  static const poppySurface     = Color(0xFFFDF8F8);
  static const poppyBackground  = Color(0xFFFFFBFB);
  static const poppyBorder      = Color(0xFFEDD8D8);

  // ── Iris ───────────────────────────────────────────────
  static const irisAccent      = Color(0xFF5C7FC4);
  static const irisAccentLight = Color(0xFFEBF0FA);
  static const irisAccentMuted = Color(0xFFA0BAEE);
  static const irisSurface     = Color(0xFFF8F9FD);
  static const irisBackground  = Color(0xFFFBFCFF);
  static const irisBorder      = Color(0xFFD4DCF0);

  // ── Lily ───────────────────────────────────────────────
  static const lilyAccent      = Color(0xFF4FAD74);
  static const lilyAccentLight = Color(0xFFEBF7F0);
  static const lilyAccentMuted = Color(0xFF90D4A8);
  static const lilySurface     = Color(0xFFF8FDF9);
  static const lilyBackground  = Color(0xFFFBFFFD);
  static const lilyBorder      = Color(0xFFCCEDD6);

  // ── Marigold ───────────────────────────────────────────
  static const marigoldAccent      = Color(0xFFB87030);
  static const marigoldAccentLight = Color(0xFFFAF3EA);
  static const marigoldAccentMuted = Color(0xFFF0C080);
  static const marigoldSurface     = Color(0xFFFDFAF6);
  static const marigoldBackground  = Color(0xFFFFFDF9);
  static const marigoldBorder      = Color(0xFFEEDEC8);

  // ── Lavender ───────────────────────────────────────────
  static const lavenderAccent      = Color(0xFF9050A8);
  static const lavenderAccentLight = Color(0xFFF5EBFA);
  static const lavenderAccentMuted = Color(0xFFDCA0E0);
  static const lavenderSurface     = Color(0xFFFCF8FD);
  static const lavenderBackground  = Color(0xFFFEFBFF);
  static const lavenderBorder      = Color(0xFFE4D0EC);

  // ── Shared text colors ─────────────────────────────────
  // These are used as the base for all themes.
  // Each theme derives its own tinted version.
  static const textDark      = Color(0xFF1A1212);
  static const textMid       = Color(0xFF5C4444);
  static const textLight     = Color(0xFFAA8888);

  // ── Entry color tag strip colors ───────────────────────
  // Independent of theme — always the same regardless of
  // which flower theme is active.
  static const tagPoppy    = Color(0xFFC94040);
  static const tagIris     = Color(0xFF5C7FC4);
  static const tagLily     = Color(0xFF4FAD74);
  static const tagMarigold = Color(0xFFB87030);
  static const tagLavender = Color(0xFF9050A8);
  static const tagStone    = Color(0xFF888888);

  // ── Semantic ───────────────────────────────────────────
  static const error       = Color(0xFFB00020);
  static const success     = Color(0xFF2E7D32);
  static const warning     = Color(0xFFF57F17);

  // ── Always absolute ────────────────────────────────────
  static const white       = Color(0xFFFFFFFF);
  static const black       = Color(0xFF000000);
  static const transparent = Colors.transparent;

  // ── Fullscreen photo viewer ────────────────────────────
  static const photoViewerBg = Color(0xFF000000);

  // ── Centre of the Poppy logo ───────────────────────────
  static const logoCentre    = Color(0xFF2D1B0E);
  static const logoHighlight = Color(0xFFF2D100);



  // ── Curated palette ──────────────────────────────────────
  // 8 columns × 9 rows = 72 swatches.
  // Columns: Reds → Pinks → Purples → Blues → Teals → Greens → Ambers → Neutrals
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
    // Neutrals (near-white → near-black)
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
    1:  Color(0xFF90A4AE), // Jan — cool gray-blue (winter)
    2:  Color(0xFFE57373), // Feb — soft rose (valentine)
    3:  Color(0xFF81C784), // Mar — fresh green (spring)
    4:  Color(0xFF64B5F6), // Apr — sky blue (rain)
    5:  Color(0xFFFFD54F), // May — warm yellow (sun/bloom)
    6:  Color(0xFFBA68C8), // Jun — soft purple (early summer)
    7:  Color(0xFFFF8A65), // Jul — coral (heat)
    8:  Color(0xFFFFB74D), // Aug — amber (late summer)
    9:  Color(0xFFA1887F), // Sep — warm brown (autumn start)
    10: Color(0xFFFF7043), // Oct — pumpkin orange
    11: Color(0xFF7986CB), // Nov — muted indigo
    12: Color(0xFF4DB6AC), // Dec — teal (cool festive)
  };

  static Color of(int month) => colors[month] ?? Colors.grey;
}