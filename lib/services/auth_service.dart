import 'package:poppy/core/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service class for handling authentication logic using Supabase.
class AuthService {
  final _client = SupabaseConfig.client;

  /// Signs in a user with their email and password.
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
        email: email.trim(), password: password);
  }

  /// Registers a new user with their email and password.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signUp(
        email: email.trim(), password: password);
  }

  /// Signs out the currently authenticated user.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Sends a password reset email to the specified address.
  Future<void> sendPasswordResetEmail(String email) async {
    await _client.auth.resetPasswordForEmail(email.trim());
  }

  /// Updates the email address of the currently authenticated user.
  Future<UserResponse> updateEmail(String newEmail) async {
    return await _client.auth.updateUser(
        UserAttributes(email: newEmail.trim()));
  }

  /// Updates the password of the currently authenticated user.
  Future<UserResponse> updatePassword(String newPassword) async {
    return await _client.auth.updateUser(
        UserAttributes(password: newPassword));
  }

  /// Returns the currently authenticated user, or null if no user is signed in.
  User? get currentUser => _client.auth.currentUser;

  /// A stream of authentication state changes.
  Stream<AuthState> get onAuthStateChange =>
      _client.auth.onAuthStateChange;

  /// Fetches the user profile from the database.
  Future<Map<String, dynamic>?> fetchProfile() async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('id', SupabaseConfig.userId)
        .maybeSingle();
    return response as Map<String, dynamic>?;
  }

  /// Updates the user profile in the database.
  Future<void> updateProfile(Map<String, dynamic> data) async {
    await _client
        .from('profiles')
        .update(data)
        .eq('id', SupabaseConfig.userId);
  }
}
