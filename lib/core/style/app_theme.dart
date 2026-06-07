import 'package:flutter/material.dart';
import 'package:poppy/core/core.dart';

/// Poppy — Flower Theme System
///
/// Defines the theme identifiers and the data structure for the app's 
/// custom "Flower" themes.
enum PoppyTheme { poppy, iris, lily, marigold, lavender }

/// Data structure containing all color information for a specific [PoppyTheme].
class PoppyThemeData {
  final PoppyTheme id;
  final String name;
  final Color accent;
  final Color accentLight;
  final Color accentMuted;
  final Color surface;
  final Color background;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color border;

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
  });

  /// Converts this [PoppyThemeData] into a standard Flutter [ThemeData].
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
        ),
      ],
    );
  }
}

/// A [ThemeExtension] that allows easy access to Poppy-specific colors 
/// from the [ThemeData].
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
    );
  }
}

/// Helper extension to access [PoppyThemeExtension] from [BuildContext].
extension PoppyThemeContext on BuildContext {
  PoppyThemeExtension get poppyTheme =>
      Theme.of(this).extension<PoppyThemeExtension>()!;
}
