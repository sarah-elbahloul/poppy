import 'package:flutter/material.dart';
import 'package:poppy/core/error_messages.dart';
import 'package:poppy/core/style/style.dart';
import 'package:poppy/core/widgets/poppy_logo.dart';
import 'package:poppy/providers/auth_provider.dart';
import 'package:poppy/services/encryption_service.dart';
import 'package:poppy/services/key_service.dart' show RewrapResult;
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Set New Password Screen
//  Location: lib/screens/auth/set_new_password_screen.dart
//
//  Shown when AuthStatus == passwordRecovery (user tapped the
//  Supabase reset email link and the app received the one-time
//  session via deep link / web URL fragment).
//
//  Three scenarios:
//    A) Same device / key still in secure storage:
//       → Re-wrap the existing data key. All entries stay readable.
//    B) Different device / fresh install — user knows old password:
//       → Fetch wrapped key from DB, unwrap with old password,
//         re-wrap with new password. All entries stay readable.
//    C) Different device — user cannot remember old password:
//       → After exhausting retries, offer "start fresh" with an
//         explicit warning that old entries will be unreadable.
//
//  Flow state machine:
//    _Phase.newPassword  → user enters new password (always first)
//    _Phase.oldPassword  → shown only on cross-device; user enters
//                          old password to recover entries
//    _Phase.confirmLoss  → shown only if user gives up on old password;
//                          final confirmation before generating new key
// ─────────────────────────────────────────────────────────────

enum _Phase { newPassword, oldPassword, confirmLoss }

class SetNewPasswordScreen extends StatefulWidget {
  const SetNewPasswordScreen({super.key});

  @override
  State<SetNewPasswordScreen> createState() => _SetNewPasswordScreenState();
}

class _SetNewPasswordScreenState extends State<SetNewPasswordScreen> {
  final _newPassController     = TextEditingController();
  final _confirmPassController = TextEditingController();
  final _oldPassController     = TextEditingController();

  bool _obscureNew     = true;
  bool _obscureConfirm = true;
  bool _obscureOld     = true;
  bool _oldPassWrong   = false;
  int  _oldPassAttempts = 0;

  _Phase _phase = _Phase.newPassword;

  // Stored after phase 1 completes so we can pass it to phase 2 / 3.
  String? _pendingNewPassword;

  /// True if the data key is NOT cached locally — means this is a
  /// fresh device / reinstall. We need the old password to recover entries.
  bool get _keyMissing => !EncryptionService.instance.hasKey;

  @override
  void dispose() {
    _newPassController.dispose();
    _confirmPassController.dispose();
    _oldPassController.dispose();
    super.dispose();
  }

  // ── Phase 1: new password ─────────────────────────────────

  Future<void> _onSubmitNewPassword() async {
    final passErr = AppErrors.validatePassword(_newPassController.text);
    if (passErr != null) { _showSnack(passErr); return; }

    final confirmErr = AppErrors.validateConfirm(
      _newPassController.text, _confirmPassController.text,
    );
    if (confirmErr != null) { _showSnack(confirmErr); return; }

    final auth        = context.read<AuthProvider>();
    final newPassword = _newPassController.text;

    auth.clearError();
    final ok = await auth.completePasswordReset(newPassword);

    if (ok) {
      // Same device — done. Navigation handled by _RootRouter.
      return;
    }

    // Cross-device: Supabase auth password was updated inside
    // completePasswordReset before it returned false. Now we need
    // the old password to recover the data key.
    if (!mounted) return;
    setState(() {
      _pendingNewPassword = newPassword;
      _phase = _Phase.oldPassword;
    });
  }

  // ── Phase 2: old password (cross-device recovery) ─────────

  Future<void> _onSubmitOldPassword() async {
    final oldPassword = _oldPassController.text.trim();
    if (oldPassword.isEmpty) { _showSnack('Enter your previous password.'); return; }

    final auth = context.read<AuthProvider>();
    auth.clearError();

    final result = await auth.completePasswordResetCrossDevice(
      oldPassword: oldPassword,
      newPassword: _pendingNewPassword!,
    );

    if (result == RewrapResult.success) {
      // Navigation handled by _RootRouter watching AuthStatus.
      return;
    }

    if (!mounted) return;
    setState(() {
      _oldPassAttempts++;
      _oldPassWrong = true;
    });

    if (_oldPassAttempts >= 3) {
      // After 3 wrong attempts, offer the "start fresh" option.
      _showGiveUpOption();
    }
  }

