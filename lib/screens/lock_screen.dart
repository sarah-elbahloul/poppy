import 'package:flutter/material.dart';
import 'package:poppy/core/app_routes.dart';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/style/style.dart';
import 'package:poppy/core/widgets/pin_pad.dart';
import 'package:poppy/core/widgets/poppy_logo.dart';
import 'package:poppy/providers/auth_provider.dart';
import 'package:poppy/services/pin_service.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Lock Screen
//  Location: lib/screens/lock_screen.dart
// ─────────────────────────────────────────────────────────────

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _pinService = PinService();
  bool _hasError = false;

  Future<void> _onPinComplete(String pin) async {
    final isCorrect = await _pinService.verify(pin);
    if (!mounted) return;

    if (isCorrect) {
      context.read<AuthProvider>().unlock();
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.home, (route) => false,
      );
    } else {
      setState(() => _hasError = true);
      await Future.delayed(AppDuration.errorReset);
      if (mounted) setState(() => _hasError = false);
    }
  }

  Future<void> _onSignOut() async {
    await context.read<AuthProvider>().signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login, (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;

    return Scaffold(
      backgroundColor: t.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Column(
                children: [
                  const PoppyLogo(size: AppIconSize.logoLg),
                  const SizedBox(height: AppSpacing.md),
                  Text(kAppName,
                      style: AppTextStyles.displayLarge(t.textPrimary)),
                ],
              ),
              const Spacer(flex: 2),
              PinPad(
                label:      'Enter your PIN',
                hasError:   _hasError,
                onComplete: _onPinComplete,
              ),
              const Spacer(flex: 3),
              TextButton(
                onPressed: _onSignOut,
                child: Text('Sign out instead',
                    style: AppTextStyles.bodySmallSans(t.textTertiary)),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}