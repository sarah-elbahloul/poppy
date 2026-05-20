import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
//
//  Flow:
//    1. User fills email + password + confirm
//    2. signUp() → Supabase creates account, generates data key
//       + recovery code, saves both wrapped to user_keys
//    3. Screen transitions to _RecoveryCodeScreen (blocking)
//    4. User must tap "I've saved my recovery code" to continue
//    5. Navigate to confirmation screen (check your inbox)
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
  bool   _obscurePassword   = true;
  bool   _obscureConfirm    = true;
  // Non-null once sign-up succeeds — triggers recovery code screen
  String? _recoveryCode;
  String  _submittedEmail   = '';

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
    return AppErrors.validateConfirm(
      _passwordController.text, _confirmController.text,
    );
  }

  Future<void> _onRegister() async {
    final err = _validate();
    if (err != null) { _showSnack(err); return; }

    final auth = context.read<AuthProvider>();
    auth.clearError();

    final code = await auth.signUp(
      email:    _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted) return;
    if (code != null) {
      setState(() {
        _submittedEmail = _emailController.text.trim();
        _recoveryCode   = code;
      });
    }
  }

  void _showSnack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    // Step 2: show blocking recovery code screen
    if (_recoveryCode != null) {
      return _RecoveryCodeScreen(
        code:  _recoveryCode!,
        email: _submittedEmail,
      );
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

// ─────────────────────────────────────────────────────────────
//  Recovery Code Screen
//  Shown immediately after sign-up succeeds.
//  Blocking — user must tick the checkbox to continue.
// ─────────────────────────────────────────────────────────────

class _RecoveryCodeScreen extends StatefulWidget {
  final String code;
  final String email;
  const _RecoveryCodeScreen({required this.code, required this.email});

  @override
  State<_RecoveryCodeScreen> createState() => _RecoveryCodeScreenState();
}

class _RecoveryCodeScreenState extends State<_RecoveryCodeScreen> {
  bool _confirmed = false;
  bool _copied    = false;

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2),
            () { if (mounted) setState(() => _copied = false); });
  }

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
              const Spacer(),

              // Icon
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: t.accentLight, shape: BoxShape.circle,
                ),
                child: Icon(AppIcons.key, size: AppIconSize.xl, color: t.accent),
              ),
              const SizedBox(height: AppSpacing.lg),

              Text(AppErrors.recoveryCodeTitle,
                  style: AppTextStyles.headlineLarge(t.textPrimary),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              Text(AppErrors.recoveryCodeWarning,
                  style: AppTextStyles.bodySmallSans(t.textSecondary)
                      .copyWith(height: 1.6),
                  textAlign: TextAlign.center),

              const SizedBox(height: AppSpacing.xl),

              // Code display box
              GestureDetector(
                onTap: _copyCode,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: t.accent.withOpacity(0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        widget.code,
                        style: AppTextStyles.titleLarge(t.textPrimary)
                            .copyWith(
                          letterSpacing: 2,
                          fontFamily:    'monospace',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _copied ? AppIcons.check : AppIcons.copy,
                            size: AppIconSize.xs,
                            color: _copied ? t.accent : t.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _copied ? 'Copied!' : 'Tap to copy',
                            style: AppTextStyles.labelLargeSans(
                              _copied ? t.accent : t.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Confirmation checkbox
              InkWell(
                onTap: () => setState(() => _confirmed = !_confirmed),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 22, height: 22,
                        child: Checkbox(
                          value: _confirmed,
                          onChanged: (v) =>
                              setState(() => _confirmed = v ?? false),
                          activeColor:  t.accent,
                          side: BorderSide(color: t.border, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          "I've saved my recovery code. I understand that "
                              'if I lose both my password and this code, '
                              'my entries cannot be recovered.',
                          style: AppTextStyles.bodySmallSans(t.textSecondary)
                              .copyWith(height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Continue button — disabled until checkbox ticked
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _confirmed
                      ? () => Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRoutes.login,
                        (route) => false,
                    arguments: {'email': widget.email},
                  )
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: t.accent,
                    disabledBackgroundColor: t.border,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: const Text('Continue to sign in',
                      style: TextStyle(fontSize: 15)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Check your inbox to confirm your email.',
                style: AppTextStyles.labelMedium(t.textTertiary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
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