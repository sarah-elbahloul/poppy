import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/error_messages.dart';
import 'package:poppy/core/supabase_client.dart';
import 'package:poppy/services/encryption_service.dart';
import 'package:poppy/services/key_service.dart' show KeyService, RewrapResult;
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Auth Provider
//  Location: lib/providers/auth_provider.dart
//
//  AUTH STATES
//  ───────────
//  unknown          → app start, checking session
//  unauthenticated  → no session, show login
//  authenticated    → normal session, show home
//  passwordRecovery → one-time reset session from email link,
//                     show SetNewPasswordScreen
//
//  FORGOT PASSWORD (email reset) — HOW IT WORKS
//  ─────────────────────────────────────────────
//  1. sendPasswordResetEmail(email) — Supabase sends link
//  2. User taps link → Supabase redirects to app deep link /
//     web URL → app receives AuthChangeEvent.passwordRecovery
//  3. _status flips to passwordRecovery → SetNewPasswordScreen shown
//  4. User enters new password → completePasswordReset(newPassword):
//       a. updateUser(password: newPassword)  — updates Supabase auth
//       b. KeyService.saveNewWrappedKey(newPassword) — re-wraps data key
//          If no key in memory (different device / reinstall):
//          generate a fresh data key (old entries unreadable — expected
//          behaviour for E2E encrypted app with no key escrow).
//       c. _status flips to authenticated → home screen
// ─────────────────────────────────────────────────────────────

enum AuthStatus { unknown, authenticated, unauthenticated, passwordRecovery }

