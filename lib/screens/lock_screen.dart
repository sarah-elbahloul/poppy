import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:poppy/core/core.dart';
import 'package:poppy/services/pin_service.dart';
import 'package:provider/provider.dart';
import 'package:poppy/providers/providers.dart';

/// A security screen that prevents access to the application until the correct PIN is entered.
///
/// If a user forgets their PIN, they are encouraged to sign out and sign back in,
/// which resets the local security state.
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
    // Ensure any active keyboard is dismissed when the lock screen is presented.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
    });

    // Pre-warm the active font pair so glyphs are ready before the first
    // frame renders, preventing the flicker / FOUT on the lock screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final fp = context.read<ThemeProvider>().currentFontPairData;
      GoogleFonts.pendingFonts([
        fp.titleFont.style(Colors.black, size: 16),
        fp.bodyFont.style(Colors.black, size: 16),
      ]);
    });
  }

  // --- Actions ---

  /// Validates the entered [pin] against the stored hash.
  ///
  /// On success, unlocks the [AuthProvider]. On failure, triggers the error
  /// animation on the [PinPad].
  Future<void> _onPinComplete(String pin) async {
    final isCorrect = await _pinService.verify(pin);
    if (!mounted) return;

    if (isCorrect) {
      // Unlocking the provider triggers a state change in the RootRouter.
      context.read<AuthProvider>().unlock();
    } else {
      setState(() => _hasError = true);
      await Future.delayed(AppDuration.errorReset);
      if (mounted) setState(() => _hasError = false);
    }
  }

  /// Terminates the current session as a fallback for forgotten PINs.
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
                  Text(
                    AppConstants.AppName,
                    style: AppTextStyles.displayLarge(t.textPrimary),
                  ),
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
                child: Text(
                  'Sign out instead',
                  style: AppTextStyles.bodySmallSans(t.textTertiary, fp),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}