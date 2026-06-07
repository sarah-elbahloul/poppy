import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
