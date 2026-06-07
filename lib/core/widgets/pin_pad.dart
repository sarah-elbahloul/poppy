import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:poppy/core/style/style.dart';
import 'package:provider/provider.dart';
import 'package:poppy/providers/theme_provider.dart';

/// A 4-digit PIN entry pad widget.
///
/// Supports two modes:
/// - **Auto-submit:** Automatically triggers [onComplete] when the 4th digit is entered.
/// - **Manual-submit:** Displays a "Confirm" button after 4 digits are entered.
class PinPad extends StatefulWidget {
  final ValueChanged<String> onComplete;
  final String label;
  final bool   hasError;

  /// Whether to automatically submit after 4 digits.
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
        Text(widget.label, style: AppTextStyles.titleSmallSans(t.textSecondary, fp)),

        const SizedBox(height: AppSpacing.lg),

        // Dot indicators with shake animation on error.
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

        // 3x4 grid for numbers and backspace.
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
              const SizedBox.shrink(),
              _DigitKey(digit: '0', onTap: () => _onDigit('0')),
              _DeleteKey(onTap: _onDelete),
            ],
          ),
        ),

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
                  style: AppTextStyles.titleSmallSans(AppColors.white, fp),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

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
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          shape:  BoxShape.circle,
          color:  t.surface,
          border: Border.all(color: t.border, width: AppStroke.hairline),
        ),
        child: Center(
          child: Text(digit,
              style: AppTextStyles.pinDigit(t.textPrimary, fp)),
        ),
      ),
    );
  }
}

class _DeleteKey extends StatelessWidget {
  final VoidCallback onTap;
  const _DeleteKey({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
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
