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
      GoogleFonts.lora(
        fontSize: 28, fontWeight: FontWeight.w600,
        color: color, letterSpacing: -0.5,
      );

  static TextStyle tagline(Color color) =>
      GoogleFonts.lora(
        fontSize: 13, color: color,
        fontStyle: FontStyle.italic,
      );

  // ── Screen headings ────────────────────────────────────

  static TextStyle screenTitle(Color color) =>
      GoogleFonts.lora(
        fontSize: 22, fontWeight: FontWeight.w600,
        color: color, letterSpacing: -0.4, height: 1.3,
      );

  static TextStyle appBarTitle(Color color) =>
      GoogleFonts.inter(
        fontSize: 17, fontWeight: FontWeight.w500,
        color: color, letterSpacing: -0.2,
      );

  static TextStyle sectionLabel(Color color) =>
      GoogleFonts.inter(
        fontSize: 11, fontWeight: FontWeight.w500,
        color: color, letterSpacing: 0.6,
      );

  // ── Entry card ─────────────────────────────────────────

  static TextStyle entryTitle(Color color) =>
      GoogleFonts.lora(
        fontSize: 14, fontWeight: FontWeight.w500,
        color: color,
      );

  static TextStyle entryPreview(Color color) =>
      GoogleFonts.inter(
        fontSize: 12, color: color, height: 1.4,
      );

  static TextStyle entryDayNumber(Color color) =>
      GoogleFonts.inter(
        fontSize: 16, fontWeight: FontWeight.w600,
        color: color, height: 1,
      );

  static TextStyle entryMonthAbbr(Color color) =>
      GoogleFonts.inter(
        fontSize: 10, color: color, letterSpacing: 0.5,
      );

  static TextStyle entryDayLabel(Color color) =>
      GoogleFonts.inter(
        fontSize: 10, color: color,
        fontWeight: FontWeight.w500, letterSpacing: 0.3,
      );

  static TextStyle wordCount(Color color) =>
      GoogleFonts.inter(fontSize: 10, color: color);

  // ── Write screen ───────────────────────────────────────

  static TextStyle writeTitle(Color color) =>
      GoogleFonts.lora(
        fontSize: 18, fontWeight: FontWeight.w500,
        color: color, letterSpacing: -0.3,
      );

  static TextStyle writeBody(Color color) =>
      GoogleFonts.lora(
        fontSize: 16, color: color, height: 1.8,
      );

  // ── Entry detail ───────────────────────────────────────

  static TextStyle detailTitle(Color color) =>
      GoogleFonts.lora(
        fontSize: 18, fontWeight: FontWeight.w600,
        color: color, letterSpacing: -0.4, height: 1.3,
      );

  static TextStyle detailBody(Color color) =>
      GoogleFonts.lora(
        fontSize: 16, color: color, height: 1.9,
      );

  static TextStyle meta(Color color) =>
      GoogleFonts.inter(fontSize: 12, color: color);

  // ── Auth screens ───────────────────────────────────────

  static TextStyle authHeading(Color color) =>
      GoogleFonts.lora(
        fontSize: 20, fontWeight: FontWeight.w600,
        color: color, letterSpacing: -0.3,
      );

  static TextStyle authSubtitle(Color color) =>
      GoogleFonts.inter(fontSize: 13, color: color);

  static TextStyle fieldLabel(Color color) =>
      GoogleFonts.inter(fontSize: 13, color: color);

  static TextStyle fieldText(Color color) =>
      GoogleFonts.inter(fontSize: 15, color: color);

  static TextStyle errorText(Color color) =>
      GoogleFonts.inter(fontSize: 13, color: color);

  static TextStyle link(Color color) =>
      GoogleFonts.inter(fontSize: 13, color: color);

  // ── Settings ───────────────────────────────────────────

  static TextStyle settingsRowLabel(Color color) =>
      GoogleFonts.inter(
        fontSize: 14, color: color, fontWeight: FontWeight.w400,
      );

  static TextStyle settingsRowSublabel(Color color) =>
      GoogleFonts.inter(fontSize: 12, color: color);

  static TextStyle settingsEmail(Color color) =>
      GoogleFonts.inter(fontSize: 13, color: color);

  // ── PIN pad ────────────────────────────────────────────

  static TextStyle pinLabel(Color color) =>
      GoogleFonts.inter(fontSize: 14, color: color, letterSpacing: 0.2);

  static TextStyle pinDigit(Color color) =>
      GoogleFonts.inter(
        fontSize: 20, fontWeight: FontWeight.w300, color: color,
      );

  // ── Photo strip ────────────────────────────────────────

  static TextStyle photoSectionLabel(Color color) =>
      GoogleFonts.inter(
        fontSize: 10, color: color, letterSpacing: 0.5,
      );

  // ── Color tag picker ───────────────────────────────────

  static TextStyle colorTagLabel(Color color) =>
      GoogleFonts.inter(
        fontSize: 11, color: color, letterSpacing: 0.5,
      );

  // ── Search ─────────────────────────────────────────────

  static TextStyle searchHint(Color color) =>
      GoogleFonts.inter(fontSize: 15, color: color);

  static TextStyle searchFilterChip(Color color,
      {bool selected = false}) =>
      GoogleFonts.inter(
        fontSize: 12, color: color,
        fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
      );

  // ── Appearance screen ──────────────────────────────────

  static TextStyle themeName(Color color) =>
      GoogleFonts.inter(
        fontSize: 15, fontWeight: FontWeight.w500, color: color,
      );

  static TextStyle themeNote(Color color) =>
      GoogleFonts.inter(fontSize: 12, color: color, height: 1.6);

  // ── Empty & error states ───────────────────────────────

  static TextStyle emptyTitle(Color color) =>
      GoogleFonts.lora(
        fontSize: 16, fontWeight: FontWeight.w500, color: color,
      );

  static TextStyle emptySubtitle(Color color) =>
      GoogleFonts.inter(fontSize: 13, color: color);

  // ── Version / legal ────────────────────────────────────

  static TextStyle version(Color color) =>
      GoogleFonts.inter(fontSize: 11, color: color);

  static TextStyle legalHeading(Color color) =>
      GoogleFonts.lora(
        fontSize: 18, fontWeight: FontWeight.w500,
        color: color, letterSpacing: -0.3,
      );

  static TextStyle legalBody(Color color) =>
      GoogleFonts.inter(
        fontSize: 14, color: color, height: 1.7,
      );

  static TextStyle legalSectionTitle(Color color) =>
      GoogleFonts.inter(
        fontSize: 13, fontWeight: FontWeight.w600,
        color: color, letterSpacing: 0.1,
      );
}