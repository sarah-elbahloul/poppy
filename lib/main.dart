import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:poppy/app.dart';
import 'package:poppy/core/supabase_client.dart';
import 'package:poppy/providers/auth_provider.dart';
import 'package:poppy/providers/entries_provider.dart';
import 'package:poppy/providers/theme_provider.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — App Entry Point
//  Location: lib/main.dart
// ─────────────────────────────────────────────────────────────

Future<void> main() async {
  // Must be called before any Flutter framework code
  WidgetsFlutterBinding.ensureInitialized();

  // Lock the app to portrait mode only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Make the status bar transparent so our backgrounds
  // bleed cleanly to the top edge on all themes
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Boot Supabase before the widget tree mounts
  await SupabaseConfig.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => EntriesProvider()),
      ],
      child: const PoppyApp(),
    ),
  );
}