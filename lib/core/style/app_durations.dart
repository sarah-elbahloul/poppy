import 'package:flutter/animation.dart';

/// Centralizes timing and easing constants for consistent animations throughout the application.
class AppDuration {
  AppDuration._();

  /// 50ms — Instant feedback (e.g., tap highlight).
  static const instant = Duration(milliseconds: 50);

  /// 100ms — Fast transitions.
  static const fast = Duration(milliseconds: 100);

  /// 200ms — Standard micro-animations (e.g., opacity, color changes).
  static const normal = Duration(milliseconds: 200);

  /// 300ms — Complex transitions (e.g., screen slides, expand/collapse).
  static const slow = Duration(milliseconds: 300);

  /// 400ms — Shake animations or long feedback loops.
  static const shake = Duration(milliseconds: 400);

  /// 600ms — Delay before resetting error states.
  static const errorReset = Duration(milliseconds: 600);
}

/// Defines a standardized set of animation curves for a cohesive user experience.
class AppCurve {
  AppCurve._();

  static const standard = Curves.easeInOut;
  static const enter = Curves.easeOut;
  static const exit = Curves.easeIn;
  static const spring = Curves.elasticIn;
  static const bounce = Curves.bounceOut;
  static const decelerate = Curves.decelerate;
}
