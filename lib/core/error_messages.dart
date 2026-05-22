// ─────────────────────────────────────────────────────────────
//  POPPY — Centralized Error Messages
//  Location: lib/core/error_messages.dart
// ─────────────────────────────────────────────────────────────

class AppErrors {
  AppErrors._();

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

// ── Private ───────────────────────────────────────────────

  static const String _networkMsg =
      'No internet connection. Please check your network and try again.';

  static bool _isNetwork(String lower) =>
      lower.contains('network')    ||
          lower.contains('socket')     ||
          lower.contains('connection') ||
          lower.contains('timeout')    ||
          lower.contains('unreachable');

  // ── Auth ──────────────────────────────────────────────────

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
      return 'Too many sign-in attempts. Please wait a few minutes.';
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
      return 'Password is too short. Use at least 6 characters.';
    }
    if (l.contains('too many requests') || l.contains('rate limit')) {
      return 'Too many attempts. Please wait a few minutes.';
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
    if (l.contains('invalid email')) return 'Please enter a valid email address.';
    if (_isNetwork(l)) return _networkMsg;
    return 'Could not update email. Please try again.';
  }

  static const String wrongCurrentPassword =
      'Your current password is incorrect.';

  static String updatePassword(String raw) {
    final l = raw.toLowerCase();
    if (l.contains('password') &&
        (l.contains('short') || l.contains('weak'))) {
      return 'Password is too short. Use at least 6 characters.';
    }
    if (_isNetwork(l)) return _networkMsg;
    return 'Could not update password. Please try again.';
  }

  // ── Entry / data ──────────────────────────────────────────

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
    return 'Could not load your entries. Check your connection and try again.';
  }

  // ── Photos ────────────────────────────────────────────────

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

  // ── Import / export ───────────────────────────────────────

  static String importFile(Object error) {
    if (error is FormatException) return error.message;
    final l = error.toString().toLowerCase();
    if (_isNetwork(l)) return _networkMsg;
    return 'Import failed. Make sure the file is a valid Poppy export.';
  }

  static String exportFile(Object error) =>
      'Export failed. Please try again.';

  static const String importWrongAccount =
      'This export is encrypted with a different account\'s password. '
      'You can only import it from the original account, or ask for '
      'a plain (unencrypted) export instead.';

  // ── PIN ───────────────────────────────────────────────────

  static const String pinIncorrect = 'Incorrect PIN. Please try again.';
  static const String pinMismatch  =
      'PINs do not match. Please try again from the beginning.';

  // ── Validation ────────────────────────────────────────────

  static const String emailEmpty    = 'Please enter your email address.';
  static const String emailInvalid  = 'Please enter a valid email address.';
  static const String passwordEmpty = 'Please enter a password.';
  static const String passwordShort = 'Password must be at least 6 characters.';
  static const String passwordMismatch = 'Passwords do not match.';
  static const String confirmEmpty  = 'Please confirm your password.';

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
}