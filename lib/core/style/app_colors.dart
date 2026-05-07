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
}