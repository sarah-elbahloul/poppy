import 'package:flutter/material.dart';
import 'package:poppy/providers/providers.dart';
import 'package:poppy/screens/screens.dart';
import 'package:poppy/core/core.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Root App Widget
//  Location: lib/app.dart
//
//  Navigation is driven EXCLUSIVELY by _RootRouter watching
//  AuthProvider.status. There is no secondary _AuthListener.
//  Having two navigation drivers caused races and blank screens.
//
//  Auth status → screen:
//    unknown          → blank (initialising)
//    unauthenticated  → LoginScreen
//    passwordRecovery → SetNewPasswordScreen
//    authenticated    → HomeScreen (or LockScreen if PIN set)
// ─────────────────────────────────────────────────────────────

class PoppyApp extends StatelessWidget {
  const PoppyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, AuthProvider>(
      builder: (context, themeProvider, auth, _) {
        // While checking the session, show a blank splash so there
        // is no flicker before we know where to send the user.
        if (auth.status == AuthStatus.unknown) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: themeProvider.currentThemeData.toThemeData(),
            home: const SplashScreen(),
          );
        }

        return MaterialApp(
          title:                     'Poppy',
          debugShowCheckedModeBanner: false,
          theme:                     themeProvider.currentThemeData.toThemeData(),
          // _RootRouter is the single source of truth for top-level
          // navigation. All other routes are used by screens that
          // push on top of the root (settings, write, etc.).
          home: const _RootRouter(),
          routes: {
            AppRoutes.login:           (_) => const LoginScreen(),
            AppRoutes.register:        (_) => const RegisterScreen(),
            AppRoutes.lock:            (_) => const LockScreen(),
            AppRoutes.home:            (_) => const HomeScreen(),
            AppRoutes.settings:        (_) => const SettingsScreen(),
            AppRoutes.settingsDrawer:  (_) => const SettingsDrawer(),
            AppRoutes.appearance:      (_) => const AppearanceScreen(),
            AppRoutes.account:         (_) => const AccountScreen(),
            AppRoutes.security:        (_) => const SecurityScreen(),
            AppRoutes.notifications:   (_) => const NotificationsScreen(),
            AppRoutes.about:           (_) => const AboutScreen(),
            AppRoutes.legalPrivacy:    (_) => const LegalScreen(doc: LegalDoc.privacy),
            AppRoutes.legalTerms:      (_) => const LegalScreen(doc: LegalDoc.terms),
            AppRoutes.legalOpensource: (_) => const LegalScreen(doc: LegalDoc.opensource),
          },
          onGenerateRoute: (settings) {
            if (settings.name == AppRoutes.write) {
              final entryId = settings.arguments as String?;
              return MaterialPageRoute(
                builder:  (_) => WriteScreen(entryId: entryId),
                settings: settings,
              );
            }
            return null;
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  _RootRouter
//
//  Watches AuthProvider and returns the correct widget for the
//  current auth state. This is a pure function of auth.status —
//  no imperative navigation, no pushNamed, no races.
//
//  When auth.status changes, Consumer rebuilds this widget and
//  Flutter swaps the tree. Clean, predictable, no side-effects.
// ─────────────────────────────────────────────────────────────

class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    switch (auth.status) {
      case AuthStatus.unknown:
        return const Scaffold(body: SizedBox());

      case AuthStatus.unauthenticated:
        return const LoginScreen();

      case AuthStatus.passwordRecovery:
        return const SetNewPasswordScreen();

      case AuthStatus.authenticated:
        if (auth.pinEnabled && auth.isLocked) {
          return const LockScreen();
        }
        return const HomeScreen();
    }
  }
}
