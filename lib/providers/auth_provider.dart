import 'dart:convert';
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
//  KEY ARCHITECTURE (Option D — random data key)
//  ──────────────────────────────────────────────
//
//  SIGN-UP FLOW
//  ────────────
//  Supabase requires email confirmation before a session exists.
//  The user_keys RLS policy requires auth.uid(), so we cannot
//  write to the DB until the user confirms their email and signs
//  in for the first time.
//
//  Solution — two-phase key save:
//    Phase 1 (sign-up, no session):
//      1. Supabase creates the user (pending confirmation)
//      2. Generate data key + recovery code in memory
//      3. Wrap both → store blobs in secure storage as
//         pendingEncKey / pendingRecoveryKey
//      4. Return recovery code to screen for display
//         (user must save it before continuing)
//
//    Phase 2 (first sign-in, confirmed session):
//      1. Normal Supabase signInWithPassword
//      2. Check if user_keys row exists for this user
//      3a. If NOT (first sign-in after sign-up):
//            - Load pending blobs from secure storage
//            - Save them to user_keys table
//            - Clear pending blobs from secure storage
//            - Set data key in EncryptionService
//      3b. If YES (returning user):
//            - Fetch + unwrap data key with password
//
//  SIGN-IN FLOW (returning user)
//  ─────────────────────────────
//    1. Supabase auth
//    2. loadAndUnwrapWithPassword() → data key in memory
//
//  PASSWORD CHANGE (from Account settings)
//  ────────────────────────────────────────
//    1. rewrapForPasswordChange(old, new) — one DB row update
//    2. supabase.auth.updateUser(password: new)
//    No entry re-encryption. Ever.
//
//  FORGOT PASSWORD (from Login screen)
//  ────────────────────────────────────
//    1. sendPasswordResetEmail() → Supabase sends email
//    2. User taps link → app resumes in reset session
//    3. resetWithRecoveryCode(code, newPassword):
//         - recoverWithCode() → unwrap with recovery key,
//           re-wrap with newPassword, update DB
//         - supabase.auth.updateUser(password: newPassword)
//    Entries untouched.
// ─────────────────────────────────────────────────────────────

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final _storage    = const FlutterSecureStorage();
  final _enc        = EncryptionService.instance;
  final _keyService = KeyService();

  AuthStatus _status       = AuthStatus.unknown;
  User?      _user;
  bool       _isLocked     = false;
  bool       _pinEnabled   = false;
  String?    _errorMessage;
  bool       _isLoading    = false;

  AuthStatus get status          => _status;
  User?      get user            => _user;
  bool       get isLocked        => _isLocked;
  bool       get pinEnabled      => _pinEnabled;
  String?    get errorMessage    => _errorMessage;
  bool       get isLoading       => _isLoading;
  bool       get isAuthenticated => _status == AuthStatus.authenticated;

  AuthProvider() { _init(); }

  Future<void> _init() async {
    final session = SupabaseConfig.client.auth.currentSession;
    if (session != null) {
      _user   = session.user;
      _status = AuthStatus.authenticated;
      await _checkPinLock();
      await _enc.loadCachedKey();
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();

    SupabaseConfig.authStateStream.listen((data) async {
      _user = data.session?.user;
      if (data.event == AuthChangeEvent.signedIn) {
        _status = AuthStatus.authenticated;
        await _checkPinLock();
        await _enc.loadCachedKey();
      } else if (data.event == AuthChangeEvent.userUpdated) {
        // Refresh local user object (e.g. after email change confirms)
        _user = data.session?.user;
      } else if (data.event == AuthChangeEvent.signedOut) {
        _status   = AuthStatus.unauthenticated;
        _isLocked = false;
        await _enc.clearKey();
      }
      notifyListeners();
    });
  }

  Future<void> _checkPinLock() async {
    final enabled = await _storage.read(key: StorageKeys.pinEnabled);
    _pinEnabled   = enabled == 'true';
    if (_pinEnabled) _isLocked = true;
  }

  void unlock() { _isLocked = false; notifyListeners(); }

  Future<void> setPinEnabled(bool enabled) async {
    _pinEnabled = enabled;
    await _storage.write(
        key: StorageKeys.pinEnabled, value: enabled.toString());
    if (!enabled) await _storage.delete(key: StorageKeys.pinHash);
    notifyListeners();
  }

  // ── Sign in ───────────────────────────────────────────────

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _setLoading(true); _clearError();
    try {
      await SupabaseConfig.client.auth.signInWithPassword(
        email: email.trim(), password: password,
      );

      // Check whether a user_keys row already exists.
      final hasKeys = await _keyService.hasKeysRow();

      if (!hasKeys) {
        // ── First sign-in after sign-up ───────────────────
        // Load the wrapped blobs we stored in secure storage
        // at sign-up time and save them to the DB now that
        // we have a valid session.
        final pendingEnc      = await _storage.read(key: StorageKeys.pendingEncKey);
        final pendingRecovery = await _storage.read(key: StorageKeys.pendingRecoveryKey);
        final cachedKey       = await _storage.read(key: StorageKeys.dataKey);

        if (pendingEnc != null && pendingRecovery != null) {
          await _keyService.saveWrappedKeys(
            encDataKeyJson:          pendingEnc,
            recoveryEncDataKeyJson:  pendingRecovery,
          );
          // Clear the temp blobs — they are now in the DB
          await _storage.delete(key: StorageKeys.pendingEncKey);
          await _storage.delete(key: StorageKeys.pendingRecoveryKey);
        }

        // Data key is already cached in secure storage from sign-up
        if (cachedKey != null) {
          await _enc.loadCachedKey();
        } else {
          // Fallback: unwrap from DB (handles reinstall edge case)
          await _keyService.loadAndUnwrapWithPassword(password);
        }
      } else {
        // ── Returning user ────────────────────────────────
        // Try loading from local cache first (fast path)
        final loaded = await _enc.loadCachedKey();
        if (!loaded) {
          // Cache miss (reinstall / new device) — fetch from DB
          await _keyService.loadAndUnwrapWithPassword(password);
        }
      }

      return true;
    } on AuthException catch (e) {
      _errorMessage = AppErrors.signIn(e.message);
      notifyListeners(); return false;
    } catch (e) {
      _errorMessage = AppErrors.fromException(e);
      notifyListeners(); return false;
    } finally { _setLoading(false); }
  }

  // ── Sign up ───────────────────────────────────────────────
  //
  // Phase 1 of the two-phase key save (see file header).
  // Returns the recovery code string on success, null on failure.
  // The DB write happens in signIn() after email confirmation.

  Future<String?> signUp({
    required String email,
    required String password,
  }) async {
    _setLoading(true); _clearError();
    try {
      await SupabaseConfig.client.auth.signUp(
        email: email.trim(), password: password,
      );

      // Generate data key + recovery code (in memory only for now)
      final dataKeyBytes = await _enc.generateDataKey();
      final recoveryCode = _enc.generateRecoveryCode();

      // Wrap both — these are safe to store locally because they
      // are ciphertext: the data key bytes are encrypted inside them
      final passwordWrapped  = await _enc.wrapWithPassword(
          dataKeyBytes, password);
      final recoveryWrapped  = await _enc.wrapWithRecoveryCode(
          dataKeyBytes, recoveryCode);

      // Save wrapped blobs to secure storage (not DB — no session yet)
      await _storage.write(
        key:   StorageKeys.pendingEncKey,
        value: jsonEncode(passwordWrapped),
      );
      await _storage.write(
        key:   StorageKeys.pendingRecoveryKey,
        value: jsonEncode(recoveryWrapped),
      );
      // Data key bytes are also cached (generateDataKey does this)

      return recoveryCode;
    } on AuthException catch (e) {
      _errorMessage = AppErrors.signUp(e.message);
      await _enc.clearKey();
      notifyListeners(); return null;
    } catch (e) {
      _errorMessage = AppErrors.fromException(e);
      await _enc.clearKey();
      notifyListeners(); return null;
    } finally { _setLoading(false); }
  }

  // ── Sign out ──────────────────────────────────────────────

  Future<void> signOut() async {
    await SupabaseConfig.client.auth.signOut();
  }

  // ── Send password reset email ─────────────────────────────

  Future<bool> sendPasswordResetEmail(String email) async {
    _setLoading(true); _clearError();
    try {
      await SupabaseConfig.client.auth
          .resetPasswordForEmail(email.trim());
      return true;
    } on AuthException catch (e) {
      _errorMessage = AppErrors.resetPassword(e.message);
      notifyListeners(); return false;
    } catch (e) {
      _errorMessage = AppErrors.fromException(e);
      notifyListeners(); return false;
    } finally { _setLoading(false); }
  }

  // ── Reset password with recovery code ────────────────────

  Future<bool> resetWithRecoveryCode({
    required String recoveryCode,
    required String newPassword,
  }) async {
    _setLoading(true); _clearError();
    try {
      final normCode     = EncryptionService.normaliseRecoveryCode(recoveryCode);
      final dataKeyBytes = await _keyService.recoverWithCode(
        recoveryCode: normCode,
        newPassword:  newPassword,
      );
      if (dataKeyBytes == null) {
        _errorMessage = AppErrors.wrongRecoveryCode;
        notifyListeners(); return false;
      }
      await SupabaseConfig.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      await _enc.setDataKey(dataKeyBytes);
      return true;
    } on AuthException catch (e) {
      _errorMessage = AppErrors.updatePassword(e.message);
      notifyListeners(); return false;
    } catch (e) {
      _errorMessage = AppErrors.fromException(e);
      notifyListeners(); return false;
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
      notifyListeners(); return false;
    } catch (e) {
      _errorMessage = AppErrors.fromException(e);
      notifyListeners(); return false;
    } finally { _setLoading(false); }
  }

  // ── Update password ───────────────────────────────────────
  //
  // Re-wraps the data key only. No entry re-encryption.
  // Requires the old password to unwrap the current data key.

  Future<bool> updatePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    _setLoading(true); _clearError();
    try {
      final ok = await _keyService.rewrapForPasswordChange(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
      if (!ok) {
        _errorMessage = AppErrors.wrongCurrentPassword;
        notifyListeners(); return false;
      }
      await SupabaseConfig.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return true;
    } on AuthException catch (e) {
      _errorMessage = AppErrors.updatePassword(e.message);
      notifyListeners(); return false;
    } catch (e) {
      _errorMessage = AppErrors.fromException(e);
      notifyListeners(); return false;
    } finally { _setLoading(false); }
  }

  void _setLoading(bool v) { _isLoading = v; notifyListeners(); }
  void _clearError()       => _errorMessage = null;
  void clearError()        { _clearError(); notifyListeners(); }
}