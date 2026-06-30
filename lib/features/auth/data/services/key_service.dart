import 'dart:convert';
import 'dart:typed_data';
import 'package:poppy/core/core.dart';
import 'package:poppy/features/auth/data/services/encryption_service.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Key Management Service
//  Location: lib/features/auth/data/services/key_service.dart
// ─────────────────────────────────────────────────────────────

class KeyService {
  final _client = SupabaseConfig.client;
  final _enc = EncryptionService.instance;

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
