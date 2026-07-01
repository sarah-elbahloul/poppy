import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Supabase Configuration
// ─────────────────────────────────────────────────────────────

/// Configuration and access point for Supabase services.
///
/// Handles initialization and provides easy access to the [SupabaseClient],
/// current user information, and storage utilities.
class SupabaseConfig {
  SupabaseConfig._();

  static const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Initializes the Supabase client with environment variables.
  ///
  /// Throws an assertion error if credentials are missing.
  static Future<void> init() async {
    assert(
    _supabaseUrl.isNotEmpty && _supabaseKey.isNotEmpty,
    '\n\n'
        '══════════════════════════════════════════════════════\n'
        '  Supabase credentials are missing.\n'
        '  Run the app with:\n'
        '  flutter run \\\n'
        '    --dart-define=SUPABASE_URL=your_url \\\n'
        '    --dart-define=SUPABASE_ANON_KEY=your_key\n'
        '══════════════════════════════════════════════════════\n',
    );

    await Supabase.initialize(
      url: _supabaseUrl,
      anonKey: _supabaseKey,
      debug: kDebugMode,
    );
  }

  /// Returns the global [SupabaseClient] instance.
  static SupabaseClient get client => Supabase.instance.client;

  /// Returns the currently authenticated [User], if any.
  static User? get currentUser => client.auth.currentUser;

  /// Returns the ID of the currently authenticated user, or an empty string.
  static String get userId => currentUser?.id ?? '';

  /// Returns a stream of authentication state changes.
  static Stream<AuthState> get authStateStream => client.auth.onAuthStateChange;

  /// Generates a temporary signed URL for a file in a storage [bucket].
  ///
  /// The URL is valid for [expiresIn] seconds (default is 1 hour).
  static Future<String> getSignedUrl(
      String bucket,
      String path, {
        int expiresIn = 3600,
      }) async {
    return await client.storage
        .from(bucket)
        .createSignedUrl(path, expiresIn);
  }
}