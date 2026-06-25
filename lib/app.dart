import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:poppy/providers/providers.dart';
import 'package:poppy/screens/screens.dart';
import 'package:poppy/core/core.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Application Root
//  Location: lib/app.dart
// ─────────────────────────────────────────────────────────────

/// The root widget of the Poppy application.
///
/// Handles the top-level [MaterialApp] configuration, global theme application,
/// and authentication-based routing logic via [_RootRouter].
class PoppyApp extends StatefulWidget {
  const PoppyApp({super.key});

  @override
  State<PoppyApp> createState() => _PoppyAppState();
}

class _PoppyAppState extends State<PoppyApp> {
  bool _callbacksWired = false;

  /// Wire up AuthProvider lifecycle callbacks once the widget tree is ready.
  /// 
  /// We do this here to avoid circular constructor dependencies.
  /// It connects [AuthProvider] events to [ThemeProvider] and [EntriesProvider].
  void _wireCallbacks(AuthProvider auth, ThemeProvider themeProvider,
      EntriesProvider entries) {
    if (_callbacksWired) return;
    _callbacksWired = true;

    // On sign-in: Load user-specific personalization.
    auth.onSignedIn = () async {
      final profile = await auth.fetchProfile();
      await themeProvider.applyTagsFromProfile(profile);
      await auth.syncPinState(profile);
    };

    // On sign-out: Purge local memory for security.
    auth.onSignedOut = () {
      entries.clear();
    };
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<ThemeProvider, AuthProvider, EntriesProvider>(
      builder: (context, themeProvider, auth, entries, _) {
        _wireCallbacks(auth, themeProvider, entries);

        final theme = themeProvider.currentThemeData.toThemeData();

        // Ensure active fonts are warmed up for the current frame.
        GoogleFonts.pendingFonts([
          themeProvider.currentFontPairData.titleFont
              .style(Colors.black, size: 16),
          themeProvider.currentFontPairData.bodyFont
              .style(Colors.black, size: 16),
        ]);

        // Show a neutral background while determining the session state.
        if (auth.status == AuthStatus.unknown) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: Scaffold(
              backgroundColor: theme.scaffoldBackgroundColor,
            ),
          );
        }

        return MaterialApp(
          title: 'Poppy',
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: const _RootRouter(),
          routes: {
            AppRoutes.login: (_) => const LoginScreen(),
            AppRoutes.register: (_) => const RegisterScreen(),
            AppRoutes.lock: (_) => const LockScreen(),
            AppRoutes.setNewPassword: (_) => const SetNewPasswordScreen(),
            AppRoutes.home: (_) => const HomeScreen(),
            AppRoutes.settings: (_) => const SettingsScreen(),
            AppRoutes.settingsDrawer: (_) => const SettingsDrawer(),
            AppRoutes.appearance: (_) => const AppearanceScreen(),
            AppRoutes.tags: (_) => const EntryTagsScreen(),
            AppRoutes.account: (_) => const AccountScreen(),
            AppRoutes.security: (_) => const SecurityScreen(),
            AppRoutes.notifications: (_) => const NotificationsScreen(),
            AppRoutes.about: (_) => const AboutScreen(),
            AppRoutes.legalPrivacy: (_) => const LegalScreen(doc: LegalDoc.privacy),
            AppRoutes.legalTerms: (_) => const LegalScreen(doc: LegalDoc.terms),
            AppRoutes.legalOpensource: (_) => const LegalScreen(doc: LegalDoc.opensource),
          },
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
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Internal Router
// ─────────────────────────────────────────────────────────────

/// A router widget that determines the initial screen based on the
/// current authentication and security state.
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
        // Redirect to PIN lock screen if active and app is currently "locked".
        if (auth.pinEnabled && auth.isLocked) {
          return const LockScreen();
        }
        return const HomeScreen();
    }
  }
}
