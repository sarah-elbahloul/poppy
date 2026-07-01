import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:poppy/core/core.dart';
import 'package:poppy/features/auth/data/models/profile.dart';
import 'package:poppy/features/auth/data/services/auth_service.dart';
import 'package:poppy/features/auth/data/services/encryption_service.dart';
import 'package:poppy/features/auth/data/services/auth_errors.dart';
import 'package:poppy/features/auth/data/services/key_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Auth Provider
// ─────────────────────────────────────────────────────────────

enum AuthStatus {
  unknown,
  authenticated,
  unauthenticated,
  passwordRecovery,
  restoringKey,
}

class AuthProvider extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  final _enc = EncryptionService.instance;
  final _keyService = KeyService();
  final _sync = SyncService.instance;
  final _authService = AuthService();

  AuthStatus _status = AuthStatus.unknown;
  User? _user;
  Profile? _profile;
  bool _isLocked = false;
  bool _isCompletingPasswordReset = false;
  String? _errorMessage;
  bool _isLoading = false;
  bool _encryptionReady = false;

  bool _isSigningIn = false;

  VoidCallback? onSignedIn;
  VoidCallback? onSignedOut;

  AuthStatus get status => _status;
  User? get user => _user;
  Profile? get profile => _profile;
  bool get isLocked => _isLocked;
  bool get pinEnabled => _profile?.pinEnabled ?? false;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get encryptionReady => _encryptionReady;
  bool get needsKeyRestore => _status == AuthStatus.restoringKey;

  String get displayName => _profile?.displayName ?? 'User';

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    final session = SupabaseConfig.client.auth.currentSession;
    if (session != null) {
      _user = session.user;
      await _refreshProfile();
      await _checkPinLock(resetLock: true);

      final loaded = await _enc.loadCachedKey();
      _encryptionReady = loaded;

      if (_encryptionReady) {
        _status = AuthStatus.authenticated;
        _startSync();
      } else {
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

        case AuthChangeEvent.signedIn:
          if (!_isSigningIn) {
            if (_encryptionReady) {
              await _refreshProfile();
              _status = AuthStatus.authenticated;
              _safeNotify();
            }
          }
          break;

        case AuthChangeEvent.userUpdated:
          _user = data.session?.user;
          await _refreshProfile();
          _safeNotify();
          break;

        case AuthChangeEvent.signedOut:
          if (_isCompletingPasswordReset) break;
          _stopSync();
          await _clearLocalCache();
          _status = AuthStatus.unauthenticated;
          _user = null;
          _profile = null;
          _isLocked = false;
          _encryptionReady = false;
          onSignedOut?.call();
          _safeNotify();
          break;

        default:
          break;
      }
    });
  }

  Future<void> _refreshProfile() async {
    if (_user == null) return;
    try {
      final map = await _authService.fetchProfile();
      if (map != null) {
        _profile = Profile.fromMap(map, _user!);
      }
    } catch (e) {
      debugPrint('Profile refresh failed: $e');
    }
  }

  Future<bool> restoreKeyWithPassword(String password) async {
    _setLoading(true);
    _clearError();

    try {
      final success = await _keyService.loadAndUnwrapWithPassword(password);

      if (success && _enc.hasKey) {
        _encryptionReady = true;
        _status = AuthStatus.authenticated;
        await _refreshProfile();
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

  Future<void> signOutForFreshLogin() async {
    await _enc.clearKey();
    await SupabaseConfig.client.auth.signOut();
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    await _authService.updateProfile(data);
    await _refreshProfile();
    _safeNotify();
  }

  Future<void> syncPinState() async {
    if (_profile == null) await _refreshProfile();
    if (_profile == null) return;

    final remotePin = _profile!.pinEnabled;
    final enabledStr = await _storage.read(key: StorageKeys.pinEnabled);
    final localPin = enabledStr == 'true';

    if (remotePin != localPin) {
      await setPinEnabled(remotePin, syncToCloud: false);
    }
  }

  Future<void> _checkPinLock({bool resetLock = false}) async {
    final enabled = await _storage.read(key: StorageKeys.pinEnabled);
    final pinEnabled = enabled == 'true';
    if (pinEnabled && resetLock) {
      _isLocked = true;
    }
  }

  void unlock() {
    _isLocked = false;
    _safeNotify();
  }

  Future<void> setPinEnabled(bool enabled, {bool syncToCloud = true}) async {
    await _storage.write(key: StorageKeys.pinEnabled, value: enabled.toString());
    if (!enabled) await _storage.delete(key: StorageKeys.pinHash);

    if (syncToCloud && isAuthenticated) {
      await updateProfile({DBColumn.pinEnabled: enabled});
    } else {
      if (_profile != null) {
        _profile = _profile!.copyWith(pinEnabled: enabled);
      }
      _safeNotify();
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();
    _encryptionReady = false;
    _isSigningIn = true;

    try {
      await SupabaseConfig.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final hasKeys = await _keyService.hasKeysRow();

      if (!hasKeys) {
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
        final loaded = await _enc.loadCachedKey();
        if (!loaded) {
          await _keyService.loadAndUnwrapWithPassword(password);
        }
      }

      _encryptionReady = _enc.hasKey;

      if (!_encryptionReady) {
        _errorMessage = 'Failed to load encryption key. Please try again.';
        _safeNotify();
        return false;
      }

      await _refreshProfile();
      await _checkPinLock();
      _isLocked = false;
      _status = AuthStatus.authenticated;
      _startSync();
      onSignedIn?.call();
      _safeNotify();
      return true;

    } on AuthException catch (e) {
      _errorMessage = AuthErrors.signIn(e.message);
      _encryptionReady = false;
      _safeNotify();
      return false;
    } catch (e) {
      _errorMessage = AppErrors.fromException(e);
      _encryptionReady = false;
      _safeNotify();
      return false;
    } finally {
      _isSigningIn = false;
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
      _errorMessage = AuthErrors.signUp(e.message);
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
      _errorMessage = AuthErrors.resetPassword(e.message);
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
        await _refreshProfile();
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
        await _refreshProfile();
        if (_encryptionReady) _startSync();
        _safeNotify();
        return true;
      }

      final newKeyBytes = await _enc.generateDataKey();
      final newWrapped = await _enc.wrapWithPassword(newKeyBytes, newPassword);
      await _keyService.saveWrappedKeyMapWithRecovery(newWrapped, uid);
      _encryptionReady = _enc.hasKey;
      _status = AuthStatus.authenticated;
      await _refreshProfile();
      if (_encryptionReady) _startSync();
      _safeNotify();
      return true;
    } on AuthException catch (e) {
      _errorMessage = AuthErrors.updatePassword(e.message);
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
      await _refreshProfile();
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
      _errorMessage = AuthErrors.updateEmail(e.message);
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
        _errorMessage = AuthErrors.wrongCurrentPassword;
        _safeNotify();
        return false;
      }
      await SupabaseConfig.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      _safeNotify();
      return true;
    } on AuthException catch (e) {
      _errorMessage = AuthErrors.updatePassword(e.message);
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
      await _enc.clearKey();
      _status = AuthStatus.unauthenticated;
      _user = null;
      _profile = null;
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
    if (!hasListeners) return;

    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (hasListeners) notifyListeners();
      });
    } else {
      notifyListeners();
    }
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