  void _showGiveUpOption() {
    final t = context.poppyTheme;
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          "Can't remember your password?",
          style: AppTextStyles.headlineSmall(t.textPrimary),
        ),
        content: Text(
          'You can keep trying, or start fresh with a new encryption key.\n\n'
              'Starting fresh means existing diary entries on this device will '
              'no longer be readable. Your account stays active and entries are '
              'still in the cloud — if you sign in on your original device '
              'you can read them again.',
          style: AppTextStyles.bodySmallSans(t.textSecondary)
              .copyWith(height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() { _oldPassWrong = false; });
            },
            child: Text('Keep trying',
                style: AppTextStyles.bodySmallSans(t.textTertiary)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() { _phase = _Phase.confirmLoss; });
            },
            style: FilledButton.styleFrom(backgroundColor: t.accent),
            child: const Text('Start fresh', style: TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  // ── Phase 3: confirm loss of old entries ──────────────────

  Future<void> _onConfirmFresh() async {
    final auth = context.read<AuthProvider>();
    auth.clearError();
    await auth.completePasswordResetFresh(_pendingNewPassword!);
    // Navigation handled by _RootRouter.
  }

  void _showSnack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return switch (_phase) {
      _Phase.newPassword  => _buildNewPasswordPhase(),
      _Phase.oldPassword  => _buildOldPasswordPhase(),
      _Phase.confirmLoss  => _buildConfirmLossPhase(),
    };
  }

  Widget _buildNewPasswordPhase() {
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
              SizedBox(height: AppSpacing.xl * 1.5),
              Text('Set new password',
                  style: AppTextStyles.headlineSmall(t.textPrimary)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Choose a strong password. '
                    'Your diary entries will remain accessible.',
                style: AppTextStyles.bodySmallSans(t.textTertiary)
                    .copyWith(height: 1.6),
              ),
              const SizedBox(height: AppSpacing.lg),
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
                  onToggle: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
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
                  onPressed: auth.isLoading ? null : _onSubmitNewPassword,
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
                      : const Text('Set password',
                      style: TextStyle(fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOldPasswordPhase() {
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
              SizedBox(height: AppSpacing.xl * 1.5),
              Text('Verify previous password',
                  style: AppTextStyles.headlineSmall(t.textPrimary)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                "You're signing in on a new device. Enter your previous "
                    'password so Poppy can decrypt your existing diary entries.',
                style: AppTextStyles.bodySmallSans(t.textTertiary)
                    .copyWith(height: 1.6),
              ),
              const SizedBox(height: AppSpacing.lg),
              _Field(
                controller:  _oldPassController,
                label:       'Previous password',
                obscureText: _obscureOld,
                suffixIcon: _VisToggle(
                  obscure:  _obscureOld,
                  onToggle: () => setState(() => _obscureOld = !_obscureOld),
                ),
              ),
              if (_oldPassWrong) ...[
                const SizedBox(height: AppSpacing.md),
                _ErrorBanner(
                  message: _oldPassAttempts >= 3
                      ? 'Incorrect password. Tap below to try again or start fresh.'
                      : 'Incorrect password. Please try again.',
                ),
              ],
              if (auth.errorMessage != null && !_oldPassWrong) ...[
                const SizedBox(height: AppSpacing.md),
                _ErrorBanner(message: auth.errorMessage!),
              ],
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: auth.isLoading ? null : _onSubmitOldPassword,
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
                      : const Text('Recover entries',
                      style: TextStyle(fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmLossPhase() {
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
              SizedBox(height: AppSpacing.xl * 1.5),
              Text('Start fresh?',
                  style: AppTextStyles.headlineSmall(t.textPrimary)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'This will create a new encryption key. Your existing diary '
                    'entries will no longer be readable on this device.\n\n'
                    'They are still stored in the cloud — if you sign in on '
                    'your original device you can read them there.',
                style: AppTextStyles.bodySmallSans(t.textTertiary)
                    .copyWith(height: 1.6),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (auth.errorMessage != null) ...[
                _ErrorBanner(message: auth.errorMessage!),
                const SizedBox(height: AppSpacing.md),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: auth.isLoading
                          ? null
                          : () => setState(() {
                        _phase        = _Phase.oldPassword;
                        _oldPassWrong = false;
                      }),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: const Text('Go back',
                          style: TextStyle(fontSize: 15)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: auth.isLoading ? null : _onConfirmFresh,
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
                          : const Text('Start fresh',
                          style: TextStyle(fontSize: 15)),
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

// ── Shared widgets ─────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final Widget? suffixIcon;
  const _Field({
    required this.controller, required this.label,
    this.obscureText = false, this.suffixIcon,
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