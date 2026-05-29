import 'dart:convert';
import 'dart:typed_data';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/supabase_client.dart';
import 'package:poppy/services/encryption_service.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Key Service
//  Location: lib/services/key_service.dart
//
//  DUAL-WRAPPING ARCHITECTURE
//  ──────────────────────────
//  The data key is stored in user_keys as TWO wrapped copies:
//
//    encrypted_data_key       — wrapped with user's password (PBKDF2)
//    recovery_enc_data_key    — wrapped with user's uid (PBKDF2 + pepper)
//
//  The recovery copy is written every time the data key is
//  successfully loaded (sign-in on any device, sign-up).
//  It lets forgot-password work on any device with zero UX friction:
//    1. User gets passwordRecovery session from email link
//    2. App unwraps recovery copy using uid from the session
//    3. Re-wraps with the new password, saves, done
//    No old password prompt. Ever.
//
//  Security note: the recovery wrapping is weaker than the
//  password wrapping (uid is not secret to the server). This is
//  the same trade-off every "forgot password" feature makes —
//  the alternative is permanent data loss. The pepper prevents
//  offline attacks from a DB-only dump.
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

  // ── Sign-up: flush pending wrapped key to DB ──────────────

  Future<void> saveWrappedKey({required String encDataKeyJson}) async {
    final uid     = SupabaseConfig.userId;
    final keyBytes = await _enc.currentDataKeyBytes();

    Map<String, String>? recoveryWrapped;
    if (keyBytes != null) {
      recoveryWrapped = await _enc.wrapWithUid(keyBytes, uid);
    }

    await _client.from(DBTable.userKeys).upsert({
      DBColumn.userId:             uid,
      DBColumn.encDataKey:         jsonDecode(encDataKeyJson),
      if (recoveryWrapped != null)
        DBColumn.recoveryEncDataKey: recoveryWrapped,
    }, onConflict: DBColumn.userId);
  }

  Future<void> saveWrappedKeyMap(Map<String, String> wrapped) async {
    final uid      = SupabaseConfig.userId;
    final keyBytes = await _enc.currentDataKeyBytes();

    Map<String, String>? recoveryWrapped;
    if (keyBytes != null) {
      recoveryWrapped = await _enc.wrapWithUid(keyBytes, uid);
    }

    await _client.from(DBTable.userKeys).upsert({
      DBColumn.userId:     uid,
      DBColumn.encDataKey: wrapped,
      if (recoveryWrapped != null)
        DBColumn.recoveryEncDataKey: recoveryWrapped,
    }, onConflict: DBColumn.userId);
  }

  // ── Sign-in: unwrap with password, refresh recovery copy ──

  /// Unwraps the password-wrapped key, loads it into memory, and
  /// refreshes the recovery copy in DB so it's always up to date.
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
      await _refreshRecoveryKey(dataKeyBytes); // best-effort
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Password change (settings) ────────────────────────────

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

      final wrapped      = _toMap(row[DBColumn.encDataKey]);
      if (wrapped == null) return false;

      final dataKeyBytes = await _enc.unwrapWithPassword(wrapped, oldPassword);
      if (dataKeyBytes == null) return false;

      final newWrapped      = await _enc.wrapWithPassword(dataKeyBytes, newPassword);
      final recoveryWrapped = await _enc.wrapWithUid(
          dataKeyBytes, SupabaseConfig.userId);

      await _client.rpc('update_data_key', params: {
        'new_wrapped_key':          newWrapped,
        'new_recovery_wrapped_key': recoveryWrapped,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Forgot password: same device (key in secure storage) ──

  /// Key is in memory — just re-wrap with the new password.
  Future<bool> saveNewWrappedKey(String newPassword) async {
    try {
      if (!_enc.hasKey) return false;
      final dataKeyBytes = await _enc.currentDataKeyBytes();
      if (dataKeyBytes == null) return false;

      final newWrapped      = await _enc.wrapWithPassword(dataKeyBytes, newPassword);
      final recoveryWrapped = await _enc.wrapWithUid(
          dataKeyBytes, SupabaseConfig.userId);

      await _client.rpc('update_data_key', params: {
        'new_wrapped_key':          newWrapped,
        'new_recovery_wrapped_key': recoveryWrapped,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Forgot password: any device (recovery key path) ───────

  /// Uses the uid-wrapped recovery copy to recover the data key
  /// without needing the old password. Works on any device as long
  /// as the recovery copy has been written (happens at every sign-in).
  ///
  /// Returns true on success. False means the recovery column is
  /// missing (account predates dual-wrapping) — caller should fall
  /// back to [rewrapWithOldPassword] or [completePasswordResetFresh].
  Future<bool> rewrapWithRecoveryKey({
    required String uid,
    required String newPassword,
  }) async {
    try {
      final row = await _client
          .from(DBTable.userKeys)
          .select('${DBColumn.encDataKey},${DBColumn.recoveryEncDataKey}')
          .eq(DBColumn.userId, uid)
          .single();

      final recoveryWrapped = _toMap(row[DBColumn.recoveryEncDataKey]);
      if (recoveryWrapped == null) return false; // no recovery copy yet

      final dataKeyBytes = await _enc.unwrapWithUid(recoveryWrapped, uid);
      if (dataKeyBytes == null) return false;

      // Re-wrap with new password and refresh recovery copy.
      final newWrapped         = await _enc.wrapWithPassword(dataKeyBytes, newPassword);
      final newRecoveryWrapped = await _enc.wrapWithUid(dataKeyBytes, uid);

      await _client.rpc('update_data_key', params: {
        'new_wrapped_key':          newWrapped,
        'new_recovery_wrapped_key': newRecoveryWrapped,
      });

      await _enc.setDataKey(dataKeyBytes);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Fresh key (last resort, data loss accepted) ───────────

  Future<void> saveWrappedKeyMapWithRecovery(
      Map<String, String> wrapped, String uid) async {
    final keyBytes        = await _enc.currentDataKeyBytes();
    final recoveryWrapped = keyBytes != null
        ? await _enc.wrapWithUid(keyBytes, uid)
        : null;

    await _client.from(DBTable.userKeys).upsert({
      DBColumn.userId:     uid,
      DBColumn.encDataKey: wrapped,
      if (recoveryWrapped != null)
        DBColumn.recoveryEncDataKey: recoveryWrapped,
    }, onConflict: DBColumn.userId);
  }

  // ── Private ───────────────────────────────────────────────

  /// Refreshes the recovery copy in DB after loading the data key.
  /// Best-effort: failure is silent (next sign-in will retry).
  Future<void> _refreshRecoveryKey(Uint8List dataKeyBytes) async {
    try {
      final uid             = SupabaseConfig.userId;
      final recoveryWrapped = await _enc.wrapWithUid(dataKeyBytes, uid);
      await _client
          .from(DBTable.userKeys)
          .update({DBColumn.recoveryEncDataKey: recoveryWrapped})
          .eq(DBColumn.userId, uid);
    } catch (_) {
      // Silent — not critical for sign-in to succeed.
    }
  }

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