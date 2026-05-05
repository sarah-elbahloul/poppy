import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Supabase Client
//  Location: lib/core/supabase_client.dart
//
//  Single place where Supabase is initialised and accessed.
//  Call SupabaseConfig.init() once in main.dart before
//  runApp(). After that, use the getters anywhere in the app.
// ─────────────────────────────────────────────────────────────

// ── Your project credentials ──────────────────────────────────
// These are read from the environment at build time via
// the --dart-define flags we add to the run command.
// Never hard-code these values here.

const _supabaseUrl  = String.fromEnvironment('SUPABASE_URL');
const _supabaseKey  = String.fromEnvironment('SUPABASE_ANON_KEY');

class SupabaseConfig {
  SupabaseConfig._();

  /// Call once in main.dart before runApp().
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
        '  Or set them up in your IDE run configuration.\n'
        '══════════════════════════════════════════════════════\n',
    );

    await Supabase.initialize(
      url: _supabaseUrl,
      anonKey: _supabaseKey,
      debug: kDebugMode, // logs queries in debug builds only
    );
  }

  // ── Convenience getters ───────────────────────────────────

  /// The Supabase client — use this for all database calls.
  static SupabaseClient get client => Supabase.instance.client;

  /// The currently signed-in user, or null if logged out.
  static User? get currentUser => client.auth.currentUser;

  /// The current user's id. Throws if not signed in.
  /// Services should always check currentUser != null first.
  static String get userId {
    final user = currentUser;
    assert(user != null, 'userId accessed while not signed in.');
    return user!.id;
  }

  /// Auth state stream — listen to this in auth_provider.dart.
  static Stream<AuthState> get authStateStream =>
      client.auth.onAuthStateChange;

  // ── Storage helper ────────────────────────────────────────

  /// Returns a short-lived signed URL for a private storage object.
  /// [expiresIn] defaults to 1 hour.
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