class AuthProvider extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  final _enc = EncryptionService.instance;
  final _keyService = KeyService();

  AuthStatus _status = AuthStatus.unknown;
  User? _user;
  bool _isLocked = false;
  bool _pinEnabled = false;
  String? _errorMessage;
  bool _isLoading = false;
  bool _encryptionReady = false;

  AuthStatus get status => _status;

  User? get user => _user;

  bool get isLocked => _isLocked;

  bool get pinEnabled => _pinEnabled;

  String? get errorMessage => _errorMessage;

  bool get isLoading => _isLoading;

  bool get isAuthenticated => _status == AuthStatus.authenticated;

  bool get encryptionReady => _encryptionReady;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    final session = SupabaseConfig.client.auth.currentSession;
    if (session != null) {
      _user = session.user;
      // Await pin lock state BEFORE setting status so the first frame
      // rendered by _RootRouter already has the correct isLocked value.
      // Without this, _status = authenticated fires a frame showing
      // HomeScreen for one tick before _isLocked becomes true.
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
          // signIn() sets _status and _encryptionReady itself after the
          // full key-load sequence completes. The stream event fires
          // concurrently — if we set status here too we create a race
          // where _RootRouter renders HomeScreen before the key is ready.
          // Only handle the case where the session was restored at cold
          // start (i.e. _init already handled it) — nothing to do here.
          break;

        case AuthChangeEvent.passwordRecovery:
          // One-time session from reset email link.
          // Try to load the data key from local cache — may succeed
          // if same device; will fail on fresh install (expected).
          _status = AuthStatus.passwordRecovery;
          await _enc.loadCachedKey(); // best-effort; may not succeed
          _safeNotify();
          break;

        case AuthChangeEvent.userUpdated:
          // Fired after updateUser() — just keep user reference fresh.
          // completePasswordReset() has already set status/encryptionReady.
          await SupabaseConfig.client.auth.refreshSession();
          _user = SupabaseConfig.client.auth.currentUser;
          _safeNotify();
          break;

        case AuthChangeEvent.signedOut:
          _status = AuthStatus.unauthenticated;
          _isLocked = false;
          _encryptionReady = false;
          await _enc.clearKey();
          _safeNotify();
          break;

        case AuthChangeEvent.tokenRefreshed:
          _user = SupabaseConfig.client.auth.currentUser;
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

  void unlock() {
    _isLocked = false;
    _safeNotify();
  }

  Future<void> setPinEnabled(bool enabled) async {
    _pinEnabled = enabled;
    await _storage.write(
        key: StorageKeys.pinEnabled, value: enabled.toString());
    if (!enabled) await _storage.delete(key: StorageKeys.pinHash);
    _safeNotify();
  }

  // ── Sign in ───────────────────────────────────────────────

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
        // First sign-in after sign-up: flush pending blob to DB
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
      await _checkPinLock(resetLock: true);
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

  // ── Sign up (phase 1 — no session yet) ───────────────────

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

  // ── Sign out ──────────────────────────────────────────────

  Future<void> signOut() async {
    await SupabaseConfig.client.auth.signOut();
  }

  // ── Forgot password: send reset email ────────────────────

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

  // ── Forgot password: complete reset (called from SetNewPasswordScreen)
  //
  // At this point the user has a one-time passwordRecovery session.
  // We update the Supabase auth password, then re-wrap the data key.
  //
  // KEY RECOVERY LOGIC:
  //  1. Same device / key still in cache:
  //       Re-wrap existing key with new password. ✓ All entries readable.
  //  2. Different device — old password provided and correct:
  //       Fetch wrapped key from DB, unwrap with old password, re-wrap
  //       with new password. ✓ All entries readable.
  //  3. Different device — old password wrong or not provided:
  //       Caller must first call [completePasswordResetWithOldPassword]
  //       which returns false so the UI can show the old-password prompt.
  //       If the user explicitly gives up, call [completePasswordResetFresh]
  //       to generate a new key (old entries unreadable — last resort).

  /// Step 1 of password reset: updates Supabase auth password.
  /// Must be called before the one-time session token expires.
  Future<bool> updateAuthPassword(String newPassword) async {
    _setLoading(true);
    _clearError();
    try {
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

  /// Full password reset when the data key is cached on this device
  /// (same device as registration, or key was previously loaded).
  /// Returns true and sets authenticated state on success.
  Future<bool> completePasswordReset(String newPassword) async {
    _setLoading(true);
    _clearError();
    try {
      await SupabaseConfig.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (_enc.hasKey) {
        // Same device: re-wrap the in-memory key.
        await _keyService.saveNewWrappedKey(newPassword);
        _encryptionReady = true;
        _status = AuthStatus.authenticated;
        _safeNotify();
        return true;
      }

      // Key not in memory — caller should use completePasswordResetCrossDevice
      // to ask for the old password before falling back to a new key.
      // Return false so SetNewPasswordScreen shows the old-password prompt.
      return false;
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

  /// Cross-device password reset: tries to recover entries using the
  /// user's old password. Call this after [completePasswordReset] returns
  /// false (key not cached — different device or fresh install).
  ///
  /// [newPassword] must already have been applied to Supabase auth via
  /// [completePasswordReset] (which called updateUser before returning false).
  ///
  /// Returns [RewrapResult.success] → all entries readable, status set to authenticated.
  /// Returns [RewrapResult.wrongPassword] → old password incorrect, let user retry.
  /// Returns [RewrapResult.error] → network failure.
  Future<RewrapResult> completePasswordResetCrossDevice({
    required String oldPassword,
    required String newPassword,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      final result = await _keyService.rewrapWithOldPassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
      if (result == RewrapResult.success) {
        _encryptionReady = _enc.hasKey;
        _status = AuthStatus.authenticated;
        _safeNotify();
      }
      return result;
    } catch (e) {
      _errorMessage = AppErrors.fromException(e);
      _safeNotify();
      return RewrapResult.error;
    } finally {
      _setLoading(false);
    }
  }

  /// Last-resort: generates a brand-new data key after the user has
  /// explicitly accepted that old entries will be unreadable.
  /// Call only after [completePasswordResetCrossDevice] failed AND the
  /// user confirmed the loss-of-entries warning.
  ///
  /// [newPassword] must already have been applied to Supabase auth.
  Future<bool> completePasswordResetFresh(String newPassword) async {
    _setLoading(true);
    _clearError();
    try {
      final newKeyBytes = await _enc.generateDataKey();
      final newWrapped = await _enc.wrapWithPassword(newKeyBytes, newPassword);
      await _keyService.saveWrappedKeyMap(newWrapped);
      _encryptionReady = _enc.hasKey;
      _status = AuthStatus.authenticated;
      _safeNotify();
      return true;
    } catch (e) {
      _errorMessage = AppErrors.fromException(e);
      _safeNotify();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Update email ──────────────────────────────────────────

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

  // ── Update password (from settings) ──────────────────────

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

  // ── Helpers ───────────────────────────────────────────────

  /// The redirect URL to use for Supabase auth emails.
  /// On web: the current page origin (works for any port).
  /// On mobile: the registered custom scheme deep link.
  static String get _redirectUrl {
    if (kIsWeb) {
      // Use the window's origin so it works on any port / domain
      // without hard-coding localhost:49296.
      // ignore: undefined_prefixed_name
      return Uri.base.origin;
    }
    return 'io.supabase.poppy://login-callback/';
  }

  // ── Delete account ────────────────────────────────────────
  //
  // Calls the Supabase `delete_user_account` RPC which must:
  //   1. Delete all rows in user_keys, entries, photos for this user
  //   2. Call auth.admin.deleteUser(uid) via a Postgres trigger or
  //      Supabase Edge Function (see SQL migration note below).
  //

  Future<bool> deleteAccount() async {
    _setLoading(true);
    _clearError();
    try {
      // Step 1: delete all app data via RPC
      await SupabaseConfig.client.rpc('delete_user_account');

      // Step 2: call Edge Function to delete the auth.users row
      // (service role key is required — only safe from server side)
      try {
        await SupabaseConfig.client.functions.invoke('delete-user');
      } catch (_) {
        // If Edge Function isn't deployed yet, the data is still
        // gone but the auth row remains. Sign out anyway so the
        // user is effectively logged out.
      }

      // Step 3: sign out locally
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

// NOTE: This extension is appended — the class above ends with the closing }.
// The deleteAccount method is added directly below inside the class definition
// via the patch in auth_provider_patch.dart — see that file.
