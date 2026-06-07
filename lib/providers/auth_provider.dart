import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:poppy/core/core.dart';
import 'package:poppy/services/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Represents the possible authentication states of the application.
enum AuthStatus {
  /// Initial state while checking for an existing session.
  unknown,

  /// User is successfully signed in.
  authenticated,

  /// No active session exists.
  unauthenticated,

  /// One-time session active from a password reset email link.
  passwordRecovery,
}

/// Poppy — Auth Provider
///
/// Manages the authentication state of the application, including sign-in,
/// sign-up, password recovery, and session persistence.
///
/// It also handles the encryption state and PIN lock functionality.
class AuthProvider extends ChangeNotifier {
  final _storage    = const FlutterSecureStorage();
  final _enc        = EncryptionService.instance;
  final _keyService = KeyService();

  AuthStatus _status          = AuthStatus.unknown;
  User?      _user;
  bool       _isLocked        = false;
  bool       _isCompletingPasswordReset = false;
  bool       _pinEnabled      = false;
  String?    _errorMessage;
  bool       _isLoading       = false;
  bool       _encryptionReady = false;

  AuthStatus get status          => _status;
  User?      get user            => _user;
  bool       get isLocked        => _isLocked;
  bool       get pinEnabled      => _pinEnabled;
  String?    get errorMessage    => _errorMessage;
  bool       get isLoading       => _isLoading;
  bool       get isAuthenticated => _status == AuthStatus.authenticated;
  bool       get encryptionReady => _encryptionReady;

  /// Returns the display name from metadata, or falls back to the email prefix.
  String get displayName {
    final meta = _user?.userMetadata;
    if (meta != null) {
      final name = meta['display_name'] as String?;
      if (name != null && name.trim().isNotEmpty) return name.trim();
      final full = meta['full_name'] as String?;
      if (full != null && full.trim().isNotEmpty) return full.trim();
    }
    final email = _user?.email ?? '';
    return email.contains('@') ? email.split('@')[0] : email;
  }

  AuthProvider() {
    _init();
  }

  /// Initializes the provider by checking for an existing Supabase session.
  Future<void> _init() async {
    final session = SupabaseConfig.client.auth.currentSession;
    if (session != null) {
      _user = session.user;
      // Await pin lock state before setting status to ensure correct initial routing.
      await _checkPinLock(resetLock: true);
      final loaded = await _enc.loadCachedKey();
      _encryptionReady = loaded;
      _status = AuthStatus.authenticated;
    } else {
      _status = AuthStatus.unauthenticated;
    }
    _safeNotify();

    SupabaseConfig.authStateStream.listen((data) async {
      _user = data.session?.user;
      switch (data.event) {
        case AuthChangeEvent.signedIn:
          // signIn() handles status and encryptionReady manually to avoid races.
          break;

        case AuthChangeEvent.passwordRecovery:
          _status = AuthStatus.passwordRecovery;
          await _enc.loadCachedKey(); // best-effort load
          _safeNotify();
          break;

        case AuthChangeEvent.userUpdated:
          _user = data.session?.user;
          _safeNotify();
          break;

        case AuthChangeEvent.signedOut:
          if (_isCompletingPasswordReset) break;
          _status          = AuthStatus.unauthenticated;
          _isLocked        = false;
          _encryptionReady = false;
          await _enc.clearKey();
          _safeNotify();
          break;

        default:
          break;
      }
    });
  }

  Future<void> _checkPinLock({bool resetLock = false}) async {
    final enabled = await _storage.read(key: StorageKeys.pinEnabled);
    _pinEnabled = enabled == 'true';
    if (_pinEnabled && resetLock) {
      _isLocked = true;
    }
  }

  /// Unlocks the app from PIN protection.
  void unlock() {
    _isLocked = false;
    _safeNotify();
  }

