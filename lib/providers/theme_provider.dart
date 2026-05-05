import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/theme/themes.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Theme Provider
//  Location: lib/providers/theme_provider.dart
//
//  Persists the user's chosen flower theme across sessions
//  using flutter_secure_storage. Notifies the widget tree
//  whenever the theme changes so MaterialApp re-renders.
// ─────────────────────────────────────────────────────────────

class ThemeProvider extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();

  PoppyTheme _currentTheme = PoppyTheme.poppy;

  PoppyTheme get currentTheme => _currentTheme;

  PoppyThemeData get currentThemeData =>
      PoppyThemes.fromId(_currentTheme);

  ThemeProvider() {
    _loadSavedTheme();
  }

  // ── Load persisted theme on startup ──────────────────────

  Future<void> _loadSavedTheme() async {
    try {
      final saved = await _storage.read(key: StorageKeys.selectedTheme);
      if (saved != null) {
        final match = PoppyTheme.values.firstWhere(
              (t) => t.name == saved,
          orElse: () => PoppyTheme.poppy,
        );
        _currentTheme = match;
        notifyListeners();
      }
    } catch (_) {
      // If storage fails just keep the default poppy theme
    }
  }

  // ── Change theme ──────────────────────────────────────────

  Future<void> setTheme(PoppyTheme theme) async {
    if (_currentTheme == theme) return;
    _currentTheme = theme;
    notifyListeners();
    await _storage.write(
      key: StorageKeys.selectedTheme,
      value: theme.name,
    );
  }
}