import 'package:flutter/material.dart';
import 'package:poppy/providers/providers.dart';
import 'package:poppy/screens/screens.dart';
import 'package:poppy/core/core.dart';
import 'package:provider/provider.dart';

/// Poppy — Root App Widget
///
/// Navigation is managed by [_RootRouter] which responds to [AuthProvider.status].
/// This approach ensures a single source of truth for the authentication flow,
/// avoiding race conditions between multiple listeners.
///
/// Auth status mapping:
/// - [AuthStatus.unknown]          => Splash/Blank screen (initialising)
/// - [AuthStatus.unauthenticated]  => [LoginScreen]
/// - [AuthStatus.passwordRecovery] => [SetNewPasswordScreen]
/// - [AuthStatus.authenticated]    => [HomeScreen] (or [LockScreen] if PIN is enabled and locked)
class PoppyApp extends StatelessWidget {
  const PoppyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, AuthProvider>(
      builder: (context, themeProvider, auth, _) {
        // While checking the session, show a blank splash to avoid flickering.
        if (auth.status == AuthStatus.unknown) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: themeProvider.currentThemeData.toThemeData(),
            home: Scaffold(
              backgroundColor: themeProvider.currentThemeData.toThemeData().scaffoldBackgroundColor,
            ),
          );
        }

        return MaterialApp(
          title: 'Poppy',
          debugShowCheckedModeBanner: false,
          theme: themeProvider.currentThemeData.toThemeData(),
          // _RootRouter is the single source of truth for top-level navigation.
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

/// A router widget that watches [AuthProvider] and returns the appropriate 
/// screen based on the current authentication state.
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
