import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/theme/themes.dart';
import 'package:poppy/core/widgets/pin_pad.dart';
import 'package:poppy/providers/auth_provider.dart';
import 'package:poppy/services/pin_service.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Security Screen
//  Location: lib/screens/settings/security_screen.dart
//
//  Toggle PIN lock on/off and change the PIN.
//  Steps through a small flow rather than showing
//  everything at once.
// ─────────────────────────────────────────────────────────────

enum _PinStep { idle, setNew, confirmNew, changeOld, changeNew, changeConfirm }

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _pinService = PinService();

  _PinStep _step = _PinStep.idle;
  String _firstPin = '';
  bool _hasError = false;

  // ── Toggle PIN on / off ───────────────────────────────────

  Future<void> _onTogglePin(bool enabled) async {
    if (enabled) {
      // Start the set-new-PIN flow
      setState(() => _step = _PinStep.setNew);
    } else {
      await _pinService.removePin();
      await context.read<AuthProvider>().setPinEnabled(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PIN lock removed.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Set new PIN flow ──────────────────────────────────────

  Future<void> _onSetNewPin(String pin) async {
    if (_step == _PinStep.setNew) {
      // First entry — store and ask to confirm
      setState(() {
        _firstPin = pin;
        _step = _PinStep.confirmNew;
      });
      return;
    }

    if (_step == _PinStep.confirmNew) {
      if (pin == _firstPin) {
        // Match — save PIN
        await _pinService.savePin(pin);
        await context.read<AuthProvider>().setPinEnabled(true);
        if (mounted) {
          setState(() => _step = _PinStep.idle);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PIN lock enabled.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        // Mismatch — shake and restart
        setState(() => _hasError = true);
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          setState(() {
            _hasError = false;
            _firstPin = '';
            _step = _PinStep.setNew;
          });
        }
      }
      return;
    }
  }

  // ── Change PIN flow ───────────────────────────────────────

  Future<void> _onChangePinStep(String pin) async {
    if (_step == _PinStep.changeOld) {
      final correct = await _pinService.verify(pin);
      if (correct) {
        setState(() => _step = _PinStep.changeNew);
      } else {
        setState(() => _hasError = true);
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) setState(() => _hasError = false);
      }
      return;
    }

    if (_step == _PinStep.changeNew) {
      setState(() {
        _firstPin = pin;
        _step = _PinStep.changeConfirm;
      });
      return;
    }

    if (_step == _PinStep.changeConfirm) {
      if (pin == _firstPin) {
        await _pinService.savePin(pin);
        if (mounted) {
          setState(() => _step = _PinStep.idle);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PIN updated.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        setState(() => _hasError = true);
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          setState(() {
            _hasError = false;
            _firstPin = '';
            _step = _PinStep.changeNew;
          });
        }
      }
    }
  }

  // ── Route PIN pad input to correct handler ────────────────

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

  String get _pinLabel {
    switch (_step) {
      case _PinStep.setNew:
        return 'Choose a 4-digit PIN';
      case _PinStep.confirmNew:
        return 'Confirm your PIN';
      case _PinStep.changeOld:
        return 'Enter your current PIN';
      case _PinStep.changeNew:
        return 'Choose a new PIN';
      case _PinStep.changeConfirm:
        return 'Confirm your new PIN';
      case _PinStep.idle:
        return '';
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
          onPressed: _step == _PinStep.idle
              ? () => context.pop()
              : () => setState(() {
            _step = _PinStep.idle;
            _firstPin = '';
          }),
        ),
        title: Text('Security',
            style: TextStyle(fontSize: 18, color: t.textPrimary)),
      ),
      body: _step == _PinStep.idle
          ? _buildIdleView(context, t, auth)
          : _buildPinPadView(context, t),
    );
  }

  // ── Idle view — toggle + change ───────────────────────────

  Widget _buildIdleView(
      BuildContext context,
      PoppyThemeExtension t,
      AuthProvider auth,
      ) {
    return ListView(
      padding: const EdgeInsets.all(kSpaceLG),
      children: [
        // ── PIN toggle ──────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(kRadiusMD),
            border: Border.all(color: t.border, width: 0.5),
          ),
          child: SwitchListTile(
            title: Text('PIN lock',
                style: TextStyle(fontSize: 14, color: t.textPrimary)),
            subtitle: Text(
              'Require a PIN when opening Poppy.',
              style: TextStyle(fontSize: 12, color: t.textTertiary),
            ),
            value: auth.pinEnabled,
            activeColor: t.accent,
            onChanged: _onTogglePin,
          ),
        ),

        // ── Change PIN (only shown when PIN is active) ──────
        if (auth.pinEnabled) ...[
          const SizedBox(height: kSpaceSM),
          Container(
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(kRadiusMD),
              border: Border.all(color: t.border, width: 0.5),
            ),
            child: InkWell(
              onTap: () => setState(() => _step = _PinStep.changeOld),
              borderRadius: BorderRadius.circular(kRadiusMD),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: kSpaceMD, vertical: kSpaceMD),
                child: Row(
                  children: [
                    Icon(Icons.pin_outlined,
                        size: 20, color: t.textTertiary),
                    const SizedBox(width: kSpaceMD),
                    Expanded(
                      child: Text('Change PIN',
                          style: TextStyle(
                              fontSize: 14, color: t.textPrimary)),
                    ),
                    Icon(Icons.chevron_right,
                        size: 18, color: t.textTertiary),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── PIN pad view ──────────────────────────────────────────

  Widget _buildPinPadView(BuildContext context, PoppyThemeExtension t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: kSpaceLG),
        child: PinPad(
          label: _pinLabel,
          hasError: _hasError,
          onComplete: _onPinComplete,
        ),
      ),
    );
  }
}