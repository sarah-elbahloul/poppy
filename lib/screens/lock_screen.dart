import 'package:flutter/material.dart';
import 'package:poppy/core/core.dart';
import 'package:poppy/services/pin_service.dart';
import 'package:provider/provider.dart';
import 'package:poppy/providers/providers.dart';

/// Poppy — Lock Screen
///
/// Prevents access to the app until the correct PIN is entered.
/// If the user forgets their PIN, they must sign out and sign back in,
/// which effectively resets the PIN lock state.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _pinService = PinService();
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    // Ensure any open keyboard is dismissed when the lock screen appears.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  // ─── Actions ───

  /// Validates the entered PIN.
  ///
  /// On success, notifies the [AuthProvider] to unlock.
  Future<void> _onPinComplete(String pin) async {
    final isCorrect = await _pinService.verify(pin);
    if (!mounted) return;

    if (isCorrect) {
      // Unlocking the provider triggers a rebuild in the RootRouter.
      context.read<AuthProvider>().unlock();
    } else {
      setState(() => _hasError = true);
      await Future.delayed(AppDuration.errorReset);
      if (mounted) setState(() => _hasError = false);
    }
  }

  /// Signs out the user as a fallback if they cannot enter the PIN.
  Future<void> _onSignOut() async {
    await context.read<AuthProvider>().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final fp = context.read<ThemeProvider>().currentFontPairData;

    return Scaffold(
      resizeToAvoidBottomInset: false,
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
                label: 'Enter your PIN',
                hasError: _hasError,
                onComplete: _onPinComplete,
              ),
              const Spacer(flex: 3),
              TextButton(
                onPressed: _onSignOut,
                child: Text('Sign out instead',
                    style: AppTextStyles.bodySmallSans(t.textTertiary, fp)),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
