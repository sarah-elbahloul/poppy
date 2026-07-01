/// Generic, reusable error-handling utilities shared across the app:
/// turning low-level exceptions into user-facing copy, and basic form
/// validation.
///
/// Feature-specific error mapping lives with its feature instead — for
/// example, Supabase Auth error messages live in
/// `features/auth/data/services/auth_errors.dart`. Keeping this file
/// generic is what makes it safe to copy into another project unchanged.
class AppErrors {
  AppErrors._();

  /// Extracts a user-friendly error message from a general [error] object.
  static String fromException(Object error) {
    final lower = error.toString().toLowerCase();
    if (isNetworkError(lower)) return networkMessage;
    return 'Something went wrong. Please try again.';
  }

  /// Standard copy shown whenever a request fails due to connectivity.
  static const String networkMessage =
      'No internet connection. Please check your network and try again.';

  /// Heuristic check for whether a lowercased error string describes a
  /// network/connectivity failure (timeout, no connection, unreachable...).
  static bool isNetworkError(String lowercaseError) =>
      lowercaseError.contains('network') ||
          lowercaseError.contains('socket') ||
          lowercaseError.contains('connection') ||
          lowercaseError.contains('timeout') ||
          lowercaseError.contains('unreachable');

  /// Validates an email address and returns an error message if invalid.
  static String? validateEmail(String email) {
    if (email.trim().isEmpty) return 'Please enter your email.';
    if (!email.contains('@') || !email.contains('.')) return 'Invalid email.';
    return null;
  }

  /// Validates a password's strength and returns an error message if insufficient.
  static String? validatePassword(String password) {
    if (password.isEmpty) {
      return 'Please enter a password.';
    }
    final isValid = password.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'\d').hasMatch(password) &&
        RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;/~`]').hasMatch(password);
    if (!isValid) {
      return 'Password must be at least 8 characters and include uppercase, lowercase, number, and symbol.';
    }
    return null;
  }

  /// Validates that a confirmation password matches the primary password.
  static String? validateConfirm(String password, String confirm) {
    if (confirm.isEmpty) return 'Please confirm your password.';
    if (password != confirm) return 'Passwords do not match.';
    return null;
  }
}