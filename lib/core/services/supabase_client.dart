import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Supabase Configuration
//  Location: lib/core/services/supabase_client.dart
// ─────────────────────────────────────────────────────────────

class SupabaseConfig {
  SupabaseConfig._();

  static const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');

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

  static SupabaseClient get client => Supabase.instance.client;
  static User? get currentUser => client.auth.currentUser;
  static String get userId => currentUser?.id ?? '';
  static Stream<AuthState> get authStateStream => client.auth.onAuthStateChange;

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
