import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:poppy/core/core.dart';
import 'package:poppy/services/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Authentication lifecycle states.
enum AuthStatus { unknown, authenticated, unauthenticated, passwordRecovery }

/// Manages authentication, PIN lock, and encryption key lifecycle.
///
/// ## PIN Behavior
///
/// | Scenario | Behavior |
/// |----------|----------|
/// | Cold start (app killed) | Lock if PIN enabled |
/// | Warm resume (backgrounded) | Lock if elapsed > timeout |
/// | Fresh sign-in | Never lock (password just verified) |
/// | Sign out | Keep PIN enabled (device setting) |
/// | Uninstall/reinstall | Disable PIN remotely (recovery) |
/// | User disables PIN | Clear local hash, sync to cloud |
class AuthProvider extends ChangeNotifier with WidgetsBindingObserver {
  final _storage = const FlutterSecureStorage();
  final _auth = AuthService();
  final _enc = EncryptionService.instance;
  final _keyService = KeyService();
  final _sync = SyncService.instance;

  // ── State ──────────────────────────────────────────────────

  AuthStatus _status = AuthStatus.unknown;
  User? _user;
  bool _isLoading = false;
  String? _errorMessage;

  bool _pinEnabled = false;
  bool _isLocked = false;
  DateTime? _backgroundedAt;

  bool _encryptionReady = false;
  bool _isResettingPassword = false;

  /// Guards against the initial stream emission during [init].
  ///
  /// Supabase's `onAuthStateChange` emits the current state immediately
  /// when subscribed. Without this guard, that initial emission would
  /// trigger [_onSignedIn], which incorrectly clears the lock state
  /// that was just set during cold start, causing the home screen to
  /// flash before the lock screen.
  bool _initComplete = false;

  // ── Callbacks (wired in app.dart) ──────────────────────────

  VoidCallback? onSignedIn;
  VoidCallback? onSignedOut;

  // ── Constants ──────────────────────────────────────────────

  /// Auto-lock after 2 minutes of backgrounding.
  static const autoLockDuration = Duration(minutes: 2);

  // ── Getters ────────────────────────────────────────────────

  AuthStatus get status => _status;
  User? get user => _user;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLocked => _isLocked;
  bool get pinEnabled => _pinEnabled;
  bool get encryptionReady => _encryptionReady;

  String get displayName {
    final meta = _user?.userMetadata;
    final name = meta?['display_name'] ?? meta?['full_name'];
    if (name is String && name.trim().isNotEmpty) return name.trim();
    final email = _user?.email ?? '';
    return email.contains('@') ? email.split('@')[0] : email;
  }

  // ── Lifecycle ──────────────────────────────────────────────

  AuthProvider() {
    _init();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _init() async {
    final session = SupabaseConfig.client.auth.currentSession;

    if (session != null) {
      _user = session.user;
      _status = AuthStatus.authenticated;

      // Load PIN state and lock immediately on cold start.
      await _loadPinState();
      if (_pinEnabled) _isLocked = true;

      // Load encryption key from secure cache.
      _encryptionReady = await _enc.loadCachedKey();
      if (_encryptionReady) _sync.startListening();

      // Background sync: handle reinstall recovery.
      _syncPinStateAfterInit();
    } else {
      _status = AuthStatus.unauthenticated;
    }

    // Mark init complete BEFORE subscribing to the stream.
    // This prevents the initial emission from triggering
    // [_onSignedIn] and clearing the lock state.
    _initComplete = true;
    _notify();

    // Now safe to listen — all subsequent events are real transitions.
    SupabaseConfig.authStateStream.listen(_handleAuthEvent);
  }

  void _handleAuthEvent(AuthState data) {
    // During init, we already handled the current state by checking
    // currentSession directly. The stream's initial emission is
    // redundant and must be ignored to prevent race conditions.
    if (!_initComplete) return;

    _user = data.session?.user;

    switch (data.event) {
      case AuthChangeEvent.signedIn:
        _onSignedIn();
      case AuthChangeEvent.signedOut:
        if (!_isResettingPassword) _onSignedOut();
      case AuthChangeEvent.passwordRecovery:
        _status = AuthStatus.passwordRecovery;
        _enc.loadCachedKey();
        _notify();
      case AuthChangeEvent.userUpdated:
        _notify();
      default:
        break;
    }
  }

  void _onSignedIn() async {
    _status = AuthStatus.authenticated;

    // Load PIN state but do NOT lock after fresh sign-in.
    await _loadPinState();
    _isLocked = false;

    // Load or unwrap encryption key.
    _encryptionReady = await _enc.loadCachedKey();
    if (_encryptionReady) _sync.startListening();

    onSignedIn?.call();
    _notify();
  }

  void _onSignedOut() async {
    _sync.stopListening();
    await _clearLocalData();

    _status = AuthStatus.unauthenticated;
    _isLocked = false;
    _encryptionReady = false;

    onSignedOut?.call();
    _notify();
  }

  // ── App Lifecycle (Auto-Lock) ──────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_pinEnabled || _isLocked) return;

    if (state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed && _backgroundedAt != null) {
      final elapsed = DateTime.now().difference(_backgroundedAt!);
      _backgroundedAt = null;

      if (elapsed >= autoLockDuration) {
        _isLocked = true;
        _notify();
      }
    }
  }

