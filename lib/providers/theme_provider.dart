import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:poppy/core/core.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Appearance Provider
//  Location: lib/providers/theme_provider.dart
// ─────────────────────────────────────────────────────────────

class ColorSlot {
  final String key;
  final String label;
  final String description;
  final Color  defaultValue;

  const ColorSlot({
    required this.key,
    required this.label,
    required this.description,
    required this.defaultValue,
  });
}

class ColorSlots {
  ColorSlots._();

  static const accent = ColorSlot(
    key:          StorageKeys.colorAccent,
    label:        'Accent',
    description:  'Buttons, FAB, selected icons',
    defaultValue: AppColors.accent,
  );
  static const accentLight = ColorSlot(
    key:          StorageKeys.colorAccentLight,
    label:        'Highlight',
    description:  'Card headers, tag backgrounds',
    defaultValue: AppColors.accentLight,
  );
  static const accentMuted = ColorSlot(
    key:          StorageKeys.colorAccentMuted,
    label:        'Muted',
    description:  'Secondary icons, pill chips',
    defaultValue: AppColors.accentMuted,
  );
  static const surface = ColorSlot(
    key:          StorageKeys.colorSurface,
    label:        'Surface',
    description:  'Cards, input field backgrounds',
    defaultValue: AppColors.surface,
  );
  static const background = ColorSlot(
    key:          StorageKeys.colorBackground,
    label:        'Background',
    description:  'Main screen background',
    defaultValue: AppColors.background,
  );
  static const textPrimary = ColorSlot(
    key:          StorageKeys.colorTextPrimary,
    label:        'Text',
    description:  'Headings and body text',
    defaultValue: AppColors.textPrimary,
  );
  static const textSecondary = ColorSlot(
    key:          StorageKeys.colorTextSecondary,
    label:        'Subtext',
    description:  'Labels, subtitles',
    defaultValue: AppColors.textSecondary,
  );
  static const textTertiary = ColorSlot(
    key:          StorageKeys.colorTextTertiary,
    label:        'Hint',
    description:  'Placeholders, timestamps',
    defaultValue: AppColors.textTertiary,
  );
  static const border = ColorSlot(
    key:          StorageKeys.colorBorder,
    label:        'Border',
    description:  'Card outlines, dividers',
    defaultValue: AppColors.border,
  );

  static const all = [
    accent, accentLight, accentMuted,
    surface, background,
    textPrimary, textSecondary, textTertiary,
    border,
  ];
}

class ThemeProvider extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  final Map<String, Color> _colors = {};

  PoppyFont _titleFont = PoppyFont.literata;
  PoppyFont _bodyFont  = PoppyFont.kalam;

  ThemeProvider() { _loadAll(); }

  // ── Getters ──────────────────────────────────────────────

  Color colorFor(ColorSlot slot) => _colors[slot.key] ?? slot.defaultValue;
  bool isCustomized(ColorSlot slot) => _colors.containsKey(slot.key);
  bool get hasAnyCustomColor => ColorSlots.all.any(isCustomized);

  PoppyFont get currentTitleFont => _titleFont;
  PoppyFont get currentBodyFont  => _bodyFont;

  FontPairData get currentFontPairData =>
      FontPairData(PoppyFonts.fromId(_titleFont), PoppyFonts.fromId(_bodyFont));

  PoppyThemeData get currentThemeData => PoppyThemeData(
    id:            PoppyTheme.poppy,
    name:          'Poppy',
    accent:        colorFor(ColorSlots.accent),
    accentLight:   colorFor(ColorSlots.accentLight),
    accentMuted:   colorFor(ColorSlots.accentMuted),
    surface:       colorFor(ColorSlots.surface),
    background:    colorFor(ColorSlots.background),
    textPrimary:   colorFor(ColorSlots.textPrimary),
    textSecondary: colorFor(ColorSlots.textSecondary),
    textTertiary:  colorFor(ColorSlots.textTertiary),
    border:        colorFor(ColorSlots.border),
  );

  // ── Loading & Persistence ────────────────────────────────

  Future<void> _loadAll() async {
    try {
      for (final slot in ColorSlots.all) {
        final hex = await _storage.read(key: slot.key);
        if (hex != null) _colors[slot.key] = _hexToColor(hex);
      }
      final tf = await _storage.read(key: StorageKeys.selectedTitleFont);
      final bf = await _storage.read(key: StorageKeys.selectedBodyFont);

      _titleFont = PoppyFont.values.firstWhere((f) => f.name == tf, orElse: () => PoppyFont.literata);
      _bodyFont  = PoppyFont.values.firstWhere((f) => f.name == bf, orElse: () => PoppyFont.kalam);
    } catch (_) {}
    notifyListeners();
  }

  // ── Setters ──────────────────────────────────────────────

  Future<void> setColor(ColorSlot slot, Color color) async {
    _colors[slot.key] = color;
    notifyListeners();
    await _storage.write(key: slot.key, value: _colorToHex(color));
  }

  Future<void> resetColor(ColorSlot slot) async {
    _colors.remove(slot.key);
    notifyListeners();
    await _storage.delete(key: slot.key);
  }

  Future<void> resetAllColors() async {
    _colors.clear();
    notifyListeners();
    for (final slot in ColorSlots.all) {
      await _storage.delete(key: slot.key);
    }
  }

  Future<void> setTitleFont(PoppyFont v) async {
    if (_titleFont == v) return;
    _titleFont = v;
    notifyListeners();
    await _storage.write(key: StorageKeys.selectedTitleFont, value: v.name);
  }

  Future<void> setBodyFont(PoppyFont v) async {
    if (_bodyFont == v) return;
    _bodyFont = v;
    notifyListeners();
    await _storage.write(key: StorageKeys.selectedBodyFont, value: v.name);
  }

  // ── Helpers ──────────────────────────────────────────────

  String _colorToHex(Color c) => '#${(c.value & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0').toUpperCase()}';
  Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse(h.length == 6 ? 'FF$h' : h, radix: 16));
  }
}
