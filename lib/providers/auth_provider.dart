import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:poppy/core/core.dart';
import 'package:poppy/services/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Auth Provider (FIXED)
// ─────────────────────────────────────────────────────────────

/// Represents the various authentication states of the application.
enum AuthStatus {
  unknown,
  authenticated,
  unauthenticated,
  passwordRecovery,
  restoringKey,  // ← NEW: Key needs to be restored from cloud
}

/// Manages the authentication lifecycle, encryption keys, and security state.
class AuthProvider extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  final _enc = EncryptionService.instance;
  final _keyService = KeyService();
  final _sync = SyncService.instance;
  final _authService = AuthService();

  AuthStatus _status = AuthStatus.unknown;
  User? _user;
  bool _isLocked = false;
  bool _isCompletingPasswordReset = false;
  bool _pinEnabled = false;
  String? _errorMessage;
  bool _isLoading = false;
  bool _encryptionReady = false;

  /// Tracks whether we're in the middle of a signIn() call
  /// to prevent the listener from interfering.
  bool _isSigningIn = false;

  VoidCallback? onSignedIn;
  VoidCallback? onSignedOut;

  // ─────────────────────────────────────────────────────────────
  //  Getters
  // ─────────────────────────────────────────────────────────────

  AuthStatus get status => _status;
  User? get user => _user;
  bool get isLocked => _isLocked;
  bool get pinEnabled => _pinEnabled;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get encryptionReady => _encryptionReady;
  bool get needsKeyRestore => _status == AuthStatus.restoringKey;

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

  // ─────────────────────────────────────────────────────────────
  //  Initialization & Lifecycle
  // ─────────────────────────────────────────────────────────────

  Future<void> _init() async {
    final session = SupabaseConfig.client.auth.currentSession;
    if (session != null) {
      _user = session.user;
      await _checkPinLock(resetLock: true);

      final loaded = await _enc.loadCachedKey();
      _encryptionReady = loaded;

      if (_encryptionReady) {
        // Key is cached locally - we're fully ready
        _status = AuthStatus.authenticated;
        _startSync();
      } else {
        // Key not cached - user needs to enter password to restore it
        // DO NOT set authenticated until key is restored
        _status = AuthStatus.restoringKey;
      }
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
          _encryptionReady = _enc.hasKey;
          _safeNotify();
          break;

      // ─────────────────────────────────────────────────────
      //  CRITICAL FIX: Do NOT handle signedIn here
      //  The signIn() method controls this flow completely
      //  to avoid the race condition
      // ─────────────────────────────────────────────────────
        case AuthChangeEvent.signedIn:
        // Only update user reference - don't touch status or encryption
        // signIn() will handle everything
          if (!_isSigningIn) {
            // This handles automatic session refresh, not manual signIn
            // In this case, the key should already be in memory
            if (_encryptionReady) {
              _status = AuthStatus.authenticated;
              _safeNotify();
            }
          }
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
          // Keep the cached key for convenience (see clearKey below)
          onSignedOut?.call();
          _safeNotify();
          break;

        default:
          break;
      }
    });
  }

  // ─────────────────────────────────────────────────────────────
  //  Key Restoration (NEW)
  // ─────────────────────────────────────────────────────────────

  /// Called when the app has a session but no cached key.
  /// Prompts user for password to unwrap the cloud-stored key.
  Future<bool> restoreKeyWithPassword(String password) async {
    _setLoading(true);
    _clearError();

    try {
      final success = await _keyService.loadAndUnwrapWithPassword(password);

      if (success && _enc.hasKey) {
        _encryptionReady = true;
        _status = AuthStatus.authenticated;
        await _checkPinLock();
        _isLocked = false;
        _startSync();
        onSignedIn?.call();
        _safeNotify();
        return true;
      } else {
        _errorMessage = 'Incorrect password. Please try again.';
        _safeNotify();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Failed to restore encryption key: ${e.toString()}';
      _safeNotify();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Signs out and forces a fresh sign-in (used when key restore fails too many times).
  Future<void> signOutForFreshLogin() async {
    await _enc.clearKey();  // Actually clear the key this time
    await SupabaseConfig.client.auth.signOut();
  }

  // ─────────────────────────────────────────────────────────────
  //  Profile & Data Sync
  // ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> fetchProfile() async {
    try {
      return await _authService.fetchProfile();
    } catch (e) {
      debugPrint('Profile fetch failed: $e');
      return null;
    }
  }

  Future<void> updateProfile(Map<String, dynamic> data) {
    return _authService.updateProfile(data);
  }

  Future<void> syncPinState([Map<String, dynamic>? profile]) async {
    final data = profile ?? await fetchProfile();
    if (data == null) return;
    final remotePin = data[DBColumn.pinEnabled] as bool? ?? false;
    if (remotePin != _pinEnabled) {
      await setPinEnabled(remotePin, syncToCloud: false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  PIN Lock Management
  // ─────────────────────────────────────────────────────────────

  Future<void> _checkPinLock({bool resetLock = false}) async {
    final enabled = await _storage.read(key: StorageKeys.pinEnabled);
    _pinEnabled = enabled == 'true';
    if (_pinEnabled && resetLock) {
      _isLocked = true;
    }
  }

  void unlock() {
    _isLocked = false;
    _safeNotify();
  }

  Future<void> setPinEnabled(bool enabled, {bool syncToCloud = true}) async {
    _pinEnabled = enabled;
    await _storage.write(key: StorageKeys.pinEnabled, value: enabled.toString());
    if (!enabled) await _storage.delete(key: StorageKeys.pinHash);

    if (syncToCloud && isAuthenticated) {
      await _authService.updateProfile({DBColumn.pinEnabled: enabled});
    }

    _safeNotify();
  }

  // ─────────────────────────────────────────────────────────────
  //  Authentication Actions
  // ─────────────────────────────────────────────────────────────

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();
    _encryptionReady = false;
    _isSigningIn = true;  // ← Prevent listener from interfering

    try {
      // This will trigger the signedIn event, but our listener
      // now ignores it because _isSigningIn is true
      await SupabaseConfig.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      // Now we're in control - load the key
      final hasKeys = await _keyService.hasKeysRow();

      if (!hasKeys) {
        // New account - check for pending key from signUp
        final pending = await _storage.read(key: StorageKeys.pendingEncKey);
        if (pending != null) {
          await _keyService.saveWrappedKey(encDataKeyJson: pending);
          await _storage.delete(key: StorageKeys.pendingEncKey);
        }
        final loaded = await _enc.loadCachedKey();
        if (!loaded && !_enc.hasKey) {
          await _keyService.loadAndUnwrapWithPassword(password);
        }
      } else {
        // Existing account - try cached key first, then unwrap
        final loaded = await _enc.loadCachedKey();
        if (!loaded) {
          await _keyService.loadAndUnwrapWithPassword(password);
        }
      }

      // NOW check if we actually have the key
      _encryptionReady = _enc.hasKey;

      if (!_encryptionReady) {
        // This shouldn't happen with correct password, but handle it
        _errorMessage = 'Failed to load encryption key. Please try again.';
        _safeNotify();
        return false;
      }

      await _checkPinLock();
      _isLocked = false;
      _status = AuthStatus.authenticated;
      _startSync();
      onSignedIn?.call();
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
      _isSigningIn = false;  // ← Release the lock
      _setLoading(false);
    }
  }

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

  Future<void> signOut() async {
    await SupabaseConfig.client.auth.signOut();
    // Note: We do NOT call _enc.clearKey() here anymore
    // The key stays cached for convenience on next sign-in
    // See EncryptionService.clearKey() modification below
  }

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

      if (_enc.hasKey) {
        await _keyService.saveNewWrappedKey(newPassword);
        _encryptionReady = true;
        _status = AuthStatus.authenticated;
        _startSync();
        _safeNotify();
        return true;
      }

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

  Future<bool> deleteAccount() async {
    _setLoading(true);
    _clearError();

    try {
      await SupabaseConfig.client.rpc('delete_user_account');
      try {
        await SupabaseConfig.client.functions.invoke('delete-user');
      } catch (_) {}
      _stopSync();
      await _clearLocalCache();
      await SupabaseConfig.client.auth.signOut();
      await _enc.clearKey();  // Actually clear on account delete
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

  // ─────────────────────────────────────────────────────────────
  //  Internal Helpers
  // ─────────────────────────────────────────────────────────────

  void _startSync() => _sync.startListening();
  void _stopSync() => _sync.stopListening();

  Future<void> _clearLocalCache() async {
    final userId = SupabaseConfig.currentUser?.id;
    if (userId != null) {
      await LocalDbService.instance.clearForUser(userId);
    }
  }

  static String get _redirectUrl {
    if (kIsWeb) return Uri.base.origin;
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

  void clearError() {
    _clearError();
    _safeNotify();
  }
}