import 'package:flutter/material.dart';
import 'package:poppy/core/error_messages.dart';
import 'package:poppy/core/style/style.dart';
import 'package:poppy/providers/auth_provider.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Account Screen
//  Location: lib/screens/settings/account_screen.dart
//
//  Password change (Option D):
//    Requires current password + new password + confirm.
//    KeyService.rewrapForPasswordChange() unwraps the data key
//    with the old password and re-wraps it with the new one.
//    ONE DB row update. No entry re-encryption. Instant.
// ─────────────────────────────────────────────────────────────

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  String? _openPanel;

  final _emailController       = TextEditingController();
  final _currentPassController = TextEditingController();
  final _newPassController     = TextEditingController();
  final _confirmPassController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew     = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _emailController.dispose();
    _currentPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  Future<void> _onUpdateEmail() async {
    final err = AppErrors.validateEmail(_emailController.text);
    if (err != null) { _showSnack(err); return; }
    final auth = context.read<AuthProvider>();
    auth.clearError();
    final ok = await auth.updateEmail(_emailController.text);
    if (!mounted) return;
    if (ok) {
      setState(() => _openPanel = null);
      _emailController.clear();
      _showSnack('Check your new email for a confirmation link.');
    }
  }

  Future<void> _onUpdatePassword() async {
    if (_currentPassController.text.isEmpty) {
      _showSnack('Please enter your current password.'); return;
    }
    final passErr = AppErrors.validatePassword(_newPassController.text);
    if (passErr != null) { _showSnack(passErr); return; }
    final confirmErr = AppErrors.validateConfirm(
      _newPassController.text, _confirmPassController.text,
    );
    if (confirmErr != null) { _showSnack(confirmErr); return; }

    final auth = context.read<AuthProvider>();
    auth.clearError();
    final ok = await auth.updatePassword(
      oldPassword: _currentPassController.text,
      newPassword: _newPassController.text,
    );
    if (!mounted) return;
    if (ok) {
      setState(() => _openPanel = null);
      _currentPassController.clear();
      _newPassController.clear();
      _confirmPassController.clear();
      _showSnack('Password updated successfully.');
    }
  }

  void _showSnack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final t    = context.poppyTheme;
    final auth = context.watch<AuthProvider>();
    final fp = context.read<ThemeProvider>().currentFontPairData;

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        leading: IconButton(
          icon: Icon(AppIcons.back,
              size: AppIconSize.xs, color: t.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Account',
            style: AppTextStyles.titleLarge(t.textPrimary, fp)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text('Signed in as',
              style: AppTextStyles.labelLargeSans(t.textTertiary, fp)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            auth.user?.email ?? '—',
            style: AppTextStyles.headlineSmall(t.textPrimary,fp)
                .copyWith(fontSize: 15),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Change email ──────────────────────────────────
          _ExpandablePanel(
            icon:  AppIcons.email,
            title: 'Change email',
            isOpen: _openPanel == 'email',
            onToggle: () => setState(() =>
            _openPanel = _openPanel == 'email' ? null : 'email'),
            child: Column(
              children: [
                _Field(
                  controller:   _emailController,
                  label:        'New email address',
                  keyboardType: TextInputType.emailAddress,
                ),
                if (auth.errorMessage != null && _openPanel == 'email') ...[
                  const SizedBox(height: AppSpacing.sm),
                  _ErrorText(message: auth.errorMessage!),
                ],
                const SizedBox(height: AppSpacing.md),
                _SubmitButton(
                  label:     'Update email',
                  isLoading: auth.isLoading,
                  onPressed: _onUpdateEmail,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // ── Change password ───────────────────────────────
          _ExpandablePanel(
            icon:  AppIcons.password,
            title: 'Change password',
            isOpen: _openPanel == 'password',
            onToggle: () => setState(() =>
            _openPanel =
            _openPanel == 'password' ? null : 'password'),
            child: Column(
              children: [
                _Field(
                  controller:  _currentPassController,
                  label:       'Current password',
                  obscureText: _obscureCurrent,
                  suffixIcon: _VisToggle(
                    obscure:  _obscureCurrent,
                    onToggle: () => setState(
                            () => _obscureCurrent = !_obscureCurrent),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
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
                    onToggle: () => setState(
                            () => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                if (auth.errorMessage != null &&
                    _openPanel == 'password') ...[
                  const SizedBox(height: AppSpacing.sm),
                  _ErrorText(message: auth.errorMessage!),
                ],
                const SizedBox(height: AppSpacing.md),
                _SubmitButton(
                  label:     'Update password',
                  isLoading: auth.isLoading,
                  onPressed: _onUpdatePassword,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Expandable panel ───────────────────────────────────────────

class _ExpandablePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isOpen;
  final VoidCallback onToggle;
  final Widget child;
  const _ExpandablePanel({
    required this.icon, required this.title,
    required this.isOpen, required this.onToggle, required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final fp = context.read<ThemeProvider>().currentFontPairData;

    return AnimatedContainer(
      duration: AppDuration.normal,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isOpen ? t.accent.withOpacity(0.4) : t.border,
          width: AppStroke.hairline,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Icon(icon, size: AppIconSize.sm, color: t.textTertiary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: Text(title,
                      style: AppTextStyles.titleSmallSans(t.textPrimary,fp))),
                  Icon(
                    isOpen ? AppIcons.chevronUp : AppIcons.chevronDown,
                    size: AppIconSize.sm, color: t.textTertiary,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: AppDuration.normal,
            crossFadeState: isOpen
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild:  const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 0, AppSpacing.md, AppSpacing.md,
              ),
              child: Column(
                children: [
                  Divider(height: AppSpacing.md,
                      color: t.border, thickness: AppStroke.hairline),
                  child,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  final String message;
  const _ErrorText({required this.message});
  @override
  Widget build(BuildContext context) {
    final fp = context.read<ThemeProvider>().currentFontPairData;
    final t = context.poppyTheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(message,
          style: AppTextStyles.bodySmallSans(t.accent,fp)),
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
    final fp = context.read<ThemeProvider>().currentFontPairData;

    return Container(
      decoration: BoxDecoration(
        color: t.background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: t.border, width: AppStroke.hairline),
      ),
      child: TextField(
        controller: controller, obscureText: obscureText,
        keyboardType: keyboardType,
        style: AppTextStyles.bodyMedium(t.textPrimary,fp),
        decoration: InputDecoration(
          labelText:  label,
          labelStyle: AppTextStyles.bodySmallSans(t.textTertiary,fp),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm,
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

class _SubmitButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onPressed;
  const _SubmitButton({
    required this.label, required this.isLoading, required this.onPressed,
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        child: isLoading
            ? const SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Colors.white),
        )
            : Text(label),
      ),
    );
  }
}