  // ── PIN Operations ─────────────────────────────────────────

  /// Verifies PIN hash without modifying lock state.
  Future<bool> verifyPin(String pin) async {
    final storedHash = await _storage.read(key: StorageKeys.pinHash);
    return storedHash != null && _hashPin(pin) == storedHash;
  }

  /// Verifies PIN and unlocks if correct.
  Future<bool> verifyAndUnlock(String pin) async {
    final storedHash = await _storage.read(key: StorageKeys.pinHash);
    if (storedHash == null || _hashPin(pin) != storedHash) return false;

    _isLocked = false;
    _notify();
    return true;
  }

  /// Saves a new PIN and enables lock.
  Future<void> setPin(String pin) async {
    await _storage.write(key: StorageKeys.pinHash, value: _hashPin(pin));
    await _storage.write(key: StorageKeys.pinEnabled, value: 'true');
    _pinEnabled = true;

    if (isAuthenticated) {
      await _updateProfile({DBColumn.pinEnabled: true});
    }
    _notify();
  }

  /// Removes PIN and disables lock.
  Future<void> removePin() async {
    await _storage.delete(key: StorageKeys.pinHash);
    await _storage.write(key: StorageKeys.pinEnabled, value: 'false');
    _pinEnabled = false;
    _isLocked = false;

    if (isAuthenticated) {
      await _updateProfile({DBColumn.pinEnabled: false});
    }
    _notify();
  }

  /// Changes PIN after verifying the current one.
  Future<bool> changePin({required String currentPin, required String newPin}) async {
    final storedHash = await _storage.read(key: StorageKeys.pinHash);
    if (storedHash == null || _hashPin(currentPin) != storedHash) return false;

    await _storage.write(key: StorageKeys.pinHash, value: _hashPin(newPin));
    return true;
  }

  Future<void> _loadPinState() async {
    final value = await _storage.read(key: StorageKeys.pinEnabled);
    _pinEnabled = value == 'true';
  }

  Future<void> _syncPinStateAfterInit() async {
    if (!isAuthenticated) return;

    try {
      final profile = await _fetchProfile();
      if (profile == null) return;

      final remoteEnabled = profile[DBColumn.pinEnabled] as bool? ?? false;
      final hasLocalHash = await _storage.read(key: StorageKeys.pinHash) != null;

      if (remoteEnabled && !hasLocalHash) {
        await _updateProfile({DBColumn.pinEnabled: false});
        await _storage.write(key: StorageKeys.pinEnabled, value: 'false');
        _pinEnabled = false;
        _isLocked = false;
        _notify();
        debugPrint('PIN disabled remotely (reinstall recovery)');
      } else if (remoteEnabled != _pinEnabled) {
        _pinEnabled = remoteEnabled;
        await _storage.write(
          key: StorageKeys.pinEnabled,
          value: remoteEnabled.toString(),
        );
        _notify();
      }
    } catch (e) {
      debugPrint('PIN sync failed: $e');
    }
  }

