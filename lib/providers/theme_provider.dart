import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:poppy/core/core.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Theme Provider
//  Location: lib/providers/theme_provider.dart
// ─────────────────────────────────────────────────────────────

/// Represents a customizable color slot within the application's theme.
class ColorSlot {
  final String key;
  final String label;
  final String description;
  final Color defaultValue;

  const ColorSlot({
    required this.key,
    required this.label,
    required this.description,
    required this.defaultValue,
  });
}

/// Registry of all themeable color slots available in Poppy.
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

/// Manages application-wide theming, including custom colors, fonts, and tag palettes.
/// 
/// This provider handles:
/// - Loading and persisting theme overrides via [FlutterSecureStorage].
/// - Constructing the current [PoppyThemeData] and [FontPairData].
/// - Syncing user-defined tag colors with the remote profile.
class ThemeProvider extends ChangeNotifier {
  ThemeProvider._();

  final _storage = const FlutterSecureStorage();
  final Map<String, Color> _colors = {};

  PoppyFont _titleFont = PoppyFont.lora;
  PoppyFont _bodyFont = PoppyFont.inter;

  List<TagColorData> _tagColors = EntryTags.defaults;

  /// Asynchronously creates and initializes the [ThemeProvider] with persisted settings.
  static Future<ThemeProvider> initialise() async {
    final provider = ThemeProvider._();
    await provider._loadAll();
    return provider;
  }

  // ─────────────────────────────────────────────────────────────
  //  Getters
  // ─────────────────────────────────────────────────────────────

  Color colorFor(ColorSlot slot) => _colors[slot.key] ?? slot.defaultValue;
  bool isCustomized(ColorSlot slot) => _colors.containsKey(slot.key);
  bool get hasAnyCustomColor => ColorSlots.all.any(isCustomized);

  PoppyFont get currentTitleFont => _titleFont;
  PoppyFont get currentBodyFont => _bodyFont;
  List<TagColorData> get tagColors => _tagColors;

  /// Returns the combination of fonts currently selected by the user.
  FontPairData get currentFontPairData =>
      FontPairData(PoppyFonts.fromId(_titleFont), PoppyFonts.fromId(_bodyFont));

  /// Generates the active theme configuration based on defaults and user overrides.
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

  // ─────────────────────────────────────────────────────────────
  //  Loading & Initialization
  // ─────────────────────────────────────────────────────────────

  Future<void> _loadAll() async {
    try {
      final futures = {
        for (final slot in ColorSlots.all)
          slot.key: _storage.read(key: slot.key),
        StorageKeys.selectedTitleFont:
        _storage.read(key: StorageKeys.selectedTitleFont),
        StorageKeys.selectedBodyFont:
        _storage.read(key: StorageKeys.selectedBodyFont),
        StorageKeys.entryTags:
        _storage.read(key: StorageKeys.entryTags),
      };

      final results = await Future.wait(futures.values);

      final map = <String, String?>{};
      var i = 0;
      for (final key in futures.keys) {
        map[key] = results[i++];
      }

      // Load Colors
      for (final slot in ColorSlots.all) {
        final hex = map[slot.key];
        if (hex != null) {
          _colors[slot.key] = _hexToColor(hex);
        }
      }

      // Load Fonts
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

      // Load Tag Palette
      final tagsJson = map[StorageKeys.entryTags];
      if (tagsJson != null) {
        final List decoded = jsonDecode(tagsJson);
        _tagColors = decoded.map((m) => TagColorData.fromMap(m)).toList();
        EntryTags.updateRegistry(_tagColors);
      }
    } catch (_) {}

    if (hasListeners) notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────
  //  Color Customization
  // ─────────────────────────────────────────────────────────────

  /// Overrides a specific theme color and persists the change.
  Future<void> setColor(ColorSlot slot, Color color) async {
    _colors[slot.key] = color;
    notifyListeners();
    await _storage.write(key: slot.key, value: _colorToHex(color));
  }

  /// Reverts a specific theme color to its default value.
  Future<void> resetColor(ColorSlot slot) async {
    _colors.remove(slot.key);
    notifyListeners();
    await _storage.delete(key: slot.key);
  }

  /// Reverts all theme colors to their system defaults.
  Future<void> resetAllColors() async {
    _colors.clear();
    notifyListeners();
    for (final slot in ColorSlots.all) {
      await _storage.delete(key: slot.key);
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  Font Configuration
  // ─────────────────────────────────────────────────────────────

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

  // ─────────────────────────────────────────────────────────────
  //  Tag Management & Profile Sync
  // ─────────────────────────────────────────────────────────────

  /// Updates the global registry of entry tag colors.
  Future<void> setTagColors(List<TagColorData> tags, {bool persist = true}) async {
    _tagColors = tags;
    EntryTags.updateRegistry(tags);
    notifyListeners();
    if (persist) {
      final json = jsonEncode(tags.map((t) => t.toMap()).toList());
      await _storage.write(key: StorageKeys.entryTags, value: json);
    }
  }

  /// Applies tag colors found in a raw profile map (e.g. a Supabase 'profiles' row).
  Future<void> applyTagsFromProfile(Map<String, dynamic>? profile) async {
    final tagsJson = profile?[DBColumn.tags];
    if (tagsJson == null) return;
    final List decoded = tagsJson is String ? jsonDecode(tagsJson) : tagsJson;
    final tags = decoded.map((m) => TagColorData.fromMap(m)).toList();
    await setTagColors(tags, persist: true);
  }

  /// Pushes the current tag colors to a remote profile store via [save].
  Future<bool> pushTagColors(
      Future<void> Function(Map<String, dynamic> data) save,
      ) async {
    try {
      final tagsJson = _tagColors.map((t) => t.toMap()).toList();
      await save({DBColumn.tags: tagsJson});
      return true;
    } catch (e) {
      debugPrint('Failed to push tag colors to remote profile: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  Internal Helpers
  // ─────────────────────────────────────────────────────────────

  String _colorToHex(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

  Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    final val = int.parse(h.length == 6 ? 'FF$h' : h, radix: 16);
    return Color(val);
  }
}
