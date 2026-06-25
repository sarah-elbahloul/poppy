import 'dart:convert';
import 'dart:typed_data';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/supabase_client.dart';
import 'package:poppy/services/encryption_service.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Key Management Service
//  Location: lib/services/key_service.dart
// ─────────────────────────────────────────────────────────────

/// Manages the persistence and retrieval of wrapped encryption keys in the remote database.
///
/// **Dual-Wrap Strategy:**
/// 1. **Password Wrap**: Data Key encrypted with the user's password.
/// 2. **Recovery Wrap**: Data Key encrypted with the user's UID (plus a salt/pepper).
class KeyService {
  final _client = SupabaseConfig.client;
  final _enc = EncryptionService.instance;

  /// Checks if the current user has an existing key record in the database.
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

  // ─────────────────────────────────────────────────────────────
  //  Key Persistence
  // ─────────────────────────────────────────────────────────────

  /// Saves the Data Key to the cloud in both password-wrapped and recovery-wrapped forms.
  ///
  /// [encDataKeyJson] is the JSON string of the password-wrapped key.
  Future<void> saveWrappedKey({required String encDataKeyJson}) async {
    final uid = SupabaseConfig.userId;
    final keyBytes = await _enc.currentDataKeyBytes();

    Map<String, String>? recoveryWrapped;
    if (keyBytes != null) {
      recoveryWrapped = await _enc.wrapWithUid(keyBytes, uid);
    }

    await _client.from(DBTable.userKeys).upsert({
      DBColumn.userId: uid,
      DBColumn.encDataKey: jsonDecode(encDataKeyJson),
      if (recoveryWrapped != null)
        DBColumn.recoveryEncDataKey: recoveryWrapped,
    }, onConflict: DBColumn.userId);
  }

  /// Saves a pre-wrapped key map and refreshes the recovery wrap.
  Future<void> saveWrappedKeyMap(Map<String, String> wrapped) async {
    final uid = SupabaseConfig.userId;
    final keyBytes = await _enc.currentDataKeyBytes();

    Map<String, String>? recoveryWrapped;
    if (keyBytes != null) {
      recoveryWrapped = await _enc.wrapWithUid(keyBytes, uid);
    }

    await _client.from(DBTable.userKeys).upsert({
      DBColumn.userId: uid,
      DBColumn.encDataKey: wrapped,
      if (recoveryWrapped != null)
        DBColumn.recoveryEncDataKey: recoveryWrapped,
    }, onConflict: DBColumn.userId);
  }

  /// Saves a wrapped key map along with a recovery copy for the specified [uid].
  Future<void> saveWrappedKeyMapWithRecovery(
    Map<String, String> wrapped,
    String uid,
  ) async {
    final keyBytes = await _enc.currentDataKeyBytes();
    final recoveryWrapped = keyBytes != null ? await _enc.wrapWithUid(keyBytes, uid) : null;

    await _client.from(DBTable.userKeys).upsert({
      DBColumn.userId: uid,
      DBColumn.encDataKey: wrapped,
      if (recoveryWrapped != null)
        DBColumn.recoveryEncDataKey: recoveryWrapped,
    }, onConflict: DBColumn.userId);
  }

  // ─────────────────────────────────────────────────────────────
  //  Decryption Flow
  // ─────────────────────────────────────────────────────────────

  /// Retrieves the wrapped key and attempts to unwrap it using the user's password.
  Future<bool> loadAndUnwrapWithPassword(String password) async {
    try {
      final row = await _client
          .from(DBTable.userKeys)
          .select(DBColumn.encDataKey)
          .eq(DBColumn.userId, SupabaseConfig.userId)
          .single();

      final wrapped = _toMap(row[DBColumn.encDataKey]);
      if (wrapped == null) return false;

      final dataKeyBytes = await _enc.unwrapWithPassword(wrapped, password);
      if (dataKeyBytes == null) return false;

      await _enc.setDataKey(dataKeyBytes);
      await _refreshRecoveryKey(dataKeyBytes);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  Rotation & Recovery
  // ─────────────────────────────────────────────────────────────

  /// Re-wraps the Data Key with a [newPassword] during a standard security update.
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
      final recoveryWrapped = await _enc.wrapWithUid(dataKeyBytes, SupabaseConfig.userId);

      await _client.rpc('update_data_key', params: {
        'new_wrapped_key': newWrapped,
        'new_recovery_wrapped_key': recoveryWrapped,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Re-wraps the existing Data Key in memory with a [newPassword].
  Future<bool> saveNewWrappedKey(String newPassword) async {
    try {
      if (!_enc.hasKey) return false;
      final dataKeyBytes = await _enc.currentDataKeyBytes();
      if (dataKeyBytes == null) return false;

      final newWrapped = await _enc.wrapWithPassword(dataKeyBytes, newPassword);
      final recoveryWrapped = await _enc.wrapWithUid(dataKeyBytes, SupabaseConfig.userId);

      await _client.rpc('update_data_key', params: {
        'new_wrapped_key': newWrapped,
        'new_recovery_wrapped_key': recoveryWrapped,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Recovers the Data Key using the UID-wrapped recovery copy and re-wraps it.
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
      if (recoveryWrapped == null) return false;

      final dataKeyBytes = await _enc.unwrapWithUid(recoveryWrapped, uid);
      if (dataKeyBytes == null) return false;

      final newWrapped = await _enc.wrapWithPassword(dataKeyBytes, newPassword);
      final newRecoveryWrapped = await _enc.wrapWithUid(dataKeyBytes, uid);

      await _client.rpc('update_data_key', params: {
        'new_wrapped_key': newWrapped,
        'new_recovery_wrapped_key': newRecoveryWrapped,
      });

      await _enc.setDataKey(dataKeyBytes);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  Internal Helpers
  // ─────────────────────────────────────────────────────────────

  /// Refreshes the recovery key stored in the database.
  Future<void> _refreshRecoveryKey(Uint8List dataKeyBytes) async {
    try {
      final uid = SupabaseConfig.userId;
      final recoveryWrapped = await _enc.wrapWithUid(dataKeyBytes, uid);
      await _client
          .from(DBTable.userKeys)
          .update({DBColumn.recoveryEncDataKey: recoveryWrapped})
          .eq(DBColumn.userId, uid);
    } catch (_) {}
  }

  /// Normalizes dynamic database values into a [Map<String, dynamic>].
  Map<String, dynamic>? _toMap(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    if (value is String) {
      try {
        return jsonDecode(value) as Map<String, dynamic>;
      } catch (_) {}
    }
    return null;
  }
}
