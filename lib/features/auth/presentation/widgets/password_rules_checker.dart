import 'package:flutter/material.dart';
import 'package:poppy/core/core.dart';
import 'package:poppy/features/settings/presentation/providers/theme_provider.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Password Rules Checker
// ─────────────────────────────────────────────────────────────

/// A widget that displays a list of password requirements and 
/// live-updates their status as the user types.
class PasswordRulesChecker extends StatefulWidget {
  /// The controller of the password text field to monitor.
  final TextEditingController controller;

  const PasswordRulesChecker({super.key, required this.controller});

  @override
  State<PasswordRulesChecker> createState() => _PasswordRulesCheckerState();
}

class _PasswordRulesCheckerState extends State<PasswordRulesChecker>
    with SingleTickerProviderStateMixin {
  String _password = '';

  @override
  void initState() {
    super.initState();
    _password = widget.controller.text;
    widget.controller.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    final newValue = widget.controller.text;
    if (newValue == _password) return;
    setState(() => _password = newValue);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onPasswordChanged);
    super.dispose();
  }

  static const _rules = [
    _Rule('At least 8 characters', r'.{8,}'),
    _Rule('One uppercase letter (A–Z)', r'[A-Z]'),
    _Rule('One lowercase letter (a–z)', r'[a-z]'),
    _Rule('One number (0–9)', r'\d'),
    _Rule('One symbol (!@#\$%^&*…)', r'[!@#\$%^&*()\,.?":{}|<>_\-+=\[\]\\;/~`]'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final fp = context.read<ThemeProvider>().currentFontPairData;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: t.border, width: AppStroke.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password requirements',
            style: AppTextStyles.labelLargeSans(t.textTertiary, fp),
          ),
          const SizedBox(height: AppSpacing.sm),
          ..._rules.map((rule) => _RuleRow(
            rule: rule,
            password: _password,
            fp: fp,
            t: t,
          )),
        ],
      ),
    );
  }
}

class _Rule {
  final String label;
  final String pattern;
  const _Rule(this.label, this.pattern);

  bool isMet(String password) => RegExp(pattern).hasMatch(password);
}

class _RuleRow extends StatelessWidget {
  final _Rule rule;
  final String password;
  final FontPairData fp;
  final PoppyThemeExtension t;

  const _RuleRow({
    required this.rule,
    required this.password,
    required this.fp,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final met = rule.isMet(password);

    final iconColor = met ? AppColors.success : t.textTertiary;
    final textColor = met ? AppColors.success : t.textTertiary;
    final icon = met ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: anim,
              child: child,
            ),
            child: Icon(
              icon,
              key: ValueKey(met),
              size: AppIconSize.xs,
              color: iconColor,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            rule.label,
            style: AppTextStyles.labelLargeSans(textColor, fp),
          ),
        ],
      ),
    );
  }
}