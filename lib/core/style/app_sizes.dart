// ─────────────────────────────────────────────────────────────
//  POPPY — Sizes
//  Location: lib/core/style/app_sizes.dart
//
//  All numeric constants for spacing, border radius,
//  component sizes, and icon sizes.
//  Use these everywhere instead of raw numbers.
// ─────────────────────────────────────────────────────────────

class AppSpacing {
  AppSpacing._();

  /// 4 dp — used for the tightest gaps (e.g. between label and value)
  static const double xs = 4.0;

  /// 8 dp — small gaps inside components
  static const double sm = 8.0;

  /// 14 dp — standard internal padding
  static const double md = 14.0;

  /// 20 dp — screen-edge horizontal padding, section gaps
  static const double lg = 20.0;

  /// 32 dp — large vertical breathing room
  static const double xl = 32.0;

  /// 48 dp — splash screen / lock screen vertical offsets
  static const double xxl = 50.0;
}

class AppRadius {
  AppRadius._();

  /// 6 dp — tags, small chips
  static const double xs  = 6.0;

  /// 8 dp — photo thumbnails, small containers
  static const double sm  = 8.0;

  /// 12 dp — cards, input fields
  static const double md  = 12.0;

  /// 16 dp — sheets, large cards
  static const double lg  = 16.0;

  /// 24 dp — FAB, pill chips
  static const double xl  = 24.0;

  /// 999 dp — fully rounded / stadium shape
  static const double full = 999.0;
}

class AppStroke {
  AppStroke._();

  /// 0.5 dp — hairline dividers and card borders
  static const double hairline = 0.5;

  /// 1.0 dp — standard border
  static const double thin = 1.0;

  /// 1.5 dp — selected state border
  static const double medium = 1.5;

  static const double thick = 2.0;

  /// 3.0 dp — entry color tag strip
  static const double colorStrip = 4.0;
}

class AppIconSize {
  AppIconSize._();

  /// 16 dp — inline icons next to small text
  static const double xs  = 16.0;

  /// 20 dp — standard action icons in app bars and rows
  static const double sm  = 20.0;

  /// 24 dp — default Material icon size
  static const double md  = 24.0;

  /// 28 dp — nav bar / prominent icons
  static const double lg  = 28.0;

  /// 36 dp — empty state illustrations
  static const double xl  = 36.0;

  /// 52 dp — logo on auth screens
  static const double logo = 70.0;

  /// 64 dp — large logo on lock / splash
  static const double logoLg = 64.0;
}

class AppComponentSize {
  AppComponentSize._();

  /// Standard app bar height (Flutter default is 56)
  static const double appBarHeight = 56.0;

  /// Height of a compact entry card row
  static const double entryCardHeight = 58.0;

  /// Height of the photo strip section
  static const double photoStripHeight = 100.0;

  /// Photo thumbnail size inside the strip
  static const double photoThumbSize = 64.0;

  /// Color dot — default size
  static const double colorDot = 20.0;

  /// Color dot — inside the color picker toolbar
  static const double colorDotPicker = 18.0;

  /// Color dot — inside search filter chips
  static const double colorDotChip = 10.0;

  /// PIN pad digit key diameter
  static const double pinKey = 64.0;

  /// PIN dot indicator diameter
  static const double pinDot = 12.0;

  /// FAB size
  static const double fab = 56.0;

  /// Bottom sheet handle bar width
  static const double sheetHandle = 36.0;

  /// Bottom sheet handle bar height
  static const double sheetHandleHeight = 4.0;

  /// Settings section icon column width
  static const double settingsIconCol = 20.0;

  /// Confirmation icon circle (e.g. email sent screen)
  static const double confirmIconCircle = 72.0;
}