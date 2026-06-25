import 'package:poppy/core/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Auth Service
//  Location: lib/services/auth_service.dart
// ─────────────────────────────────────────────────────────────

/// Orchestrates authentication workflows using Supabase Auth.
///
/// This service acts as the direct interface with Supabase for:
/// - User sign-in, sign-up, and sign-out.
/// - Password recovery and email updates.
/// - Profile metadata management in the 'profiles' table.
class AuthService {
  final _client = SupabaseConfig.client;

  // ─────────────────────────────────────────────────────────────
  //  Authentication Workflows
  // ─────────────────────────────────────────────────────────────

  /// Authenticates a user with email and password.
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Registers a new user account.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signUp(
      email: email.trim(),
      password: password,
    );
  }

  /// Terminates the current session.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Triggers the password recovery flow for the given [email].
  Future<void> sendPasswordResetEmail(String email) async {
    await _client.auth.resetPasswordForEmail(email.trim());
  }

  // ─────────────────────────────────────────────────────────────
  //  User Account Management
  // ─────────────────────────────────────────────────────────────

  /// Updates the email address for the currently authenticated user.
  Future<UserResponse> updateEmail(String newEmail) async {
    return await _client.auth.updateUser(
      UserAttributes(email: newEmail.trim()),
    );
  }

  /// Updates the password for the currently authenticated user.
  Future<UserResponse> updatePassword(String newPassword) async {
    return await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  /// Returns the currently authenticated user metadata, or null if signed out.
  User? get currentUser => _client.auth.currentUser;

  /// Provides a stream of authentication state changes (signedIn, signedOut, etc).
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  // ─────────────────────────────────────────────────────────────
  //  Profile Data Persistence
  // ─────────────────────────────────────────────────────────────

  /// Fetches extended profile data (PIN status, tags, etc.) from the 'profiles' table.
  Future<Map<String, dynamic>?> fetchProfile() async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('id', SupabaseConfig.userId)
        .maybeSingle();
    return response as Map<String, dynamic>?;
  }

  /// Updates profile-specific preferences stored in the backend.
  Future<void> updateProfile(Map<String, dynamic> data) async {
    await _client
        .from('profiles')
        .update(data)
        .eq('id', SupabaseConfig.userId);
  }
}
