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
//  KEY ARCHITECTURE (Option D)
//  ───────────────────────────
//  ONE random DATA KEY per user, generated at sign-up.
//  It encrypts all entries and NEVER changes.
//
//  The data key is wrapped (AES-256-GCM encrypted) in two ways
//  and stored in the user_keys table:
//
//    encrypted_data_key          ← wrapped with PBKDF2(password)
//    recovery_encrypted_data_key ← wrapped with PBKDF2(recovery_code)
//
//  On password change: unwrap data key → re-wrap with new password.
//  ONE tiny DB update. No entry re-encryption. Ever.
//
//  On password reset: user provides recovery code → unwrap data key
//  → re-wrap with new password → update encrypted_data_key in DB.
//  Entries untouched.
//
//  ALGORITHM
//  ─────────
//  Data key : 32 random bytes (cryptographically secure)
//  Wrapping : AES-256-GCM
//  KDF      : PBKDF2-HMAC-SHA256, 100k iterations
//  Salts    : different constants for password vs recovery paths
//             so the same passphrase produces different keys
//
//  STORAGE
//  ───────
//  Data key bytes cached in flutter_secure_storage so we don't
//  hit the DB on every cold start.
//
//  WHAT IS ENCRYPTED
//  ─────────────────
//  entry title_enc   — JSONB in Supabase
//  entry content_enc — JSONB in Supabase
//
//  NOT encrypted (needed for sort/filter):
//  entry_date, word_count, color_tag, created_at, updated_at
// ─────────────────────────────────────────────────────────────

class EncryptionService {
  EncryptionService._();
  static final EncryptionService instance = EncryptionService._();

  static final _algorithm = AesGcm.with256bits();
  final _storage          = const FlutterSecureStorage();
  final _rng              = Random.secure();

  SecretKey? _dataKey;

  // ── Data key management ───────────────────────────────────

  /// Generates a fresh random 32-byte data key.
  /// Call this ONCE at sign-up, then immediately wrap and save it.
  /// Returns the raw bytes so KeyService can wrap and persist them.
  Future<Uint8List> generateDataKey() async {
    final bytes = Uint8List(32);
    for (var i = 0; i < 32; i++) bytes[i] = _rng.nextInt(256);
    _dataKey = SecretKey(bytes);
    // Cache in secure storage for cold-start reuse
    await _storage.write(
      key:   StorageKeys.dataKey,
      value: base64Encode(bytes),
    );
    return bytes;
  }

  /// Loads the data key from the local secure storage cache.
  /// Returns true if a key was found.  Call at app start when
  /// the user is already authenticated.
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

  /// Sets the data key directly from raw bytes (e.g. after
  /// unwrapping from user_keys on sign-in) and caches it.
  Future<void> setDataKey(Uint8List keyBytes) async {
    _dataKey = SecretKey(keyBytes);
    await _storage.write(
      key:   StorageKeys.dataKey,
      value: base64Encode(keyBytes),
    );
  }

  /// Clears the in-memory key and the secure storage cache.
  /// Call on sign-out.
  Future<void> clearKey() async {
    _dataKey = null;
    await _storage.delete(key: StorageKeys.dataKey);
  }

  /// True when a data key is loaded and crypto ops can proceed.
  bool get hasKey => _dataKey != null;

  // ── Key wrapping ──────────────────────────────────────────
  //
  // "Wrapping" = encrypting the raw data key bytes with a key
  // derived from a passphrase (password or recovery code).
  // The wrapped result is a JSONB-ready map.

  /// Wraps [dataKeyBytes] using a key derived from [password].
  /// Returns a JSONB-encodable map.
  Future<Map<String, String>> wrapWithPassword(
      Uint8List dataKeyBytes,
      String    password,
      ) async {
    final wrappingKey = await _derivePasswordKey(password);
    return _wrap(dataKeyBytes, wrappingKey);
  }