  String _hashPin(String pin) {
    return sha256.convert(utf8.encode(pin)).toString();
  }

  // ── Authentication Actions ─────────────────────────────────

  Future<bool> signIn({required String email, required String password}) async {
    _setLoading(true);
    _clearError();
    _encryptionReady = false;

    try {
      await _auth.signIn(email: email, password: password);

      final hasKeys = await _keyService.hasKeysRow();
      if (hasKeys) {
        final loaded = await _enc.loadCachedKey();
        if (!loaded) await _keyService.loadAndUnwrapWithPassword(password);
      } else {
        final pending = await _storage.read(key: StorageKeys.pendingEncKey);
        if (pending != null) {
          await _keyService.saveWrappedKey(encDataKeyJson: pending);
          await _storage.delete(key: StorageKeys.pendingEncKey);
        }
        final loaded = await _enc.loadCachedKey();
        if (!loaded && !_enc.hasKey) {
          await _keyService.loadAndUnwrapWithPassword(password);
        }
      }

      _encryptionReady = _enc.hasKey;
      if (_encryptionReady) _sync.startListening();

      await _loadPinState();
      _isLocked = false;

      _status = AuthStatus.authenticated;
      _notify();
      return true;
    } on AuthException catch (e) {
      _errorMessage = AppErrors.signIn(e.message);
    } catch (e) {
      _errorMessage = AppErrors.fromException(e);
    } finally {
      _setLoading(false);
    }
    return false;
  }

