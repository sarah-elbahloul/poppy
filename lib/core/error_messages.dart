/// Provides human-readable error messages and validation logic for various 
/// application failure scenarios.
class AppErrors {
  AppErrors._();

  /// The maximum allowed word count for a single entry.
  static const int wordLimit = 10000;

  /// Returns a message when an entry exceeds the [wordLimit].
  static String wordLimitExceeded(int count) =>
      'Your entry has $count words, which exceeds the $wordLimit-word limit. '
      'Please shorten it before saving.';

  /// Extracts a user-friendly error message from a general [error] object.
  static String fromException(Object error) {
    final l = error.toString().toLowerCase();
    if (_isNetwork(l)) return _networkMsg;
    return 'Something went wrong. Please try again.';
  }

  // --- Internal Helpers ---

  static const String _networkMsg =
      'No internet connection. Please check your network and try again.';

  static bool _isNetwork(String lower) =>
      lower.contains('network') ||
      lower.contains('socket') ||
      lower.contains('connection') ||
      lower.contains('timeout') ||
      lower.contains('unreachable');

  // --- Authentication Errors ---

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
    if (_isNetwork(l)) return _networkMsg;
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
    if (_isNetwork(l)) return _networkMsg;
    return 'Could not create your account. Please try again.';
  }

  /// Maps Supabase Auth errors for password reset requests.
  static String resetPassword(String raw) {
    final l = raw.toLowerCase();
    if (l.contains('user not found')) return 'No account found with that email.';
    if (_isNetwork(l)) return _networkMsg;
    return 'Could not send reset email. Please try again.';
  }

  /// Maps Supabase Auth errors for email update requests.
  static String updateEmail(String raw) {
    final l = raw.toLowerCase();
    if (l.contains('already registered') || l.contains('already exists')) {
      return 'This email is already in use by another account.';
    }
    if (l.contains('invalid email')) return 'Please enter a valid email address.';
    if (_isNetwork(l)) return _networkMsg;
    return 'Could not update email. Please try again.';
  }

  /// Maps Supabase Auth errors for password update requests.
  static String updatePassword(String raw) {
    final l = raw.toLowerCase();
    if (l.contains('password') && (l.contains('short') || l.contains('weak'))) {
      return 'Password is too short. Use at least 6 characters.';
    }
    if (_isNetwork(l)) return _networkMsg;
    return 'Could not update password. Please try again.';
  }

  /// Error message shown when the current password verification fails.
  static const String wrongCurrentPassword = 'Your current password is incorrect.';

  // --- Data & Storage Errors ---

  /// Returns a user-friendly message for entry saving failures.
  static String saveEntry(String raw) {
    if (raw.toLowerCase().contains('content_length')) {
      return 'Your entry is too long (max 10,000 words).';
    }
    if (_isNetwork(raw.toLowerCase())) return _networkMsg;
    return 'Could not save your entry.';
  }

  /// Returns a user-friendly message for photo upload failures.
  static String uploadPhoto(String raw) {
    if (raw.toLowerCase().contains('too large')) {
      return 'This photo is too large. Please choose a smaller image.';
    }
    if (_isNetwork(raw.toLowerCase())) return _networkMsg;
    return 'Could not upload the photo.';
  }

  // --- PIN & Validation ---

  /// Error message for incorrect PIN entry.
  static const String pinIncorrect = 'Incorrect PIN. Please try again.';

  /// Error message when two entered PINs do not match.
  static const String pinMismatch = 'PINs do not match.';

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
