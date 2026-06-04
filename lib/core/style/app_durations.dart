// ─────────────────────────────────────────────────────────────
//  POPPY — Animation Durations & Curves
//  Location: lib/core/style/app_durations.dart
// ─────────────────────────────────────────────────────────────


import 'package:flutter/animation.dart';

class AppDuration {
  AppDuration._();

  /// 50ms — instant feedback (tap highlight, dot fill)
  static const instant   = Duration(milliseconds: 50);

  /// 100ms — instant feedback (tap highlight, dot fill)
  static const fast   = Duration(milliseconds: 100);

  /// 200ms — standard micro-animations (color change, opacity)
  static const normal = Duration(milliseconds: 200);

  /// 300ms — screen transitions, expand/collapse
  static const slow   = Duration(milliseconds: 300);

  /// 400ms — PIN shake animation
  static const shake  = Duration(milliseconds: 400);

  /// 600ms — error state reset delay
  static const errorReset = Duration(milliseconds: 600);
}

class AppCurve {
  AppCurve._();

  static const standard  = Curves.easeInOut;
  static const enter     = Curves.easeOut;
  static const exit      = Curves.easeIn;
  static const spring    = Curves.elasticIn;
  static const bounce    = Curves.bounceOut;
  static const decelerate = Curves.decelerate;
}