  Future<bool> signUp({required String email, required String password}) async {
    _setLoading(true);
    _clearError();

    try {
      await _auth.signUp(
        email: email,
        password: password,
        redirectTo: _redirectUrl,
      );

      final dataKey = await _enc.generateDataKey();
      final wrapped = await _enc.wrapWithPassword(dataKey, password);
      await _storage.write(
        key: StorageKeys.pendingEncKey,
        value: jsonEncode(wrapped),
      );
      return true;
    } on AuthException catch (e) {
      _errorMessage = AppErrors.signUp(e.message);
      await _enc.clearKey();
    } catch (e) {
      _errorMessage = AppErrors.fromException(e);
      await _enc.clearKey();
    } finally {
      _setLoading(false);
    }
    return false;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ── Password Management ────────────────────────────────────

  Future<bool> sendPasswordReset(String email) async {
    _setLoading(true);
    _clearError();

    try {
      await _auth.sendPasswordReset(email, redirectTo: _redirectUrl);
      return true;
    } on AuthException catch (e) {
      _errorMessage = AppErrors.resetPassword(e.message);
    } catch (e) {
      _errorMessage = AppErrors.fromException(e);
    } finally {
      _setLoading(false);
    }
    return false;
  }

  Future<bool> completePasswordReset(String newPassword) async {
    _setLoading(true);
    _clearError();
    _isResettingPassword = true;

    try {
      await _auth.updateUser(UserAttributes(password: newPassword));

      if (_enc.hasKey) {
        await _keyService.saveNewWrappedKey(newPassword);
      } else {
        final recovered = await _keyService.rewrapWithRecoveryKey(
          uid: SupabaseConfig.userId,
          newPassword: newPassword,
        );
        if (!recovered) {
          final newKey = await _enc.generateDataKey();
          final wrapped = await _enc.wrapWithPassword(newKey, newPassword);
          await _keyService.saveWrappedKeyMapWithRecovery(wrapped, SupabaseConfig.userId);
        }
      }

      _encryptionReady = _enc.hasKey;
      _status = AuthStatus.authenticated;
      if (_encryptionReady) _sync.startListening();
      _notify();
      return true;
    } on AuthException catch (e) {
      _errorMessage = AppErrors.updatePassword(e.message);
    } catch (e) {
      _errorMessage = AppErrors.fromException(e);
    } finally {
      _isResettingPassword = false;
      _setLoading(false);
    }
    return false;
  }

  Future<bool> updatePassword({required String oldPassword, required String newPassword}) async {
    _setLoading(true);
    _clearError();

    try {
      final ok = await _keyService.rewrapKey(oldPassword: oldPassword, newPassword: newPassword);
      if (!ok) {
        _errorMessage = AppErrors.wrongCurrentPassword;
        _notify();
        return false;
      }
      await _auth.updateUser(UserAttributes(password: newPassword));
      _notify();
      return true;
    } on AuthException catch (e) {
      _errorMessage = AppErrors.updatePassword(e.message);
    } catch (e) {
      _errorMessage = AppErrors.fromException(e);
    } finally {
      _setLoading(false);
    }
    return false;
  }

  // ── Account Management ─────────────────────────────────────

  Future<bool> updateDisplayName(String name) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _auth.updateUser(
        UserAttributes(data: {'display_name': name.trim()}),
      );
      _user = response.user;
      _notify();
      return true;
    } catch (e) {
      _errorMessage = AppErrors.fromException(e);
    } finally {
      _setLoading(false);
    }
    return false;

  }

  Future<bool> updateEmail(String newEmail) async {
    _setLoading(true);
    _clearError();

    try {
      await _auth.updateUser(UserAttributes(email: newEmail.trim()));
      return true;
    } on AuthException catch (e) {
      _errorMessage = AppErrors.updateEmail(e.message);
    } catch (e) {
      _errorMessage = AppErrors.fromException(e);
    } finally {
      _setLoading(false);
    }
    return false;
  }

  Future<bool> deleteAccount() async {
    _setLoading(true);
    _clearError();

    try {
      await SupabaseConfig.client.rpc('delete_user_account');
      try {
        await SupabaseConfig.client.functions.invoke('delete-user');
      } catch (_) {}

      _sync.stopListening();
      await _clearLocalData();
      await _auth.signOut();
      await _enc.clearKey();

      await _storage.delete(key: StorageKeys.pinHash);
      await _storage.delete(key: StorageKeys.pinEnabled);
      _pinEnabled = false;

      _status = AuthStatus.unauthenticated;
      _encryptionReady = false;
      _notify();
      return true;
    } on AuthException catch (e) {
      _errorMessage = 'Could not delete account: ${e.message}';
    } catch (e) {
      _errorMessage = AppErrors.fromException(e);
    } finally {
      _setLoading(false);
    }
    return false;
  }

  // ── Profile Data ───────────────────────────────────────────

  Future<Map<String, dynamic>?> fetchProfile() => _fetchProfile();

  Future<void> updateProfile(Map<String, dynamic> data) => _updateProfile(data);

  Future<Map<String, dynamic>?> _fetchProfile() async {
    try {
      return await SupabaseConfig.client
          .from('profiles')
          .select()
          .eq('id', SupabaseConfig.userId)
          .maybeSingle();
    } catch (e) {
      debugPrint('Profile fetch failed: $e');
      return null;
    }
  }

  Future<void> _updateProfile(Map<String, dynamic> data) async {
    try {
      await SupabaseConfig.client
          .from('profiles')
          .update(data)
          .eq('id', SupabaseConfig.userId);
    } catch (e) {
      debugPrint('Profile update failed: $e');
    }
  }

  // ── Internal Helpers ───────────────────────────────────────

  Future<void> _clearLocalData() async {
    final userId = SupabaseConfig.currentUser?.id;
    if (userId != null) {
      await LocalDbService.instance.clearForUser(userId);
    }
  }

  static String get _redirectUrl {
    if (kIsWeb) return Uri.base.origin;
    return 'io.supabase.poppy://login-callback/';
  }

  void _setLoading(bool v) {
    _isLoading = v;
    _notify();
  }

  void _clearError() => _errorMessage = null;

  void clearError() {
    _clearError();
    _notify();
  }

  void _notify() {
    if (!hasListeners) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (hasListeners) notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }
}