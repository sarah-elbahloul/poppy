import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:poppy/app.dart';
import 'package:poppy/core/supabase_client.dart';
import 'package:poppy/providers/providers.dart';
import 'package:poppy/services/services.dart';
import 'package:provider/provider.dart';

/// Poppy — Entry Point
///
/// Sets up system-level configurations and initializes essential services
/// before running the app with global providers.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Restrict the app to portrait orientation.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set the default system UI overlay style.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize core services.
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
