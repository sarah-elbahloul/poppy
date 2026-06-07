import 'dart:convert';
import 'dart:typed_data';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/supabase_client.dart';
import 'package:poppy/services/encryption_service.dart';

/// Poppy — Key Service
///
/// **Dual-Wrapping Architecture:**
/// The user's unique data encryption key is stored in the `user_keys` table 
/// in two wrapped (encrypted) copies:
/// 1. `encrypted_data_key`: Wrapped using a key derived from the user's password.
/// 2. `recovery_enc_data_key`: Wrapped using a key derived from the user's UID 
///    and an app-level pepper.
///
/// This dual-wrap approach allows for seamless password recovery. If a user 
/// resets their password via email, the app can unwrap the data key using 
/// their UID (provided by the recovery session) and then re-wrap it with 
/// the new password.
class KeyService {
  final _client = SupabaseConfig.client;
  final _enc    = EncryptionService.instance;

  // --- Initialization & Detection ---

  /// Checks if a row already exists for the current user in the `user_keys` table.
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

  // --- Save Wrapped Keys ---

  /// Saves the password-wrapped key and automatically generates/saves a 
  /// recovery copy.
  Future<void> saveWrappedKey({required String encDataKeyJson}) async {
    final uid      = SupabaseConfig.userId;
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

  /// Saves a wrapped key map and refreshes the recovery copy.
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

  // --- Load & Unwrap ---

  /// Fetches the password-wrapped key from the database, unwraps it, loads 
  /// it into memory, and refreshes the recovery copy.
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

  // --- Key Rotation (Password Change) ---

  /// Re-wraps the data key with a new password. Used when changing 
  /// password from the settings.
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

  // --- Password Recovery ---

  /// Re-wraps the data key after a successful password reset.
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

  /// Uses the UID-wrapped recovery key to recover the data key and 
  /// re-wrap it with a new password.
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

  // --- Fallback & Utilities ---

  /// Saves a wrapped key map along with a recovery copy. 
  /// Used as a last resort during recovery if the recovery key didn't exist.
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

  /// Refreshes the recovery key stored in the database.
  Future<void> _refreshRecoveryKey(Uint8List dataKeyBytes) async {
    try {
      final uid             = SupabaseConfig.userId;
      final recoveryWrapped = await _enc.wrapWithUid(dataKeyBytes, uid);
      await _client
          .from(DBTable.userKeys)
          .update({DBColumn.recoveryEncDataKey: recoveryWrapped})
          .eq(DBColumn.userId, uid);
    } catch (_) {
      // Best-effort update.
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