  /// Toggles whether the PIN lock is enabled.
  Future<void> setPinEnabled(bool enabled) async {
    _pinEnabled = enabled;
    await _storage.write(
        key: StorageKeys.pinEnabled, value: enabled.toString());
    if (!enabled) await _storage.delete(key: StorageKeys.pinHash);
    _safeNotify();
  }

  // --- Sign In ---

  /// Signs in the user and handles the decryption key loading sequence.
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();
    _encryptionReady = false;
    try {
      await SupabaseConfig.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final hasKeys = await _keyService.hasKeysRow();

      if (!hasKeys) {
        // Handle pending wrapped keys from sign-up if this is the first sign-in.
        final pending = await _storage.read(key: StorageKeys.pendingEncKey);
        if (pending != null) {
          await _keyService.saveWrappedKey(encDataKeyJson: pending);
          await _storage.delete(key: StorageKeys.pendingEncKey);
        }
        await _enc.loadCachedKey();
      } else {
        final loaded = await _enc.loadCachedKey();
        if (!loaded) {
          await _keyService.loadAndUnwrapWithPassword(password);
        }
      }

      _encryptionReady = _enc.hasKey;
      await _checkPinLock();
      _isLocked = false;
      _status = AuthStatus.authenticated;
      _safeNotify();
      return true;
    } on AuthException catch (e) {
      _errorMessage = AppErrors.signIn(e.message);
      _encryptionReady = false;
      _safeNotify();
      return false;
    } catch (e) {
      _errorMessage = AppErrors.fromException(e);
      _encryptionReady = false;
      _safeNotify();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // --- Sign Up ---

  /// Registers a new user and generates their unique data encryption key.
  Future<bool> signUp({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      await SupabaseConfig.client.auth.signUp(
        email:           email.trim(),
        password:        password,
        emailRedirectTo: _redirectUrl,
      );

      final dataKeyBytes = await _enc.generateDataKey();
      final wrapped      = await _enc.wrapWithPassword(dataKeyBytes, password);

      await _storage.write(
        key:   StorageKeys.pendingEncKey,
        value: jsonEncode(wrapped),
      );
      return true;
    } on AuthException catch (e) {
      _errorMessage = AppErrors.signUp(e.message);
      await _enc.clearKey();
      _safeNotify();
      return false;
    } catch (e) {
      _errorMessage = AppErrors.fromException(e);
      await _enc.clearKey();
      _safeNotify();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // --- Sign Out ---

  /// Signs out the user and clears sensitive data from memory and local cache.
  Future<void> signOut() async {
    await SupabaseConfig.client.auth.signOut();
  }

  // --- Password Recovery ---

  /// Sends a password reset email to the user.
  Future<bool> sendPasswordResetEmail(String email) async {
    _setLoading(true);
    _clearError();
    try {
      await SupabaseConfig.client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: _redirectUrl,
      );
      return true;
    } on AuthException catch (e) {
      _errorMessage = AppErrors.resetPassword(e.message);
      _safeNotify();
      return false;
    } catch (e) {
      _errorMessage = AppErrors.fromException(e);
      _safeNotify();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Completes the password reset process using the new password.
  /// 
  /// Updates the authentication password and re-wraps the user's data 
  /// encryption key using the new password and a recovery key if necessary.
  Future<bool> completePasswordReset(String newPassword) async {
    _setLoading(true);
    _clearError();
    try {
      final uid = SupabaseConfig.userId;

      _isCompletingPasswordReset = true;
      try {
        await SupabaseConfig.client.auth.updateUser(
          UserAttributes(password: newPassword),
        );
      } finally {
        _isCompletingPasswordReset = false;
      }

      // Re-wrap the key if it's already in memory.
      if (_enc.hasKey) {
        await _keyService.saveNewWrappedKey(newPassword);
        _encryptionReady = true;
        _status          = AuthStatus.authenticated;
        _safeNotify();
        return true;
      }

      // Try recovery via the UID-wrapped key from the database.
      final recovered = await _keyService.rewrapWithRecoveryKey(
        uid:         uid,
        newPassword: newPassword,
      );
      if (recovered) {
        _encryptionReady = _enc.hasKey;
        _status          = AuthStatus.authenticated;
        _safeNotify();
        return true;
      }

      // Fallback: Generate a new key if recovery is not possible.
      final newKeyBytes = await _enc.generateDataKey();
      final newWrapped  = await _enc.wrapWithPassword(newKeyBytes, newPassword);
      await _keyService.saveWrappedKeyMapWithRecovery(newWrapped, uid);
      _encryptionReady = _enc.hasKey;
      _status          = AuthStatus.authenticated;
      _safeNotify();
      return true;
    } on AuthException catch (e) {
      _errorMessage = AppErrors.updatePassword(e.message);
      _safeNotify();
      return false;
    } catch (e) {
      _errorMessage = AppErrors.fromException(e);
      _safeNotify();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // --- Profile Updates ---

  /// Updates the user's display name.
  Future<bool> updateDisplayName(String name) async {
    _setLoading(true);
    _clearError();
    try {
      final response = await SupabaseConfig.client.auth.updateUser(
        UserAttributes(data: {'display_name': name.trim()}),
      );
      _user = response.user;
      _safeNotify();
      return true;
    } on AuthException catch (e) {
      _errorMessage = AppErrors.fromException(e);
      _safeNotify();
      return false;
    } catch (e) {
      _errorMessage = AppErrors.fromException(e);
      _safeNotify();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Initiates an email update.
  Future<bool> updateEmail(String newEmail) async {
    _setLoading(true);
    _clearError();
    try {
      await SupabaseConfig.client.auth.updateUser(
        UserAttributes(email: newEmail.trim()),
        emailRedirectTo: _redirectUrl,
      );
      return true;
    } on AuthException catch (e) {
      _errorMessage = AppErrors.updateEmail(e.message);
      _safeNotify();
      return false;
    } catch (e) {
      _errorMessage = AppErrors.fromException(e);
      _safeNotify();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Updates the user's password from within the settings.
  Future<bool> updatePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      final ok = await _keyService.rewrapKey(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
      if (!ok) {
        _errorMessage = AppErrors.wrongCurrentPassword;
        _safeNotify();
        return false;
      }
      await SupabaseConfig.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return true;
    } on AuthException catch (e) {
      _errorMessage = AppErrors.updatePassword(e.message);
      _safeNotify();
      return false;
    } catch (e) {
      _errorMessage = AppErrors.fromException(e);
      _safeNotify();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // --- Account Deletion ---

  /// Deletes the user's account and all associated data.
  Future<bool> deleteAccount() async {
    _setLoading(true);
    _clearError();
    try {
      await SupabaseConfig.client.rpc('delete_user_account');
      try {
        await SupabaseConfig.client.functions.invoke('delete-user');
      } catch (_) {
        // Log or handle error if edge function fails.
      }
      await SupabaseConfig.client.auth.signOut();
      await _enc.clearKey();
      _status          = AuthStatus.unauthenticated;
      _encryptionReady = false;
      _safeNotify();
      return true;
    } on AuthException catch (e) {
      _errorMessage = 'Could not delete account: ${e.message}';
      _safeNotify();
      return false;
    } catch (e) {
      _errorMessage = AppErrors.fromException(e);
      _safeNotify();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // --- Helpers ---

  static String get _redirectUrl {
    if (kIsWeb) {
      // ignore: undefined_prefixed_name
      return Uri.base.origin;
    }
    return 'io.supabase.poppy://login-callback/';
  }

  void _safeNotify() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (hasListeners) notifyListeners();
    });
  }

  void _setLoading(bool v) {
    _isLoading = v;
    _safeNotify();
  }

  void _clearError() => _errorMessage = null;

  /// Clears the current error message.
  void clearError() {
    _clearError();
    _safeNotify();
  }
}
