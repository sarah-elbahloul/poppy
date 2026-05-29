import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:poppy/core/constants.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Encryption Service
//  Location: lib/services/encryption_service.dart
//
//  KEY ARCHITECTURE
//  ────────────────
//  One random 32-byte DATA KEY per user, generated at sign-up.
//  It encrypts all entries and NEVER changes.
//
//  The data key is wrapped (AES-256-GCM encrypted) with a key
//  derived from the user's password (PBKDF2) and stored in the
//  user_keys table as encrypted_data_key.
//
//  A second copy is wrapped with a key derived from the user's
//  uid + app pepper and stored as recovery_enc_data_key.
//  This lets forgot-password work on any device with no UX prompts.
//
//  Password change:
//    Unwrap data key with old password → re-wrap with new →
//    update one DB row. No entry re-encryption. Ever.
//
//  Forgot password (Supabase reset email):
//    App unwraps recovery copy using uid from the one-time session,
//    re-wraps with new password, saves. Zero extra prompts.
//
//  WHAT IS ENCRYPTED
//  ─────────────────
//  entry title_enc, content_enc — JSONB in Supabase.
//  NOT encrypted: entry_date, word_count, color_tag, timestamps.
// ─────────────────────────────────────────────────────────────

class EncryptionService {
  EncryptionService._();
  static final EncryptionService instance = EncryptionService._();

  static final _algorithm = AesGcm.with256bits();
  final _storage          = const FlutterSecureStorage();
  final _rng              = Random.secure();

  SecretKey? _dataKey;

  // ── Data key lifecycle ────────────────────────────────────

  /// Generates a fresh random 32-byte data key.
  /// Caches it in secure storage and returns the raw bytes
  /// so the caller can wrap and persist them.
  Future<Uint8List> generateDataKey() async {
    final bytes = Uint8List(32);
    for (var i = 0; i < 32; i++) bytes[i] = _rng.nextInt(256);
    _dataKey = SecretKey(bytes);
    await _storage.write(
      key:   StorageKeys.dataKey,
      value: base64Encode(bytes),
    );
    return bytes;
  }

