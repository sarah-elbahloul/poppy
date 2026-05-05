import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/theme/themes.dart';
import 'package:poppy/core/widgets/poppy_logo.dart';
import 'package:poppy/providers/auth_provider.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Register Screen
//  Location: lib/screens/auth/register_screen.dart
//
//  Two stages:
//    1. Enter email + password → Supabase sends confirm email
//    2. Confirmation pending screen → user checks inbox
// ─────────────────────────────────────────────────────────────

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // After successful sign-up, show the confirmation pending screen
  bool _awaitingConfirmation = false;
  String _submittedEmail = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ── Validation ─────────────────────────────────────────────

  String? _validate() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (email.isEmpty) return 'Please enter your email address.';
    if (!email.contains('@') || !email.contains('.')) {
      return 'Please enter a valid email address.';
    }
    if (password.isEmpty) return 'Please enter a password.';
    if (password.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    if (confirm.isEmpty) return 'Please confirm your password.';
    if (password != confirm) return 'Passwords do not match.';
    return null;
  }

  // ── Register ───────────────────────────────────────────────

  Future<void> _onRegister() async {
    final validationError = _validate();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    auth.clearError();

    final success = await auth.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      setState(() {
        _submittedEmail = _emailController.text.trim();
        _awaitingConfirmation = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _awaitingConfirmation
        ? _ConfirmationPendingScreen(email: _submittedEmail)
        : _RegisterFormScreen(
      emailController: _emailController,
      passwordController: _passwordController,
      confirmController: _confirmController,
      obscurePassword: _obscurePassword,
      obscureConfirm: _obscureConfirm,
      onTogglePassword: () =>
          setState(() => _obscurePassword = !_obscurePassword),
      onToggleConfirm: () =>
          setState(() => _obscureConfirm = !_obscureConfirm),
      onRegister: _onRegister,
    );
  }
}

// ── Registration form ──────────────────────────────────────────

class _RegisterFormScreen extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final bool obscurePassword;
  final bool obscureConfirm;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirm;
  final VoidCallback onRegister;

  const _RegisterFormScreen({
    required this.emailController,
    required this.passwordController,
    required this.confirmController,
    required this.obscurePassword,
    required this.obscureConfirm,
    required this.onTogglePassword,
    required this.onToggleConfirm,
    required this.onRegister,
  });

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

              // ── Logo ─────────────────────────────────────
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

              Text(
                'Create your diary',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: t.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: kSpaceXS),
              Text(
                'Your entries are private and belong only to you.',
                style: TextStyle(fontSize: 13, color: t.textTertiary),
              ),

              const SizedBox(height: kSpaceLG),

              _Field(
                controller: emailController,
                label: 'Email address',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: kSpaceSM),
              _Field(
                controller: passwordController,
                label: 'Password',
                obscureText: obscurePassword,
                suffixIcon: _VisibilityToggle(
                  obscure: obscurePassword,
                  onToggle: onTogglePassword,
                ),
              ),
              const SizedBox(height: kSpaceSM),
              _Field(
                controller: confirmController,
                label: 'Confirm password',
                obscureText: obscureConfirm,
                suffixIcon: _VisibilityToggle(
                  obscure: obscureConfirm,
                  onToggle: onToggleConfirm,
                ),
              ),

              // ── Meaningful error message ──────────────────
              if (auth.errorMessage != null) ...[
                const SizedBox(height: kSpaceMD),
                Container(
                  padding: const EdgeInsets.all(kSpaceMD),
                  decoration: BoxDecoration(
                    color: t.accentLight,
                    borderRadius: BorderRadius.circular(kRadiusSM),
                    border: Border.all(
                        color: t.accent.withOpacity(0.3), width: 0.5),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 16, color: t.accent),
                      const SizedBox(width: kSpaceSM),
                      Expanded(
                        child: Text(
                          _friendlyError(auth.errorMessage!),
                          style: TextStyle(fontSize: 13, color: t.accent),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: kSpaceLG),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: auth.isLoading ? null : onRegister,
                  style: FilledButton.styleFrom(
                    backgroundColor: t.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(kRadiusMD),
                    ),
                  ),
                  child: auth.isLoading
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text(
                    'Create account',
                    style: TextStyle(fontSize: 15),
                  ),
                ),
              ),

              const SizedBox(height: kSpaceMD),

              Center(
                child: TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text(
                    'Already have an account? Sign in',
                    style: TextStyle(fontSize: 13, color: t.textTertiary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _friendlyError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('already registered') ||
        lower.contains('already exists') ||
        lower.contains('user already')) {
      return 'An account with this email already exists. Try signing in instead.';
    }
    if (lower.contains('invalid email') || lower.contains('valid email')) {
      return 'Please enter a valid email address.';
    }
    if (lower.contains('password') && lower.contains('short')) {
      return 'Password is too short. Please use at least 6 characters.';
    }
    if (lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('connection')) {
      return 'No internet connection. Please check your network and try again.';
    }
    if (lower.contains('database') || lower.contains('transaction')) {
      return 'Something went wrong on our end. Please wait a moment and try again.';
    }
    if (lower.contains('rate limit') || lower.contains('too many')) {
      return 'Too many attempts. Please wait a few minutes and try again.';
    }
    return 'Could not create your account. Please try again.';
  }
}

// ── Confirmation pending screen ────────────────────────────────

class _ConfirmationPendingScreen extends StatelessWidget {
  final String email;

  const _ConfirmationPendingScreen({required this.email});

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;

    return Scaffold(
      backgroundColor: t.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: kSpaceLG,
            vertical: kSpaceXL,
          ),
          child: Column(
            children: [
              const Spacer(flex: 2),

              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: t.accentLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mark_email_unread_outlined,
                  size: 32,
                  color: t.accent,
                ),
              ),

              const SizedBox(height: kSpaceLG),

              Text(
                'Check your inbox',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: t.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),

              const SizedBox(height: kSpaceSM),

              Text(
                'We sent a confirmation link to',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: t.textSecondary),
              ),
              const SizedBox(height: kSpaceXS),
              Text(
                email,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: t.textPrimary,
                ),
              ),

              const SizedBox(height: kSpaceMD),

              Text(
                'Tap the link in the email to activate your account, then come back here and sign in.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: t.textTertiary,
                  height: 1.6,
                ),
              ),

              const Spacer(flex: 3),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.go('/login'),
                  style: FilledButton.styleFrom(
                    backgroundColor: t.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(kRadiusMD),
                    ),
                  ),
                  child: const Text(
                    'Go to sign in',
                    style: TextStyle(fontSize: 15),
                  ),
                ),
              ),

              const SizedBox(height: kSpaceMD),

              Text(
                "Didn't get the email? Check your spam folder.",
                style: TextStyle(fontSize: 12, color: t.textTertiary),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: kSpaceLG),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared field widget ────────────────────────────────────────

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

// ── Visibility toggle ──────────────────────────────────────────

class _VisibilityToggle extends StatelessWidget {
  final bool obscure;
  final VoidCallback onToggle;

  const _VisibilityToggle({required this.obscure, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    return IconButton(
      icon: Icon(
        obscure
            ? Icons.visibility_outlined
            : Icons.visibility_off_outlined,
        size: 18,
        color: t.textTertiary,
      ),
      onPressed: onToggle,
    );
  }
}