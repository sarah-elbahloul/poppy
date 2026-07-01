import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:poppy/core/constants.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Encryption Service
// ─────────────────────────────────────────────────────────────

/// Manages high-level cryptographic operations for the application.
///
/// **Key Architecture:**
/// - **Data Key**: A random 32-byte AES-256-GCM key generated once per user.
///   Used to encrypt all diary content.
/// - **Password Wrapping**: The Data Key is wrapped (encrypted) with a key
///   derived from the user's password via PBKDF2-HMAC-SHA256.
/// - **Recovery Wrapping**: The Data Key is also wrapped with a key derived
///   from the user's UID for account recovery.
///
/// **Salt Strategy:**
/// Every wrap operation generates a fresh 16-byte cryptographically random
/// salt, which is stored alongside the wrapped key in the `s` field of the
/// JSON blob. This is backward compatible: old blobs without `s` fall back
/// to the original static salt so existing accounts continue to work.
///
/// **PBKDF2 Parameters:**
/// - Algorithm : HMAC-SHA256
/// - Iterations: 600 000 (OWASP 2023 recommendation for HMAC-SHA256)
/// - Output    : 256 bits
/// - Threading : key derivation runs in a background [Isolate] to avoid
///   freezing the UI (600 k rounds takes 1–3 s on mid-range devices).
class EncryptionService {
  EncryptionService._();

  /// Singleton instance of [EncryptionService].
  static final EncryptionService instance = EncryptionService._();

  static final _algorithm = AesGcm.with256bits();
  final _storage = const FlutterSecureStorage();
  final _rng = Random.secure();

  SecretKey? _dataKey;

  // ─────────────────────────────────────────────────────────────
  //  Data Key Management
  // ─────────────────────────────────────────────────────────────

  /// Generates a new random 32-byte Data Key and persists it locally.
  /// 
  /// Returns the raw bytes of the generated key.
  Future<Uint8List> generateDataKey() async {
    final bytes = Uint8List(32);
    for (var i = 0; i < 32; i++) bytes[i] = _rng.nextInt(256);
    _dataKey = SecretKey(bytes);
    await _storage.write(
      key: StorageKeys.dataKey,
      value: base64Encode(bytes),
    );
    return bytes;
  }

  /// Loads the Data Key from secure storage into memory.
  /// 
  /// Returns `true` if a key was found and successfully loaded.
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

  /// Sets a specific Data Key and persists it to secure storage.
  Future<void> setDataKey(Uint8List keyBytes) async {
    _dataKey = SecretKey(keyBytes);
    await _storage.write(
      key: StorageKeys.dataKey,
      value: base64Encode(keyBytes),
    );
  }

  /// Wipes the Data Key from memory and local storage.
  Future<void> clearKey() async {
    _dataKey = null;
    await _storage.delete(key: StorageKeys.dataKey);
  }

  /// Returns true if the Data Key is currently loaded in memory.
  bool get hasKey => _dataKey != null;

  /// Retrieves the raw bytes of the current Data Key.
  Future<Uint8List?> currentDataKeyBytes() async {
    final key = _dataKey;
    if (key == null) return null;
    return Uint8List.fromList(await key.extractBytes());
  }

  // ─────────────────────────────────────────────────────────────
  //  Key Wrapping
  // ─────────────────────────────────────────────────────────────

  /// Wraps [dataKeyBytes] using a key derived from the user's [password].
  ///
  /// Generates a fresh 16-byte random salt and embeds it as the `s` field
  /// in the returned map alongside the ciphertext (`c`), nonce (`n`),
  /// and MAC (`m`).
  Future<Map<String, String>> wrapWithPassword(
      Uint8List dataKeyBytes,
      String password,
      ) async {
    final salt = _generateSalt();
    final wrappingKey = await _deriveKeyFromPassword(password, salt);
    final wrapped = await _wrap(dataKeyBytes, wrappingKey);
    return {...wrapped, 's': base64Encode(salt)};
  }

