import 'package:flutter/material.dart';
import 'package:poppy/core/core.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Theme Configuration
//  Location: lib/core/style/app_theme.dart
// ─────────────────────────────────────────────────────────────

/// Supported application theme identifiers.
enum PoppyTheme { poppy, iris, lily, marigold, lavender }

/// Encapsulates the color scheme and Material [ThemeData] generation for the application.
/// 
/// This class serves as the bridge between Poppy's custom design tokens 
/// and Flutter's standard Material theme system.
class PoppyThemeData {
  final PoppyTheme id;
  final String name;

  // Primary palette
  final Color accent;
  final Color accentLight;
  final Color accentMuted;

  // Surface & Background
  final Color surface;
  final Color background;

  // Typography colors
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  // Structural
  final Color border;

  // Typography Data
  final FontPairData fontPair;

  const PoppyThemeData({
    required this.id,
    required this.name,
    required this.accent,
    required this.accentLight,
    required this.accentMuted,
    required this.surface,
    required this.background,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.border,
    required this.fontPair,
  });

  // ─────────────────────────────────────────────────────────────
  //  Material Theme Generation
  // ─────────────────────────────────────────────────────────────

  /// Maps the Poppy theme properties to a standard Flutter [ThemeData] object.
  ThemeData toThemeData() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.light(
        primary: accent,
        secondary: accentMuted,
        surface: surface,
        onPrimary: AppColors.white,
        onSurface: textPrimary,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: border, width: AppStroke.hairline),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: textPrimary, size: AppIconSize.sm),
      ),
      textTheme: TextTheme(
        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.2,
        ),
        bodyMedium: TextStyle(
          color: textSecondary,
          fontSize: 13,
          height: 1.6,
        ),
        bodySmall: TextStyle(
          color: textTertiary,
          fontSize: 11,
          letterSpacing: 0.1,
        ),
        headlineSmall: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.5,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: textTertiary, fontSize: 15),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: border,
        thickness: AppStroke.hairline,
        space: 0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: AppColors.white,
        elevation: 2,
        shape: const CircleBorder(),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: textPrimary,
        contentTextStyle: TextStyle(color: background, fontSize: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w500,
        ),
        contentTextStyle: TextStyle(
          color: textSecondary,
          fontSize: 14,
          height: 1.5,
        ),
      ),
      extensions: [
        PoppyThemeExtension(
          accent: accent,
          accentLight: accentLight,
          accentMuted: accentMuted,
          surface: surface,
          background: background,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          textTertiary: textTertiary,
          border: border,
          themeName: name,
          fontPair: fontPair,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Theme Extensions
// ─────────────────────────────────────────────────────────────

/// A [ThemeExtension] that allows direct access to Poppy's custom color tokens.
/// 
/// Usage: `Theme.of(context).extension<PoppyThemeExtension>()` or `context.poppyTheme`.
class PoppyThemeExtension extends ThemeExtension<PoppyThemeExtension> {
  final Color accent;
  final Color accentLight;
  final Color accentMuted;
  final Color surface;
  final Color background;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color border;
  final String themeName;
  final FontPairData fontPair;

  const PoppyThemeExtension({
    required this.accent,
    required this.accentLight,
    required this.accentMuted,
    required this.surface,
    required this.background,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.border,
    required this.themeName,
    required this.fontPair,
  });

  @override
  PoppyThemeExtension copyWith({
    Color? accent,
    Color? accentLight,
    Color? accentMuted,
    Color? surface,
    Color? background,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? border,
    String? themeName,
    FontPairData? fontPair,
  }) =>
      PoppyThemeExtension(
        accent: accent ?? this.accent,
        accentLight: accentLight ?? this.accentLight,
        accentMuted: accentMuted ?? this.accentMuted,
        surface: surface ?? this.surface,
        background: background ?? this.background,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        textTertiary: textTertiary ?? this.textTertiary,
        border: border ?? this.border,
        themeName: themeName ?? this.themeName,
        fontPair: fontPair ?? this.fontPair,
      );

  @override
  PoppyThemeExtension lerp(PoppyThemeExtension? other, double t) {
    if (other == null) return this;
    return PoppyThemeExtension(
      accent: Color.lerp(accent, other.accent, t)!,
      accentLight: Color.lerp(accentLight, other.accentLight, t)!,
      accentMuted: Color.lerp(accentMuted, other.accentMuted, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      background: Color.lerp(background, other.background, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      border: Color.lerp(border, other.border, t)!,
      themeName: other.themeName,
      fontPair: t < 0.5 ? fontPair : other.fontPair,
    );
  }
}

/// Provides convenient access to the [PoppyThemeExtension] from the [BuildContext].
extension PoppyThemeContext on BuildContext {
  /// Returns the current [PoppyThemeExtension] from the theme.
  PoppyThemeExtension get poppyTheme =>
      Theme.of(this).extension<PoppyThemeExtension>()!;

  /// Returns the current [FontPairData] from the theme extension.
  FontPairData get fontPair => poppyTheme.fontPair;
}
