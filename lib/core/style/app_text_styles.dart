import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Text Styles
//  Location: lib/core/style/app_text_styles.dart
//
//  Lora  — entry titles, body content, app name, tagline
//          Warm serif. Feels like a real diary.
//  Inter — all UI chrome: labels, buttons, meta, settings
//          Clean sans-serif. Stays out of the way.
// ─────────────────────────────────────────────────────────────

class AppTextStyles {
  AppTextStyles._();

  // ── App identity ───────────────────────────────────────

  static TextStyle appName(Color color) =>
      GoogleFonts.kavoon(
        fontSize: 28,
        color: color, letterSpacing: -0.5,
      );

  static TextStyle tagline(Color color) =>
      GoogleFonts.chilanka(
        fontSize: 13, color: color,fontWeight: FontWeight.w600,
      );

  // ── Screen headings ────────────────────────────────────

  static TextStyle screenTitle(Color color) =>
      GoogleFonts.kavoon(
        fontSize: 22,
        color: color, letterSpacing: -0.4, height: 1.3,
      );

  static TextStyle appBarTitle(Color color) =>
      GoogleFonts.kavoon(
        fontSize: 17,
        color: color, letterSpacing: -0.2,
      );

  static TextStyle sectionLabel(Color color) =>
      GoogleFonts.kavoon(
        fontSize: 12,
        color: color, letterSpacing: 0.6,
      );

  // ── Entry card ─────────────────────────────────────────

  static TextStyle entryTitle(Color color) =>
      GoogleFonts.chilanka(
        fontSize: 14, fontWeight: FontWeight.w500,
        color: color,
      );

  static TextStyle entryPreview(Color color) =>
      GoogleFonts.chilanka(
        fontSize: 12, color: color, height: 1.4,
      );

  static TextStyle entryDayNumber(Color color) =>
      GoogleFonts.chilanka(
        fontSize: 16, fontWeight: FontWeight.w600,
        color: color, height: 1,
      );

  static TextStyle entryMonthAbbr(Color color) =>
      GoogleFonts.chilanka(
        fontSize: 10, color: color, letterSpacing: 0.5,
      );

  static TextStyle entryDayLabel(Color color) =>
      GoogleFonts.chilanka(
        fontSize: 10, color: color,
        fontWeight: FontWeight.w500, letterSpacing: 0.3,
      );

  static TextStyle wordCount(Color color) =>
      GoogleFonts.chilanka(fontSize: 10, color: color);

  // ── Write screen ───────────────────────────────────────

  static TextStyle writeTitle(Color color) =>
      GoogleFonts.kavoon(
        fontSize: 18,
        color: color, letterSpacing: -0.3,
      );

  static TextStyle writeBody(Color color) =>
      GoogleFonts.chilanka(
        fontSize: 16, color: color, height: 1.8,
      );

  // ── Entry detail ───────────────────────────────────────

  static TextStyle detailTitle(Color color) =>
      GoogleFonts.kavoon(
        fontSize: 18,
        color: color, letterSpacing: -0.4, height: 1.3,
      );

  static TextStyle detailBody(Color color) =>
      GoogleFonts.kavoon(
        fontSize: 16, color: color, height: 1.9,
      );

  static TextStyle meta(Color color) =>
      GoogleFonts.chilanka(fontSize: 12, color: color);

  // ── Auth screens ───────────────────────────────────────

  static TextStyle authHeading(Color color) =>
      GoogleFonts.kavoon(
        fontSize: 20,
        color: color, letterSpacing: -0.3,
      );

  static TextStyle authSubtitle(Color color) =>
      GoogleFonts.chilanka(fontSize: 13, color: color);

  static TextStyle fieldLabel(Color color) =>
      GoogleFonts.chilanka(fontSize: 13, color: color);

  static TextStyle fieldText(Color color) =>
      GoogleFonts.chilanka(fontSize: 15, color: color);

  static TextStyle errorText(Color color) =>
      GoogleFonts.chilanka(fontSize: 13, color: color);

  static TextStyle link(Color color) =>
      GoogleFonts.chilanka(fontSize: 13, color: color);

  // ── Settings ───────────────────────────────────────────

  static TextStyle settingsRowLabel(Color color) =>
      GoogleFonts.chilanka(
        fontSize: 14, color: color, fontWeight: FontWeight.w400,
      );

  static TextStyle settingsRowSublabel(Color color) =>
      GoogleFonts.chilanka(fontSize: 12, color: color);

  static TextStyle settingsEmail(Color color) =>
      GoogleFonts.chilanka(fontSize: 13, color: color);

  // ── PIN pad ────────────────────────────────────────────

  static TextStyle pinLabel(Color color) =>
      GoogleFonts.chilanka(fontSize: 14, color: color, letterSpacing: 0.2);

  static TextStyle pinDigit(Color color) =>
      GoogleFonts.chilanka(
        fontSize: 20, fontWeight: FontWeight.w300, color: color,
      );

  // ── Photo strip ────────────────────────────────────────

  static TextStyle photoSectionLabel(Color color) =>
      GoogleFonts.chilanka(
        fontSize: 10, color: color, letterSpacing: 0.5,
      );

  // ── Color tag picker ───────────────────────────────────

  static TextStyle colorTagLabel(Color color) =>
      GoogleFonts.chilanka(
        fontSize: 11, color: color, letterSpacing: 0.5,
      );

  // ── Search ─────────────────────────────────────────────

  static TextStyle searchHint(Color color) =>
      GoogleFonts.chilanka(fontSize: 15, color: color);

  static TextStyle searchFilterChip(Color color,
      {bool selected = false}) =>
      GoogleFonts.chilanka(
        fontSize: 12, color: color,
        fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
      );

  // ── Appearance screen ──────────────────────────────────

  static TextStyle themeName(Color color) =>
      GoogleFonts.chilanka(
        fontSize: 15, fontWeight: FontWeight.w500, color: color,
      );

  static TextStyle themeNote(Color color) =>
      GoogleFonts.chilanka(fontSize: 12, color: color, height: 1.6);

  // ── Empty & error states ───────────────────────────────

  static TextStyle emptyTitle(Color color) =>
      GoogleFonts.kavoon(
        fontSize: 16, color: color,
      );

  static TextStyle emptySubtitle(Color color) =>
      GoogleFonts.chilanka(fontSize: 13, color: color);

  // ── Version / legal ────────────────────────────────────

  static TextStyle version(Color color) =>
      GoogleFonts.chilanka(fontSize: 11, color: color);

  static TextStyle legalHeading(Color color) =>
      GoogleFonts.kavoon(
        fontSize: 18,
        color: color, letterSpacing: -0.3,
      );

  static TextStyle legalBody(Color color) =>
      GoogleFonts.chilanka(
        fontSize: 14, color: color, height: 1.7,
      );

  static TextStyle legalSectionTitle(Color color) =>
      GoogleFonts.chilanka(
        fontSize: 13, fontWeight: FontWeight.w600,
        color: color, letterSpacing: 0.1,
      );
}