import 'package:poppy/core/core.dart';

/// Maps raw Supabase Auth error strings to user-friendly copy for this
/// app's sign-in, sign-up, and account-management flows.
///
/// Built on top of the generic helpers in [AppErrors]; keep auth-specific
/// wording here so [AppErrors] stays portable across projects.
class AuthErrors {
  AuthErrors._();

  /// Maps Supabase Auth errors to user-friendly strings for sign-in attempts.
  static String signIn(String raw) {
    final l = raw.toLowerCase();
    if (l.contains('invalid login credentials') ||
        l.contains('invalid credentials') ||
        l.contains('wrong password') ||
        l.contains('user not found')) {
      return 'Email or password is incorrect.';
    }
    if (l.contains('email not confirmed')) {
      return 'Please confirm your email before signing in.';
    }
    if (l.contains('too many requests') || l.contains('rate limit')) {
      return 'Too many sign-in attempts. Please wait a few minutes.';
    }
    if (AppErrors.isNetworkError(l)) return AppErrors.networkMessage;
    return 'Could not sign in. Please try again.';
  }

  /// Maps Supabase Auth errors to user-friendly strings for registration.
  static String signUp(String raw) {
    final l = raw.toLowerCase();
    if (l.contains('already registered') || l.contains('already exists')) {
      return 'An account with this email already exists.';
    }
    if (l.contains('invalid email')) return 'Please enter a valid email address.';
    if (l.contains('password') && (l.contains('short') || l.contains('weak'))) {
      return 'Password is too short. Use at least 8 characters.';
    }
    if (AppErrors.isNetworkError(l)) return AppErrors.networkMessage;
    return 'Could not create your account. Please try again.';
  }

  /// Maps Supabase Auth errors for password reset requests.
  static String resetPassword(String raw) {
    final l = raw.toLowerCase();
    if (l.contains('user not found')) return 'No account found with that email.';
    if (AppErrors.isNetworkError(l)) return AppErrors.networkMessage;
    return 'Could not send reset email. Please try again.';
  }

  /// Maps Supabase Auth errors for email update requests.
  static String updateEmail(String raw) {
    final l = raw.toLowerCase();
    if (l.contains('already registered') || l.contains('already exists')) {
      return 'This email is already in use by another account.';
    }
    if (l.contains('invalid email')) return 'Please enter a valid email address.';
    if (AppErrors.isNetworkError(l)) return AppErrors.networkMessage;
    return 'Could not update email. Please try again.';
  }

  /// Maps Supabase Auth errors for password update requests.
  static String updatePassword(String raw) {
    final l = raw.toLowerCase();
    if (l.contains('password') && (l.contains('short') || l.contains('weak'))) {
      return 'Password is too short. Use at least 6 characters.';
    }
    if (AppErrors.isNetworkError(l)) return AppErrors.networkMessage;
    return 'Could not update password. Please try again.';
  }

  /// Error message shown when the current password verification fails.
  static const String wrongCurrentPassword = 'Your current password is incorrect.';

  /// Error message for incorrect PIN entry.
  static const String pinIncorrect = 'Incorrect PIN. Please try again.';

  /// Error message when two entered PINs do not match.
  static const String pinMismatch = 'PINs do not match.';
}