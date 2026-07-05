import 'dart:async';

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
  //
  // SupabaseConfig.init(), LocalDbService.instance.init(), and
  // ThemeProvider.initialise() don't depend on each other's results, so
  // they run concurrently instead of one after another — total wait time
  // becomes roughly the slowest of the three instead of the sum of all
  // three.
  //
  // NotificationService.init() is deliberately NOT in this batch. Nothing
  // on the very first screen (Login/Lock) touches notifications, and
  // nothing else in this file depends on it being ready synchronously — so
  // it's fired off in the background instead of blocking startup. By the
  // time a user reaches Settings to toggle reminders, it will have long
  // since finished.
  unawaited(NotificationService.init());

  final initResults = await Future.wait([
    SupabaseConfig.init(),
    LocalDbService.instance.init(),
    ThemeProvider.initialise(),
  ]);
  final themeProvider = initResults[2] as ThemeProvider;

  // 3. Pre-warm the font pair actually used in the UI
  // (regular for body text, bold/w600 for headlines and titles), plus the
  // hardcoded Literata w700 used for branding on the Login/Lock screens.
  // Missing any of these causes a visible flash: the text renders in the
  // fallback system font for a frame until Google Fonts finishes fetching
  // that specific family+weight, then swaps.
  final fp = themeProvider.currentFontPairData;
  await GoogleFonts.pendingFonts([
    fp.titleFont.style(Colors.black, size: 16),
    fp.titleFont.bold(Colors.black, size: 16),
    fp.bodyFont.style(Colors.black, size: 16),
    GoogleFonts.literata(fontWeight: FontWeight.w700),
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