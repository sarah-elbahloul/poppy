import 'package:flutter/material.dart';
import 'package:poppy/core/app_routes.dart';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/error_messages.dart';
import 'package:poppy/core/style/style.dart';
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
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword    = true;
  bool _forgotPasswordMode = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onSignIn() async {
    // Client-side validation first
    final emailErr = AppErrors.validateEmail(_emailController.text);
    if (emailErr != null) {
      _showSnack(emailErr);
      return;
    }

    final auth = context.read<AuthProvider>();
    auth.clearError();

    final success = await auth.signIn(
      email:    _emailController.text,
      password: _passwordController.text,
    );

    // Navigation handled by _AuthListener in app.dart
    // No need to push here — sign-in triggers the auth stream
    // which _AuthListener watches and routes to home.
    if (!success && mounted && auth.errorMessage != null) {
      // Error already stored in provider — displayed in build()
    }
  }

  Future<void> _onResetPassword() async {
    final emailErr = AppErrors.validateEmail(_emailController.text);
    if (emailErr != null) {
      _showSnack(emailErr);
      return;
    }

    final auth = context.read<AuthProvider>();
    auth.clearError();

    final success =
    await auth.resetPassword(_emailController.text);
    if (success && mounted) {
      setState(() => _forgotPasswordMode = false);
      _showSnack('Check your email for a reset link.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final t    = context.poppyTheme;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: t.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xl),
              Center(child: const PoppyLogo(size: AppIconSize.logo)),
              const SizedBox(height: AppSpacing.md),
              Center(child: Text(kAppName,
                  style: AppTextStyles.displayLarge(t.textPrimary))),
              Center(child: Text(kAppTagline,
                  style: AppTextStyles.bodySmallSerif(t.textTertiary))),
              SizedBox(height: AppSpacing.xl * 1.5),
              Text(
                _forgotPasswordMode
                    ? 'Reset password'
                    : 'Welcome back',
                style: AppTextStyles.headlineSmall(t.textPrimary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _forgotPasswordMode
                    ? 'Enter your email and we\'ll send a reset link.'
                    : 'Sign in to your diary.',
                style: AppTextStyles.bodySmallSans(t.textTertiary),
              ),
              const SizedBox(height: AppSpacing.lg),
              _Field(
                controller:   _emailController,
                label:        'Email',
                keyboardType: TextInputType.emailAddress,
              ),
              if (!_forgotPasswordMode) ...[
                const SizedBox(height: AppSpacing.sm),
                _Field(
                  controller:  _passwordController,
                  label:       'Password',
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? AppIcons.visibilityOn
                          : AppIcons.visibilityOff,
                      size: AppIconSize.xs, color: t.textTertiary,
                    ),
                    onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ],

              // Error message — uses AppErrors for friendly text
              if (auth.errorMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                _ErrorBanner(
                  message: _forgotPasswordMode
                      ? AppErrors.resetPassword(auth.errorMessage!)
                      : AppErrors.signIn(auth.errorMessage!),
                ),
              ],

              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: auth.isLoading
                      ? null
                      : (_forgotPasswordMode
                      ? _onResetPassword
                      : _onSignIn),
                  style: FilledButton.styleFrom(
                    backgroundColor: t.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: auth.isLoading
                      ? const _LoadingIndicator()
                      : Text(
                    _forgotPasswordMode
                        ? 'Send reset link'
                        : 'Sign in',
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      context.read<AuthProvider>().clearError();
                      setState(() => _forgotPasswordMode =
                      !_forgotPasswordMode);
                    },
                    child: Text(
                      _forgotPasswordMode
                          ? 'Back to sign in'
                          : 'Forgot password?',
                      style: AppTextStyles.bodySmallSans(t.textTertiary),
                    ),
                  ),
                  if (!_forgotPasswordMode)
                    TextButton(
                      onPressed: () => Navigator.of(context)
                          .pushNamed(AppRoutes.register),
                      child: Text('Create account',
                          style: AppTextStyles.bodySmallSans(t.accent)),
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

// ── Shared private widgets ─────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  const _Field({
    required this.controller, required this.label,
    this.obscureText = false, this.keyboardType, this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: t.border, width: AppStroke.hairline),
      ),
      child: TextField(
        controller: controller, obscureText: obscureText,
        keyboardType: keyboardType,
        style: AppTextStyles.bodyMedium(t.textPrimary),
        decoration: InputDecoration(
          labelText:  label,
          labelStyle: AppTextStyles.bodySmallSans(t.textTertiary),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.md,
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: t.accentLight,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
            color: t.accent.withOpacity(0.3), width: AppStroke.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AppIcons.info, size: AppIconSize.xs, color: t.accent),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message,
              style: AppTextStyles.bodySmallSans(t.accent))),
        ],
      ),
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 18, height: 18,
    child: CircularProgressIndicator(
        strokeWidth: 2, color: Colors.white),
  );
}