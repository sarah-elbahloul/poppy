import 'package:flutter/cupertino.dart';

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

/// Fixed dimensions and responsive calculation helpers for specific UI components.
class AppComponentSize {
  AppComponentSize._();

  static const double appBarHeight = 60.0;
  static const double inputHeight = 44.0;
  static const double filterBarHeight = 40.0;
  static const double entryCardHeight = 58.0;
  static const double entryDateColWidth = 48.0;
  static const double photoStripHeight = 96.0;
  static const double photoThumbSize = 80.0;
  static const double colorDot = 20.0;
  static const double colorDotPicker = 18.0;
  static const double colorDotChip = 15.0;
  static const double pinKey = 64.0;
  static const double pinDot = 12.0;
  static const double fab = 56.0;
  static const double sheetHandle = 36.0;
  static const double sheetHandleHeight = 4.0;
  static const double settingsIconCol = 20.0;
  static const double confirmIconCircle = 72.0;
  static const double colorPickerWheel = 180.0;
  static const double colorPickerRing = 24.0;
  static const double colorPickerSwatch = 42.0;

  /// Returns a responsive width for search fields, typically 70% of the screen.
  static double searchFieldWidth(BuildContext context) =>
      MediaQuery.sizeOf(context).width * 0.7;

  /// Returns the responsive width for the navigation drawer.
  static double drawerWidth(BuildContext context) =>
      MediaQuery.sizeOf(context).width * 0.8;
}
