import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/theme/themes.dart';
import 'package:poppy/core/widgets/pin_pad.dart';
import 'package:poppy/core/widgets/poppy_logo.dart';
import 'package:poppy/providers/auth_provider.dart';
import 'package:poppy/services/pin_service.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Lock Screen
//  Location: lib/screens/lock_screen.dart
//
//  Shown on app launch when PIN is enabled.
//  User must enter the correct PIN to proceed to home.
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
      context.go('/home');
    } else {
      setState(() => _hasError = true);
      // Reset the error flag after a short delay so
      // PinPad can shake and then accept a new attempt
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) setState(() => _hasError = false);
    }
  }

  Future<void> _onSignOut() async {
    await context.read<AuthProvider>().signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;

    return Scaffold(
      backgroundColor: t.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: kSpaceLG),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Logo + app name ──────────────────────────
              Column(
                children: [
                  const PoppyLogo(size: 56),
                  const SizedBox(height: kSpaceMD),
                  Text(
                    kAppName,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w500,
                      color: t.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 2),

              // ── PIN pad ───────────────────────────────────
              PinPad(
                label: 'Enter your PIN',
                hasError: _hasError,
                onComplete: _onPinComplete,
              ),

              const Spacer(flex: 3),

              // ── Sign out link ─────────────────────────────
              TextButton(
                onPressed: _onSignOut,
                child: Text(
                  'Sign out instead',
                  style: TextStyle(
                    fontSize: 13,
                    color: t.textTertiary,
                  ),
                ),
              ),

              const SizedBox(height: kSpaceLG),
            ],
          ),
        ),
      ),
    );
  }
}