import 'package:flutter/material.dart';
import 'package:poppy/core/error_messages.dart';
import 'package:poppy/core/style/style.dart';
import 'package:poppy/providers/auth_provider.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Account Screen
//  Location: lib/screens/settings/account_screen.dart
// ─────────────────────────────────────────────────────────────

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  String? _openPanel;
  final _emailController           = TextEditingController();
  final _newPasswordController     = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureNew     = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _onUpdateEmail() async {
    // Validate before network call
    final emailErr = AppErrors.validateEmail(_emailController.text);
    if (emailErr != null) {
      _showSnack(emailErr);
      return;
    }

    final auth = context.read<AuthProvider>();
    auth.clearError();
    final success = await auth.updateEmail(_emailController.text);
    if (!mounted) return;
    if (success) {
      setState(() => _openPanel = null);
      _emailController.clear();
      _showSnack('Check your new email for a confirmation link.');
    }
    // Error already translated in auth_provider via AppErrors.updateEmail()
  }

  Future<void> _onUpdatePassword() async {
    // Validate before network call
    final passwordErr =
    AppErrors.validatePassword(_newPasswordController.text);
    if (passwordErr != null) {
      _showSnack(passwordErr);
      return;
    }
    final confirmErr = AppErrors.validateConfirm(
      _newPasswordController.text,
      _confirmPasswordController.text,
    );
    if (confirmErr != null) {
      _showSnack(confirmErr);
      return;
    }

    final auth = context.read<AuthProvider>();
    auth.clearError();
    final success =
    await auth.updatePassword(_newPasswordController.text);
    if (!mounted) return;
    if (success) {
      setState(() => _openPanel = null);
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _showSnack('Password updated successfully.');
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
      appBar: AppBar(
        backgroundColor: t.background,
        leading: IconButton(
          icon: Icon(AppIcons.back,
              size: AppIconSize.xs, color: t.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Account',
            style: AppTextStyles.appBarTitle(t.textPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text('Signed in as',
              style: AppTextStyles.sectionLabel(t.textTertiary)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            auth.user?.email ?? '—',
            style: AppTextStyles.authHeading(t.textPrimary)
                .copyWith(fontSize: 15),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Change email
          _ExpandablePanel(
            icon:  AppIcons.email,
            title: 'Change email',
            isOpen: _openPanel == 'email',
            onToggle: () => setState(() =>
            _openPanel = _openPanel == 'email' ? null : 'email'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Field(
                  controller:   _emailController,
                  label:        'New email address',
                  keyboardType: TextInputType.emailAddress,
                ),
                // Error already friendly from auth_provider
                if (auth.errorMessage != null &&
                    _openPanel == 'email') ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(auth.errorMessage!,
                      style: AppTextStyles.errorText(t.accent)),
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

          // Change password
          _ExpandablePanel(
            icon:  AppIcons.password,
            title: 'Change password',
            isOpen: _openPanel == 'password',
            onToggle: () => setState(() =>
            _openPanel =
            _openPanel == 'password' ? null : 'password'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Field(
                  controller:  _newPasswordController,
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
                  controller:  _confirmPasswordController,
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
                  Text(auth.errorMessage!,
                      style: AppTextStyles.errorText(t.accent)),
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
                      style: AppTextStyles.settingsRowLabel(t.textPrimary))),
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
        color: t.background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: t.border, width: AppStroke.hairline),
      ),
      child: TextField(
        controller: controller, obscureText: obscureText,
        keyboardType: keyboardType,
        style: AppTextStyles.fieldText(t.textPrimary),
        decoration: InputDecoration(
          labelText:  label,
          labelStyle: AppTextStyles.fieldLabel(t.textTertiary),
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