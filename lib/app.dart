import 'package:flutter/material.dart';
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
import 'package:poppy/screens/settings/security_screen.dart';
import 'package:poppy/screens/settings/settings_screen.dart';
import 'package:poppy/screens/settings/legal_screen.dart';
import 'package:poppy/screens/write/write_screen.dart';
import 'package:provider/provider.dart';

class PoppyApp extends StatelessWidget {
  const PoppyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          title: 'Poppy',
          debugShowCheckedModeBanner: false,
          theme: themeProvider.currentThemeData.toThemeData(),
          home: const AuthWrapper(),
          onGenerateRoute: AppRoutes.onGenerateRoute,
        );
      },
    );
  }
}

/// A wrapper that decides which screen to show based on auth and lock state.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final isLoggedIn = SupabaseConfig.currentUser != null;
        if (!isLoggedIn) return const LoginScreen();
        if (auth.isLocked) return const LockScreen();
        return const HomeScreen();
      },
    );
  }
}

class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const lock = '/lock';
  static const home = '/home';
  static const write = '/write';
  static const search = '/search';
  static const settings = '/settings';
  static const appearance = '/settings/appearance';
  static const account = '/settings/account';
  static const security = '/settings/security';
  static const legalPrivacy = '/settings/legal/privacy';
  static const legalTerms = '/settings/legal/terms';
  static const legalOpensource = '/settings/legal/opensource';

  static Route<dynamic> onGenerateRoute(RouteSettings setting) {
    switch (setting.name) {
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case lock:
        return MaterialPageRoute(builder: (_) => const LockScreen());
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case write:
        final entryId = setting.arguments as String?;
        return MaterialPageRoute(builder: (_) => WriteScreen(entryId: entryId));
      case search:
        return MaterialPageRoute(builder: (_) => const SearchScreen());
      case settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case appearance:
        return MaterialPageRoute(builder: (_) => const AppearanceScreen());
      case account:
        return MaterialPageRoute(builder: (_) => const AccountScreen());
      case security:
        return MaterialPageRoute(builder: (_) => const SecurityScreen());
      case legalPrivacy:
        return MaterialPageRoute(builder: (_) => const LegalScreen(doc: LegalDoc.privacy));
      case legalTerms:
        return MaterialPageRoute(builder: (_) => const LegalScreen(doc: LegalDoc.terms));
      case legalOpensource:
        return MaterialPageRoute(builder: (_) => const LegalScreen(doc: LegalDoc.opensource));
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('No route defined for ${setting.name}')),
          ),
        );
    }
  }
}
