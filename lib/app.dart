import 'package:flutter/material.dart';
import 'package:poppy/core/app_routes.dart';
import 'package:poppy/providers/auth_provider.dart';
import 'package:poppy/providers/theme_provider.dart';
import 'package:poppy/screens/auth/login_screen.dart';
import 'package:poppy/screens/auth/register_screen.dart';
import 'package:poppy/screens/auth/set_new_password_screen.dart';
import 'package:poppy/screens/home/home_screen.dart';
import 'package:poppy/screens/lock_screen.dart';
import 'package:poppy/screens/settings/account_screen.dart';
import 'package:poppy/screens/settings/appearance_screen.dart';
import 'package:poppy/screens/settings/legal_screen.dart';
import 'package:poppy/screens/settings/security_screen.dart';
import 'package:poppy/screens/settings/settings_drawer.dart';
import 'package:poppy/screens/settings/settings_screen.dart';
import 'package:poppy/screens/write/write_screen.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Root App Widget
//  Location: lib/app.dart
//
//  Auth status → screen mapping:
//    unknown          → blank splash (checking session)
//    unauthenticated  → LoginScreen
//    authenticated    → HomeScreen (or LockScreen if PIN set)
//    passwordRecovery → SetNewPasswordScreen
//                       (user tapped Supabase reset email link)
// ─────────────────────────────────────────────────────────────

class PoppyApp extends StatelessWidget {
  const PoppyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, AuthProvider>(
      builder: (context, themeProvider, auth, _) {

        if (auth.status == AuthStatus.unknown) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: themeProvider.currentThemeData.toThemeData(),
            home: Scaffold(
              backgroundColor: themeProvider.currentThemeData.background,
            ),
          );
        }

        return MaterialApp(
          title:                     'Poppy',
          debugShowCheckedModeBanner: false,
          theme:                     themeProvider.currentThemeData.toThemeData(),
          home:                      const _RootRouter(),
          routes: {
            AppRoutes.login:      (_) => const LoginScreen(),
            AppRoutes.register:   (_) => const RegisterScreen(),
            AppRoutes.lock:       (_) => const LockScreen(),
            AppRoutes.setNewPassword:       (_) => const SetNewPasswordScreen(),
            AppRoutes.home:       (_) => const _AuthListener(child: HomeScreen()),
            AppRoutes.settings:   (_) => const SettingsScreen(),
            AppRoutes.settingsDrawer: (_) => const SettingsDrawer(),
            AppRoutes.appearance: (_) => const AppearanceScreen(),
            AppRoutes.account:    (_) => const AccountScreen(),
            AppRoutes.security:   (_) => const SecurityScreen(),
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
//  Root Router
//  Watches AuthStatus and renders the correct top-level screen.
//  This is the single source of truth for auth-driven navigation.
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
      // User tapped the Supabase reset email deep link.
      // Show the set-new-password screen — no navigation needed,
      // auth_provider.completePasswordReset() flips status to
      // authenticated which causes this widget to rebuild to HomeScreen.
        return const SetNewPasswordScreen();

      case AuthStatus.authenticated:
        if (auth.isLocked) return const LockScreen();
        return const _AuthListener(child: HomeScreen());
    }
  }
}

// ─────────────────────────────────────────────────────────────
//  Auth Listener
//  Wraps HomeScreen. Reacts to auth changes AFTER mount
//  (sign-out, lock) and redirects appropriately.
// ─────────────────────────────────────────────────────────────

class _AuthListener extends StatefulWidget {
  final Widget child;
  const _AuthListener({required this.child});

  @override
  State<_AuthListener> createState() => _AuthListenerState();
}

class _AuthListenerState extends State<_AuthListener> {
  AuthStatus? _lastStatus;
  bool?       _lastLocked;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth   = context.watch<AuthProvider>();
    final status = auth.status;
    final locked = auth.isLocked;

    if (_lastStatus == null) {
      _lastStatus = status;
      _lastLocked = locked;
      return;
    }

    final statusChanged = status != _lastStatus;
    final lockedChanged = locked != _lastLocked;
    _lastStatus = status;
    _lastLocked = locked;

    if (!statusChanged && !lockedChanged) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final nav = Navigator.of(context);
      if (status == AuthStatus.unauthenticated) {
        nav.pushNamedAndRemoveUntil(AppRoutes.login, (r) => false);
      } else if (status == AuthStatus.passwordRecovery) {
        // Reset email link tapped while home is shown — go to set-password
        nav.pushNamedAndRemoveUntil(AppRoutes.login, (r) => false);
      } else if (status == AuthStatus.authenticated && locked) {
        nav.pushNamedAndRemoveUntil(AppRoutes.lock, (r) => false);
      } else if (status == AuthStatus.authenticated && !locked) {
        nav.pushNamedAndRemoveUntil(AppRoutes.home, (r) => false);
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}