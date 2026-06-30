import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:poppy/app.dart';
import 'package:poppy/core/core.dart';
import 'package:poppy/features/auth/auth.dart';
import 'package:poppy/features/journal/presentation/providers/entries_provider.dart';
import 'package:poppy/features/settings/presentation/providers/theme_provider.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Entry Point
//  Location: lib/main.dart
// ─────────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. System Configuration
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // 2. Core Infrastructure Initialization
  await SupabaseConfig.init();
  await NotificationService.init();
  
  // Local SQLite database must be ready before any provider initialization.
  await LocalDbService.instance.init();

  // 3. Pre-warm User Preferences
  final themeProvider = await ThemeProvider.initialise();

  // Pre-warm the default font pair.
  final fp = themeProvider.currentFontPairData;
  await GoogleFonts.pendingFonts([
    fp.titleFont.style(Colors.black, size: 16),
    fp.bodyFont.style(Colors.black, size: 16),
  ]);

  // 4. Run Application
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => themeProvider),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => EntriesProvider()),
      ],
      child: const PoppyApp(),
    ),
  );
}
