import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:poppy/core/core.dart';

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

class ThemeProvider extends ChangeNotifier {
  ThemeProvider._();

  final _storage = const FlutterSecureStorage();
  final Map<String, Color> _colors = {};

  PoppyFont _titleFont = PoppyFont.lora;
  PoppyFont _bodyFont = PoppyFont.inter;

  List<TagColorData> _tagColors = EntryTags.defaults;

  static Future<ThemeProvider> initialise() async {
    final provider = ThemeProvider._();
    await provider._loadAll();
    return provider;
  }

  Color colorFor(ColorSlot slot) => _colors[slot.key] ?? slot.defaultValue;
  bool isCustomized(ColorSlot slot) => _colors.containsKey(slot.key);
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
  );

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

      for (final slot in ColorSlots.all) {
        final hex = map[slot.key];
        if (hex != null) {
          _colors[slot.key] = _hexToColor(hex);
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

  Future<void> setTagColors(List<TagColorData> tags, {bool persist = true}) async {
    _tagColors = tags;
    EntryTags.updateRegistry(tags);
    notifyListeners();
    if (persist) {
      final json = jsonEncode(tags.map((t) => t.toMap()).toList());
      await _storage.write(key: StorageKeys.entryTags, value: json);
    }
  }

  // --- Remote profile sync ---
  //
  // These two methods are deliberately decoupled from any specific auth/
  // backend type. They take a raw profile map (or a save callback) rather
  // than a service instance, so ThemeProvider has zero compile-time
  // dependency on how the profile row is actually fetched/stored. This
  // makes the provider portable: dropping it into another project only
  // requires that project to supply *some* `Map<String, dynamic>` profile
  // representation with a 'tags' key — not a particular AuthService shape.

  /// Applies tag colors found in a raw profile map (e.g. a Supabase
  /// 'profiles' row) to local state, decoding from JSON if necessary.
  ///
  /// Pass the map returned by your backend's profile fetch. If the map has
  /// no 'tags' key, this is a no-op. Local state is always persisted so the
  /// device has an offline-available copy.
  Future<void> applyTagsFromProfile(Map<String, dynamic>? profile) async {
    final tagsJson = profile?[DBColumn.tags];
    if (tagsJson == null) return;
    final List decoded = tagsJson is String ? jsonDecode(tagsJson) : tagsJson;
    final tags = decoded.map((m) => TagColorData.fromMap(m)).toList();
    await setTagColors(tags, persist: true);
  }

  /// Pushes the current tag colors to a remote profile store via [save].
  ///
  /// [save] is any function that persists a partial profile update — e.g.
  /// `(data) => authService.updateProfile(data)`. Failures are caught and
  /// logged rather than thrown, matching the "best-effort background sync"
  /// behavior used elsewhere in the app; callers that need to know whether
  /// the push succeeded should inspect the returned bool.
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

  String _colorToHex(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

  Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    final val = int.parse(h.length == 6 ? 'FF$h' : h, radix: 16);
    return Color(val);
  }
}