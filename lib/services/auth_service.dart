import 'package:poppy/core/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Auth Service
//  Location: lib/services/auth_service.dart
//
//  Low-level Supabase auth calls.
//  AuthProvider calls these — never the UI directly.
// ─────────────────────────────────────────────────────────────

class AuthService {
  final _client = SupabaseConfig.client;

  // ── Sign in ───────────────────────────────────────────────

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  // ── Sign up ───────────────────────────────────────────────

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signUp(
      email: email.trim(),
      password: password,
    );
  }

  // ── Sign out ──────────────────────────────────────────────

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // ── Password reset email ──────────────────────────────────

  Future<void> sendPasswordResetEmail(String email) async {
    await _client.auth.resetPasswordForEmail(email.trim());
  }

  // ── Update email ──────────────────────────────────────────

  Future<UserResponse> updateEmail(String newEmail) async {
    return await _client.auth.updateUser(
      UserAttributes(email: newEmail.trim()),
    );
  }

  // ── Update password ───────────────────────────────────────

  Future<UserResponse> updatePassword(String newPassword) async {
    return await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  // ── Current user ──────────────────────────────────────────

  User? get currentUser => _client.auth.currentUser;

  // ── Auth state stream ─────────────────────────────────────

  Stream<AuthState> get onAuthStateChange =>
      _client.auth.onAuthStateChange;

  // ── Profile helpers ───────────────────────────────────────
  // Reads and writes the profiles table that was created
  // alongside the auth setup in Supabase.

  Future<Map<String, dynamic>?> fetchProfile() async {
    final userId = SupabaseConfig.userId;
    final response = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return response as Map<String, dynamic>?;
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    final userId = SupabaseConfig.userId;
    await _client
        .from('profiles')
        .update(data)
        .eq('id', userId);
  }
}