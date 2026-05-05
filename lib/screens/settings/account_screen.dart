import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/theme/themes.dart';
import 'package:poppy/providers/auth_provider.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Account Screen
//  Location: lib/screens/settings/account_screen.dart
//
//  Lets the user update their email or password.
//  One action at a time — no wall of fields.
// ─────────────────────────────────────────────────────────────

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  // Which panel is open: null = none, 'email', 'password'
  String? _openPanel;

  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ── Update email ──────────────────────────────────────────

  Future<void> _onUpdateEmail() async {
    final auth = context.read<AuthProvider>();
    auth.clearError();

    final success = await auth.updateEmail(_emailController.text);
    if (!mounted) return;

    if (success) {
      setState(() => _openPanel = null);
      _emailController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Check your new email for a confirmation link.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Update password ───────────────────────────────────────

  Future<void> _onUpdatePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_newPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    auth.clearError();

    final success =
    await auth.updatePassword(_newPasswordController.text);
    if (!mounted) return;

    if (success) {
      setState(() => _openPanel = null);
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              size: 18, color: t.textSecondary),
          onPressed: () => context.pop(),
        ),
        title: Text('Account',
            style: TextStyle(fontSize: 18, color: t.textPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(kSpaceLG),
        children: [
          // ── Current email ─────────────────────────────────
          Text(
            'Signed in as',
            style: TextStyle(fontSize: 11, color: t.textTertiary,
                letterSpacing: 0.5),
          ),
          const SizedBox(height: kSpaceXS),
          Text(
            auth.user?.email ?? '—',
            style: TextStyle(
              fontSize: 15,
              color: t.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: kSpaceLG),

          // ── Change email ──────────────────────────────────
          _ExpandableSection(
            title: 'Change email',
            icon: Icons.email_outlined,
            isOpen: _openPanel == 'email',
            onToggle: () => setState(() =>
            _openPanel = _openPanel == 'email' ? null : 'email'),
            child: Column(
              children: [
                _Field(
                  controller: _emailController,
                  label: 'New email address',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: kSpaceMD),
                if (auth.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: kSpaceSM),
                    child: Text(auth.errorMessage!,
                        style: TextStyle(fontSize: 13, color: t.accent)),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: auth.isLoading ? null : _onUpdateEmail,
                    style: FilledButton.styleFrom(
                      backgroundColor: t.accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(kRadiusMD),
                      ),
                    ),
                    child: auth.isLoading
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                        : const Text('Update email'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: kSpaceSM),

          // ── Change password ───────────────────────────────
          _ExpandableSection(
            title: 'Change password',
            icon: Icons.key_outlined,
            isOpen: _openPanel == 'password',
            onToggle: () => setState(() =>
            _openPanel = _openPanel == 'password' ? null : 'password'),
            child: Column(
              children: [
                _Field(
                  controller: _newPasswordController,
                  label: 'New password',
                  obscureText: _obscureNew,
                  suffixIcon: _VisibilityToggle(
                    obscure: _obscureNew,
                    onToggle: () =>
                        setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
                const SizedBox(height: kSpaceSM),
                _Field(
                  controller: _confirmPasswordController,
                  label: 'Confirm new password',
                  obscureText: _obscureConfirm,
                  suffixIcon: _VisibilityToggle(
                    obscure: _obscureConfirm,
                    onToggle: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                const SizedBox(height: kSpaceMD),
                if (auth.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: kSpaceSM),
                    child: Text(auth.errorMessage!,
                        style: TextStyle(fontSize: 13, color: t.accent)),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed:
                    auth.isLoading ? null : _onUpdatePassword,
                    style: FilledButton.styleFrom(
                      backgroundColor: t.accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(kRadiusMD),
                      ),
                    ),
                    child: auth.isLoading
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                        : const Text('Update password'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Expandable section ─────────────────────────────────────────

class _ExpandableSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isOpen;
  final VoidCallback onToggle;
  final Widget child;

  const _ExpandableSection({
    required this.title,
    required this.icon,
    required this.isOpen,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;

    return AnimatedContainer(
      duration: kAnimNormal,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(kRadiusMD),
        border: Border.all(
          color: isOpen ? t.accent.withOpacity(0.4) : t.border,
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          // Header row
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(kRadiusMD),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: kSpaceMD, vertical: kSpaceMD),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: t.textTertiary),
                  const SizedBox(width: kSpaceMD),
                  Expanded(
                    child: Text(title,
                        style: TextStyle(
                            fontSize: 14, color: t.textPrimary)),
                  ),
                  Icon(
                    isOpen
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                    color: t.textTertiary,
                  ),
                ],
              ),
            ),
          ),

          // Expandable content
          AnimatedCrossFade(
            duration: kAnimNormal,
            crossFadeState: isOpen
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(
                  kSpaceMD, 0, kSpaceMD, kSpaceMD),
              child: Column(
                children: [
                  Divider(height: kSpaceMD, color: t.border, thickness: 0.5),
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
        color: t.background,
        borderRadius: BorderRadius.circular(kRadiusSM),
        border: Border.all(color: t.border, width: 0.5),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: TextStyle(fontSize: 14, color: t.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 12, color: t.textTertiary),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: kSpaceMD, vertical: kSpaceSM),
        ),
      ),
    );
  }
}

// ── Visibility toggle icon ─────────────────────────────────────

class _VisibilityToggle extends StatelessWidget {
  final bool obscure;
  final VoidCallback onToggle;

  const _VisibilityToggle({required this.obscure, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    return IconButton(
      icon: Icon(
        obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: 18,
        color: t.textTertiary,
      ),
      onPressed: onToggle,
    );
  }
}