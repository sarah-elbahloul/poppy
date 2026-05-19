import 'package:flutter/material.dart';
import 'package:poppy/core/error_messages.dart';
import 'package:poppy/core/style/style.dart';
import 'package:poppy/core/widgets/pin_pad.dart';
import 'package:poppy/providers/auth_provider.dart';
import 'package:poppy/services/pin_service.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Security Screen
//  Location: lib/screens/settings/security_screen.dart
//
//  PIN pad uses autoSubmit = false so the user must tap
//  the Confirm button explicitly. This prevents accidental
//  PIN setting from a mistyped 4th digit.
// ─────────────────────────────────────────────────────────────

enum _PinStep {
  idle,
  setNew,
  confirmNew,
  changeOld,
  changeNew,
  changeConfirm,
}

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _pinService = PinService();

  _PinStep _step     = _PinStep.idle;
  String   _firstPin = '';
  bool     _hasError = false;

  // ── Toggle PIN on/off ─────────────────────────────────────

  Future<void> _onTogglePin(bool enabled) async {
    if (enabled) {
      setState(() => _step = _PinStep.setNew);
    } else {
      await _pinService.removePin();
      await context.read<AuthProvider>().setPinEnabled(false);
      if (mounted) _showSnack('PIN lock removed.');
    }
  }

  // ── Set PIN flow ──────────────────────────────────────────

  Future<void> _onSetNewPin(String pin) async {
    if (_step == _PinStep.setNew) {
      setState(() {
        _firstPin = pin;
        _step     = _PinStep.confirmNew;
      });
      return;
    }
    if (_step == _PinStep.confirmNew) {
      if (pin == _firstPin) {
        await _pinService.savePin(pin);
        await context.read<AuthProvider>().setPinEnabled(true);
        if (mounted) {
          setState(() => _step = _PinStep.idle);
          _showSnack('PIN lock enabled.');
        }
      } else {
        // Mismatch — show error, restart from setNew
        await _shake();
        if (mounted) {
          setState(() {
            _firstPin = '';
            _step     = _PinStep.setNew;
          });
          _showSnack(AppErrors.pinMismatch);
        }
      }
    }
  }

  // ── Change PIN flow ───────────────────────────────────────

  Future<void> _onChangePinStep(String pin) async {
    if (_step == _PinStep.changeOld) {
      final correct = await _pinService.verify(pin);
      if (correct) {
        setState(() => _step = _PinStep.changeNew);
      } else {
        await _shake();
        if (mounted) _showSnack(AppErrors.pinIncorrect);
      }
      return;
    }
    if (_step == _PinStep.changeNew) {
      setState(() {
        _firstPin = pin;
        _step     = _PinStep.changeConfirm;
      });
      return;
    }
    if (_step == _PinStep.changeConfirm) {
      if (pin == _firstPin) {
        await _pinService.savePin(pin);
        if (mounted) {
          setState(() => _step = _PinStep.idle);
          _showSnack('PIN updated successfully.');
        }
      } else {
        await _shake();
        if (mounted) {
          setState(() {
            _firstPin = '';
            _step     = _PinStep.changeNew;
          });
          _showSnack(AppErrors.pinMismatch);
        }
      }
    }
  }

  Future<void> _shake() async {
    setState(() => _hasError = true);
    await Future.delayed(AppDuration.errorReset);
    if (mounted) setState(() => _hasError = false);
  }

  void _onPinComplete(String pin) {
    switch (_step) {
      case _PinStep.setNew:
      case _PinStep.confirmNew:
        _onSetNewPin(pin);
        break;
      case _PinStep.changeOld:
      case _PinStep.changeNew:
      case _PinStep.changeConfirm:
        _onChangePinStep(pin);
        break;
      case _PinStep.idle:
        break;
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String get _pinLabel => switch (_step) {
    _PinStep.setNew        => 'Choose a 4-digit PIN',
    _PinStep.confirmNew    => 'Confirm your PIN',
    _PinStep.changeOld     => 'Enter your current PIN',
    _PinStep.changeNew     => 'Choose a new PIN',
    _PinStep.changeConfirm => 'Confirm your new PIN',
    _PinStep.idle          => '',
  };

  String get _stepSubtitle => switch (_step) {
    _PinStep.setNew        => 'You will confirm it on the next step.',
    _PinStep.confirmNew    => 'Enter the same PIN again to confirm.',
    _PinStep.changeOld     => 'Enter your existing PIN to continue.',
    _PinStep.changeNew     => 'Choose a new 4-digit PIN.',
    _PinStep.changeConfirm => 'Enter the new PIN again to confirm.',
    _PinStep.idle          => '',
  };

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
          onPressed: _step == _PinStep.idle
              ? () => Navigator.of(context).pop()
              : () => setState(() {
            _step     = _PinStep.idle;
            _firstPin = '';
          }),
        ),
        title: Text('Security',
            style: AppTextStyles.titleLarge(t.textPrimary)),
      ),
      body: _step == _PinStep.idle
          ? _buildIdleView(context, t, auth)
          : _buildPinView(context, t),
    );
  }

  // ── Idle view ─────────────────────────────────────────────

  Widget _buildIdleView(
      BuildContext context,
      PoppyThemeExtension t,
      AuthProvider auth,
      ) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // Toggle
        Container(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: t.border, width: AppStroke.hairline),
          ),
          child: SwitchListTile(
            title: Text('PIN lock',
                style: AppTextStyles.titleSmallSans(t.textPrimary)),
            subtitle: Text(
              'Require a 4-digit PIN when opening Poppy.',
              style: AppTextStyles.labelLargeSans(t.textTertiary),
            ),
            value:       auth.pinEnabled,
            activeColor: t.accent,
            onChanged:   _onTogglePin,
          ),
        ),

        // Change PIN — only when enabled
        if (auth.pinEnabled) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                  color: t.border, width: AppStroke.hairline),
            ),
            child: InkWell(
              onTap: () =>
                  setState(() => _step = _PinStep.changeOld),
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Icon(AppIcons.pin,
                        size: AppIconSize.sm, color: t.textTertiary),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text('Change PIN',
                          style: AppTextStyles.titleSmallSans(
                              t.textPrimary)),
                    ),
                    Icon(AppIcons.chevronRight,
                        size: AppIconSize.xs, color: t.textTertiary),
                  ],
                ),
              ),
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.xl),

        // Info note
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: t.accentLight,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
                color: t.accent.withOpacity(0.2),
                width: AppStroke.hairline),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(AppIcons.info,
                  size: AppIconSize.xs, color: t.accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'The PIN protects access to the app on this device. '
                      'Your entries are encrypted separately with your account password.',
                  style: AppTextStyles.labelLargeSans(t.accent),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── PIN pad view ──────────────────────────────────────────

  Widget _buildPinView(BuildContext context, PoppyThemeExtension t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Step subtitle for clarity
            if (_stepSubtitle.isNotEmpty) ...[
              Text(
                _stepSubtitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmallSans(t.textTertiary),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            PinPad(
              label:       _pinLabel,
              hasError:    _hasError,
              onComplete:  _onPinComplete,
              autoSubmit:  false, // ← user must tap Confirm explicitly
            ),
          ],
        ),
      ),
    );
  }
}