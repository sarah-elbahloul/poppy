import 'package:poppy/core/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase Auth interface.
///
/// Handles only authentication operations. Profile data and PIN state
/// are managed separately to avoid mixing concerns.
class AuthService {
  final _client = SupabaseConfig.client;

  Future<AuthResponse> signIn({required String email, required String password}) {
    return _client.auth.signInWithPassword(email: email.trim(), password: password);
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? redirectTo,
  }) {
    return _client.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: redirectTo,
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<void> sendPasswordReset(String email, {String? redirectTo}) {
    return _client.auth.resetPasswordForEmail(email.trim(), redirectTo: redirectTo);
  }

  Future<UserResponse> updateUser(UserAttributes attributes) {
    return _client.auth.updateUser(attributes);
  }

  User? get currentUser => _client.auth.currentUser;
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;
}