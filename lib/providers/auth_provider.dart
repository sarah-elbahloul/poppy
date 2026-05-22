import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/error_messages.dart';
import 'package:poppy/core/supabase_client.dart';
import 'package:poppy/services/encryption_service.dart';
import 'package:poppy/services/key_service.dart';
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
//  SIGN-UP (two-phase key save)
//  ────────────────────────────
//  Phase 1 (sign-up, no confirmed session):
//    Generate data key → wrap with password → store blob in
//    secure storage (pendingEncKey). Return to screen.
//  Phase 2 (first sign-in):
//    Flush pendingEncKey blob to user_keys table. Clear storage.
//
//  PASSWORD CHANGE (settings)
//  ──────────────────────────
//  KeyService.rewrapKey(old, new) — unwrap with old, re-wrap
//  with new, update DB via update_data_key() RPC. One call.
//
//  FORGOT PASSWORD (email reset)
//  ─────────────────────────────
//  1. sendPasswordResetEmail(email) — Supabase sends link
//  2. User taps link → app gets AuthChangeEvent.passwordRecovery
//  3. status flips to passwordRecovery → app shows SetNewPasswordScreen
//  4. User enters new password → completePasswordReset(newPassword):
//       a. updateUser(password: newPassword)  — updates Supabase auth
//       b. KeyService.saveNewWrappedKey(newPassword) — re-wraps data key
//       c. status flips to authenticated → home screen
// ─────────────────────────────────────────────────────────────

enum AuthStatus { unknown, authenticated, unauthenticated, passwordRecovery }

class AuthProvider extends ChangeNotifier {
  final _storage    = const FlutterSecureStorage();
  final _enc        = EncryptionService.instance;
  final _keyService = KeyService();

  AuthStatus _status          = AuthStatus.unknown;
  User?      _user;
  bool       _isLocked        = false;
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

  AuthProvider() { _init(); }

  Future<void> _init() async {
    final session = SupabaseConfig.client.auth.currentSession;
    if (session != null) {
      _user   = session.user;
      _status = AuthStatus.authenticated;
      await _checkPinLock();
      final loaded = await _enc.loadCachedKey();
      _encryptionReady = loaded;
    } else {
      _status = AuthStatus.unauthenticated;
    }
    _safeNotify();

    SupabaseConfig.authStateStream.listen((data) async {
      _user = data.session?.user;
      switch (data.event) {
        case AuthChangeEvent.signedIn:
        // Handled explicitly in signIn() — don't duplicate key load here
          _status = AuthStatus.authenticated;
          await _checkPinLock();
          break;
        case AuthChangeEvent.passwordRecovery:
        // One-time session from reset email link.
        // Data key is still in secure storage cache from before
        // the user forgot their password (same device) OR we
        // can't decrypt without the old password.
        // Either way, navigate to SetNewPasswordScreen.
          _status = AuthStatus.passwordRecovery;
          await _enc.loadCachedKey(); // may or may not succeed
          break;
        case AuthChangeEvent.userUpdated:
          _user = data.session?.user;
          break;
        case AuthChangeEvent.signedOut:
          _status          = AuthStatus.unauthenticated;
          _isLocked        = false;
          _encryptionReady = false;
          await _enc.clearKey();
          break;
        default:
          break;
      }
      _safeNotify();
    });
  }

  Future<void> _checkPinLock() async {
    final enabled = await _storage.read(key: StorageKeys.pinEnabled);
    _pinEnabled   = enabled == 'true';
    if (_pinEnabled) _isLocked = true;
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

      _encryptionReady = true;
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
        email:      email.trim(),
        password:   password,
        emailRedirectTo: kIsWeb ? 'http://localhost:49296' : 'io.supabase.poppy://login-callback/',
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
        redirectTo: kIsWeb ? 'http://localhost:49296' : 'io.supabase.poppy://login-callback/',
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
  // We update the Supabase auth password, then re-wrap the data key.
  // If the data key isn't in memory (different device / reinstall),
  // entries will be unreadable after the reset — this is the
  // fundamental limitation of E2E encryption with no escrow.

  Future<bool> completePasswordReset(String newPassword) async {
    _setLoading(true); _clearError();
    try {
      // Update Supabase auth password
      await SupabaseConfig.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      // Re-wrap the data key with the new password (if key is in memory)
      if (_enc.hasKey) {
        final ok = await _keyService.saveNewWrappedKey(newPassword);
        if (!ok) {
          // Key save failed but password updated — non-fatal, user can
          // sign in but entries may not decrypt until key is recovered.
          // Log this in production.
        }
      }

      _status          = AuthStatus.authenticated;
      _encryptionReady = _enc.hasKey;
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

  // ── Update email ──────────────────────────────────────────

  Future<bool> updateEmail(String newEmail) async {
    _setLoading(true); _clearError();
    try {
      await SupabaseConfig.client.auth.updateUser(
        UserAttributes(email: newEmail.trim()),
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

  void _safeNotify() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (hasListeners) notifyListeners();
    });
  }

  void _setLoading(bool v) { _isLoading = v; _safeNotify(); }
  void _clearError()       => _errorMessage = null;
  void clearError()        { _clearError(); _safeNotify(); }
}