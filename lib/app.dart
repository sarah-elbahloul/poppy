import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:poppy/providers/providers.dart';
import 'package:poppy/screens/screens.dart';
import 'package:poppy/core/core.dart';
import 'package:provider/provider.dart';

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
  /// We do this here so we have access to all sibling providers without
  /// introducing circular constructor dependencies.
  void _wireCallbacks(AuthProvider auth, ThemeProvider themeProvider,
      EntriesProvider entries) {
    if (_callbacksWired) return;
    _callbacksWired = true;

    // On sign-in: fetch the remote profile once, then hand each slice to
    // the provider that owns it. AuthProvider and ThemeProvider each stay
    // ignorant of the other's existence/type — app.dart is the only place
    // that wires sibling providers together.
    auth.onSignedIn = () async {
      final profile = await auth.fetchProfile();
      await themeProvider.applyTagsFromProfile(profile);
      await auth.syncPinState(profile);
    };

    // On sign-out: clear the entries cache so stale data is never shown to the
    // next user session (or after re-login).
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

        // Pre-load the active fonts so they are ready before the first frame
        // is painted.  GoogleFonts caches the result, so this is cheap on
        // subsequent builds.
        GoogleFonts.pendingFonts([
          themeProvider.currentFontPairData.titleFont
              .style(Colors.black, size: 16),
          themeProvider.currentFontPairData.bodyFont
              .style(Colors.black, size: 16),
        ]);

        // While checking the session, show a blank splash to avoid flickering.
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
      // If PIN protection is enabled and the app is locked, redirect to LockScreen.
        if (auth.pinEnabled && auth.isLocked) {
          return const LockScreen();
        }
        return const HomeScreen();
    }
  }
}