  /// Wraps [dataKeyBytes] using a key derived from [recoveryCode].
  Future<Map<String, String>> wrapWithRecoveryCode(
      Uint8List dataKeyBytes,
      String    recoveryCode,
      ) async {
    final wrappingKey = await _deriveRecoveryKey(recoveryCode);
    return _wrap(dataKeyBytes, wrappingKey);
  }

  /// Unwraps a map previously produced by [wrapWithPassword].
  /// Returns the raw data key bytes, or null if the password is wrong.
  Future<Uint8List?> unwrapWithPassword(
      Map<String, dynamic> wrappedKey,
      String               password,
      ) async {
    final wrappingKey = await _derivePasswordKey(password);
    return _unwrap(wrappedKey, wrappingKey);
  }

  /// Unwraps a map previously produced by [wrapWithRecoveryCode].
  /// Returns the raw data key bytes, or null if the code is wrong.
  Future<Uint8List?> unwrapWithRecoveryCode(
      Map<String, dynamic> wrappedKey,
      String               recoveryCode,
      ) async {
    final wrappingKey = await _deriveRecoveryKey(recoveryCode);
    return _unwrap(wrappedKey, wrappingKey);
  }

  // ── Recovery code generation ──────────────────────────────

  /// Generates a human-readable recovery code.
  /// Format: POPPY-XXXX-XXXX-XXXX-XXXX  (hex, uppercase)
  String generateRecoveryCode() {
    final sb = StringBuffer(RecoveryConfig.prefix);
    for (var g = 0; g < RecoveryConfig.groupCount; g++) {
      sb.write('-');
      for (var c = 0; c < RecoveryConfig.groupLength; c++) {
        sb.write(_rng.nextInt(16).toRadixString(16).toUpperCase());
      }
    }
    return sb.toString();
  }

  /// Normalises a user-typed recovery code:
  /// strips spaces, uppercases, ensures POPPY- prefix.
  static String normaliseRecoveryCode(String raw) {
    var s = raw.trim().toUpperCase().replaceAll(' ', '');
    if (!s.startsWith('${RecoveryConfig.prefix}-')) {
      s = '${RecoveryConfig.prefix}-$s';
    }
    return s;
  }

  // ── Encrypt / Decrypt (entries) ───────────────────────────

  /// Encrypts [plaintext] with the loaded data key.
  /// Returns a JSONB-ready map.
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
      if (!jsonStr.startsWith('{')) return jsonStr; // legacy plain text
      final map    = jsonDecode(jsonStr) as Map<String, dynamic>;
      final result = await decrypt(map);
      return result ?? fallback;
    } catch (_) {
      return jsonStr;
    }
  }

  // ── Bulk entry helpers ────────────────────────────────────

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

  // ── Private: low-level wrap/unwrap ────────────────────────

  Future<Map<String, String>> _wrap(
      Uint8List  dataKeyBytes,
      SecretKey  wrappingKey,
      ) async {
    final nonce     = _algorithm.newNonce();
    final secretBox = await _algorithm.encrypt(
      dataKeyBytes,
      secretKey: wrappingKey,
      nonce:     nonce,
    );
    return {
      'c': base64Encode(secretBox.cipherText),
      'n': base64Encode(nonce),
      'm': base64Encode(secretBox.mac.bytes),
    };
  }

  Future<Uint8List?> _unwrap(
      Map<String, dynamic> wrapped,
      SecretKey            wrappingKey,
      ) async {
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
      return null; // wrong key / corrupted
    }
  }

  // ── Private: KDF ─────────────────────────────────────────

  Future<SecretKey> _derivePasswordKey(String password) =>
      _pbkdf2(password, 'poppy-diary-salt-v1');

  Future<SecretKey> _deriveRecoveryKey(String recoveryCode) =>
      _pbkdf2(recoveryCode, RecoveryConfig.pbkdf2Salt);

  Future<SecretKey> _pbkdf2(String secret, String saltString) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations:   100000,
      bits:         256,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(secret)),
      nonce:     utf8.encode(saltString),
    );
  }
}