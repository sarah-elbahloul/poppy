import 'package:flutter/material.dart';
import 'package:poppy/core/error_messages.dart';
import 'package:poppy/core/style/style.dart';
import 'package:poppy/core/widgets/poppy_logo.dart';
import 'package:poppy/providers/auth_provider.dart';
import 'package:poppy/services/encryption_service.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Set New Password Screen
//  Location: lib/screens/auth/set_new_password_screen.dart
//
//  Shown when AuthStatus == passwordRecovery (user tapped the
//  Supabase reset email link and the app received the one-time
//  session via deep link / web URL fragment).
//
//  Two scenarios:
//    A) Same device / key still in secure storage:
//       → Re-wrap the existing data key. All entries stay readable.
//    B) Different device / fresh install:
//       → A new data key is generated. Old encrypted entries
//         become unreadable (expected E2E limitation). A warning
//         is shown to the user before they confirm.
//
//  auth_provider.completePasswordReset() handles both cases.
// ─────────────────────────────────────────────────────────────

class SetNewPasswordScreen extends StatefulWidget {
  const SetNewPasswordScreen({super.key});

  @override
  State<SetNewPasswordScreen> createState() => _SetNewPasswordScreenState();
}

class _SetNewPasswordScreenState extends State<SetNewPasswordScreen> {
  final _newPassController     = TextEditingController();
  final _confirmPassController = TextEditingController();
  bool _obscureNew     = true;
  bool _obscureConfirm = true;

  /// True if the data key is NOT cached locally — means this is a
  /// fresh device / reinstall. Old entries will become unreadable.
  bool get _keyMissing => !EncryptionService.instance.hasKey;

  @override
  void dispose() {
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    final passErr = AppErrors.validatePassword(_newPassController.text);
    if (passErr != null) { _showSnack(passErr); return; }

    final confirmErr = AppErrors.validateConfirm(
      _newPassController.text, _confirmPassController.text,
    );
    if (confirmErr != null) { _showSnack(confirmErr); return; }

    // If on a fresh device, warn the user that old entries will be lost
    if (_keyMissing) {
      final confirmed = await _showLostEntriesDialog();
      if (!confirmed) return;
    }

    final auth = context.read<AuthProvider>();
    auth.clearError();
    await auth.completePasswordReset(_newPassController.text);
    // Navigation handled by _RootRouter watching AuthStatus
  }

  Future<bool> _showLostEntriesDialog() async {
    final t = context.poppyTheme;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          'Entries may be unreadable',
          style: AppTextStyles.headlineSmall(t.textPrimary),
        ),
        content: Text(
          'You\'re resetting your password on a different device or after '
              'reinstalling the app. Because Poppy is end-to-end encrypted, '
              'your existing diary entries cannot be decrypted without the '
              'original encryption key, which is only stored on the device '
              'you first used.\n\n'
              'Your account and entries will still exist — if you sign in '
              'on your original device you can read them again.',
          style: AppTextStyles.bodySmallSans(t.textSecondary)
              .copyWith(height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: AppTextStyles.bodySmallSans(t.textTertiary)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: t.accent),
            child: Text('Continue anyway',
                style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSnack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

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
              SizedBox(height: AppSpacing.xl * 1.5),
              Text('Set new password',
                  style: AppTextStyles.headlineSmall(t.textPrimary)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _keyMissing
                    ? 'Choose a new password. Note: existing entries may '
                    'not be readable on this device (see info above).'
                    : 'Choose a strong password. Your diary entries will '
                    'remain accessible.',
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
                  onToggle: () =>
                      setState(() => _obscureNew = !_obscureNew),
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
                  onPressed: auth.isLoading ? null : _onSubmit,
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
}

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