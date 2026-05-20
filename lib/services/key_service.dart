import 'dart:convert';
import 'dart:typed_data';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/supabase_client.dart';
import 'package:poppy/services/encryption_service.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Key Service
//  Location: lib/services/key_service.dart
//
//  All DB operations for the user_keys table.
//  EncryptionService owns the crypto; this owns the persistence.
//
//  METHODS
//  ───────
//  hasKeysRow             — check if row exists (first-sign-in detection)
//  saveWrappedKeys        — insert pre-wrapped blobs (first sign-in)
//  saveKeys               — convenience: wrap + insert (not used in
//                           normal flow but kept for testing / admin)
//  loadAndUnwrapWithPassword     — returning user sign-in
//  recoverWithCode               — forgot-password path
//  rewrapForPasswordChange       — settings password change
// ─────────────────────────────────────────────────────────────

class KeyService {
  final _client = SupabaseConfig.client;
  final _enc    = EncryptionService.instance;

  // ── Check row existence ───────────────────────────────────

  /// Returns true if a user_keys row already exists for this user.
  /// Used in signIn() to detect first-sign-in-after-signup.
  Future<bool> hasKeysRow() async {
    try {
      final result = await _client
          .from(DBTable.userKeys)
          .select(DBColumn.userId)
          .eq(DBColumn.userId, SupabaseConfig.userId)
          .maybeSingle();
      return result != null;
    } catch (_) {
      return false;
    }
  }

  // ── First sign-in: save pre-wrapped blobs from secure storage ─

  /// Saves wrapped key blobs that were generated at sign-up and
  /// stored locally. Called on first sign-in when hasKeysRow() == false.
  /// [encDataKeyJson] and [recoveryEncDataKeyJson] are the JSON strings
  /// that were stored in secure storage during sign-up.
  Future<void> saveWrappedKeys({
    required String encDataKeyJson,
    required String recoveryEncDataKeyJson,
  }) async {
    await _client.from(DBTable.userKeys).upsert({
      DBColumn.userId:             SupabaseConfig.userId,
      DBColumn.encDataKey:         jsonDecode(encDataKeyJson),
      DBColumn.recoveryEncDataKey: jsonDecode(recoveryEncDataKeyJson),
    }, onConflict: DBColumn.userId);
  }

  // ── Convenience: wrap + save in one call ──────────────────

  /// Wraps [dataKeyBytes] with both passwords and saves to DB.
  /// Requires a valid session. Used for testing / admin scenarios.
  Future<void> saveKeys({
    required Uint8List dataKeyBytes,
    required String    password,
    required String    recoveryCode,
  }) async {
    final passwordWrapped = await _enc.wrapWithPassword(dataKeyBytes, password);
    final recoveryWrapped = await _enc.wrapWithRecoveryCode(dataKeyBytes, recoveryCode);
    await _client.from(DBTable.userKeys).upsert({
      DBColumn.userId:             SupabaseConfig.userId,
      DBColumn.encDataKey:         passwordWrapped,
      DBColumn.recoveryEncDataKey: recoveryWrapped,
    }, onConflict: DBColumn.userId);
  }

  // ── Returning user sign-in: unwrap with password ──────────

  /// Fetches the password-wrapped key, unwraps it, loads into
  /// EncryptionService. Returns true on success.
  Future<bool> loadAndUnwrapWithPassword(String password) async {
    try {
      final row = await _client
          .from(DBTable.userKeys)
          .select(DBColumn.encDataKey)
          .eq(DBColumn.userId, SupabaseConfig.userId)
          .single();

      final wrapped      = _toMap(row[DBColumn.encDataKey]);
      if (wrapped == null) return false;

      final dataKeyBytes = await _enc.unwrapWithPassword(wrapped, password);
      if (dataKeyBytes == null) return false;

      await _enc.setDataKey(dataKeyBytes);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Forgot password: unwrap with recovery code ────────────

  /// Unwraps the data key using the recovery code, re-wraps it
  /// with newPassword, updates encrypted_data_key in DB.
  /// Returns the raw data key bytes on success, null if wrong code.
  Future<Uint8List?> recoverWithCode({
    required String recoveryCode,
    required String newPassword,
  }) async {
    try {
      final row = await _client
          .from(DBTable.userKeys)
          .select(DBColumn.recoveryEncDataKey)
          .eq(DBColumn.userId, SupabaseConfig.userId)
          .single();

      final wrapped      = _toMap(row[DBColumn.recoveryEncDataKey]);
      if (wrapped == null) return null;

      final normCode     = EncryptionService.normaliseRecoveryCode(recoveryCode);
      final dataKeyBytes = await _enc.unwrapWithRecoveryCode(wrapped, normCode);
      if (dataKeyBytes == null) return null;

      // Re-wrap with new password and persist
      final newWrapped = await _enc.wrapWithPassword(dataKeyBytes, newPassword);
      await _client
          .from(DBTable.userKeys)
          .update({DBColumn.encDataKey: newWrapped})
          .eq(DBColumn.userId, SupabaseConfig.userId);

      return dataKeyBytes;
    } catch (_) {
      return null;
    }
  }

  // ── Password change: re-wrap only ─────────────────────────

  /// Unwraps with oldPassword, re-wraps with newPassword.
  /// One DB row update. No entry re-encryption.
  Future<bool> rewrapForPasswordChange({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final row = await _client
          .from(DBTable.userKeys)
          .select(DBColumn.encDataKey)
          .eq(DBColumn.userId, SupabaseConfig.userId)
          .single();

      final wrapped      = _toMap(row[DBColumn.encDataKey]);
      if (wrapped == null) return false;

      final dataKeyBytes = await _enc.unwrapWithPassword(wrapped, oldPassword);
      if (dataKeyBytes == null) return false;

      final newWrapped = await _enc.wrapWithPassword(dataKeyBytes, newPassword);
      await _client
          .from(DBTable.userKeys)
          .update({DBColumn.encDataKey: newWrapped})
          .eq(DBColumn.userId, SupabaseConfig.userId);

      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Private ───────────────────────────────────────────────

  Map<String, dynamic>? _toMap(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    if (value is String) {
      try { return jsonDecode(value) as Map<String, dynamic>; } catch (_) {}
    }
    return null;
  }
}