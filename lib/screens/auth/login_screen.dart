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
//
//  Two modes (toggled inline):
//
//    normal  — email + password → signIn()
//
//    forgot  — email only → sendPasswordResetEmail()
//              Supabase sends a magic link. User taps it,
//              app receives AuthChangeEvent.passwordRecovery,
//              _RootRouter shows SetNewPasswordScreen.
//              No recovery code. No step 2 in this screen.
// ─────────────────────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _forgotMode = false;

  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword     = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Actions ───────────────────────────────────────────────

  Future<void> _onSignIn() async {
    final emailErr = AppErrors.validateEmail(_emailController.text);
    if (emailErr != null) { _showSnack(emailErr); return; }
    final auth = context.read<AuthProvider>();
    auth.clearError();
    await auth.signIn(
      email:    _emailController.text,
      password: _passwordController.text,
    );
    // Navigation handled by _RootRouter watching auth.status
  }

  Future<void> _onSendResetEmail() async {
    final emailErr = AppErrors.validateEmail(_emailController.text);
    if (emailErr != null) { _showSnack(emailErr); return; }
    final auth = context.read<AuthProvider>();
    auth.clearError();
    final ok = await auth.sendPasswordResetEmail(_emailController.text);
    if (ok && mounted) {
      _showSnack('Reset link sent — check your inbox and tap the link.');
      setState(() => _forgotMode = false);
    }
  }

  void _setMode(bool forgot) {
    context.read<AuthProvider>().clearError();
    setState(() => _forgotMode = forgot);
  }

  void _showSnack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  // ── Build ─────────────────────────────────────────────────

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

              // ── Title ──────────────────────────────────────
              Text(
                _forgotMode ? 'Reset password' : 'Welcome back',
                style: AppTextStyles.headlineSmall(t.textPrimary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _forgotMode
                    ? "We'll email you a link. Tap it and you'll be prompted to set a new password."
                    : 'Sign in to your diary.',
                style: AppTextStyles.bodySmallSans(t.textTertiary)
                    .copyWith(height: 1.6),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Fields ─────────────────────────────────────
              _Field(
                controller:   _emailController,
                label:        'Email',
                keyboardType: TextInputType.emailAddress,
              ),
              if (!_forgotMode) ...[
                const SizedBox(height: AppSpacing.sm),
                _Field(
                  controller:  _passwordController,
                  label:       'Password',
                  obscureText: _obscurePassword,
                  suffixIcon: _VisToggle(
                    obscure:  _obscurePassword,
                    onToggle: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ],

              // ── Error ──────────────────────────────────────
              if (auth.errorMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                _ErrorBanner(message: auth.errorMessage!),
              ],

              const SizedBox(height: AppSpacing.lg),

              // ── Primary button ─────────────────────────────
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: auth.isLoading
                      ? null
                      : (_forgotMode ? _onSendResetEmail : _onSignIn),
                  style: FilledButton.styleFrom(
                    backgroundColor: t.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: auth.isLoading
                      ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                      : Text(
                    _forgotMode ? 'Send reset link' : 'Sign in',
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => _setMode(!_forgotMode),
                    child: Text(
                      _forgotMode ? 'Back to sign in' : 'Forgot password?',
                      style: AppTextStyles.bodySmallSans(t.textTertiary),
                    ),
                  ),
                  if (!_forgotMode)
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context).pushNamed(AppRoutes.register),
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

// ── Private widgets ────────────────────────────────────────────

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

class _VisToggle extends StatelessWidget {
  final bool obscure;
  final VoidCallback onToggle;
  const _VisToggle({required this.obscure, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    return IconButton(
      icon: Icon(
        obscure ? AppIcons.visibilityOn : AppIcons.visibilityOff,
        size: AppIconSize.xs, color: t.textTertiary,
      ),
      onPressed: onToggle,
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