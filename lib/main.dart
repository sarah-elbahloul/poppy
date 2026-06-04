import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:poppy/app.dart';
import 'package:poppy/core/supabase_client.dart';
import 'package:poppy/providers/providers.dart';
import 'package:poppy/services/services.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Entry Point
//  Location: lib/main.dart
// ─────────────────────────────────────────────────────────────

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor:           Colors.transparent,
      statusBarIconBrightness:  Brightness.dark,
    ),
  );

  await SupabaseConfig.init();
  await NotificationService.init();

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