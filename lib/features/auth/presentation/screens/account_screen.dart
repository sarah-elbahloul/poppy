import 'package:flutter/material.dart';
import 'package:poppy/core/core.dart';
import 'package:poppy/features/auth/presentation/providers/auth_provider.dart';
import 'package:poppy/features/settings/presentation/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:poppy/features/auth/presentation/widgets/password_rules_checker.dart';
// ─────────────────────────────────────────────────────────────
//  POPPY — Account Screen
// ─────────────────────────────────────────────────────────────

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  String? _openPanel;

  final _displayNameController = TextEditingController();
  final _emailController       = TextEditingController();
  final _currentPassController = TextEditingController();
  final _newPassController     = TextEditingController();
  final _confirmPassController = TextEditingController();
  final _newPassFocus          = FocusNode();

  bool _obscureCurrent  = true;
  bool _obscureNew      = true;
  bool _obscureConfirm  = true;

  @override
  void initState() {
    super.initState();
    _newPassController.addListener(() => setState(() {}));
    context.read<AuthProvider>().refreshUser();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _currentPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    _newPassFocus.dispose();
    super.dispose();
  }

  Future<void> _onUpdateDisplayName() async {
    final name = _displayNameController.text.trim();
    if (name.isEmpty) {
      PoppySnackbar.warning(context, 'Please enter a display name.');
      return;
    }
    final auth = context.read<AuthProvider>();
    auth.clearError();
    final ok = await auth.updateDisplayName(name);
    if (!mounted) return;
    if (ok) {
      setState(() => _openPanel = null);
      _displayNameController.clear();
      PoppySnackbar.success(context, 'Display name updated.');
    }
  }

  Future<void> _onUpdateEmail() async {
    final err = AppErrors.validateEmail(_emailController.text);
    if (err != null) {
      PoppySnackbar.error(context, err);
      return;
    }
    final auth = context.read<AuthProvider>();
    auth.clearError();
    final ok = await auth.updateEmail(_emailController.text);
    if (!mounted) return;
    if (ok) {
      setState(() => _openPanel = null);
      _emailController.clear();
      PoppySnackbar.success(context, 'Check your new email for a confirmation link.', title: 'Verification sent');
    }
  }

  Future<void> _onUpdatePassword() async {
    if (_currentPassController.text.isEmpty) {
      PoppySnackbar.warning(context, 'Please enter your current password.');
      return;
    }
    final passErr = AppErrors.validatePassword(_newPassController.text);
    if (passErr != null) {
      PoppySnackbar.error(context, passErr);
      return;
    }
    final confirmErr = AppErrors.validateConfirm(
      _newPassController.text, _confirmPassController.text,
    );
    if (confirmErr != null) {
      PoppySnackbar.error(context, confirmErr);
      return;
    }

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
      PoppySnackbar.success(context, 'Password updated successfully.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t    = context.poppyTheme;
    final auth = context.watch<AuthProvider>();
    final fp   = context.read<ThemeProvider>().currentFontPairData;

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
          Text(
            auth.displayName,
            style: AppTextStyles.headlineSmall(t.textPrimary, fp),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Signed in as',
              style: AppTextStyles.labelLargeSans(t.textTertiary, fp)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            auth.user?.email ?? '—',
            style: AppTextStyles.headlineSmall(t.textPrimary, fp)
                .copyWith(fontSize: 15),
          ),
          const SizedBox(height: AppSpacing.lg),

          _ExpandablePanel(
            icon:    AppIcons.person,
            title:   'Change display name',
            isOpen:  _openPanel == 'displayName',
            onToggle: () => setState(() {
              if (_openPanel != 'displayName') {
                _displayNameController.text = auth.displayName;
              }
              _openPanel =
              _openPanel == 'displayName' ? null : 'displayName';
            }),
            child: Column(
              children: [
                _Field(
                  controller:   _displayNameController,
                  label:        'Display name',
                  keyboardType: TextInputType.name,
                ),
                if (auth.errorMessage != null &&
                    _openPanel == 'displayName') ...[
                  const SizedBox(height: AppSpacing.sm),
                  _ErrorText(message: auth.errorMessage!),
                ],
                const SizedBox(height: AppSpacing.md),
                _SubmitButton(
                  label:     'Update name',
                  isLoading: auth.isLoading,
                  onPressed: _onUpdateDisplayName,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          _ExpandablePanel(
            icon:    AppIcons.email,
            title:   'Change email',
            isOpen:  _openPanel == 'email',
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

          _ExpandablePanel(
            icon:    AppIcons.password,
            title:   'Change password',
            isOpen:  _openPanel == 'password',
            onToggle: () => setState(() {
              _openPanel =
              _openPanel == 'password' ? null : 'password';
              if (_openPanel == null) {
                _newPassController.clear();
                _currentPassController.clear();
                _confirmPassController.clear();
              }
            }),
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
                  focusNode:   _newPassFocus,
                  suffixIcon: _VisToggle(
                    obscure:  _obscureNew,
                    onToggle: () =>
                        setState(() => _obscureNew = !_obscureNew),
                  ),
                ),

                TweenAnimationBuilder<double>(
                  duration: AppDuration.normal,
                  curve: Curves.easeOutCubic,
                  tween: Tween(
                    begin: 0,
                    end: _newPassController.text.isNotEmpty ? 1 : 0,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: PasswordRulesChecker(
                      controller: _newPassController,
                    ),
                  ),
                  builder: (context, value, child) {
                    return ClipRect(
                      child: Align(
                        alignment: Alignment.topCenter,
                        heightFactor: value,
                        child: child,
                      ),
                    );
                  },
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

class _ExpandablePanel extends StatelessWidget {
  final IconData     icon;
  final String       title;
  final bool         isOpen;
  final VoidCallback onToggle;
  final Widget       child;
  const _ExpandablePanel({
    required this.icon, required this.title,
    required this.isOpen, required this.onToggle, required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final t  = context.poppyTheme;
    final fp = context.read<ThemeProvider>().currentFontPairData;

    return AnimatedContainer(
      duration: AppDuration.normal,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isOpen ? t.accent.withValues(alpha: 0.4) : t.border,
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
                      style: AppTextStyles.titleSmallSans(t.textPrimary, fp))),
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
                  Divider(
                      height: AppSpacing.md,
                      color: t.border,
                      thickness: AppStroke.hairline),
                  const SizedBox(height: AppSpacing.xs),
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
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(message,
          style: AppTextStyles.bodySmallSans(AppColors.error, fp)),
    );
  }
}

class _Field extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final FocusNode? focusNode;

  const _Field({
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
    this.focusNode,
  });

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  late final FocusNode _internalFocus;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _internalFocus = widget.focusNode ?? FocusNode();
    _internalFocus.addListener(
            () => setState(() => _focused = _internalFocus.hasFocus));
  }

  @override
  void dispose() {
    if (widget.focusNode == null) _internalFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t  = context.poppyTheme;
    final fp = context.read<ThemeProvider>().currentFontPairData;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: _focused ? t.accent : t.border,
          width: _focused ? AppStroke.medium : AppStroke.hairline,
        ),
      ),
      child: TextField(
        controller:   widget.controller,
        focusNode:    _internalFocus,
        obscureText:  widget.obscureText,
        keyboardType: widget.keyboardType,
        style: AppTextStyles.bodyMedium(t.textPrimary, fp),
        decoration: InputDecoration(
          labelText:  widget.label,
          labelStyle: AppTextStyles.bodySmallSans(
              _focused ? t.accent : t.textTertiary, fp),
          suffixIcon: widget.suffixIcon,
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
  final String       label;
  final bool         isLoading;
  final VoidCallback onPressed;
  const _SubmitButton({
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        child: isLoading
            ? const SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(
              strokeWidth: AppSpacing.xxs, color: Colors.white),
        )
            : Text(label),
      ),
    );
  }
}