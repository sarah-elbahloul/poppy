import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:poppy/features/auth/auth.dart';
import 'package:poppy/features/journal/journal.dart';
import 'package:poppy/features/settings/settings.dart';
import 'package:poppy/core/core.dart';
import 'package:provider/provider.dart';

import 'features/auth/presentation/screens/security_screen.dart';

/// Application root widget.
class PoppyApp extends StatefulWidget {
  const PoppyApp({super.key});

  @override
  State<PoppyApp> createState() => _PoppyAppState();
}

class _PoppyAppState extends State<PoppyApp> {
  bool _callbacksWired = false;
  String? _lastAppliedProfileId;

  void _wireCallbacks(AuthProvider auth, ThemeProvider theme, EntriesProvider entries) {
    if (_callbacksWired) return;
    _callbacksWired = true;

    auth.onSignedIn = () async {
      if (auth.profile != null) {
        await theme.applyProfile(auth.profile!);
        _lastAppliedProfileId = auth.profile!.id;
      }
    };

    auth.onSignedOut = () {
      entries.clear();
      _lastAppliedProfileId = null;
    };
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<ThemeProvider, AuthProvider, EntriesProvider>(
      builder: (context, theme, auth, entries, _) {
        _wireCallbacks(auth, theme, entries);

        // Only apply profile ONCE on initial load, not on every rebuild
        if (auth.isAuthenticated &&
            auth.profile != null &&
            _lastAppliedProfileId == null) {
          _lastAppliedProfileId = auth.profile!.id;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            theme.applyProfile(auth.profile!);
          });
        }

        final themeData = theme.currentThemeData.toThemeData();

        GoogleFonts.pendingFonts([
          theme.currentFontPairData.titleFont.style(Colors.black, size: 16),
          theme.currentFontPairData.bodyFont.style(Colors.black, size: 16),
        ]);

        return MaterialApp(
          title: 'Poppy',
          debugShowCheckedModeBanner: false,
          theme: themeData,
          home: auth.status == AuthStatus.unknown
              ? Scaffold(backgroundColor: themeData.scaffoldBackgroundColor)
              : const _RootRouter(),
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

/// Determines initial screen based on auth and lock state.
class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return switch (auth.status) {
      AuthStatus.unknown => const Scaffold(body: SizedBox()),
      AuthStatus.restoringKey => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      AuthStatus.unauthenticated => const LoginScreen(),
      AuthStatus.passwordRecovery => const SetNewPasswordScreen(),
      AuthStatus.authenticated =>
      auth.isLocked ? const LockScreen() : const HomeScreen(),
    };
  }
}