import 'package:flutter/material.dart';
import 'package:poppy/core/core.dart';
import 'package:poppy/core/widgets/widgets.dart';
import 'package:poppy/providers/providers.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Set New Password Screen
//  Location: lib/screens/auth/set_new_password_screen.dart
// ─────────────────────────────────────────────────────────────

/// Shown when AuthStatus == passwordRecovery (user tapped the
/// Supabase reset email link).
///
/// The user enters a new password and confirms it.
/// [completePasswordReset] handles key recovery silently:
/// 1. Key in memory (same device)  → re-wrap directly.
/// 2. Recovery key in DB           → unwrap with uid, re-wrap with new pw.
/// 3. Neither (legacy account)     → generate fresh key (last resort).
class SetNewPasswordScreen extends StatefulWidget {
  const SetNewPasswordScreen({super.key});

  @override
  State<SetNewPasswordScreen> createState() => _SetNewPasswordScreenState();
}

class _SetNewPasswordScreenState extends State<SetNewPasswordScreen> {
  final _newPassController     = TextEditingController();
  final _confirmPassController = TextEditingController();
  final _newPassFocus          = FocusNode();

  bool _obscureNew     = true;
  bool _obscureConfirm = true;
  bool _newPassFocused = false;

  @override
  void initState() {
    super.initState();
    _newPassFocus.addListener(() {
      setState(() => _newPassFocused = _newPassFocus.hasFocus);
    });
  }

  @override
  void dispose() {
    _newPassController.dispose();
    _confirmPassController.dispose();
    _newPassFocus.dispose();
    super.dispose();
  }

  // ─── Actions ───

  Future<void> _onSubmit() async {
    final passErr = AppErrors.validatePassword(_newPassController.text);
    if (passErr != null) {
      AppSnackbar.error(context, passErr);
      return;
    }

    final confirmErr = AppErrors.validateConfirm(
      _newPassController.text, _confirmPassController.text,
    );
    if (confirmErr != null) {
      AppSnackbar.error(context, confirmErr);
      return;
    }

    context.read<AuthProvider>().clearError();
    await context.read<AuthProvider>().completePasswordReset(
      _newPassController.text,
    );
    // Navigation handled by _RootRouter watching AuthStatus.
  }

  @override
  Widget build(BuildContext context) {
    final t    = context.poppyTheme;
    final auth = context.watch<AuthProvider>();
    final fp   = context.read<ThemeProvider>().currentFontPairData;

    final showChecker = _newPassFocused ||
        _newPassController.text.isNotEmpty;

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
              const Center(child: PoppyLogo(size: AppIconSize.logo)),
              const SizedBox(height: AppSpacing.xl * 1.5),
              Text('Set new password',
                  style: AppTextStyles.headlineSmall(t.textPrimary, fp)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Choose a strong password. Your diary entries will stay intact.',
                style: AppTextStyles.bodySmallSans(t.textTertiary, fp)
                    .copyWith(height: 1.6),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── New password + live rules ──────────────────
              _Field(
                controller:  _newPassController,
                label:       'New password',
                obscureText: _obscureNew,
                focusNode:   _newPassFocus,
                suffixIcon: _VisToggle(
                  obscure:  _obscureNew,
                  onToggle: () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),

              AnimatedSize(
                duration: AppDuration.normal,
                curve:    Curves.easeOutCubic,
                child: showChecker
                    ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: PasswordRulesChecker(
                    controller: _newPassController,
                  ),
                )
                    : const SizedBox.shrink(),
              ),

              const SizedBox(height: AppSpacing.sm),

              // ── Confirm password ───────────────────────────
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

// ─────────────────────────────────────────────────────────────
//  Private sub-widgets
// ─────────────────────────────────────────────────────────────

class _Field extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final Widget? suffixIcon;
  final FocusNode? focusNode;

  const _Field({
    required this.controller,
    required this.label,
    this.obscureText = false,
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
        controller:  widget.controller,
        focusNode:   _internalFocus,
        obscureText: widget.obscureText,
        style: AppTextStyles.bodyMedium(t.textPrimary, fp),
        decoration: InputDecoration(
          labelText:  widget.label,
          labelStyle: AppTextStyles.bodySmallSans(
              _focused ? t.accent : t.textTertiary, fp),
          suffixIcon: widget.suffixIcon,
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
    final fp = context.read<ThemeProvider>().currentFontPairData;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
            color: AppColors.errorMuted, width: AppStroke.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(AppIcons.warning, size: AppIconSize.xs, color: AppColors.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(message,
                style: AppTextStyles.bodySmallSans(AppColors.error, fp)
                    .copyWith(height: 1.4)),
          ),
        ],
      ),
    );
  }
}