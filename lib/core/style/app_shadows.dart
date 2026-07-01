import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Shadow Definitions
// ─────────────────────────────────────────────────────────────

/// Defines standard shadow tokens used to provide depth and hierarchy.
class AppShadows {
  AppShadows._();

  /// Subtle lift for cards and elevated containers.
  static List<BoxShadow> card = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  /// More pronounced shadow for Floating Action Buttons.
  static List<BoxShadow> fab = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  /// Glow effect for highlighted color indicators.
  static List<BoxShadow> colorDotGlow(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.9),
      blurRadius: 6,
      spreadRadius: 1,
    ),
  ];

  /// Shadow for bottom sheets and overlay panels.
  static List<BoxShadow> sheet = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 20,
      offset: const Offset(0, -4),
    ),
  ];

  static const List<BoxShadow> none = [];
}