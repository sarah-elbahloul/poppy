import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:poppy/core/constants.dart';

/// Poppy — Encryption Service
///
/// **Key Architecture:**
/// - **Data Key:** A unique, random 32-byte key generated per user at sign-up. 
///   It encrypts all journal entries and remains constant.
/// - **Password Wrapping:** The data key is encrypted (wrapped) with a key 
///   derived from the user's password (PBKDF2) and stored in `user_keys`.
/// - **Recovery Wrapping:** A second copy is wrapped with a key derived from 
///   the user's UID and an app pepper. This allows password resets via email 
///   without losing access to encrypted data.
///
/// **Encryption Coverage:**
/// - Entry `title_enc` and `content_enc` are encrypted before being stored.
/// - Metadata like dates, word counts, and color tags are stored in plain text 
///   for searching and filtering.
class EncryptionService {
  EncryptionService._();
  static final EncryptionService instance = EncryptionService._();

  static final _algorithm = AesGcm.with256bits();
  final _storage          = const FlutterSecureStorage();
  final _rng              = Random.secure();

  SecretKey? _dataKey;

  // --- Data Key Lifecycle ---

  /// Generates a fresh random 32-byte data key and caches it locally.
  /// Returns the raw bytes for the caller to wrap and persist.
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

  /// Loads the data key from local secure storage. Returns true if successful.
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
  Future<void> setDataKey(Uint8List keyBytes) async {
    _dataKey = SecretKey(keyBytes);
    await _storage.write(
      key:   StorageKeys.dataKey,
      value: base64Encode(keyBytes),
    );
  }

  /// Clears the in-memory key and local secure storage.
  Future<void> clearKey() async {
    _dataKey = null;
    await _storage.delete(key: StorageKeys.dataKey);
  }

  /// Whether a data key is currently loaded in memory.
  bool get hasKey => _dataKey != null;

  /// Returns the raw data key bytes, or null if none is loaded.
  Future<Uint8List?> currentDataKeyBytes() async {
    final key = _dataKey;
    if (key == null) return null;
    return Uint8List.fromList(await key.extractBytes());
  }

  // --- Key Wrapping (Password) ---

  /// Wraps the [dataKeyBytes] using a key derived from the [password].
  Future<Map<String, String>> wrapWithPassword(
    Uint8List dataKeyBytes,
    String    password,
  ) async {
    final wrappingKey = await _deriveKeyFromPassword(password);
    return _wrap(dataKeyBytes, wrappingKey);
  }

  /// Unwraps the data key using the provided [password].
  Future<Uint8List?> unwrapWithPassword(
    Map<String, dynamic> wrapped,
    String               password,
  ) async {
    final wrappingKey = await _deriveKeyFromPassword(password);
    return _unwrap(wrapped, wrappingKey);
  }

  // --- Key Wrapping (UID Recovery) ---

  /// Wraps the [dataKeyBytes] using a key derived from the user's [uid].
  Future<Map<String, String>> wrapWithUid(
    Uint8List dataKeyBytes,
    String    uid,
  ) async {
    final wrappingKey = await _deriveKeyFromUid(uid);
    return _wrap(dataKeyBytes, wrappingKey);
  }

  /// Unwraps the data key using the user's [uid].
  Future<Uint8List?> unwrapWithUid(
    Map<String, dynamic> wrapped,
    String               uid,
  ) async {
    final wrappingKey = await _deriveKeyFromUid(uid);
    return _unwrap(wrapped, wrappingKey);
  }

  // --- Entry Encryption / Decryption ---

  /// Encrypts a string of plaintext using the current data key.
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

  /// Encrypts plaintext and returns it as a JSON string.
  Future<String?> encryptToJson(String plaintext) async {
    final map = await encrypt(plaintext);
    return map == null ? null : jsonEncode(map);
  }

  /// Decrypts a map containing ciphertext, nonce, and MAC.
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

  /// Decrypts a JSON string, returning the [fallback] if decryption fails.
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

  // --- Bulk Helpers ---

  /// Encrypts both title and content of an entry.
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

  /// Decrypts both title and content of an entry.
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

  // --- Private Helpers ---

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
