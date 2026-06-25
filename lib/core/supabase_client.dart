import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Supabase Configuration
//  Location: lib/core/supabase_client.dart
// ─────────────────────────────────────────────────────────────

/// Centralized management for Supabase initialization and client access.
/// 
/// This class handles:
/// - Initializing the connection with environment-defined credentials.
/// - Providing global access to the [SupabaseClient].
/// - Exposing helper getters for the current user and auth state.
/// - Managing signed URL generation for private cloud storage.
class SupabaseConfig {
  SupabaseConfig._();

  static const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Initializes the Supabase client.
  ///
  /// Throws an assertion error if credentials are not provided via `--dart-define`.
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

  // ─────────────────────────────────────────────────────────────
  //  Client & User Getters
  // ─────────────────────────────────────────────────────────────

  /// Returns the global [SupabaseClient] instance.
  static SupabaseClient get client => Supabase.instance.client;

  /// Returns the currently authenticated user, or null if signed out.
  static User? get currentUser => client.auth.currentUser;

  /// Returns the ID of the currently authenticated user, or an empty string.
  ///
  /// Safe to call during sign-out races as it returns an empty string 
  /// instead of throwing or returning null.
  static String get userId => currentUser?.id ?? '';

  /// Provides a stream of authentication state changes.
  static Stream<AuthState> get authStateStream =>
      client.auth.onAuthStateChange;

  // ─────────────────────────────────────────────────────────────
  //  Storage Helpers
  // ─────────────────────────────────────────────────────────────

  /// Generates a short-lived (1 hour) signed URL for private storage objects.
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
