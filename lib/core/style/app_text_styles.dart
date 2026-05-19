import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Standardized Text Styles
//  Location: lib/core/style/app_text_styles.dart
//
//  Lora (Serif)  — Diary content, identity, editorial headings
//  Inter (Sans)  — All UI chrome, settings, labels, inputs
// ─────────────────────────────────────────────────────────────

class AppTextStyles {
  AppTextStyles._();

  // ── Display ────────────────────────────────────────────

  static TextStyle displayLarge(Color color) => GoogleFonts.lora(
    fontSize: 28,
    color: color,
    letterSpacing: -0.5,
    fontWeight: FontWeight.w700,
  ); // App name

  // ── Headlines ──────────────────────────────────────────

  static TextStyle headlineLarge(Color color) => GoogleFonts.lora(
    fontSize: 22,
    color: color,
    letterSpacing: -0.4,
    height: 1.3,
  ); // Screen title, Legal heading

  static TextStyle headlineMedium(Color color) => GoogleFonts.lora(
    fontSize: 18,
    color: color,
    letterSpacing: -0.3,
    height: 1.3,
  ); // Entry detail title, Legal heading (smaller)

  static TextStyle headlineSmall(Color color) => GoogleFonts.inter(
    fontSize: 20,
    color: color,
    letterSpacing: -0.3,
    fontWeight: FontWeight.w600,
  ); // Auth heading

  // ── Titles ─────────────────────────────────────────────

  static TextStyle titleLarge(Color color) => GoogleFonts.lora(
    fontSize: 17,
    color: color,
    letterSpacing: -0.2,
    fontWeight: FontWeight.w600,
  ); // App bar title

  static TextStyle titleMedium(Color color) => GoogleFonts.inter(
    fontSize: 15,
    color: color,
    letterSpacing: -0.3,
  ); // Write screen title, Theme name

  static TextStyle titleSmallSerif(Color color) => GoogleFonts.lora(
    fontSize: 14,
    color: color,
    fontWeight: FontWeight.w500,
  ); // Entry card title

  static TextStyle titleSmallSans(Color color) => GoogleFonts.inter(
    fontSize: 14,
    color: color,
  ); // Settings row label, Pin label

  // ── Body ───────────────────────────────────────────────

  static TextStyle bodyLarge(Color color) => GoogleFonts.lora(
    fontSize: 16,
    color: color,
    height: 1.8,
  ); // Write screen body, Entry detail body, Empty state title

  static TextStyle bodyMedium(Color color) => GoogleFonts.inter(
    fontSize: 15,
    color: color,
  ); // Search hint, Field text, Legal body text

  static TextStyle bodySmallSerif(Color color) => GoogleFonts.lora(
    fontSize: 13,
    color: color,
    fontWeight: FontWeight.w600,
  ); // App tagline

  static TextStyle bodySmallSans(Color color) => GoogleFonts.inter(
    fontSize: 13,
    color: color,
  ); // Auth subtitle, Field label, Error text, Link, Settings email, Empty subtitle, Legal section title

  // ── Labels ─────────────────────────────────────────────

  static TextStyle labelLargeSerif(Color color) => GoogleFonts.lora(
    fontSize: 12,
    color: color,
    height: 1.4,
  ); // Entry preview text, Entry meta data (date/time)

  static TextStyle labelLargeSans(Color color) => GoogleFonts.inter(
    fontSize: 12,
    color: color,
    letterSpacing: 0.5,
  ); // Section label, Settings row sublabel, Theme note, Search filter chip

  static TextStyle labelMedium(Color color) => GoogleFonts.inter(
    fontSize: 11,
    color: color,
  ); // Version text

  static TextStyle labelSmall(Color color) => GoogleFonts.inter(
    fontSize: 10,
    color: color,
    letterSpacing: 0.3,
  ); // Entry month abbreviation, Entry day label, Word count

  // ── Specialized UI ─────────────────────────────────────

  static TextStyle calendarDay(Color color) => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: color,
    height: 1,
  ); // Entry card day number (calendar widget style)

  static TextStyle pinDigit(Color color) => GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w300,
    color: color,
  ); // PIN pad digit button
}