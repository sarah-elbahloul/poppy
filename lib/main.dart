import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:poppy/app.dart';
import 'package:poppy/core/supabase_client.dart';
import 'package:poppy/providers/providers.dart';
import 'package:poppy/services/services.dart';
import 'package:provider/provider.dart';

/// Poppy application entry point.
///
/// Responsible for initializing core services, setting system-wide configurations,
/// and launching the [MultiProvider] root.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock device orientation to portrait for a consistent UI experience.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Configure system UI overlay style.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize infrastructure and persistence layers.
  await SupabaseConfig.init();
  await NotificationService.init();
  // Local SQLite database initialization must complete before service access.
  await LocalDbService.instance.init();

  // Load font + color preferences before the first frame is drawn.
  final themeProvider = await ThemeProvider.initialise();

  // Pre-warm the default font pair so no FOUT occurs on the first frame.
  // GoogleFonts.pendingFonts() downloads/caches the font files eagerly;
  // subsequent TextStyle lookups are then synchronous.
  final fp = themeProvider.currentFontPairData;
  await GoogleFonts.pendingFonts([
    fp.titleFont.style(Colors.black, size: 16),
    fp.bodyFont.style(Colors.black, size: 16),
  ]);

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