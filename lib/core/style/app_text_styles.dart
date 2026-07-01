import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:poppy/core/style/style.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Typography System
// ─────────────────────────────────────────────────────────────

/// Centralized management for all typography used in the application.
///
/// The typography system uses two primary font roles:
/// - **Title font**: Used for headings, app bars, and entry titles.
/// - **Body font**: Used for content writing, previews, and labels.
///
/// Most styles adapt dynamically based on the [FontPairData] selected by the user.
class AppTextStyles {
  AppTextStyles._();

  // ─────────────────────────────────────────────────────────────
  //  Branding
  // ─────────────────────────────────────────────────────────────

  /// Primary display style using Literata for brand identity.
  static TextStyle displayLarge(Color color) => GoogleFonts.literata(
    fontSize: 28,
    color: color,
    letterSpacing: -0.5,
    fontWeight: FontWeight.w700,
  );

  /// Secondary display style for sub-branding or large labels.
  static TextStyle displayMedium(Color color) => GoogleFonts.literata(
    fontSize: 17,
    color: color,
    letterSpacing: -0.5,
    fontWeight: FontWeight.w700,
  );

  // ─────────────────────────────────────────────────────────────
  //  Headlines
  // ─────────────────────────────────────────────────────────────

  /// Large headline style, typically used for screen titles.
  static TextStyle headlineLarge(
      Color color,
      FontPairData fp, {
        double scale = 1.0,
      }) =>
      fp.titleFont.bold(color, size: 22 * scale, height: 1.3);

  /// Medium headline style for section headers.
  static TextStyle headlineMedium(
      Color color,
      FontPairData fp, {
        double scale = 1.0,
      }) =>
      fp.titleFont.style(
        color,
        size: 20 * scale,
        height: 1.3,
        weight: FontWeight.w500,
      );

  /// Small headline style for minor section grouping.
  static TextStyle headlineSmall(Color color, FontPairData fp) =>
      fp.titleFont.style(color, size: 18, height: 1.3);

  // ─────────────────────────────────────────────────────────────
  //  Titles
  // ─────────────────────────────────────────────────────────────

  /// Large title style, often used in modals or prominent list items.
  static TextStyle titleLarge(
      Color color,
      FontPairData fp, {
        double scale = 1.0,
      }) =>
      fp.titleFont.bold(color, size: 17 * scale, height: 1.2);

  /// Medium title style for general UI elements.
  static TextStyle titleMedium(Color color, FontPairData fp) =>
      fp.titleFont.style(color, size: 15);

  /// Small serif title style, primarily used for entry titles in lists.
  static TextStyle titleSmallSerif(
      Color color,
      FontPairData fp, {
        double scale = 1.0,
      }) =>
      fp.titleFont.bold(color, size: 14 * scale, height: 1.3);

  /// Small sans-serif title style for UI controls.
  static TextStyle titleSmallSans(Color color, FontPairData fp) =>
      fp.titleFont.style(color, size: 14);

  // ─────────────────────────────────────────────────────────────
  //  Body
  // ─────────────────────────────────────────────────────────────

  /// Large body text style, optimized for long-form reading.
  static TextStyle bodyLarge(
      Color color,
      FontPairData fp, {
        double scale = 1.0,
        double height = 1.8,
      }) =>
      fp.bodyFont.style(color, size: 16 * scale, height: height);

  /// Standard body text style.
  static TextStyle bodyMedium(Color color, FontPairData fp) =>
      fp.bodyFont.style(color, size: 15);

  /// Small serif body text for secondary information.
  static TextStyle bodySmallSerif(Color color, FontPairData fp) =>
      fp.bodyFont.style(color, size: 13, height: 1.5);

  /// Small sans-serif body text for dense UI information.
  static TextStyle bodySmallSans(Color color, FontPairData fp) =>
      fp.bodyFont.style(color, size: 13);

  // ─────────────────────────────────────────────────────────────
  //  Labels
  // ─────────────────────────────────────────────────────────────

  /// Large label style using a serif face.
  static TextStyle labelLargeSerif(Color color, FontPairData fp) =>
      fp.bodyFont.style(color, size: 12, height: 1.4);

  /// Large label style using a sans-serif face.
  static TextStyle labelLargeSans(Color color, FontPairData fp) =>
      fp.bodyFont.style(color, size: 12, height: 1.4);

  /// Standard label style for UI annotations.
  static TextStyle labelMedium(Color color, FontPairData fp) =>
      fp.bodyFont.style(color, size: 11);

  /// Small label style for minor details or metadata.
  static TextStyle labelSmall(Color color, FontPairData fp) =>
      fp.bodyFont.style(color, size: 10, height: 1.4);

  // ─────────────────────────────────────────────────────────────
  //  Specialized
  // ─────────────────────────────────────────────────────────────

  /// Specific style for day numbers in calendar-like views.
  static TextStyle calendarDay(Color color, FontPairData fp) =>
      fp.bodyFont.style(color, size: 14, height: 1);

  /// Specific style for PIN entry digits.
  static TextStyle pinDigit(Color color, FontPairData fp) =>
      fp.bodyFont.style(color, size: 20);
}