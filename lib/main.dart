import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:poppy/app.dart';
import 'package:poppy/core/supabase_client.dart';
import 'package:poppy/providers/providers.dart';
import 'package:poppy/services/services.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Entry Point
//  Location: lib/main.dart
// ─────────────────────────────────────────────────────────────

/// The main entry point for the Poppy application.
///
/// This function is responsible for:
/// 1. Initializing Flutter bindings and system UI settings.
/// 2. Setting up core infrastructure (Supabase, Notifications, SQLite).
/// 3. Pre-loading user preferences and Warming up fonts.
/// 4. Launching the [MultiProvider] and the root [PoppyApp].
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
  // Load font + color preferences before the first frame is drawn to avoid UI jump.
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
