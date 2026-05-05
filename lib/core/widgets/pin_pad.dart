import 'package:flutter/material.dart';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/theme/themes.dart';
import 'dart:math' as math;

// ─────────────────────────────────────────────────────────────
//  POPPY — PIN Pad Widget
//  Location: lib/core/widgets/pin_pad.dart
//
//  A clean 4-digit PIN entry pad.
//  Shows dot indicators at the top and a 3x4 number grid.
//  Used by both LockScreen and SecurityScreen.
// ─────────────────────────────────────────────────────────────

class PinPad extends StatefulWidget {
  /// Called with the 4-digit PIN string when all 4 digits
  /// have been entered.
  final ValueChanged<String> onComplete;

  /// Optional label shown above the dot indicators.
  final String label;

  /// If true, shows an error shake animation and clears
  /// the input — set this to true then back to false
  /// from the parent to trigger the shake.
  final bool hasError;

  const PinPad({
    super.key,
    required this.onComplete,
    this.label = 'Enter your PIN',
    this.hasError = false,
  });

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad>
    with SingleTickerProviderStateMixin {
  String _input = '';
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  @override
  void didUpdateWidget(PinPad old) {
    super.didUpdateWidget(old);
    if (widget.hasError && !old.hasError) {
      _triggerError();
    }
  }

  Future<void> _triggerError() async {
    await _shakeController.forward();
    _shakeController.reset();
    setState(() => _input = '');
  }

  void _onDigit(String digit) {
    if (_input.length >= 4) return;
    setState(() => _input += digit);
    if (_input.length == 4) {
      widget.onComplete(_input);
    }
  }

  void _onDelete() {
    if (_input.isEmpty) return;
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Label ─────────────────────────────────────────
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 14,
            color: t.textSecondary,
            letterSpacing: 0.2,
          ),
        ),

        const SizedBox(height: kSpaceLG),

        // ── Dot indicators ────────────────────────────────
        AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            final offset = math_sin(_shakeAnimation.value * math.pi * 6) * 8;
            return Transform.translate(
              offset: Offset(offset, 0),
              child: child,
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) {
              final filled = i < _input.length;
              return AnimatedContainer(
                duration: kAnimFast,
                width: 12,
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled ? t.accent : Colors.transparent,
                  border: Border.all(
                    color: filled ? t.accent : t.border,
                    width: 1.5,
                  ),
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: kSpaceXL),

        // ── Number grid ────────────────────────────────────
        SizedBox(
          width: 240,
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: kSpaceMD,
            crossAxisSpacing: kSpaceMD,
            children: [
              ...'123456789'.split('').map(
                    (d) => _DigitKey(
                  digit: d,
                  onTap: () => _onDigit(d),
                ),
              ),
              // Empty cell bottom-left
              const SizedBox.shrink(),
              _DigitKey(digit: '0', onTap: () => _onDigit('0')),
              // Delete button bottom-right
              _DeleteKey(onTap: _onDelete),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Individual digit key ──────────────────────────────────────

class _DigitKey extends StatelessWidget {
  final String digit;
  final VoidCallback onTap;

  const _DigitKey({required this.digit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: t.surface,
          border: Border.all(color: t.border, width: 0.5),
        ),
        child: Center(
          child: Text(
            digit,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w400,
              color: t.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Delete key ────────────────────────────────────────────────

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
          child: Icon(
            Icons.backspace_outlined,
            size: 20,
            color: t.textTertiary,
          ),
        ),
      ),
    );
  }
}

// ── math helpers (avoid dart:math import in build) ────────────

double math_sin(double x) => math.sin(x);