import 'package:flutter/material.dart';
import 'package:poppy/core/style/style.dart';
import 'package:poppy/core/widgets/pin_pad.dart';
import 'package:poppy/providers/auth_provider.dart';
import 'package:poppy/services/pin_service.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Security Screen
//  Location: lib/screens/settings/security_screen.dart
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

  // ── Toggle PIN ────────────────────────────────────────────

  Future<void> _onTogglePin(bool enabled) async {
    if (enabled) {
      setState(() => _step = _PinStep.setNew);
    } else {
      await _pinService.removePin();
      await context.read<AuthProvider>().setPinEnabled(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN lock removed.')),
        );
      }
    }
  }

  // ── Set new PIN flow ──────────────────────────────────────

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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PIN lock enabled.')),
          );
        }
      } else {
        await _shake();
        setState(() {
          _firstPin = '';
          _step     = _PinStep.setNew;
        });
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PIN updated.')),
          );
        }
      } else {
        await _shake();
        setState(() {
          _firstPin = '';
          _step     = _PinStep.changeNew;
        });
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

  String get _pinLabel => switch (_step) {
    _PinStep.setNew       => 'Choose a 4-digit PIN',
    _PinStep.confirmNew   => 'Confirm your PIN',
    _PinStep.changeOld    => 'Enter your current PIN',
    _PinStep.changeNew    => 'Choose a new PIN',
    _PinStep.changeConfirm => 'Confirm your new PIN',
    _PinStep.idle         => '',
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
              ? () => Navigator.pop(context)
              : () => setState(() {
            _step     = _PinStep.idle;
            _firstPin = '';
          }),
        ),
        title: Text('Security',
            style: AppTextStyles.appBarTitle(t.textPrimary)),
      ),
      body: _step == _PinStep.idle
          ? _buildIdleView(context, t, auth)
          : _buildPinPadView(context, t),
    );
  }

  Widget _buildIdleView(
      BuildContext context, PoppyThemeExtension t, AuthProvider auth) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // PIN toggle
        Container(
          decoration: BoxDecoration(
            color:        t.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border:       Border.all(
                color: t.border, width: AppStroke.hairline),
          ),
          child: SwitchListTile(
            title: Text('PIN lock',
                style: AppTextStyles.settingsRowLabel(t.textPrimary)),
            subtitle: Text(
              'Require a PIN when opening Poppy.',
              style: AppTextStyles.settingsRowSublabel(t.textTertiary),
            ),
            value:       auth.pinEnabled,
            activeColor: t.accent,
            onChanged:   _onTogglePin,
          ),
        ),

        // Change PIN (only when PIN is enabled)
        if (auth.pinEnabled) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(
              color:        t.surface,
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
                  horizontal: AppSpacing.md,
                  vertical:   AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Icon(AppIcons.pin,
                        size:  AppIconSize.sm,
                        color: t.textTertiary),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text('Change PIN',
                          style: AppTextStyles.settingsRowLabel(
                              t.textPrimary)),
                    ),
                    Icon(AppIcons.chevronRight,
                        size:  AppIconSize.xs,
                        color: t.textTertiary),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPinPadView(
      BuildContext context, PoppyThemeExtension t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg),
        child: PinPad(
          label:      _pinLabel,
          hasError:   _hasError,
          onComplete: _onPinComplete,
        ),
      ),
    );
  }
}
