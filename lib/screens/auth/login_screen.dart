import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/theme/themes.dart';
import 'package:poppy/core/widgets/poppy_logo.dart';
import 'package:poppy/providers/auth_provider.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Login Screen
//  Location: lib/screens/auth/login_screen.dart
// ─────────────────────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _forgotPasswordMode = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onSignIn() async {
    final auth = context.read<AuthProvider>();
    auth.clearError();

    final success = await auth.signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (success && mounted) context.go('/home');
  }

  Future<void> _onResetPassword() async {
    final auth = context.read<AuthProvider>();
    auth.clearError();

    final success = await auth.resetPassword(_emailController.text);
    if (success && mounted) {
      setState(() => _forgotPasswordMode = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Check your email for a reset link.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: t.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: kSpaceLG,
            vertical: kSpaceXL,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: kSpaceXL),

              // ── Logo ───────────────────────────────────────
              Center(child: const PoppyLogo(size: 52)),
              const SizedBox(height: kSpaceMD),
              Center(
                child: Text(
                  kAppName,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w500,
                    color: t.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              Center(
                child: Text(
                  kAppTagline,
                  style: TextStyle(
                    fontSize: 13,
                    color: t.textTertiary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

              const SizedBox(height: kSpaceXL * 1.5),

              // ── Screen title ───────────────────────────────
              Text(
                _forgotPasswordMode ? 'Reset password' : 'Welcome back',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: t.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: kSpaceXS),
              Text(
                _forgotPasswordMode
                    ? 'Enter your email and we\'ll send a reset link.'
                    : 'Sign in to your diary.',
                style: TextStyle(fontSize: 13, color: t.textTertiary),
              ),

              const SizedBox(height: kSpaceLG),

              // ── Email field ────────────────────────────────
              _Field(
                controller: _emailController,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
              ),

              if (!_forgotPasswordMode) ...[
                const SizedBox(height: kSpaceSM),

                // ── Password field ─────────────────────────
                _Field(
                  controller: _passwordController,
                  label: 'Password',
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                      color: t.textTertiary,
                    ),
                    onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                    ),
                  ),
                ),
              ],

              // ── Error message ──────────────────────────────
              if (auth.errorMessage != null) ...[
                const SizedBox(height: kSpaceMD),
                Text(
                  auth.errorMessage!,
                  style: TextStyle(fontSize: 13, color: t.accent),
                ),
              ],

              const SizedBox(height: kSpaceLG),

              // ── Primary action button ──────────────────────
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: auth.isLoading
                      ? null
                      : (_forgotPasswordMode ? _onResetPassword : _onSignIn),
                  style: FilledButton.styleFrom(
                    backgroundColor: t.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(kRadiusMD),
                    ),
                  ),
                  child: auth.isLoading
                      ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : Text(
                    _forgotPasswordMode ? 'Send reset link' : 'Sign in',
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ),

              const SizedBox(height: kSpaceMD),

              // ── Secondary links ────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => setState(
                          () => _forgotPasswordMode = !_forgotPasswordMode,
                    ),
                    child: Text(
                      _forgotPasswordMode ? 'Back to sign in' : 'Forgot password?',
                      style: TextStyle(
                        fontSize: 13,
                        color: t.textTertiary,
                      ),
                    ),
                  ),
                  if (!_forgotPasswordMode)
                    TextButton(
                      onPressed: () => context.go('/register'),
                      child: Text(
                        'Create account',
                        style: TextStyle(
                          fontSize: 13,
                          color: t.accent,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Reusable text field ────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;

  const _Field({
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;

    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(kRadiusMD),
        border: Border.all(color: t.border, width: 0.5),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: TextStyle(fontSize: 15, color: t.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 13, color: t.textTertiary),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: kSpaceMD,
            vertical: kSpaceMD,
          ),
        ),
      ),
    );
  }
}