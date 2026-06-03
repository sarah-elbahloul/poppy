import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:poppy/providers/theme_provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Text Styles
//  Location: lib/core/style/app_text_styles.dart
//
//  Font roles:
//    Title font — entry titles, app bar, display text
//    Body font  — diary writing, previews, editorial body
//
//  The active fonts come from ThemeProvider via FontPairData.
//  Pass `fp` from ThemeProvider into all methods except display.
//
//  LOCKED: Display styles (app name, branding) always use Lora.
//  UNLOCKED: All other styles respect the user's font choice.
//
//  Font size scaling:
//    Scalable methods accept an optional `scale` parameter
//    (from tp.currentFontSize.scale) so the whole reading
//    experience grows/shrinks together.
// ─────────────────────────────────────────────────────────────

class AppTextStyles {
  AppTextStyles._();

  // ── Display (LOCKED — always Lora) ───────────────────────

  // App name
  static TextStyle displayLarge(Color color) => GoogleFonts.lora(
    fontSize: 28,
    color: color,
    letterSpacing: -0.5,
    fontWeight: FontWeight.w700,
  );

  // App name (compact)
  static TextStyle displayMedium(Color color) => GoogleFonts.lora(
    fontSize: 17,
    color: color,
    letterSpacing: -0.5,
    fontWeight: FontWeight.w700,
  );

  // ── Headlines ────────────────────────────────────────────

  // Screen title, Legal heading
  static TextStyle headlineLarge(Color color, FontPairData fp,
      {double scale = 1.0}) =>
      fp.titleFont.bold(color, size: 22 * scale, height: 1.3);

  // Entry detail title, Legal heading (smaller)
  static TextStyle headlineMedium(Color color, FontPairData fp,
      {double scale = 1.0}) =>
      fp.titleFont.style(color, size: 18 * scale, height: 1.3, weight: FontWeight.w500);

  // Auth heading
  static TextStyle headlineSmall(Color color, FontPairData fp) =>
      fp.titleFont.style(color, size: 20, height: 1.3);

  // ── Titles ───────────────────────────────────────────────

  // App bar title
  static TextStyle titleLarge(Color color, FontPairData fp,
      {double scale = 1.0}) =>
      fp.titleFont.bold(color, size: 17 * scale, height: 1.2);

  // Write screen title, Theme name
  static TextStyle titleMedium(Color color, FontPairData fp) =>
      fp.titleFont.style(color, size: 15);

  // Entry card title
  static TextStyle titleSmallSerif(Color color, FontPairData fp,
      {double scale = 1.0}) =>
      fp.titleFont.bold(color, size: 14 * scale, height: 1.3);

  // Settings row label, Pin label
  static TextStyle titleSmallSans(Color color, FontPairData fp) =>
      fp.titleFont.style(color, size: 14);

  // ── Body ─────────────────────────────────────────────────

  // Write screen body, Entry detail body, Empty state title
  static TextStyle bodyLarge(Color color, FontPairData fp,
      {double scale = 1.0, double height = 1.8}) =>
      fp.bodyFont.style(color, size: 16 * scale, height: height);

  // Search hint, Field text, Legal body text
  static TextStyle bodyMedium(Color color, FontPairData fp) =>
      fp.bodyFont.style(color, size: 15);

  // App tagline
  static TextStyle bodySmallSerif(Color color, FontPairData fp) =>
      fp.bodyFont.style(color, size: 13, height: 1.5);

  // Auth subtitle, Field label, Error text, Link, Settings email, Empty subtitle, Legal section title
  static TextStyle bodySmallSans(Color color, FontPairData fp) =>
      fp.bodyFont.style(color, size: 13);

  // ── Labels ───────────────────────────────────────────────

  // Entry preview text, Entry meta data (date/time)
  static TextStyle labelLargeSerif(Color color, FontPairData fp) =>
      fp.bodyFont.style(color, size: 12, height: 1.4);

  // Section label, Settings row sublabel, Theme note, Search filter chip
  static TextStyle labelLargeSans(Color color, FontPairData fp) =>
      fp.bodyFont.style(color, size: 12, height: 1.4);

  // Version text
  static TextStyle labelMedium(Color color, FontPairData fp) =>
      fp.bodyFont.style(color, size: 11);

  // Entry month abbreviation, Entry day label, Word count
  static TextStyle labelSmall(Color color, FontPairData fp) =>
      fp.bodyFont.style(color, size: 10, height: 1.4);

  // ── Specialised UI ───────────────────────────────────────

  // Entry card day number (calendar widget style)
  static TextStyle calendarDay(Color color, FontPairData fp) =>
      fp.bodyFont.style(color, size: 14, height: 1);

  // PIN pad digit button
  static TextStyle pinDigit(Color color, FontPairData fp) =>
      fp.bodyFont.style(color, size: 20);
}