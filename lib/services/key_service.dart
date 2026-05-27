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
//
//  SIGN-UP NOTE
//  ────────────
//  Supabase email confirmation means there's no session
//  immediately after signUp().  So we store the wrapped key
//  blob in secure storage (pendingEncKey) at sign-up time
//  and flush it to the DB on first sign-in when a session exists.
//  hasKeysRow() detects first sign-in vs returning user.
//
//  PASSWORD CHANGE (settings) + FORGOT PASSWORD (reset email)
//  ──────────────────────────────────────────────────────────
//  Settings:            rewrapKey(old, new) — unwrap old → wrap new
//  Reset (same device): saveNewWrappedKey(new) — re-wrap in-memory key
//  Reset (diff device): rewrapWithOldPassword(old, new) — unwrap from
//                       DB using old password → wrap with new. No data
//                       loss. Falls back to new key only if old password
//                       is wrong (user genuinely cannot remember it).
// ─────────────────────────────────────────────────────────────

class KeyService {
  final _client = SupabaseConfig.client;
  final _enc    = EncryptionService.instance;

  // ── First sign-in detection ───────────────────────────────

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

  // ── First sign-in: flush pending wrapped key to DB ────────

  /// Saves a pre-wrapped key blob that was stored in secure storage
  /// at sign-up time, now that a confirmed session exists.
  Future<void> saveWrappedKey({required String encDataKeyJson}) async {
    await _client.from(DBTable.userKeys).upsert({
      DBColumn.userId:     SupabaseConfig.userId,
      DBColumn.encDataKey: jsonDecode(encDataKeyJson),
    }, onConflict: DBColumn.userId);
  }

  /// Saves a pre-wrapped key map directly (used after password reset
  /// on a fresh device where a new data key was generated).
  Future<void> saveWrappedKeyMap(Map<String, String> wrapped) async {
    await _client.from(DBTable.userKeys).upsert({
      DBColumn.userId:     SupabaseConfig.userId,
      DBColumn.encDataKey: wrapped,
    }, onConflict: DBColumn.userId);
  }

  // ── Returning user: unwrap with password ──────────────────

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

  // ── Password change (settings): unwrap old, wrap new ──────

  /// Requires the old password to unwrap the current data key.
  /// Returns false if oldPassword is wrong.
  Future<bool> rewrapKey({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final row = await _client
          .from(DBTable.userKeys)
          .select(DBColumn.encDataKey)
          .eq(DBColumn.userId, SupabaseConfig.userId)
          .single();

      final wrapped = _toMap(row[DBColumn.encDataKey]);
      if (wrapped == null) return false;

      final dataKeyBytes = await _enc.unwrapWithPassword(wrapped, oldPassword);
      if (dataKeyBytes == null) return false;

      final newWrapped = await _enc.wrapWithPassword(dataKeyBytes, newPassword);
      await _client.rpc('update_data_key',
          params: {'new_wrapped_key': newWrapped});
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Forgot password (same device): save new wrapping ──────

  /// Called when the user has a one-time reset session AND the data
  /// key is already in memory (loaded from secure storage cache —
  /// same device that originally registered).
  /// Returns false if the key is not in memory (different device).
  Future<bool> saveNewWrappedKey(String newPassword) async {
    try {
      if (!_enc.hasKey) return false;

      final dataKeyBytes = await _enc.currentDataKeyBytes();
      if (dataKeyBytes == null) return false;

      final newWrapped = await _enc.wrapWithPassword(dataKeyBytes, newPassword);
      await _client.rpc('update_data_key',
          params: {'new_wrapped_key': newWrapped});
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Forgot password (different device): unwrap from DB ────

  /// Fetches the wrapped key from the DB and tries to unwrap it using
  /// [oldPassword]. If successful, re-wraps with [newPassword], saves
  /// it, and loads the data key into memory.
  ///
  /// Returns [RewrapResult.success] on success.
  /// Returns [RewrapResult.wrongPassword] if [oldPassword] is wrong —
  /// the caller should tell the user and let them try again or choose
  /// to generate a new key (losing old entries).
  /// Returns [RewrapResult.error] on network / DB failures.
  Future<RewrapResult> rewrapWithOldPassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final row = await _client
          .from(DBTable.userKeys)
          .select(DBColumn.encDataKey)
          .eq(DBColumn.userId, SupabaseConfig.userId)
          .single();

      final wrapped = _toMap(row[DBColumn.encDataKey]);
      if (wrapped == null) return RewrapResult.error;

      final dataKeyBytes = await _enc.unwrapWithPassword(wrapped, oldPassword);
      if (dataKeyBytes == null) return RewrapResult.wrongPassword;

      // Old password was correct — re-wrap with new password and save.
      final newWrapped = await _enc.wrapWithPassword(dataKeyBytes, newPassword);
      await _client.rpc('update_data_key',
          params: {'new_wrapped_key': newWrapped});

      // Load the data key into memory so entries are immediately readable.
      await _enc.setDataKey(dataKeyBytes);
      return RewrapResult.success;
    } catch (_) {
      return RewrapResult.error;
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

/// Result of [KeyService.rewrapWithOldPassword].
enum RewrapResult { success, wrongPassword, error }