import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Auth Provider
//  Location: lib/providers/auth_provider.dart
// ─────────────────────────────────────────────────────────────

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();

  AuthStatus _status = AuthStatus.unknown;
  User? _user;
  bool _isLocked = false;
  bool _pinEnabled = false;
  String? _errorMessage;
  bool _isLoading = false;

  AuthStatus get status    => _status;
  User?      get user      => _user;
  bool       get isLocked  => _isLocked;
  bool       get pinEnabled => _pinEnabled;
  String?    get errorMessage => _errorMessage;
  bool       get isLoading => _isLoading;
  bool       get isAuthenticated => _status == AuthStatus.authenticated;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    final session = SupabaseConfig.client.auth.currentSession;
    if (session != null) {
      _user   = session.user;
      _status = AuthStatus.authenticated;
      await _checkPinLock();
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();

    SupabaseConfig.authStateStream.listen((data) async {
      final event = data.event;
      _user = data.session?.user;

      if (event == AuthChangeEvent.signedIn) {
        _status = AuthStatus.authenticated;
        await _checkPinLock();
      } else if (event == AuthChangeEvent.signedOut) {
        _status  = AuthStatus.unauthenticated;
        _isLocked = false;
      }
      notifyListeners();
    });
  }

  Future<void> _checkPinLock() async {
    final enabled = await _storage.read(key: StorageKeys.pinEnabled);
    _pinEnabled = enabled == 'true';
    if (_pinEnabled) _isLocked = true;
  }

  void unlock() {
    _isLocked = false;
    notifyListeners();
  }

  Future<void> setPinEnabled(bool enabled) async {
    _pinEnabled = enabled;
    await _storage.write(
      key: StorageKeys.pinEnabled,
      value: enabled.toString(),
    );
    if (!enabled) await _storage.delete(key: StorageKeys.pinHash);
    notifyListeners();
  }

  Future<bool> signIn({required String email, required String password}) async {
    _setLoading(true);
    _clearError();
    try {
      await SupabaseConfig.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Something went wrong. Please try again.';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signUp({required String email, required String password}) async {
    _setLoading(true);
    _clearError();
    try {
      await SupabaseConfig.client.auth.signUp(
        email: email.trim(),
        password: password,
      );
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Something went wrong. Please try again.';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    await SupabaseConfig.client.auth.signOut();
  }

  Future<bool> resetPassword(String email) async {
    _setLoading(true);
    _clearError();
    try {
      await SupabaseConfig.client.auth.resetPasswordForEmail(email.trim());
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateEmail(String newEmail) async {
    _setLoading(true);
    _clearError();
    try {
      await SupabaseConfig.client.auth.updateUser(
        UserAttributes(email: newEmail.trim()),
      );
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updatePassword(String newPassword) async {
    _setLoading(true);
    _clearError();
    try {
      await SupabaseConfig.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _clearError() => _errorMessage = null;

  void clearError() {
    _clearError();
    notifyListeners();
  }
}