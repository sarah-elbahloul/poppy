import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:poppy/core/style/style.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — PIN Pad Widget
//  Location: lib/core/widgets/pin_pad.dart
//
//  A 4-digit PIN entry pad.
//
//  Two modes controlled by [autoSubmit]:
//    autoSubmit = true  (default for lock screen)
//      → onComplete fires automatically when 4 digits entered.
//        Used on the lock screen where the user just wants
//        to get in quickly.
//    autoSubmit = false (used in security settings)
//      → A confirm button appears after 4 digits are entered.
//        The user must tap it to confirm. This prevents
//        accidental PIN setting from a mistyped digit.
// ─────────────────────────────────────────────────────────────

class PinPad extends StatefulWidget {
  final ValueChanged<String> onComplete;
  final String label;
  final bool   hasError;

  /// When true, fires onComplete as soon as the 4th digit
  /// is entered (lock screen behaviour).
  /// When false, shows a confirm button the user must tap
  /// (security settings behaviour).
  final bool autoSubmit;

  const PinPad({
    super.key,
    required this.onComplete,
    this.label      = 'Enter your PIN',
    this.hasError   = false,
    this.autoSubmit = true,
  });

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad>
    with SingleTickerProviderStateMixin {
  String _input = '';
  late AnimationController _shakeController;
  late Animation<double>   _shakeAnimation;

  bool get _isComplete => _input.length == 4;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync:    this,
      duration: AppDuration.shake,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: AppCurve.spring),
    );
  }

  @override
  void didUpdateWidget(PinPad old) {
    super.didUpdateWidget(old);
    if (widget.hasError && !old.hasError) _triggerError();
  }

  Future<void> _triggerError() async {
    await _shakeController.forward();
    _shakeController.reset();
    setState(() => _input = '');
  }

  void _onDigit(String digit) {
    if (_input.length >= 4) return;
    setState(() => _input += digit);

    // Auto-submit mode: fire immediately on 4th digit
    if (widget.autoSubmit && _input.length == 4) {
      widget.onComplete(_input);
    }
  }

  void _onDelete() {
    if (_input.isEmpty) return;
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  void _onConfirm() {
    if (!_isComplete) return;
    widget.onComplete(_input);
    // Reset after confirm so the pad is ready for a fresh entry
    // (e.g. confirmation step in set-PIN flow)
    setState(() => _input = '');
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final fp = context.read<ThemeProvider>().currentFontPairData;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label
        Text(widget.label, style: AppTextStyles.titleSmallSans(t.textSecondary,fp)),

        const SizedBox(height: AppSpacing.lg),

        // Dot indicators with shake animation
        AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (_, child) => Transform.translate(
            offset: Offset(
              math.sin(_shakeAnimation.value * math.pi * 6) * 8, 0,
            ),
            child: child,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) {
              final filled = i < _input.length;
              return AnimatedContainer(
                duration: AppDuration.fast,
                width:  AppComponentSize.pinDot,
                height: AppComponentSize.pinDot,
                margin: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled ? t.accent : AppColors.transparent,
                  border: Border.all(
                    color: filled ? t.accent : t.border,
                    width: AppStroke.medium,
                  ),
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // Number grid
        SizedBox(
          width: 240,
          child: GridView.count(
            crossAxisCount:  3,
            shrinkWrap:      true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing:  AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            children: [
              ...'123456789'.split('').map(
                    (d) => _DigitKey(digit: d, onTap: () => _onDigit(d)),
              ),
              const SizedBox.shrink(), // empty bottom-left
              _DigitKey(digit: '0', onTap: () => _onDigit('0')),
              _DeleteKey(onTap: _onDelete),
            ],
          ),
        ),

        // Confirm button — only shown in manual mode when all 4 digits entered
        if (!widget.autoSubmit) ...[
          const SizedBox(height: AppSpacing.lg),
          AnimatedOpacity(
            duration: AppDuration.normal,
            opacity: _isComplete ? 1.0 : 0.0,
            child: SizedBox(
              width: 240,
              child: FilledButton(
                onPressed: _isComplete ? _onConfirm : null,
                style: FilledButton.styleFrom(
                  backgroundColor: t.accent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                child: Text(
                  'Confirm',
                  style: AppTextStyles.titleSmallSans(AppColors.white,fp),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Digit key ──────────────────────────────────────────────────

class _DigitKey extends StatelessWidget {
  final String digit;
  final VoidCallback onTap;
  const _DigitKey({required this.digit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final fp = context.read<ThemeProvider>().currentFontPairData;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          shape:  BoxShape.circle,
          color:  t.surface,
          border: Border.all(color: t.border, width: AppStroke.hairline),
        ),
        child: Center(
          child: Text(digit,
              style: AppTextStyles.pinDigit(t.textPrimary,fp)),
        ),
      ),
    );
  }
}

// ── Delete key ─────────────────────────────────────────────────

class _DeleteKey extends StatelessWidget {
  final VoidCallback onTap;
  const _DeleteKey({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: Center(
          child: Icon(AppIcons.backspace,
              size: AppIconSize.sm, color: t.textTertiary),
        ),
      ),
    );
  }
}