  /// Loads the data key from local secure storage cache.
  /// Returns true if found. Call at app start when already signed in.
  Future<bool> loadCachedKey() async {
    try {
      final stored = await _storage.read(key: StorageKeys.dataKey);
      if (stored == null) return false;
      _dataKey = SecretKey(base64Decode(stored));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Sets the data key from raw bytes and caches it locally.
  /// Called after unwrapping from user_keys on sign-in.
  Future<void> setDataKey(Uint8List keyBytes) async {
    _dataKey = SecretKey(keyBytes);
    await _storage.write(
      key:   StorageKeys.dataKey,
      value: base64Encode(keyBytes),
    );
  }

  /// Clears the in-memory key and local cache. Call on sign-out.
  Future<void> clearKey() async {
    _dataKey = null;
    await _storage.delete(key: StorageKeys.dataKey);
  }

  bool get hasKey => _dataKey != null;

  /// Returns the raw data key bytes, or null if no key is loaded.
  Future<Uint8List?> currentDataKeyBytes() async {
    final key = _dataKey;
    if (key == null) return null;
    return Uint8List.fromList(await key.extractBytes());
  }

  // ── Key wrapping — password ───────────────────────────────

  /// Wraps [dataKeyBytes] with a key derived from [password].
  /// Returns a JSONB-ready map to store in user_keys.
  Future<Map<String, String>> wrapWithPassword(
      Uint8List dataKeyBytes,
      String    password,
      ) async {
    final wrappingKey = await _deriveKeyFromPassword(password);
    return _wrap(dataKeyBytes, wrappingKey);
  }

  /// Unwraps a map produced by [wrapWithPassword].
  /// Returns raw data key bytes, or null if password is wrong.
  Future<Uint8List?> unwrapWithPassword(
      Map<String, dynamic> wrapped,
      String               password,
      ) async {
    final wrappingKey = await _deriveKeyFromPassword(password);
    return _unwrap(wrapped, wrappingKey);
  }

  // ── Key wrapping — uid recovery ───────────────────────────

  /// Wraps [dataKeyBytes] with a key derived from the user's uid.
  /// Stored as recovery_enc_data_key — lets forgot-password work
  /// on any device without asking for the old password.
  Future<Map<String, String>> wrapWithUid(
      Uint8List dataKeyBytes,
      String    uid,
      ) async {
    final wrappingKey = await _deriveKeyFromUid(uid);
    return _wrap(dataKeyBytes, wrappingKey);
  }

  /// Unwraps a recovery-wrapped key produced by [wrapWithUid].
  /// Returns raw data key bytes, or null if uid is wrong.
  Future<Uint8List?> unwrapWithUid(
      Map<String, dynamic> wrapped,
      String               uid,
      ) async {
    final wrappingKey = await _deriveKeyFromUid(uid);
    return _unwrap(wrapped, wrappingKey);
  }

  // ── Encrypt / Decrypt entries ─────────────────────────────

  Future<Map<String, String>?> encrypt(String plaintext) async {
    final key = _dataKey;
    if (key == null) return null;
    final nonce     = _algorithm.newNonce();
    final secretBox = await _algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
      nonce:     nonce,
    );
    return {
      'c': base64Encode(secretBox.cipherText),
      'n': base64Encode(nonce),
      'm': base64Encode(secretBox.mac.bytes),
    };
  }

  Future<String?> encryptToJson(String plaintext) async {
    final map = await encrypt(plaintext);
    return map == null ? null : jsonEncode(map);
  }

  Future<String?> decrypt(Map<String, dynamic> data) async {
    final key = _dataKey;
    if (key == null) return null;
    try {
      final secretBox = SecretBox(
        base64Decode(data['c'] as String),
        nonce: base64Decode(data['n'] as String),
        mac:   Mac(base64Decode(data['m'] as String)),
      );
      final clearBytes = await _algorithm.decrypt(
        secretBox, secretKey: key,
      );
      return utf8.decode(clearBytes);
    } catch (_) {
      return null;
    }
  }

  Future<String> decryptFromJson(String? jsonStr, {String fallback = ''}) async {
    if (jsonStr == null || jsonStr.isEmpty) return fallback;
    try {
      if (!jsonStr.startsWith('{')) return jsonStr;
      final map    = jsonDecode(jsonStr) as Map<String, dynamic>;
      final result = await decrypt(map);
      return result ?? fallback;
    } catch (_) {
      return jsonStr;
    }
  }

  // ── Bulk helpers ──────────────────────────────────────────

  Future<({String titleJson, String contentJson})> encryptEntry({
    required String title,
    required String content,
  }) async {
    final results = await Future.wait([
      encryptToJson(title),
      encryptToJson(content),
    ]);
    return (titleJson: results[0] ?? '', contentJson: results[1] ?? '');
  }

  Future<({String title, String content})> decryptEntry({
    required String? titleJson,
    required String? contentJson,
  }) async {
    final results = await Future.wait([
      decryptFromJson(titleJson,   fallback: ''),
      decryptFromJson(contentJson, fallback: ''),
    ]);
    return (title: results[0], content: results[1]);
  }

  // ── Private ───────────────────────────────────────────────

  Future<Map<String, String>> _wrap(
      Uint8List dataKeyBytes, SecretKey wrappingKey) async {
    final nonce     = _algorithm.newNonce();
    final secretBox = await _algorithm.encrypt(
      dataKeyBytes, secretKey: wrappingKey, nonce: nonce,
    );
    return {
      'c': base64Encode(secretBox.cipherText),
      'n': base64Encode(nonce),
      'm': base64Encode(secretBox.mac.bytes),
    };
  }

  Future<Uint8List?> _unwrap(
      Map<String, dynamic> wrapped, SecretKey wrappingKey) async {
    try {
      final secretBox = SecretBox(
        base64Decode(wrapped['c'] as String),
        nonce: base64Decode(wrapped['n'] as String),
        mac:   Mac(base64Decode(wrapped['m'] as String)),
      );
      final bytes = await _algorithm.decrypt(
        secretBox, secretKey: wrappingKey,
      );
      return Uint8List.fromList(bytes);
    } catch (_) {
      return null;
    }
  }

  Future<SecretKey> _deriveKeyFromPassword(String password) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations:   100000,
      bits:         256,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce:     utf8.encode('poppy-diary-salt-v1'),
    );
  }

  Future<SecretKey> _deriveKeyFromUid(String uid) async {
    // Pepper is app-level — prevents offline attacks on the recovery
    // column from someone who only has the DB dump without the source.
    const pepper = 'poppy-recovery-pepper-v1';
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations:   100000,
      bits:         256,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(uid)),
      nonce:     utf8.encode(pepper),
    );
  }
}