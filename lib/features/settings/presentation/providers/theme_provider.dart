import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:poppy/core/core.dart';
import 'package:poppy/features/journal/data/models/entry_tag.dart';
import 'package:poppy/features/auth/data/models/profile.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Theme Provider
// ─────────────────────────────────────────────────────────────

class ColorSlot {
  final String key;
  final String label;
  final String description;
  final Color defaultValue;
  final String jsonKey;

  const ColorSlot({
    required this.key,
    required this.label,
    required this.description,
    required this.defaultValue,
    required this.jsonKey,
  });
}

class ColorSlots {
  ColorSlots._();

  static const accent = ColorSlot(
    key: StorageKeys.colorAccent,
    label: 'Accent',
    description: 'Buttons, FAB, and selected icons',
    defaultValue: AppColors.accent,
    jsonKey: 'colorAccent',
  );
  static const accentLight = ColorSlot(
    key: StorageKeys.colorAccentLight,
    label: 'Highlight',
    description: 'Card headers and tag backgrounds',
    defaultValue: AppColors.accentLight,
    jsonKey: 'colorAccentLight',
  );
  static const accentMuted = ColorSlot(
    key: StorageKeys.colorAccentMuted,
    label: 'Muted',
    description: 'Secondary icons and pill chips',
    defaultValue: AppColors.accentMuted,
    jsonKey: 'colorAccentMuted',
  );
  static const surface = ColorSlot(
    key: StorageKeys.colorSurface,
    label: 'Surface',
    description: 'Cards and input field backgrounds',
    defaultValue: AppColors.surface,
    jsonKey: 'colorSurface',
  );
  static const background = ColorSlot(
    key: StorageKeys.colorBackground,
    label: 'Background',
    description: 'Main screen background',
    defaultValue: AppColors.background,
    jsonKey: 'colorBackground',
  );
  static const textPrimary = ColorSlot(
    key: StorageKeys.colorTextPrimary,
    label: 'Text',
    description: 'Primary headings and body text',
    defaultValue: AppColors.textPrimary,
    jsonKey: 'colorTextPrimary',
  );
  static const textSecondary = ColorSlot(
    key: StorageKeys.colorTextSecondary,
    label: 'Subtext',
    description: 'Labels and subtitles',
    defaultValue: AppColors.textSecondary,
    jsonKey: 'colorTextSecondary',
  );
  static const textTertiary = ColorSlot(
    key: StorageKeys.colorTextTertiary,
    label: 'Hint',
    description: 'Placeholders and timestamps',
    defaultValue: AppColors.textTertiary,
    jsonKey: 'colorTextTertiary',
  );
  static const border = ColorSlot(
    key: StorageKeys.colorBorder,
    label: 'Border',
    description: 'Card outlines and dividers',
    defaultValue: AppColors.border,
    jsonKey: 'colorBorder',
  );

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

class ThemeProvider extends ChangeNotifier {
  ThemeProvider._();

  final _storage = const FlutterSecureStorage();

  /// Only stores colors that differ from the default.
  final Map<String, Color> _colors = {};

  PoppyFont _titleFont = PoppyFont.literata;
  PoppyFont _bodyFont = PoppyFont.inter;

  List<TagColorData> _tagColors = EntryTags.defaults;

  static Future<ThemeProvider> initialise() async {
    final provider = ThemeProvider._();
    await provider._loadAll();
    return provider;
  }

  Color colorFor(ColorSlot slot) => _colors[slot.key] ?? slot.defaultValue;

  /// True only if the color differs from the hardcoded default.
  bool isCustomized(ColorSlot slot) {
    final color = _colors[slot.key];
    if (color == null) return false;
    return color != slot.defaultValue;
  }

  bool get hasAnyCustomColor => ColorSlots.all.any(isCustomized);

  PoppyFont get currentTitleFont => _titleFont;
  PoppyFont get currentBodyFont => _bodyFont;
  List<TagColorData> get tagColors => _tagColors;

  FontPairData get currentFontPairData =>
      FontPairData(PoppyFonts.fromId(_titleFont), PoppyFonts.fromId(_bodyFont));

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
    fontPair: currentFontPairData,
  );

  /// All current colours as ARGB32 integers
  Map<String, int> get themeColorsJson {
    return {
      for (final slot in ColorSlots.all)
        slot.jsonKey: colorFor(slot).toARGB32(),
    };
  }

