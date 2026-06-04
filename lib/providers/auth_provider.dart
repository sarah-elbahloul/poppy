import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:poppy/core/core.dart';
import 'package:poppy/services/services.dart';
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

  /// Display name from Supabase user_metadata, fallback to email prefix
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

  AuthProvider() { _init(); }

  Future<void> _init() async {
    final session = SupabaseConfig.client.auth.currentSession;
    if (session != null) {
      _user   = session.user;
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
          _user = data.session?.user;
          _safeNotify();
          break;

        case AuthChangeEvent.signedOut:
        // Ignore the signedOut event that Supabase fires when
        // updateUser() consumes the one-time passwordRecovery session.
        // completePasswordReset() sets _status = authenticated itself.
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

  void unlock() { _isLocked = false; _safeNotify(); }

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
    _setLoading(true); _clearError();
    _encryptionReady = false;
    try {
      await SupabaseConfig.client.auth.signInWithPassword(
        email: email.trim(), password: password,
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
      _status          = AuthStatus.authenticated;
      _safeNotify();
      return true;
    } on AuthException catch (e) {
      _errorMessage    = AppErrors.signIn(e.message);
      _encryptionReady = false;
      _safeNotify(); return false;
    } catch (e) {
      _errorMessage    = AppErrors.fromException(e);
      _encryptionReady = false;
      _safeNotify(); return false;
    } finally { _setLoading(false); }
  }

  // ── Sign up (phase 1 — no session yet) ───────────────────

  Future<bool> signUp({
    required String email,
    required String password,
  }) async {
    _setLoading(true); _clearError();
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
      _safeNotify(); return false;
    } catch (e) {
      _errorMessage = AppErrors.fromException(e);
      await _enc.clearKey();
      _safeNotify(); return false;
    } finally { _setLoading(false); }
  }

  // ── Sign out ──────────────────────────────────────────────

  Future<void> signOut() async {
    await SupabaseConfig.client.auth.signOut();
  }

  // ── Forgot password: send reset email ────────────────────

  Future<bool> sendPasswordResetEmail(String email) async {
    _setLoading(true); _clearError();
    try {
      await SupabaseConfig.client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: _redirectUrl,
      );
      return true;
    } on AuthException catch (e) {
      _errorMessage = AppErrors.resetPassword(e.message);
      _safeNotify(); return false;
    } catch (e) {
      _errorMessage = AppErrors.fromException(e);
      _safeNotify(); return false;
    } finally { _setLoading(false); }
  }

  // ── Forgot password: complete reset (called from SetNewPasswordScreen)
  //
  // At this point the user has a one-time passwordRecovery session.
  // Priority order:
  //  1. Key in memory (same device): re-wrap directly.
  //  2. Recovery key in DB (uid-wrapped, set at every sign-in): unwrap → re-wrap.
  //  3. Neither available (account predates dual-wrapping): generate fresh key.
  //
  // Zero UX prompts. User just enters their new password and is done.

  Future<bool> completePasswordReset(String newPassword) async {
    _setLoading(true); _clearError();
    try {
      final uid = SupabaseConfig.userId;

      // 1. Update Supabase auth password (consumes the one-time session).
      // Guard against the signedOut event that Supabase fires when the
      // passwordRecovery session is invalidated by updateUser().
      _isCompletingPasswordReset = true;
      try {
        await SupabaseConfig.client.auth.updateUser(
          UserAttributes(password: newPassword),
        );
      } finally {
        _isCompletingPasswordReset = false;
      }

      // 2a. Key already in memory (same device).
      if (_enc.hasKey) {
        await _keyService.saveNewWrappedKey(newPassword);
        _encryptionReady = true;
        _status          = AuthStatus.authenticated;
        _safeNotify();
        return true;
      }

      // 2b. Try recovery key from DB (any device, written at every sign-in).
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

      // 2c. Last resort: account predates dual-wrapping — generate new key.
      final newKeyBytes = await _enc.generateDataKey();
      final newWrapped  = await _enc.wrapWithPassword(newKeyBytes, newPassword);
      await _keyService.saveWrappedKeyMapWithRecovery(newWrapped, uid);
      _encryptionReady = _enc.hasKey;
      _status          = AuthStatus.authenticated;
      _safeNotify();
      return true;
    } on AuthException catch (e) {
      _errorMessage = AppErrors.updatePassword(e.message);
      _safeNotify(); return false;
    } catch (e) {
      _errorMessage = AppErrors.fromException(e);
      _safeNotify(); return false;
    } finally { _setLoading(false); }
  }

  // ── Update display name ───────────────────────────────────

  Future<bool> updateDisplayName(String name) async {
    _setLoading(true); _clearError();
    try {
      final response = await SupabaseConfig.client.auth.updateUser(
        UserAttributes(data: {'display_name': name.trim()}),
      );
      _user = response.user;
      _safeNotify();
      return true;
    } on AuthException catch (e) {
      _errorMessage = AppErrors.fromException(e);
      _safeNotify(); return false;
    } catch (e) {
      _errorMessage = AppErrors.fromException(e);
      _safeNotify(); return false;
    } finally { _setLoading(false); }
  }

  // ── Update email ──────────────────────────────────────────

  Future<bool> updateEmail(String newEmail) async {
    _setLoading(true); _clearError();
    try {
      await SupabaseConfig.client.auth.updateUser(
        UserAttributes(email: newEmail.trim()),
        emailRedirectTo: _redirectUrl,
      );
      return true;
    } on AuthException catch (e) {
      _errorMessage = AppErrors.updateEmail(e.message);
      _safeNotify(); return false;
    } catch (e) {
      _errorMessage = AppErrors.fromException(e);
      _safeNotify(); return false;
    } finally { _setLoading(false); }
  }

  // ── Update password (from settings) ──────────────────────

  Future<bool> updatePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    _setLoading(true); _clearError();
    try {
      final ok = await _keyService.rewrapKey(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
      if (!ok) {
        _errorMessage = AppErrors.wrongCurrentPassword;
        _safeNotify(); return false;
      }
      await SupabaseConfig.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return true;
    } on AuthException catch (e) {
      _errorMessage = AppErrors.updatePassword(e.message);
      _safeNotify(); return false;
    } catch (e) {
      _errorMessage = AppErrors.fromException(e);
      _safeNotify(); return false;
    } finally { _setLoading(false); }
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
    _setLoading(true); _clearError();
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
      _status          = AuthStatus.unauthenticated;
      _encryptionReady = false;
      _safeNotify();
      return true;
    } on AuthException catch (e) {
      _errorMessage = 'Could not delete account: ${e.message}';
      _safeNotify(); return false;
    } catch (e) {
      _errorMessage = AppErrors.fromException(e);
      _safeNotify(); return false;
    } finally { _setLoading(false); }
  }

  void _safeNotify() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (hasListeners) notifyListeners();
    });
  }

  void _setLoading(bool v) { _isLoading = v; _safeNotify(); }
  void _clearError()       => _errorMessage = null;
  void clearError()        { _clearError(); _safeNotify(); }
}

// NOTE: This extension is appended — the class above ends with the closing }.
// The deleteAccount method is added directly below inside the class definition
// via the patch in auth_provider_patch.dart — see that file.