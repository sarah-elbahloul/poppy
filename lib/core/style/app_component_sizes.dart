import 'package:flutter/cupertino.dart';

// App-specific fixed dimensions for this app's particular screens and
// components. Unlike app_sizes.dart, these values are NOT generic — when
// reusing the design system in another app, this is the file you'd swap
// out or rewrite, while app_sizes.dart can usually be copied unchanged.

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