  Future<void> _loadAll() async {
    try {
      final futures = {
        for (final slot in ColorSlots.all)
          slot.key: _storage.read(key: slot.key),
        StorageKeys.selectedTitleFont:
        _storage.read(key: StorageKeys.selectedTitleFont),
        StorageKeys.selectedBodyFont:
        _storage.read(key: StorageKeys.selectedBodyFont),
        StorageKeys.entryTags: _storage.read(key: StorageKeys.entryTags),
      };

      final results = await Future.wait(futures.values);

      final map = <String, String?>{};
      var i = 0;
      for (final key in futures.keys) {
        map[key] = results[i++];
      }

      // Only store colors that differ from default
      for (final slot in ColorSlots.all) {
        final hex = map[slot.key];
        if (hex != null) {
          final color = _hexToColor(hex);
          if (color != slot.defaultValue) {
            _colors[slot.key] = color;
          } else {
            await _storage.delete(key: slot.key);
          }
        }
      }

      final tf = map[StorageKeys.selectedTitleFont];
      final bf = map[StorageKeys.selectedBodyFont];

      if (tf != null) {
        _titleFont = PoppyFont.values.firstWhere(
              (f) => f.name == tf,
          orElse: () => PoppyFont.lora,
        );
      }

      if (bf != null) {
        _bodyFont = PoppyFont.values.firstWhere(
              (f) => f.name == bf,
          orElse: () => PoppyFont.inter,
        );
      }

      final tagsJson = map[StorageKeys.entryTags];
      if (tagsJson != null) {
        final List decoded = jsonDecode(tagsJson);
        _tagColors = decoded.map((m) => TagColorData.fromMap(m)).toList();
        EntryTags.updateRegistry(_tagColors);
      }
    } catch (_) {}

    if (hasListeners) notifyListeners();
  }

  /// Set a colour. If it matches the default, it's treated as a reset.
  Future<void> setColor(ColorSlot slot, Color color) async {
    if (color == slot.defaultValue) {
      await resetColor(slot);
      return;
    }
    _colors[slot.key] = color;
    notifyListeners();
    await _storage.write(key: slot.key, value: _colorToHex(color));
  }

  Future<void> resetColor(ColorSlot slot) async {
    if (!_colors.containsKey(slot.key)) return;
    _colors.remove(slot.key);
    notifyListeners();
    await _storage.delete(key: slot.key);
  }

  Future<void> resetAllColors() async {
    if (_colors.isEmpty) return;
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

  Future<void> setTagColors(List<TagColorData> tags, {bool persist = true}) async {
    if (_tagColors.length == tags.length &&
        _tagColors.asMap().entries.every((e) => e.value.isSameAs(tags[e.key]))) {
      return;
    }
    _tagColors = tags;
    EntryTags.updateRegistry(tags);
    notifyListeners();
    if (persist) {
      final json = jsonEncode(tags.map((t) => t.toMap()).toList());
      await _storage.write(key: StorageKeys.entryTags, value: json);
    }
  }

  /// Apply profile from remote — called ONCE on sign-in.
  Future<void> applyProfile(Profile profile) async {
    bool changed = false;

    if (_titleFont != profile.fontTitle) {
      _titleFont = profile.fontTitle;
      await _storage.write(
          key: StorageKeys.selectedTitleFont, value: _titleFont.name);
      changed = true;
    }
    if (_bodyFont != profile.fontBody) {
      _bodyFont = profile.fontBody;
      await _storage.write(
          key: StorageKeys.selectedBodyFont, value: _bodyFont.name);
      changed = true;
    }

    final colorMap = {
      ColorSlots.accent: profile.colorAccent,
      ColorSlots.accentLight: profile.colorAccentLight,
      ColorSlots.accentMuted: profile.colorAccentMuted,
      ColorSlots.surface: profile.colorSurface,
      ColorSlots.background: profile.colorBackground,
      ColorSlots.textPrimary: profile.colorTextPrimary,
      ColorSlots.textSecondary: profile.colorTextSecondary,
      ColorSlots.textTertiary: profile.colorTextTertiary,
      ColorSlots.border: profile.colorBorder,
    };

    for (final entry in colorMap.entries) {
      final slot = entry.key;
      final dbColor = entry.value;
      final isDefault = dbColor == slot.defaultValue;

      if (isDefault) {
        if (_colors.containsKey(slot.key)) {
          _colors.remove(slot.key);
          await _storage.delete(key: slot.key);
          changed = true;
        }
      } else {
        final localColor = _colors[slot.key] ?? slot.defaultValue;
        if (localColor != dbColor) {
          _colors[slot.key] = dbColor;
          await _storage.write(key: slot.key, value: _colorToHex(dbColor));
          changed = true;
        }
      }
    }

    if (!(_tagColors.length == profile.tags.length &&
        _tagColors.asMap().entries.every((e) => e.value.isSameAs(profile.tags[e.key])))) {
      _tagColors = List.from(profile.tags);
      EntryTags.updateRegistry(_tagColors);
      final json = jsonEncode(_tagColors.map((t) => t.toMap()).toList());
      await _storage.write(key: StorageKeys.entryTags, value: json);
      changed = true;
    }

    if (changed) notifyListeners();
  }

  /// Push current theme to remote profile.
  Future<bool> pushTheme(
      Future<void> Function(Map<String, dynamic> data) save,
      ) async {
    try {
      final themeMap = {
        DBColumn.fontTitle: _titleFont.name,
        DBColumn.fontBody: _bodyFont.name,
        DBColumn.themeColors: themeColorsJson,
        DBColumn.tags: _tagColors.map((t) => t.toMap()).toList(),
      };
      await save(themeMap);
      return true;
    } catch (e) {
      debugPrint('Failed to push theme to remote profile: $e');
      return false;
    }
  }

  Future<bool> pushTagColors(Future<void> Function(Map<String, dynamic> data) save,) => pushTheme(save);

  String _colorToHex(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

  Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    final val = int.parse(h.length == 6 ? 'FF$h' : h, radix: 16);
    return Color(val);
  }
}