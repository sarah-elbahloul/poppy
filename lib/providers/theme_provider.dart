import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/style/style.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Theme Provider
//  Location: lib/providers/theme_provider.dart
// ─────────────────────────────────────────────────────────────

class ThemeProvider extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();

  PoppyTheme _currentTheme = PoppyTheme.poppy;

  PoppyTheme get currentTheme => _currentTheme;
  PoppyThemeData get currentThemeData => PoppyThemes.fromId(_currentTheme);

  ThemeProvider() {
    _loadSavedTheme();
  }

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
    } catch (_) {}
  }

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