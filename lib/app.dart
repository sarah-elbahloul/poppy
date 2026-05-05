import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:poppy/core/supabase_client.dart';
import 'package:poppy/providers/auth_provider.dart';
import 'package:poppy/providers/theme_provider.dart';
import 'package:poppy/screens/auth/login_screen.dart';
import 'package:poppy/screens/auth/register_screen.dart';
import 'package:poppy/screens/entry_detail/entry_detail_screen.dart';
import 'package:poppy/screens/home/home_screen.dart';
import 'package:poppy/screens/lock_screen.dart';
import 'package:poppy/screens/search/search_screen.dart';
import 'package:poppy/screens/settings/account_screen.dart';
import 'package:poppy/screens/settings/appearance_screen.dart';
import 'package:poppy/screens/settings/security_screen.dart';
import 'package:poppy/screens/settings/settings_screen.dart';
import 'package:poppy/screens/write/write_screen.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Root App Widget
//  Location: lib/app.dart
//
//  Owns the router and connects the ThemeProvider so the
//  entire widget tree re-themes when the user switches
//  flower themes in settings.
// ─────────────────────────────────────────────────────────────

class PoppyApp extends StatefulWidget {
  const PoppyApp({super.key});

  @override
  State<PoppyApp> createState() => _PoppyAppState();
}

class _PoppyAppState extends State<PoppyApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = _buildRouter();
  }

  GoRouter _buildRouter() {
    return GoRouter(
      initialLocation: '/home',
      debugLogDiagnostics: true,

      // ── Redirect logic ───────────────────────────────────
      // Runs before every navigation. Decides where the user
      // actually ends up based on auth + lock state.
      redirect: (context, state) async {
        final auth = context.read<AuthProvider>();
        final isLoggedIn = SupabaseConfig.currentUser != null;
        final isLocked = auth.isLocked;
        final loc = state.matchedLocation;

        // Not logged in → always go to login
        if (!isLoggedIn) {
          if (loc == '/login' || loc == '/register') return null;
          return '/login';
        }

        // Logged in but app is locked → go to lock screen
        if (isLocked && loc != '/lock') return '/lock';

        // Logged in + unlocked, but trying to visit auth screens → go home
        if (loc == '/login' || loc == '/register') return '/home';

        return null; // no redirect needed
      },

      // ── Routes ───────────────────────────────────────────
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/lock',
          builder: (context, state) => const LockScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/write',
          builder: (context, state) {
            // Pass an existing entry id when editing, null when creating
            final entryId = state.uri.queryParameters['entryId'];
            return WriteScreen(entryId: entryId);
          },
        ),
        GoRoute(
          path: '/entry/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return EntryDetailScreen(entryId: id);
          },
        ),
        GoRoute(
          path: '/search',
          builder: (context, state) => const SearchScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
          routes: [
            GoRoute(
              path: 'appearance',
              builder: (context, state) => const AppearanceScreen(),
            ),
            GoRoute(
              path: 'account',
              builder: (context, state) => const AccountScreen(),
            ),
            GoRoute(
              path: 'security',
              builder: (context, state) => const SecurityScreen(),
            ),
          ],
        ),
      ],

      // ── Error screen ─────────────────────────────────────
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: Text(
            'Page not found\n${state.error}',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild the MaterialApp whenever the theme changes
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp.router(
          title: 'Poppy',
          debugShowCheckedModeBanner: false,
          theme: themeProvider.currentThemeData.toThemeData(),
          routerConfig: _router,
        );
      },
    );
  }
}