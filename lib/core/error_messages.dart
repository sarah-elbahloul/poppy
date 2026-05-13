// ─────────────────────────────────────────────────────────────
//  POPPY — Centralized Error Messages
//  Location: lib/core/error_messages.dart
//
//  Single source of truth for converting raw Supabase /
//  system error strings into friendly user-facing messages.
//
//  Usage:
//    final msg = AppErrors.auth(raw);
//    final msg = AppErrors.network(raw);
//    final msg = AppErrors.db(raw);
//    final msg = AppErrors.fromException(e); // generic fallback
//
//  All screens import this and call these instead of having
//  their own _friendlyError() methods.
// ─────────────────────────────────────────────────────────────

class AppErrors {
  AppErrors._();

  // ── Auth errors (sign in / sign up) ──────────────────────

  static String signIn(String raw) {
    final l = raw.toLowerCase();
    if (l.contains('invalid login credentials') ||
        l.contains('invalid credentials')       ||
        l.contains('wrong password')            ||
        l.contains('user not found')) {
      return 'Email or password is incorrect.';
    }
    if (l.contains('email not confirmed')) {
      return 'Please confirm your email before signing in. '
          'Check your inbox for the confirmation link.';
    }
    if (l.contains('too many requests') || l.contains('rate limit')) {
      return 'Too many sign-in attempts. Please wait a few minutes and try again.';
    }
    if (_isNetwork(l)) return _networkMsg;
    return 'Could not sign in. Please try again.';
  }

  static String signUp(String raw) {
    final l = raw.toLowerCase();
    if (l.contains('already registered') ||
        l.contains('already exists')     ||
        l.contains('user already')) {
      return 'An account with this email already exists. '
          'Try signing in instead.';
    }
    if (l.contains('invalid email') || l.contains('valid email')) {
      return 'Please enter a valid email address.';
    }
    if (l.contains('password') &&
        (l.contains('short') || l.contains('weak'))) {
      return 'Password is too short. Please use at least 6 characters.';
    }
    if (l.contains('database') || l.contains('transaction')) {
      return 'Something went wrong on our end. '
          'Please wait a moment and try again.';
    }
    if (l.contains('too many requests') || l.contains('rate limit')) {
      return 'Too many attempts. Please wait a few minutes and try again.';
    }
    if (_isNetwork(l)) return _networkMsg;
    return 'Could not create your account. Please try again.';
  }

  static String resetPassword(String raw) {
    final l = raw.toLowerCase();
    if (l.contains('user not found') || l.contains('no user')) {
      return 'No account found with that email address.';
    }
    if (l.contains('too many requests') || l.contains('rate limit')) {
      return 'Too many attempts. Please wait a few minutes.';
    }
    if (_isNetwork(l)) return _networkMsg;
    return 'Could not send reset email. Please try again.';
  }

  static String updateEmail(String raw) {
    final l = raw.toLowerCase();
    if (l.contains('already registered') || l.contains('already exists')) {
      return 'This email is already in use by another account.';
    }
    if (l.contains('invalid email')) {
      return 'Please enter a valid email address.';
    }
    if (_isNetwork(l)) return _networkMsg;
    return 'Could not update email. Please try again.';
  }

  static String updatePassword(String raw) {
    final l = raw.toLowerCase();
    if (l.contains('password') &&
        (l.contains('short') || l.contains('weak'))) {
      return 'Password is too short. Please use at least 6 characters.';
    }
    if (_isNetwork(l)) return _networkMsg;
    return 'Could not update password. Please try again.';
  }

  // ── Entry / data errors ───────────────────────────────────

  static String saveEntry(String raw) {
    final l = raw.toLowerCase();
    if (l.contains('content_length') || l.contains('check constraint')) {
      return 'Your entry is too long. Please keep it under 10,000 words.';
    }
    if (_isNetwork(l)) return _networkMsg;
    return 'Could not save your entry. Please try again.';
  }

  static String deleteEntry(String raw) {
    if (_isNetwork(raw.toLowerCase())) return _networkMsg;
    return 'Could not delete the entry. Please try again.';
  }

  static String loadEntries(String raw) {
    if (_isNetwork(raw.toLowerCase())) return _networkMsg;
    return 'Could not load your entries. '
        'Check your connection and try again.';
  }

  // ── Photo errors ──────────────────────────────────────────

  static String uploadPhoto(String raw) {
    final l = raw.toLowerCase();
    if (l.contains('too large') || l.contains('payload')) {
      return 'This photo is too large. Please choose a smaller image.';
    }
    if (_isNetwork(l)) return _networkMsg;
    return 'Could not upload the photo. Please try again.';
  }

  static String deletePhoto(String raw) {
    if (_isNetwork(raw.toLowerCase())) return _networkMsg;
    return 'Could not remove the photo. Please try again.';
  }

  // ── Import / export errors ────────────────────────────────

  static String importFile(Object error) {
    if (error is FormatException) return error.message;
    final l = error.toString().toLowerCase();
    if (_isNetwork(l)) return _networkMsg;
    return 'Import failed. Make sure the file is a valid Poppy export.';
  }

  static String exportFile(Object error) {
    return 'Export failed. Please try again.';
  }

  // ── PIN errors ────────────────────────────────────────────

  static const String pinIncorrect =
      'Incorrect PIN. Please try again.';

  static const String pinMismatch =
      'PINs do not match. Please try again from the beginning.';

  // ── Validation messages ───────────────────────────────────
  // Used in forms before any network call is made.

  static const String emailEmpty    = 'Please enter your email address.';
  static const String emailInvalid  = 'Please enter a valid email address.';
  static const String passwordEmpty = 'Please enter a password.';
  static const String passwordShort =
      'Password must be at least 6 characters.';
  static const String passwordMismatch = 'Passwords do not match.';
  static const String confirmEmpty  =
      'Please confirm your password.';

  static String? validateEmail(String email) {
    if (email.trim().isEmpty) return emailEmpty;
    if (!email.contains('@') || !email.contains('.')) return emailInvalid;
    return null;
  }

  static String? validatePassword(String password) {
    if (password.isEmpty) return passwordEmpty;
    if (password.length < 6) return passwordShort;
    return null;
  }

  static String? validateConfirm(String password, String confirm) {
    if (confirm.isEmpty) return confirmEmpty;
    if (password != confirm) return passwordMismatch;
    return null;
  }

  // ── Word limit ────────────────────────────────────────────

  static const int wordLimit = 10000;

  static String wordLimitExceeded(int count) =>
      'Your entry has $count words, which exceeds the $wordLimit-word limit. '
          'Please shorten it before saving.';

  // ── Generic fallback ──────────────────────────────────────

  static String fromException(Object error) {
    final l = error.toString().toLowerCase();
    if (_isNetwork(l)) return _networkMsg;
    return 'Something went wrong. Please try again.';
  }

  // ── Private helpers ───────────────────────────────────────

  static const String _networkMsg =
      'No internet connection. Please check your network and try again.';

  static bool _isNetwork(String lower) =>
      lower.contains('network')    ||
          lower.contains('socket')     ||
          lower.contains('connection') ||
          lower.contains('timeout')    ||
          lower.contains('unreachable');
}