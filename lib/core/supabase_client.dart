import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Poppy — Supabase Client Configuration
///
/// Centralized management for Supabase initialization and access.
/// Call [SupabaseConfig.init] once in `main.dart` before [runApp].
class SupabaseConfig {
  SupabaseConfig._();

  // Your project credentials are read from the environment at build time.
  static const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Initializes the Supabase client.
  ///
  /// Throws an assertion error if credentials are not provided via dart-define.
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

  // --- Convenience Getters ---

  /// The global Supabase client instance.
  static SupabaseClient get client => Supabase.instance.client;

  /// The currently signed-in user, or null if logged out.
  static User? get currentUser => client.auth.currentUser;

  /// The current user's unique ID. Throws an assertion error if not signed in.
  static String get userId {
    final user = currentUser;
    assert(user != null, 'userId accessed while not signed in.');
    return user!.id;
  }

  /// A stream of authentication state changes.
  static Stream<AuthState> get authStateStream =>
      client.auth.onAuthStateChange;

  // --- Storage Helper ---

  /// Generates a short-lived signed URL for a private storage object.
  /// [expiresIn] defaults to 3600 seconds (1 hour).
  static Future<String> getSignedUrl(
    String bucket,
    String path, {
    int expiresIn = 3600,
  }) async {
    final response = await client.storage
        .from(bucket)
        .createSignedUrl(path, expiresIn);
    return response;
  }
}