  /// Unwraps the Data Key using the user's [password].
  ///
  /// Reads the per-wrap salt from [wrapped]['s']. If absent (legacy key
  /// wrapped before this fix), falls back to the original static salt.
  Future<Uint8List?> unwrapWithPassword(
      Map<String, dynamic> wrapped,
      String password,
      ) async {
    final salt = _saltFromMap(wrapped, fallback: 'poppy-diary-salt-v1');
    final wrappingKey = await _deriveKeyFromPassword(password, salt);
    return _unwrap(wrapped, wrappingKey);
  }

  /// Wraps [dataKeyBytes] using a key derived from the user's [uid] for recovery.
  ///
  /// Generates a fresh 16-byte random salt and embeds it as the `s` field.
  Future<Map<String, String>> wrapWithUid(
      Uint8List dataKeyBytes,
      String uid,
      ) async {
    final salt = _generateSalt();
    final wrappingKey = await _deriveKeyFromUid(uid, salt);
    final wrapped = await _wrap(dataKeyBytes, wrappingKey);
    return {...wrapped, 's': base64Encode(salt)};
  }

  /// Unwraps the Data Key using the user's [uid].
  ///
  /// Falls back to the original static pepper for legacy keys without a
  /// stored salt.
  Future<Uint8List?> unwrapWithUid(
      Map<String, dynamic> wrapped,
      String uid,
      ) async {
    final salt = _saltFromMap(wrapped, fallback: 'poppy-recovery-pepper-v1');
    final wrappingKey = await _deriveKeyFromUid(uid, salt);
    return _unwrap(wrapped, wrappingKey);
  }

  // ─────────────────────────────────────────────────────────────
  //  Content Encryption / Decryption
  // ─────────────────────────────────────────────────────────────

