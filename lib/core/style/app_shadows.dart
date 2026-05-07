import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Shadows
//  Location: lib/core/style/app_shadows.dart
//
//  Poppy is intentionally flat and calm — shadows are
//  used sparingly and are always very subtle.
// ─────────────────────────────────────────────────────────────

class AppShadows {
  AppShadows._();

  /// Barely-there lift — used on cards when elevated
  static List<BoxShadow> card = [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  /// FAB shadow
  static List<BoxShadow> fab = [
    BoxShadow(
      color: Colors.black.withOpacity(0.12),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  /// Selected color dot glow — uses the dot's color, applied inline
  static List<BoxShadow> colorDotGlow(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.9),
      blurRadius: 6,
      spreadRadius: 1,
    ),
  ];

  /// Bottom sheet lift
  static List<BoxShadow> sheet = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 20,
      offset: const Offset(0, -4),
    ),
  ];

  /// No shadow — explicit zero for clarity
  static const List<BoxShadow> none = [];
}