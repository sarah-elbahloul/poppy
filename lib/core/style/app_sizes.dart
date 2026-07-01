// Generic, app-agnostic spacing/sizing tokens — safe to copy into another
// project as-is. App-specific fixed component dimensions (e.g. this app's
// FAB size or its specific row heights) live separately in
// `app_component_sizes.dart`, which you would replace per-project instead.

/// Centralized spacing tokens for consistent padding and margins across the application.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 14.0;
  static const double lg = 20.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double xxxl = 64.0;
}

/// Border radius tokens for consistent corner rounding.
class AppRadius {
  AppRadius._();

  static const double xs = 6.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double full = 999.0;
}

/// Border width and stroke tokens.
class AppStroke {
  AppStroke._();

  static const double hairline = 0.5;
  static const double thin = 1.0;
  static const double medium = 1.5;
  static const double thick = 2.0;
  static const double colorStrip = 4.0;
}

/// Standard icon dimensions.
class AppIconSize {
  AppIconSize._();

  static const double xs = 16.0;
  static const double sm = 20.0;
  static const double md = 24.0;
  static const double lg = 28.0;
  static const double xl = 36.0;
  static const double logo = 70.0;
  static const double logoLg = 64.0;
}