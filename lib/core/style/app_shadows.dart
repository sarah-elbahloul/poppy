import 'package:flutter/material.dart';

/// Poppy — Shadows
///
/// Defines the subtle shadow effects used across the app. 
/// Poppy maintains a clean, flat aesthetic, using shadows sparingly for depth.
class AppShadows {
  AppShadows._();

  /// Subtle lift used on cards when they are elevated.
  static List<BoxShadow> card = [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  /// Shadow for Floating Action Buttons.
  static List<BoxShadow> fab = [
    BoxShadow(
      color: Colors.black.withOpacity(0.12),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  /// A glow effect used for selected color dots.
  static List<BoxShadow> colorDotGlow(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.9),
      blurRadius: 6,
      spreadRadius: 1,
    ),
  ];

  /// Shadow applied to bottom sheets.
  static List<BoxShadow> sheet = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 20,
      offset: const Offset(0, -4),
    ),
  ];

  /// Represents no shadow.
  static const List<BoxShadow> none = [];
}
