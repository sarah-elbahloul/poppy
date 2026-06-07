import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:poppy/core/style/style.dart';

/// Poppy — Text Styles
///
/// Centralized management for all typography used in the app.
/// 
/// Font roles:
/// - Title font: Used for entry titles, app bars, and display text.
/// - Body font: Used for diary writing, previews, and editorial body text.
///
/// Display styles (app branding) are locked to the Literata font.
/// All other styles adapt to the user's selected [FontPairData] from [ThemeProvider].
class AppTextStyles {
  AppTextStyles._();

  // --- Display (Locked to Literata for branding) ---

  /// App name style for large display areas.
  static TextStyle displayLarge(Color color) => GoogleFonts.literata(
    fontSize: 28,
    color: color,
    letterSpacing: -0.5,
    fontWeight: FontWeight.w700,
  );

  /// Compact app name style.
  static TextStyle displayMedium(Color color) => GoogleFonts.literata(
    fontSize: 17,
    color: color,
    letterSpacing: -0.5,
    fontWeight: FontWeight.w700,
  );

  // --- Headlines ---

  /// Screen titles and legal headings.
  static TextStyle headlineLarge(Color color, FontPairData fp,
      {double scale = 1.0}) =>
      fp.titleFont.bold(color, size: 22 * scale, height: 1.3);

  /// Entry detail titles and smaller legal headings.
  static TextStyle headlineMedium(Color color, FontPairData fp,
      {double scale = 1.0}) =>
      fp.titleFont.style(color, size: 20 * scale, height: 1.3, weight: FontWeight.w500);

  /// Authentication headings.
  static TextStyle headlineSmall(Color color, FontPairData fp) =>
      fp.titleFont.style(color, size: 18, height: 1.3);

  // --- Titles ---

  /// App bar title style.
  static TextStyle titleLarge(Color color, FontPairData fp,
      {double scale = 1.0}) =>
      fp.titleFont.bold(color, size: 17 * scale, height: 1.2);

  /// Write screen title and theme names.
  static TextStyle titleMedium(Color color, FontPairData fp) =>
      fp.titleFont.style(color, size: 15);

  /// Entry card title style.
  static TextStyle titleSmallSerif(Color color, FontPairData fp,
      {double scale = 1.0}) =>
      fp.titleFont.bold(color, size: 14 * scale, height: 1.3);

  /// Settings row labels and PIN labels.
  static TextStyle titleSmallSans(Color color, FontPairData fp) =>
      fp.titleFont.style(color, size: 14);

  // --- Body ---

  /// Write screen body, entry details, and empty state titles.
  static TextStyle bodyLarge(Color color, FontPairData fp,
      {double scale = 1.0, double height = 1.8}) =>
      fp.bodyFont.style(color, size: 16 * scale, height: height);

  /// Search hints, field text, and legal body text.
  static TextStyle bodyMedium(Color color, FontPairData fp) =>
      fp.bodyFont.style(color, size: 15);

  /// App tagline style.
  static TextStyle bodySmallSerif(Color color, FontPairData fp) =>
      fp.bodyFont.style(color, size: 13, height: 1.5);

  /// Subtitles, field labels, error text, and links.
  static TextStyle bodySmallSans(Color color, FontPairData fp) =>
      fp.bodyFont.style(color, size: 13);

  // --- Labels ---

  /// Entry preview text and meta-data (date/time).
  static TextStyle labelLargeSerif(Color color, FontPairData fp) =>
      fp.bodyFont.style(color, size: 12, height: 1.4);

  /// Section labels, settings sub-labels, and filter chips.
  static TextStyle labelLargeSans(Color color, FontPairData fp) =>
      fp.bodyFont.style(color, size: 12, height: 1.4);

  /// Version information text.
  static TextStyle labelMedium(Color color, FontPairData fp) =>
      fp.bodyFont.style(color, size: 11);

  /// Tiny labels like word counts and date abbreviations.
  static TextStyle labelSmall(Color color, FontPairData fp) =>
      fp.bodyFont.style(color, size: 10, height: 1.4);

  // --- Specialised UI ---

  /// Style for day numbers in calendar-like widgets.
  static TextStyle calendarDay(Color color, FontPairData fp) =>
      fp.bodyFont.style(color, size: 14, height: 1);

  /// PIN pad digit button style.
  static TextStyle pinDigit(Color color, FontPairData fp) =>
      fp.bodyFont.style(color, size: 20);
}
