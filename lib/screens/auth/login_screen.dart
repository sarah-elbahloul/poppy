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
//  Three modes (toggled inline, no navigation):
//
//    normal        — email + password → signIn()
//
//    forgotStep1   — email only → sendPasswordResetEmail()
//                    Supabase sends a magic deep-link.
//                    After user taps the link the app resumes
//                    in an active reset session.
//                    Screen auto-advances to forgotStep2.
//
//    forgotStep2   — recovery code + new password + confirm
//                    → resetWithRecoveryCode()
//                    No scary "your entries will be lost" warning.
//                    The recovery code unwraps the data key,
//                    entries are untouched.
//
//  With Option D key architecture there is no longer any
//  destructive path — the reset flow is safe.
// ─────────────────────────────────────────────────────────────

enum _Mode { normal, forgotStep1, forgotStep2 }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  _Mode _mode = _Mode.normal;

  final _emailController       = TextEditingController();
  final _passwordController    = TextEditingController();
  final _recoveryController    = TextEditingController();
  final _newPassController     = TextEditingController();
  final _confirmPassController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureNew      = true;
  bool _obscureConfirm  = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _recoveryController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
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
    // Navigation handled by auth listener in app.dart
  }

  Future<void> _onSendResetEmail() async {
    final emailErr = AppErrors.validateEmail(_emailController.text);
    if (emailErr != null) { _showSnack(emailErr); return; }
    final auth = context.read<AuthProvider>();
    auth.clearError();
    final ok = await auth.sendPasswordResetEmail(_emailController.text);
    if (ok && mounted) {
      // Advance to step 2 — user will tap the email link and return
      setState(() => _mode = _Mode.forgotStep2);
    }
  }

  Future<void> _onResetWithCode() async {
    final codeErr = AppErrors.validateRecoveryCode(_recoveryController.text);
    if (codeErr != null) { _showSnack(codeErr); return; }
    final passErr = AppErrors.validatePassword(_newPassController.text);
    if (passErr != null) { _showSnack(passErr); return; }
    final confirmErr = AppErrors.validateConfirm(
      _newPassController.text, _confirmPassController.text,
    );
    if (confirmErr != null) { _showSnack(confirmErr); return; }

    final auth = context.read<AuthProvider>();
    auth.clearError();
    final ok = await auth.resetWithRecoveryCode(
      recoveryCode: _recoveryController.text,
      newPassword:  _newPassController.text,
    );
    if (ok && mounted) {
      setState(() => _mode = _Mode.normal);
      _showSnack('Password reset. You can now sign in.');
    }
  }

  void _showSnack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  void _setMode(_Mode m) {
    context.read<AuthProvider>().clearError();
    setState(() => _mode = m);
  }

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
              ..._buildBody(t, auth),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBody(PoppyThemeExtension t, AuthProvider auth) {
    switch (_mode) {
      case _Mode.normal:       return _buildNormal(t, auth);
      case _Mode.forgotStep1:  return _buildForgotStep1(t, auth);
      case _Mode.forgotStep2:  return _buildForgotStep2(t, auth);
    }
  }

  // ── Normal sign-in ────────────────────────────────────────

  List<Widget> _buildNormal(PoppyThemeExtension t, AuthProvider auth) => [
    Text('Welcome back',
        style: AppTextStyles.headlineSmall(t.textPrimary)),
    const SizedBox(height: AppSpacing.xs),
    Text('Sign in to your diary.',
        style: AppTextStyles.bodySmallSans(t.textTertiary)),
    const SizedBox(height: AppSpacing.lg),
    _Field(controller: _emailController, label: 'Email',
        keyboardType: TextInputType.emailAddress),
    const SizedBox(height: AppSpacing.sm),
    _Field(
      controller:  _passwordController,
      label:       'Password',
      obscureText: _obscurePassword,
      suffixIcon: _VisToggle(
        obscure:  _obscurePassword,
        onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
      ),
    ),
    if (auth.errorMessage != null) ...[
      const SizedBox(height: AppSpacing.md),
      _ErrorBanner(message: auth.errorMessage!),
    ],
    const SizedBox(height: AppSpacing.lg),
    _PrimaryButton(
      label:     'Sign in',
      isLoading: auth.isLoading,
      onPressed: _onSignIn,
    ),
    const SizedBox(height: AppSpacing.md),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: () => _setMode(_Mode.forgotStep1),
          child: Text('Forgot password?',
              style: AppTextStyles.bodySmallSans(t.textTertiary)),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pushNamed(AppRoutes.register),
          child: Text('Create account',
              style: AppTextStyles.bodySmallSans(t.accent)),
        ),
      ],
    ),
  ];

  // ── Forgot: step 1 — enter email ─────────────────────────

  List<Widget> _buildForgotStep1(PoppyThemeExtension t, AuthProvider auth) => [
    Text('Reset password',
        style: AppTextStyles.headlineSmall(t.textPrimary)),
    const SizedBox(height: AppSpacing.xs),
    Text(
      "We'll send a link to your email. You'll also need your "
          'recovery code to complete the reset.',
      style: AppTextStyles.bodySmallSans(t.textTertiary)
          .copyWith(height: 1.6),
    ),
    const SizedBox(height: AppSpacing.lg),
    _Field(controller: _emailController, label: 'Email',
        keyboardType: TextInputType.emailAddress),
    if (auth.errorMessage != null) ...[
      const SizedBox(height: AppSpacing.md),
      _ErrorBanner(message: auth.errorMessage!),
    ],
    const SizedBox(height: AppSpacing.lg),
    _PrimaryButton(
      label:     'Send reset link',
      isLoading: auth.isLoading,
      onPressed: _onSendResetEmail,
    ),
    const SizedBox(height: AppSpacing.md),
    TextButton(
      onPressed: () => _setMode(_Mode.normal),
      child: Text('Back to sign in',
          style: AppTextStyles.bodySmallSans(t.textTertiary)),
    ),
  ];

  // ── Forgot: step 2 — enter recovery code + new password ──

  List<Widget> _buildForgotStep2(PoppyThemeExtension t, AuthProvider auth) => [
    Text('Enter your recovery code',
        style: AppTextStyles.headlineSmall(t.textPrimary)),
    const SizedBox(height: AppSpacing.xs),
    Text(
      'Check your email for the reset link and tap it first. '
          'Then enter your recovery code and choose a new password.',
      style: AppTextStyles.bodySmallSans(t.textTertiary)
          .copyWith(height: 1.6),
    ),
    const SizedBox(height: AppSpacing.lg),
    _Field(
      controller:    _recoveryController,
      label:         'Recovery code',
      keyboardType:  TextInputType.visiblePassword,
      hint:          AppErrors.recoveryCodeHint,
      textCapitalization: TextCapitalization.characters,
    ),
    const SizedBox(height: AppSpacing.sm),
    _Field(
      controller:  _newPassController,
      label:       'New password',
      obscureText: _obscureNew,
      suffixIcon: _VisToggle(
        obscure:  _obscureNew,
        onToggle: () => setState(() => _obscureNew = !_obscureNew),
      ),
    ),
    const SizedBox(height: AppSpacing.sm),
    _Field(
      controller:  _confirmPassController,
      label:       'Confirm new password',
      obscureText: _obscureConfirm,
      suffixIcon: _VisToggle(
        obscure:  _obscureConfirm,
        onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
      ),
    ),
    if (auth.errorMessage != null) ...[
      const SizedBox(height: AppSpacing.md),
      _ErrorBanner(message: auth.errorMessage!),
    ],
    const SizedBox(height: AppSpacing.lg),
    _PrimaryButton(
      label:     'Reset password',
      isLoading: auth.isLoading,
      onPressed: _onResetWithCode,
    ),
    const SizedBox(height: AppSpacing.md),
    TextButton(
      onPressed: () => _setMode(_Mode.forgotStep1),
      child: Text('Back',
          style: AppTextStyles.bodySmallSans(t.textTertiary)),
    ),
  ];
}

// ── Shared private widgets ─────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final Widget? suffixIcon;
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.suffixIcon,
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
        controller:         controller,
        obscureText:        obscureText,
        keyboardType:       keyboardType,
        textCapitalization: textCapitalization,
        style: AppTextStyles.bodyMedium(t.textPrimary),
        decoration: InputDecoration(
          labelText:  label,
          hintText:   hint,
          labelStyle: AppTextStyles.bodySmallSans(t.textTertiary),
          hintStyle:  AppTextStyles.bodySmallSans(t.textTertiary)
              .copyWith(letterSpacing: 1),
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

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onPressed;
  const _PrimaryButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: t.accent,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        child: isLoading
            ? const SizedBox(
          width: 18, height: 18,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Colors.white),
        )
            : Text(label, style: const TextStyle(fontSize: 15)),
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