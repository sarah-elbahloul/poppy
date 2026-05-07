import 'package:poppy/core/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final _client = SupabaseConfig.client;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
        email: email.trim(), password: password);
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signUp(
        email: email.trim(), password: password);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _client.auth.resetPasswordForEmail(email.trim());
  }

  Future<UserResponse> updateEmail(String newEmail) async {
    return await _client.auth.updateUser(
        UserAttributes(email: newEmail.trim()));
  }

  Future<UserResponse> updatePassword(String newPassword) async {
    return await _client.auth.updateUser(
        UserAttributes(password: newPassword));
  }

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get onAuthStateChange =>
      _client.auth.onAuthStateChange;

  Future<Map<String, dynamic>?> fetchProfile() async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('id', SupabaseConfig.userId)
        .maybeSingle();
    return response as Map<String, dynamic>?;
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    await _client
        .from('profiles')
        .update(data)
        .eq('id', SupabaseConfig.userId);
  }
}