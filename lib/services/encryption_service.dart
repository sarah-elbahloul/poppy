import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:poppy/core/constants.dart';

/// Manages high-level cryptographic operations for the application.
///
/// **Key Architecture:**
/// - **Data Key**: A random 32-byte key generated per user. Used to encrypt all diary content.
/// - **Password Wrapping**: The Data Key is wrapped (encrypted) with a key derived from the user's password.
/// - **Recovery Wrapping**: The Data Key is also wrapped with a key derived from the user's UID for recovery.
///
/// **Encryption Standard**: AES-256-GCM (Authenticated Encryption).
class EncryptionService {
  EncryptionService._();

  /// Singleton instance of [EncryptionService].
  static final EncryptionService instance = EncryptionService._();

  static final _algorithm = AesGcm.with256bits();
  final _storage = const FlutterSecureStorage();
  final _rng = Random.secure();

  SecretKey? _dataKey;

  // --- Data Key Management ---

  /// Generates a new random 32-byte Data Key and persists it locally in [FlutterSecureStorage].
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
  /// Returns true if the key was successfully loaded.
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

  // --- Key Wrapping ---

  /// Wraps (encrypts) the Data Key using a key derived from the user's [password].
  Future<Map<String, String>> wrapWithPassword(
    Uint8List dataKeyBytes,
    String password,
  ) async {
    final wrappingKey = await _deriveKeyFromPassword(password);
    return _wrap(dataKeyBytes, wrappingKey);
  }

  /// Unwraps (decrypts) the Data Key using the user's [password].
  Future<Uint8List?> unwrapWithPassword(
    Map<String, dynamic> wrapped,
    String password,
  ) async {
    final wrappingKey = await _deriveKeyFromPassword(password);
    return _unwrap(wrapped, wrappingKey);
  }

  /// Wraps the Data Key using a key derived from the user's [uid] for recovery.
  Future<Map<String, String>> wrapWithUid(
    Uint8List dataKeyBytes,
    String uid,
  ) async {
    final wrappingKey = await _deriveKeyFromUid(uid);
    return _wrap(dataKeyBytes, wrappingKey);
  }

  /// Unwraps the Data Key using the user's [uid].
  Future<Uint8List?> unwrapWithUid(
    Map<String, dynamic> wrapped,
    String uid,
  ) async {
    final wrappingKey = await _deriveKeyFromUid(uid);
    return _unwrap(wrapped, wrappingKey);
  }

  // --- Content Encryption ---

  /// Encrypts [plaintext] and returns a map containing the ciphertext ('c'), nonce ('n'), and MAC ('m').
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

  /// Decrypts a JSON string. If decryption fails or the string is not JSON, returns [fallback].
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

  // --- Batch Operations ---

  /// Encrypts both [title] and [content] for a single entry.
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

  /// Decrypts both [titleJson] and [contentJson] for a single entry.
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

  // --- Internal Cryptography ---

  /// Internal implementation for wrapping a key.
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

  /// Internal implementation for unwrapping a key.
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

  /// Derives a cryptographic key from a password using PBKDF2.
  Future<SecretKey> _deriveKeyFromPassword(String password) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 100000,
      bits: 256,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: utf8.encode('poppy-diary-salt-v1'),
    );
  }

  /// Derives a cryptographic key from a UID using PBKDF2 for recovery.
  Future<SecretKey> _deriveKeyFromUid(String uid) async {
    const pepper = 'poppy-recovery-pepper-v1';
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 100000,
      bits: 256,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(uid)),
      nonce: utf8.encode(pepper),
    );
  }
}
