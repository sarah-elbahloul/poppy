import 'package:flutter/material.dart';
import 'package:poppy/core/app_routes.dart';
import 'package:poppy/providers/auth_provider.dart';
import 'package:poppy/providers/theme_provider.dart';
import 'package:poppy/screens/auth/login_screen.dart';
import 'package:poppy/screens/auth/register_screen.dart';
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
//  Auth flow:
//  - AuthProvider listens to Supabase's auth stream.
//  - AuthProvider.status starts as AuthStatus.unknown while
//    the session is being checked.
//  - While unknown we show a blank splash so we never flash
//    the login screen before knowing the real state.
//  - Once status is known, MaterialApp mounts with the
//    correct initialRoute.
//  - After that, AuthProvider notifies on sign-in/out and
//    the _AuthListener widget pushes the right route.
//
//  Why NOT _AuthGuard with didChangeDependencies:
//  didChangeDependencies fires before the Supabase session
//  restore completes, causing a false "not logged in" check
//  that redirects to login even when the user is signed in.
// ─────────────────────────────────────────────────────────────

class PoppyApp extends StatelessWidget {
  const PoppyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, AuthProvider>(
      builder: (context, themeProvider, auth, _) {

        // ── Still checking session ──────────────────────────
        // Show a blank themed screen while Supabase restores
        // the session. This prevents flashing the login screen.
        if (auth.status == AuthStatus.unknown) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: themeProvider.currentThemeData.toThemeData(),
            home: Scaffold(
              backgroundColor: themeProvider.currentThemeData.background,
            ),
          );
        }

        // ── Session known — build the full app ──────────────
        final isLoggedIn = auth.isAuthenticated;
        final isLocked   = auth.isLocked;

        String initialRoute;
        if (!isLoggedIn) {
          initialRoute = AppRoutes.login;
        } else if (isLocked) {
          initialRoute = AppRoutes.lock;
        } else {
          initialRoute = AppRoutes.home;
        }

        return MaterialApp(
          title:                    'Poppy',
          debugShowCheckedModeBanner: false,
          theme:                    themeProvider.currentThemeData.toThemeData(),
          home: const _RootRouter(),
          routes: {
            AppRoutes.login:      (_) => const LoginScreen(),
            AppRoutes.register:   (_) => const RegisterScreen(),
            AppRoutes.lock:       (_) => const LockScreen(),
            AppRoutes.home:       (_) => const _AuthListener(child: HomeScreen()),
            AppRoutes.settings:   (_) => const SettingsScreen(),
            AppRoutes.settingsDrawer: (_) => const SettingsDrawer(),
            AppRoutes.appearance: (_) => const AppearanceScreen(),
            AppRoutes.account:    (_) => const AccountScreen(),
            AppRoutes.security:   (_) => const SecurityScreen(),
            AppRoutes.legalPrivacy: (_) => const LegalScreen(doc: LegalDoc.privacy),
            AppRoutes.legalTerms: (_) => const LegalScreen(doc: LegalDoc.terms),
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
//  Auth Listener
//  Wraps the home screen only. Listens to auth state changes
//  AFTER the app is fully mounted and redirects on sign-out
//  or lock. Does NOT run during initial session restore.
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

    // Only react to CHANGES, not the initial render
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
        nav.pushNamedAndRemoveUntil(
          AppRoutes.login, (route) => false,
        );
      } else if (status == AuthStatus.authenticated && locked) {
        nav.pushNamedAndRemoveUntil(
          AppRoutes.lock, (route) => false,
        );
      } else if (status == AuthStatus.authenticated && !locked) {
        nav.pushNamedAndRemoveUntil(
          AppRoutes.home, (route) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}


class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.status == AuthStatus.unknown) {
      return const Scaffold(body: SizedBox());
    }

    if (auth.status == AuthStatus.unauthenticated) {
      return const LoginScreen();
    }

    if (auth.isLocked) {
      return const LockScreen();
    }

    return const _AuthListener(child: HomeScreen());
  }
}