  /// Encrypts [plaintext] and returns a map containing the ciphertext (`c`),
  /// nonce (`n`), and MAC (`m`).
  Future<Map<String, String>?> encrypt(String plaintext) async {
    final key = _dataKey;
    if (key == null) return null;
    final nonce = _algorithm.newNonce();
    final secretBox = await _algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
      nonce: nonce,
    );
    return {
      'c': base64Encode(secretBox.cipherText),
      'n': base64Encode(nonce),
      'm': base64Encode(secretBox.mac.bytes),
    };
  }

  /// Encrypts [plaintext] and returns a JSON string representation.
  Future<String?> encryptToJson(String plaintext) async {
    final map = await encrypt(plaintext);
    return map == null ? null : jsonEncode(map);
  }

  /// Decrypts an encrypted [data] map.
  Future<String?> decrypt(Map<String, dynamic> data) async {
    final key = _dataKey;
    if (key == null) return null;
    try {
      final secretBox = SecretBox(
        base64Decode(data['c'] as String),
        nonce: base64Decode(data['n'] as String),
        mac: Mac(base64Decode(data['m'] as String)),
      );
      final clearBytes = await _algorithm.decrypt(
        secretBox,
        secretKey: key,
      );
      return utf8.decode(clearBytes);
    } catch (_) {
      return null;
    }
  }

  /// Decrypts a JSON string.
  ///
  /// If decryption fails or the input is not JSON, returns [fallback].
  Future<String> decryptFromJson(String? jsonStr, {String fallback = ''}) async {
    if (jsonStr == null || jsonStr.isEmpty) return fallback;
    try {
      if (!jsonStr.startsWith('{')) return jsonStr;
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final result = await decrypt(map);
      return result ?? fallback;
    } catch (_) {
      return jsonStr;
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  Batch & Entry Helpers
  // ─────────────────────────────────────────────────────────────

  /// Encrypts both [title] and [content] for a single journal entry.
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

  /// Decrypts both [titleJson] and [contentJson] for a single journal entry.
  Future<({String title, String content})> decryptEntry({
    required String? titleJson,
    required String? contentJson,
  }) async {
    final results = await Future.wait([
      decryptFromJson(titleJson, fallback: ''),
      decryptFromJson(contentJson, fallback: ''),
    ]);
    return (title: results[0], content: results[1]);
  }

  // ─────────────────────────────────────────────────────────────
  //  Internal: AES-GCM wrap / unwrap
  // ─────────────────────────────────────────────────────────────

  /// Wraps [dataKeyBytes] with [wrappingKey] using AES-256-GCM.
  Future<Map<String, String>> _wrap(
      Uint8List dataKeyBytes,
      SecretKey wrappingKey,
      ) async {
    final nonce = _algorithm.newNonce();
    final secretBox = await _algorithm.encrypt(
      dataKeyBytes,
      secretKey: wrappingKey,
      nonce: nonce,
    );
    return {
      'c': base64Encode(secretBox.cipherText),
      'n': base64Encode(nonce),
      'm': base64Encode(secretBox.mac.bytes),
    };
  }

  /// Unwraps (decrypts) a wrapped key blob with [wrappingKey].
  Future<Uint8List?> _unwrap(
      Map<String, dynamic> wrapped,
      SecretKey wrappingKey,
      ) async {
    try {
      final secretBox = SecretBox(
        base64Decode(wrapped['c'] as String),
        nonce: base64Decode(wrapped['n'] as String),
        mac: Mac(base64Decode(wrapped['m'] as String)),
      );
      final bytes = await _algorithm.decrypt(
        secretBox,
        secretKey: wrappingKey,
      );
      return Uint8List.fromList(bytes);
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  Internal: PBKDF2 key derivation (background isolate)
  // ─────────────────────────────────────────────────────────────

  /// Derives a 256-bit wrapping key from [password] and [salt] using
  /// PBKDF2-HMAC-SHA256 with 600 000 iterations.
  ///
  /// Runs in a background [Isolate] to avoid blocking the UI thread.
  Future<SecretKey> _deriveKeyFromPassword(
      String password,
      Uint8List salt,
      ) async {
    final keyBytes = await Isolate.run(() async {
      final pbkdf2 = Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: 600000,
        bits: 256,
      );
      final key = await pbkdf2.deriveKey(
        secretKey: SecretKey(utf8.encode(password)),
        nonce: salt,
      );
      return Uint8List.fromList(await key.extractBytes());
    });
    return SecretKey(keyBytes);
  }

  /// Derives a 256-bit wrapping key from [uid] and [salt] using
  /// PBKDF2-HMAC-SHA256 with 600 000 iterations.
  ///
  /// Runs in a background [Isolate] to avoid blocking the UI thread.
  Future<SecretKey> _deriveKeyFromUid(
      String uid,
      Uint8List salt,
      ) async {
    final keyBytes = await Isolate.run(() async {
      final pbkdf2 = Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: 600000,
        bits: 256,
      );
      final key = await pbkdf2.deriveKey(
        secretKey: SecretKey(utf8.encode(uid)),
        nonce: salt,
      );
      return Uint8List.fromList(await key.extractBytes());
    });
    return SecretKey(keyBytes);
  }

  // ─────────────────────────────────────────────────────────────
  //  Internal: salt helpers
  // ─────────────────────────────────────────────────────────────

  /// Generates a cryptographically random 16-byte salt.
  Uint8List _generateSalt() {
    final salt = Uint8List(16);
    for (var i = 0; i < 16; i++) salt[i] = _rng.nextInt(256);
    return salt;
  }

  /// Extracts the per-wrap salt from a key blob.
  ///
  /// If the blob has no `s` field (pre-fix legacy key), returns the
  /// [fallback] static salt encoded as UTF-8 bytes so that old keys
  /// can still be unwrapped.
  Uint8List _saltFromMap(Map<String, dynamic> map, {required String fallback}) {
    final s = map['s'] as String?;
    return s != null ? base64Decode(s) : utf8.encode(fallback);
  }
}