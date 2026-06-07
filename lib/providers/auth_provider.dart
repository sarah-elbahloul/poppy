import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:poppy/core/core.dart';
import 'package:poppy/services/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Represents the various authentication states of the application.
enum AuthStatus { unknown, authenticated, unauthenticated, passwordRecovery }

/// Manages the authentication lifecycle, encryption keys, and security state.
///
/// This provider serves as the single source of truth for the user's session,
/// handling transitions between login, registration, and password recovery.
/// It also manages the initialization of the data encryption layer.
class AuthProvider extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  final _enc = EncryptionService.instance;
  final _keyService = KeyService();
  final _sync = SyncService.instance;

  AuthStatus _status = AuthStatus.unknown;
  User? _user;
  bool _isLocked = false;
  bool _isCompletingPasswordReset = false;
  bool _pinEnabled = false;
  String? _errorMessage;
  bool _isLoading = false;
  bool _encryptionReady = false;

  /// The current authentication status.
  AuthStatus get status => _status;

  /// The currently authenticated Supabase user.
  User? get user => _user;

  /// Whether the app is currently PIN-locked.
  bool get isLocked => _isLocked;

  /// Whether PIN protection is enabled for the account.
  bool get pinEnabled => _pinEnabled;

  /// The last error message encountered during an auth operation.
  String? get errorMessage => _errorMessage;

  /// Whether an authentication operation is currently in progress.
  bool get isLoading => _isLoading;

  /// Whether a user is successfully authenticated.
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// Whether the encryption key has been successfully loaded and the data layer is ready.
  bool get encryptionReady => _encryptionReady;

  /// Returns a display name for the user, prioritizing metadata or email prefix.
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

      // Resolve PIN lock state before setting the status to avoid UI flickering.
      await _checkPinLock(resetLock: true);

      final loaded = await _enc.loadCachedKey();
      _encryptionReady = loaded;
      _status = AuthStatus.authenticated;

      if (_encryptionReady) _startSync();
    } else {
      _status = AuthStatus.unauthenticated;
    }
    _safeNotify();

    SupabaseConfig.authStateStream.listen((data) async {
      _user = data.session?.user;
      switch (data.event) {
        case AuthChangeEvent.passwordRecovery:
          _status = AuthStatus.passwordRecovery;
          await _enc.loadCachedKey();
          _safeNotify();
          break;

        case AuthChangeEvent.userUpdated:
          _user = data.session?.user;
          _safeNotify();
          break;

        case AuthChangeEvent.signedOut:
          if (_isCompletingPasswordReset) break;
          _stopSync();
          await _clearLocalCache();
          _status = AuthStatus.unauthenticated;
          _isLocked = false;
          _encryptionReady = false;
          await _enc.clearKey();
          _safeNotify();
          break;

        default:
          break;
      }
    });
  }

  // --- PIN Lock ---

  /// Checks local storage to see if PIN protection is enabled.
  Future<void> _checkPinLock({bool resetLock = false}) async {
    final enabled = await _storage.read(key: StorageKeys.pinEnabled);
    _pinEnabled = enabled == 'true';
    if (_pinEnabled && resetLock) {
      _isLocked = true;
    }
  }

  /// Unlocks the application for the current session.
  void unlock() {
    _isLocked = false;
    _safeNotify();
  }

  /// Enables or disables the PIN lock requirement.
  Future<void> setPinEnabled(bool enabled) async {
    _pinEnabled = enabled;
    await _storage.write(key: StorageKeys.pinEnabled, value: enabled.toString());
    if (!enabled) await _storage.delete(key: StorageKeys.pinHash);
    _safeNotify();
  }

  // --- Sync Control ---

  void _startSync() => _sync.startListening();

  void _stopSync() => _sync.stopListening();

  /// Clears local database cache, typically on sign-out.
  Future<void> _clearLocalCache() async {
    final userId = SupabaseConfig.currentUser?.id;
    if (userId != null) {
      await LocalDbService.instance.clearForUser(userId);
    }
  }

  // --- Authentication Actions ---

  /// Signs in the user and attempts to load or derive the encryption Data Key.
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
        // Handle first-time sign-in after sign-up where keys are pending.
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
      if (_encryptionReady) _startSync();

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

  /// Registers a new user and generates their unique Data Key.
  Future<bool> signUp({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      await SupabaseConfig.client.auth.signUp(
        email: email.trim(),
        password: password,
        emailRedirectTo: _redirectUrl,
      );

      final dataKeyBytes = await _enc.generateDataKey();
      final wrapped = await _enc.wrapWithPassword(dataKeyBytes, password);

      await _storage.write(
        key: StorageKeys.pendingEncKey,
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

  /// Ends the current user session and cleans up local sensitive data.
  Future<void> signOut() async {
    await SupabaseConfig.client.auth.signOut();
  }

  /// Triggers a password reset email to the user.
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

  /// Completes the password reset process and recovers/re-wraps the Data Key.
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

      // Priority 1: Key already in memory (same device reset).
      if (_enc.hasKey) {
        await _keyService.saveNewWrappedKey(newPassword);
        _encryptionReady = true;
        _status = AuthStatus.authenticated;
        _startSync();
        _safeNotify();
        return true;
      }

      // Priority 2: Recover using the recovery key from the database.
      final recovered = await _keyService.rewrapWithRecoveryKey(
        uid: uid,
        newPassword: newPassword,
      );
      if (recovered) {
        _encryptionReady = _enc.hasKey;
        _status = AuthStatus.authenticated;
        if (_encryptionReady) _startSync();
        _safeNotify();
        return true;
      }

      // Priority 3: Fallback — generate a fresh key (for legacy accounts).
      final newKeyBytes = await _enc.generateDataKey();
      final newWrapped = await _enc.wrapWithPassword(newKeyBytes, newPassword);
      await _keyService.saveWrappedKeyMapWithRecovery(newWrapped, uid);
      _encryptionReady = _enc.hasKey;
      _status = AuthStatus.authenticated;
      if (_encryptionReady) _startSync();
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

  // --- Account Management ---

  /// Updates the user's display name in their metadata.
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

  /// Updates the user's email address.
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

  /// Updates the account password and re-wraps the Data Key with the new password.
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

  /// Permanently deletes the user's account and all associated data.
  Future<bool> deleteAccount() async {
    _setLoading(true);
    _clearError();

    try {
      // 1. Delete application data via RPC.
      await SupabaseConfig.client.rpc('delete_user_account');

      // 2. Call Edge Function to remove the Auth user record.
      try {
        await SupabaseConfig.client.functions.invoke('delete-user');
      } catch (_) {
        // Proceed even if the Edge Function fails to ensure local sign-out.
      }

      _stopSync();
      await _clearLocalCache();

      // 3. Cleanup local state and sign out.
      await SupabaseConfig.client.auth.signOut();
      await _enc.clearKey();

      _status = AuthStatus.unauthenticated;
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

  /// Determines the redirect URL for authentication flows.
  static String get _redirectUrl {
    if (kIsWeb) {
      // ignore: undefined_prefixed_name
      return Uri.base.origin;
    }
    return 'io.supabase.poppy://login-callback/';
  }

  /// Safely notifies listeners, ensuring the notification happens after the current frame.
  void _safeNotify() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (hasListeners) notifyListeners();
    });
  }

  /// Sets the loading state and notifies listeners.
  void _setLoading(bool v) {
    _isLoading = v;
    _safeNotify();
  }

  /// Clears the internal error message.
  void _clearError() => _errorMessage = null;

  /// Public method to clear the error message and notify listeners.
  void clearError() {
    _clearError();
    _safeNotify();
  }
}
