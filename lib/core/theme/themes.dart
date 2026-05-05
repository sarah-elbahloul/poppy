import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Flower Theme System
//  Location: lib/core/theme/themes.dart
//
//  5 themes, all pastel, all calm.
//  Each theme only changes accent + tint surfaces.
//  Backgrounds stay near-white in all themes.
// ─────────────────────────────────────────────────────────────

enum PoppyTheme { poppy, iris, lily, marigold, lavender }

class PoppyThemeData {
  final PoppyTheme id;
  final String name;          // shown in settings
  final String emoji;         // shown next to name
  final Color accent;         // buttons, FAB, active states
  final Color accentLight;    // chip backgrounds, subtle tints
  final Color accentMuted;    // color tag strip on entry card
  final Color surface;        // card / sheet background
  final Color background;     // scaffold background
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color border;

  const PoppyThemeData({
    required this.id,
    required this.name,
    required this.emoji,
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

  /// Converts this data into a full Flutter ThemeData
  ThemeData toThemeData() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.light(
        primary: accent,
        secondary: accentMuted,
        surface: surface,
        onPrimary: Colors.white,
        onSurface: textPrimary,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border, width: 0.5),
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
        iconTheme: IconThemeData(color: textPrimary, size: 22),
      ),
      textTheme: TextTheme(
        // Entry title
        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.2,
        ),
        // Entry preview / body
        bodyMedium: TextStyle(
          color: textSecondary,
          fontSize: 13,
          height: 1.6,
        ),
        // Meta info (date, word count)
        bodySmall: TextStyle(
          color: textTertiary,
          fontSize: 11,
          letterSpacing: 0.1,
        ),
        // Screen headings
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
      dividerTheme: DividerThemeData(
        color: border,
        thickness: 0.5,
        space: 0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: const CircleBorder(),
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
          themeEmoji: emoji,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  ThemeExtension — lets any widget do:
//  context.poppyTheme.accent  without a provider lookup
// ─────────────────────────────────────────────────────────────

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
  final String themeEmoji;

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
    required this.themeEmoji,
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
    String? themeEmoji,
  }) {
    return PoppyThemeExtension(
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
      themeEmoji: themeEmoji ?? this.themeEmoji,
    );
  }

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
      themeEmoji: other.themeEmoji,
    );
  }
}

// Convenience extension so widgets can write: context.poppyTheme
extension PoppyThemeContext on BuildContext {
  PoppyThemeExtension get poppyTheme =>
      Theme.of(this).extension<PoppyThemeExtension>()!;
}

// ─────────────────────────────────────────────────────────────
//  THE 5 FLOWER THEMES
// ─────────────────────────────────────────────────────────────

class PoppyThemes {
  PoppyThemes._();

  static const poppy = PoppyThemeData(
    id: PoppyTheme.poppy,
    name: 'Poppy',
    emoji: '🌺',
    accent: Color(0xFFC94040),
    accentLight: Color(0xFFFBEAEA),
    accentMuted: Color(0xFFE8A0A0),
    surface: Color(0xFFFDF8F8),
    background: Color(0xFFFFFBFB),
    textPrimary: Color(0xFF1A1212),
    textSecondary: Color(0xFF5C4444),
    textTertiary: Color(0xFFAA8888),
    border: Color(0xFFEDD8D8),
  );

  static const iris = PoppyThemeData(
    id: PoppyTheme.iris,
    name: 'Iris',
    emoji: '🪻',
    accent: Color(0xFF5C7FC4),
    accentLight: Color(0xFFEBF0FA),
    accentMuted: Color(0xFFA0BAEE),
    surface: Color(0xFFF8F9FD),
    background: Color(0xFFFBFCFF),
    textPrimary: Color(0xFF12141A),
    textSecondary: Color(0xFF3A4460),
    textTertiary: Color(0xFF8090B8),
    border: Color(0xFFD4DCF0),
  );

  static const lily = PoppyThemeData(
    id: PoppyTheme.lily,
    name: 'Lily',
    emoji: '🌸',
    accent: Color(0xFF4FAD74),
    accentLight: Color(0xFFEBF7F0),
    accentMuted: Color(0xFF90D4A8),
    surface: Color(0xFFF8FDF9),
    background: Color(0xFFFBFFFD),
    textPrimary: Color(0xFF121A14),
    textSecondary: Color(0xFF324A38),
    textTertiary: Color(0xFF80AA8A),
    border: Color(0xFFCCEDD6),
  );

  static const marigold = PoppyThemeData(
    id: PoppyTheme.marigold,
    name: 'Marigold',
    emoji: '🌼',
    accent: Color(0xFFB87030),
    accentLight: Color(0xFFFAF3EA),
    accentMuted: Color(0xFFF0C080),
    surface: Color(0xFFFDFAF6),
    background: Color(0xFFFFFDF9),
    textPrimary: Color(0xFF1A1510),
    textSecondary: Color(0xFF5A4020),
    textTertiary: Color(0xFFAA8858),
    border: Color(0xFFEEDEC8),
  );

  static const lavender = PoppyThemeData(
    id: PoppyTheme.lavender,
    name: 'Lavender',
    emoji: '💜',
    accent: Color(0xFF9050A8),
    accentLight: Color(0xFFF5EBFA),
    accentMuted: Color(0xFFDCA0E0),
    surface: Color(0xFFFCF8FD),
    background: Color(0xFFFEFBFF),
    textPrimary: Color(0xFF16121A),
    textSecondary: Color(0xFF483055),
    textTertiary: Color(0xFFA080B0),
    border: Color(0xFFE4D0EC),
  );

  /// All themes in order (used in the appearance settings screen)
  static const all = [poppy, iris, lily, marigold, lavender];

  /// Look up a theme by its enum value
  static PoppyThemeData fromId(PoppyTheme id) {
    return all.firstWhere((t) => t.id == id);
  }
}