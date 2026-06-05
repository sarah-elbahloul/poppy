// ─────────────────────────────────────────────────────────────
//  Flutter Splash Screen
//  Shown while AuthProvider resolves the session.
//  Matches the native OS splash so there is no visual jump.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:poppy/core/core.dart';
import 'package:provider/provider.dart';
import 'package:poppy/providers/theme_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>().currentThemeData;

    return Scaffold(
      backgroundColor: t.background,
      body: FadeTransition(
        opacity: _fade,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PoppyLogo(
                size:       96,
                background: t.accentLight,
              ),
              const SizedBox(height: 24),
              Text(
                kAppName.toLowerCase(),
                style: GoogleFonts.lora(
                  fontSize:      28,
                  color:         t.textPrimary,
                  fontWeight:    FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                kAppTagline,
                style: GoogleFonts.lora(
                  fontSize:      13,
                  color:         t.textTertiary,
                  fontStyle:     FontStyle.italic,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}