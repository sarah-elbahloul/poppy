import 'package:flutter/material.dart';
import 'package:poppy/providers/providers.dart';
import 'package:poppy/screens/screens.dart';
import 'package:poppy/core/core.dart';
import 'package:provider/provider.dart';

/// The root widget of the Poppy application.
///
/// Handles the top-level [MaterialApp] configuration, global theme application,
/// and authentication-based routing logic via [_RootRouter].
class PoppyApp extends StatelessWidget {
  const PoppyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, AuthProvider>(
      builder: (context, themeProvider, auth, _) {
        final theme = themeProvider.currentThemeData.toThemeData();

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
