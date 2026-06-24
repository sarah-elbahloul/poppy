import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized management for Supabase initialization and client access.
class SupabaseConfig {
  SupabaseConfig._();

  static const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Initializes the Supabase client with credentials from environment variables.
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

  /// Returns the global [SupabaseClient] instance.
  static SupabaseClient get client => Supabase.instance.client;

  /// Returns the currently authenticated user, or null if signed out.
  static User? get currentUser => client.auth.currentUser;

  /// Returns the ID of the currently authenticated user, or an empty
  /// string if no user is signed in.
  ///
  /// Callers (e.g. [SyncService.syncNow]) rely on being able to check
  /// `userId.isEmpty` to no-op gracefully during sign-out races. This used
  /// to be backed by an `assert()`, which is stripped out of release builds
  /// — in release mode that meant a null-check crash instead of a graceful
  /// no-op whenever a save/sync/fetch call landed while unauthenticated.
  static String get userId => currentUser?.id ?? '';

  /// Provides a stream of authentication state changes.
  static Stream<AuthState> get authStateStream =>
      client.auth.onAuthStateChange;

  /// Generates a short-lived signed URL for accessing private storage objects.
  ///
  /// [bucket] is the name of the storage bucket.
  /// [path] is the full path to the file within the bucket.
  /// [expiresIn] defines the URL validity duration in seconds (defaults to 1 hour).
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