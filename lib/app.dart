import 'package:flutter/material.dart';
import 'package:poppy/core/app_routes.dart';
import 'package:poppy/core/supabase_client.dart';
import 'package:poppy/providers/auth_provider.dart';
import 'package:poppy/providers/theme_provider.dart';
import 'package:poppy/screens/auth/login_screen.dart';
import 'package:poppy/screens/auth/register_screen.dart';
import 'package:poppy/screens/home/home_screen.dart';
import 'package:poppy/screens/lock_screen.dart';
import 'package:poppy/screens/search/search_screen.dart';
import 'package:poppy/screens/settings/account_screen.dart';
import 'package:poppy/screens/settings/appearance_screen.dart';
import 'package:poppy/screens/settings/legal_screen.dart';
import 'package:poppy/screens/settings/security_screen.dart';
import 'package:poppy/screens/settings/settings_screen.dart';
import 'package:poppy/screens/write/write_screen.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Root App Widget
//  Location: lib/app.dart
//
//  Uses Flutter's built-in Navigator with named routes.
// ─────────────────────────────────────────────────────────────

final GlobalKey<NavigatorState> navigatorKey =
GlobalKey<NavigatorState>();

class PoppyApp extends StatelessWidget {
  const PoppyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Poppy',
          debugShowCheckedModeBanner: false,
          theme: themeProvider.currentThemeData.toThemeData(),

          // Start at home — auth guard redirects if needed
          initialRoute: AppRoutes.home,

          // ── Route definitions ──────────────────────────
          routes: {
            AppRoutes.login: (_) => const LoginScreen(),
            AppRoutes.register: (_) => const RegisterScreen(),
            AppRoutes.lock: (_) => const LockScreen(),
            AppRoutes.home: (_) => const HomeScreen(),
            AppRoutes.search: (_) => const SearchScreen(),
            AppRoutes.settings: (_) => const SettingsScreen(),
            AppRoutes.appearance: (_) => const AppearanceScreen(),
            AppRoutes.account: (_) => const AccountScreen(),
            AppRoutes.security: (_) => const SecurityScreen(),

            AppRoutes.legalPrivacy:
                (_) => const LegalScreen(doc: LegalDoc.privacy),

            AppRoutes.legalTerms:
                (_) => const LegalScreen(doc: LegalDoc.terms),

            AppRoutes.legalOpensource:
                (_) => const LegalScreen(doc: LegalDoc.opensource),
          },

          // ── Dynamic routes ─────────────────────────────
          onGenerateRoute: (settings) {
            if (settings.name == AppRoutes.write) {
              final entryId = settings.arguments as String?;

              return MaterialPageRoute(
                builder: (_) => WriteScreen(entryId: entryId),
                settings: settings,
              );
            }

            return null;
          },

          // ── Auth Guard ─────────────────────────────────
          builder: (context, child) {
            return _AuthGuard(
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Auth Guard
// ─────────────────────────────────────────────────────────────

class _AuthGuard extends StatefulWidget {
  final Widget child;

  const _AuthGuard({
    required this.child,
  });

  @override
  State<_AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<_AuthGuard> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _check();
      }
    });
  }

  void _check() {
    final auth = context.read<AuthProvider>();
    final isLoggedIn = SupabaseConfig.currentUser != null;

    final nav = navigatorKey.currentState;

    if (nav == null) return;

    final currentContext = nav.context;
    final currentRoute =
        ModalRoute.of(currentContext)?.settings.name;

    // ── Not logged in ────────────────────────────────
    if (!isLoggedIn &&
        currentRoute != AppRoutes.login) {
      nav.pushNamedAndRemoveUntil(
        AppRoutes.login,
            (route) => false,
      );

      return;
    }

    // ── Locked ───────────────────────────────────────
    if (auth.isLocked &&
        currentRoute != AppRoutes.lock) {
      nav.pushNamedAndRemoveUntil(
        AppRoutes.lock,
            (route) => false,
      );

      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild whenever auth state changes
    context.watch<AuthProvider>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _check();
      }
    });

    return widget.child;
  }
}