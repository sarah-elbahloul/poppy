import 'package:flutter/material.dart';
import 'package:poppy/core/app_routes.dart';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/error_messages.dart';
import 'package:poppy/core/style/style.dart';
import 'package:poppy/core/widgets/poppy_logo.dart';
import 'package:poppy/providers/auth_provider.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Register Screen
//  Location: lib/screens/auth/register_screen.dart
// ─────────────────────────────────────────────────────────────

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController  = TextEditingController();
  bool _obscurePassword     = true;
  bool _obscureConfirm      = true;
  bool _awaitingConfirmation = false;
  String _submittedEmail    = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validate() {
    final emailErr = AppErrors.validateEmail(_emailController.text);
    if (emailErr != null) return emailErr;
    final passwordErr = AppErrors.validatePassword(_passwordController.text);
    if (passwordErr != null) return passwordErr;
    final confirmErr = AppErrors.validateConfirm(
      _passwordController.text, _confirmController.text,
    );
    return confirmErr;
  }

  Future<void> _onRegister() async {
    final err = _validate();
    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    final auth = context.read<AuthProvider>();
    auth.clearError();
    final success = await auth.signUp(
      email:    _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted) return;
    if (success) {
      setState(() {
        _submittedEmail       = _emailController.text.trim();
        _awaitingConfirmation = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_awaitingConfirmation) {
      return _ConfirmationScreen(email: _submittedEmail);
    }
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
              Text('Create your diary',
                  style: AppTextStyles.headlineSmall(t.textPrimary)),
              const SizedBox(height: AppSpacing.xs),
              Text('Your entries are private and belong only to you.',
                  style: AppTextStyles.bodySmallSans(t.textTertiary)),
              const SizedBox(height: AppSpacing.lg),
              _Field(
                controller:   _emailController,
                label:        'Email address',
                keyboardType: TextInputType.emailAddress,
              ),
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
              const SizedBox(height: AppSpacing.sm),
              _Field(
                controller:  _confirmController,
                label:       'Confirm password',
                obscureText: _obscureConfirm,
                suffixIcon: _VisToggle(
                  obscure:  _obscureConfirm,
                  onToggle: () => setState(
                          () => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              // Error already friendly from auth_provider via AppErrors
              if (auth.errorMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                _ErrorBanner(message: auth.errorMessage!),
              ],
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: auth.isLoading ? null : _onRegister,
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
                      : const Text('Create account',
                      style: TextStyle(fontSize: 15)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Already have an account? Sign in',
                      style: AppTextStyles.bodySmallSans(t.textTertiary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmationScreen extends StatelessWidget {
  final String email;
  const _ConfirmationScreen({required this.email});

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    return Scaffold(
      backgroundColor: t.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.xl,
          ),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: AppComponentSize.confirmIconCircle,
                height: AppComponentSize.confirmIconCircle,
                decoration: BoxDecoration(
                    color: t.accentLight, shape: BoxShape.circle),
                child: Icon(AppIcons.emailUnread,
                    size: AppIconSize.xl, color: t.accent),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Check your inbox',
                  style: AppTextStyles.headlineLarge(t.textPrimary)),
              const SizedBox(height: AppSpacing.sm),
              Text('We sent a confirmation link to',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmallSans(t.textSecondary)),
              const SizedBox(height: AppSpacing.xs),
              Text(email,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headlineSmall(t.textPrimary)
                      .copyWith(fontSize: 14)),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Tap the link in the email to activate your account,\nthen come back and sign in.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmallSans(t.textTertiary)
                    .copyWith(height: 1.6),
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context)
                      .pushNamedAndRemoveUntil(
                      AppRoutes.login, (route) => false),
                  style: FilledButton.styleFrom(
                    backgroundColor: t.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: const Text('Go to sign in',
                      style: TextStyle(fontSize: 15)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text("Didn't get the email? Check your spam folder.",
                  style: AppTextStyles.labelMedium(t.textTertiary),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

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