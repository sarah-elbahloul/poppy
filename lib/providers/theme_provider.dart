import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:poppy/core/core.dart';

/// Represents a customizable color slot within the application's theme.
class ColorSlot {
  /// The storage key used to persist the color value.
  final String key;

  /// The user-facing label for the color slot.
  final String label;

  /// A brief description of what this color affects in the UI.
  final String description;

  /// The default color value if no customization exists.
  final Color defaultValue;

  const ColorSlot({
    required this.key,
    required this.label,
    required this.description,
    required this.defaultValue,
  });
}

/// Defines the collection of available color slots for theme customization.
class ColorSlots {
  ColorSlots._();

  static const accent = ColorSlot(
    key: StorageKeys.colorAccent,
    label: 'Accent',
    description: 'Buttons, FAB, and selected icons',
    defaultValue: AppColors.accent,
  );
  static const accentLight = ColorSlot(
    key: StorageKeys.colorAccentLight,
    label: 'Highlight',
    description: 'Card headers and tag backgrounds',
    defaultValue: AppColors.accentLight,
  );
  static const accentMuted = ColorSlot(
    key: StorageKeys.colorAccentMuted,
    label: 'Muted',
    description: 'Secondary icons and pill chips',
    defaultValue: AppColors.accentMuted,
  );
  static const surface = ColorSlot(
    key: StorageKeys.colorSurface,
    label: 'Surface',
    description: 'Cards and input field backgrounds',
    defaultValue: AppColors.surface,
  );
  static const background = ColorSlot(
    key: StorageKeys.colorBackground,
    label: 'Background',
    description: 'Main screen background',
    defaultValue: AppColors.background,
  );
  static const textPrimary = ColorSlot(
    key: StorageKeys.colorTextPrimary,
    label: 'Text',
    description: 'Primary headings and body text',
    defaultValue: AppColors.textPrimary,
  );
  static const textSecondary = ColorSlot(
    key: StorageKeys.colorTextSecondary,
    label: 'Subtext',
    description: 'Labels and subtitles',
    defaultValue: AppColors.textSecondary,
  );
  static const textTertiary = ColorSlot(
    key: StorageKeys.colorTextTertiary,
    label: 'Hint',
    description: 'Placeholders and timestamps',
    defaultValue: AppColors.textTertiary,
  );
  static const border = ColorSlot(
    key: StorageKeys.colorBorder,
    label: 'Border',
    description: 'Card outlines and dividers',
    defaultValue: AppColors.border,
  );

  /// A list of all customizable color slots.
  static const all = [
    accent,
    accentLight,
    accentMuted,
    surface,
    background,
    textPrimary,
    textSecondary,
    textTertiary,
    border,
  ];
}

/// Manages the visual theme of the application, including custom colors 
/// and typography selections.
///
/// Customizations are persisted locally using [FlutterSecureStorage].
class ThemeProvider extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  final Map<String, Color> _colors = {};

  PoppyFont _titleFont = PoppyFont.literata;
  PoppyFont _bodyFont = PoppyFont.kalam;

  ThemeProvider() {
    _loadAll();
  }

  /// Returns the current color for a specific [slot], falling back to its default.
  Color colorFor(ColorSlot slot) => _colors[slot.key] ?? slot.defaultValue;

  /// Returns true if a specific [slot] has a custom user-defined color.
  bool isCustomized(ColorSlot slot) => _colors.containsKey(slot.key);

  /// Returns true if any theme colors have been customized.
  bool get hasAnyCustomColor => ColorSlots.all.any(isCustomized);

  /// The currently selected font for titles.
  PoppyFont get currentTitleFont => _titleFont;

  /// The currently selected font for body text.
  PoppyFont get currentBodyFont => _bodyFont;

  /// Returns the current [FontPairData] for styling text.
  FontPairData get currentFontPairData =>
      FontPairData(PoppyFonts.fromId(_titleFont), PoppyFonts.fromId(_bodyFont));

  /// Generates the [PoppyThemeData] based on current customizations.
  PoppyThemeData get currentThemeData => PoppyThemeData(
    id: PoppyTheme.poppy,
    name: 'Poppy',
    accent: colorFor(ColorSlots.accent),
    accentLight: colorFor(ColorSlots.accentLight),
    accentMuted: colorFor(ColorSlots.accentMuted),
    surface: colorFor(ColorSlots.surface),
    background: colorFor(ColorSlots.background),
    textPrimary: colorFor(ColorSlots.textPrimary),
    textSecondary: colorFor(ColorSlots.textSecondary),
    textTertiary: colorFor(ColorSlots.textTertiary),
    border: colorFor(ColorSlots.border),
  );

  /// Loads persisted theme settings from local storage.
  Future<void> _loadAll() async {
    try {
      for (final slot in ColorSlots.all) {
        final hex = await _storage.read(key: slot.key);
        if (hex != null) _colors[slot.key] = _hexToColor(hex);
      }
      final tf = await _storage.read(key: StorageKeys.selectedTitleFont);
      final bf = await _storage.read(key: StorageKeys.selectedBodyFont);

      if (tf != null) {
        _titleFont = PoppyFont.values.firstWhere(
          (f) => f.name == tf,
          orElse: () => PoppyFont.literata,
        );
      }
      if (bf != null) {
        _bodyFont = PoppyFont.values.firstWhere(
          (f) => f.name == bf,
          orElse: () => PoppyFont.kalam,
        );
      }
    } catch (_) {
      // Errors during loading default to fallback values.
    }
    notifyListeners();
  }

  /// Sets a custom color for a specific [slot] and persists it.
  Future<void> setColor(ColorSlot slot, Color color) async {
    _colors[slot.key] = color;
    notifyListeners();
    await _storage.write(key: slot.key, value: _colorToHex(color));
  }

  /// Resets a specific [slot] to its default value.
  Future<void> resetColor(ColorSlot slot) async {
    _colors.remove(slot.key);
    notifyListeners();
    await _storage.delete(key: slot.key);
  }

  /// Resets all theme color customizations to their defaults.
  Future<void> resetAllColors() async {
    _colors.clear();
    notifyListeners();
    for (final slot in ColorSlots.all) {
      await _storage.delete(key: slot.key);
    }
  }

  /// Sets and persists the [titleFont] selection.
  Future<void> setTitleFont(PoppyFont v) async {
    if (_titleFont == v) return;
    _titleFont = v;
    notifyListeners();
    await _storage.write(key: StorageKeys.selectedTitleFont, value: v.name);
  }

  /// Sets and persists the [bodyFont] selection.
  Future<void> setBodyFont(PoppyFont v) async {
    if (_bodyFont == v) return;
    _bodyFont = v;
    notifyListeners();
    await _storage.write(key: StorageKeys.selectedBodyFont, value: v.name);
  }

  /// Converts a [Color] to a hex string (e.g., #AARRGGBB).
  String _colorToHex(Color c) =>
      '#${(c.value & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0').toUpperCase()}';

  /// Converts a hex string to a [Color].
  Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse(h.length == 6 ? 'FF$h' : h, radix: 16));
  }
}
