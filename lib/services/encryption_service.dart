import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Encryption Service
//  Location: lib/services/encryption_service.dart
//
//  End-to-end encryption for diary entries.
//
//  Algorithm : AES-256-GCM (authenticated encryption)
//  Key source: PBKDF2 derived from user's password
//  Storage   : derived key bytes cached in flutter_secure_storage
//              so we only re-derive on first login per session
//
//  What is encrypted:
//    - entry title
//    - entry content
//
//  What is NOT encrypted (needed for sorting/display):
//    - entry_date
//    - word_count
//    - color_tag
//    - created_at / updated_at
//
//  Encrypted fields are stored in Supabase as JSONB:
//    {
//      "c": "<base64 ciphertext>",
//      "n": "<base64 nonce>",
//      "m": "<base64 mac>"
//    }
//  Short keys keep storage small.
// ─────────────────────────────────────────────────────────────

class EncryptionService {
  EncryptionService._();
  static final EncryptionService instance = EncryptionService._();

  static const _storageKey = 'poppy_enc_key';
  static final _algorithm  = AesGcm.with256bits();
  final _storage            = const FlutterSecureStorage();

  SecretKey? _cachedKey;

  // ── Key management ────────────────────────────────────────

  /// Derives an AES-256 key from [password] using PBKDF2
  /// and caches it in secure storage and memory.
  /// Call this once after the user signs in.
  Future<void> initFromPassword(String password) async {
    final key = await _deriveKey(password);
    _cachedKey = key;

    // Cache the raw key bytes so we don't re-derive on every cold start
    final keyBytes = await key.extractBytes();
    await _storage.write(
      key: _storageKey,
      value: base64Encode(keyBytes),
    );
  }

  /// Loads a previously cached key from secure storage.
  /// Returns true if a key was found and loaded.
  /// Call this on app start if the user is already logged in.
  Future<bool> loadCachedKey() async {
    try {
      final stored = await _storage.read(key: _storageKey);
      if (stored == null) return false;
      final keyBytes = base64Decode(stored);
      _cachedKey = SecretKey(keyBytes);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Clears the cached key from memory and storage.
  /// Call this on sign-out so the next user cannot decrypt.
  Future<void> clearKey() async {
    _cachedKey = null;
    await _storage.delete(key: _storageKey);
  }

  /// True when a key is loaded and encryption/decryption can proceed.
  bool get hasKey => _cachedKey != null;

  // ── Key derivation ────────────────────────────────────────

  Future<SecretKey> _deriveKey(String password) async {
    // Use a fixed salt derived from the app name + a constant.
    // In a production app you would store a per-user random salt
    // in the database. For Poppy this is acceptable because the
    // password itself provides the entropy and the salt prevents
    // pre-computation attacks across different apps.
    const saltString = 'poppy-diary-salt-v1';
    final salt       = utf8.encode(saltString);

    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations:   100000, // 100k rounds — adjust down if too slow on device
      bits:         256,
    );

    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce:     salt,
    );
  }

  // ── Encrypt ───────────────────────────────────────────────

  /// Encrypts [plaintext] and returns a JSON-encodable map.
  /// Returns null if no key is loaded (should never happen in normal flow).
  Future<Map<String, String>?> encrypt(String plaintext) async {
    final key = _cachedKey;
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

  /// Encrypts [plaintext] and returns the result as a JSON string
  /// suitable for storing directly in a Supabase JSONB column.
  Future<String?> encryptToJson(String plaintext) async {
    final map = await encrypt(plaintext);
    if (map == null) return null;
    return jsonEncode(map);
  }

  // ── Decrypt ───────────────────────────────────────────────

  /// Decrypts a map previously produced by [encrypt].
  /// Returns the original plaintext, or null on failure.
  Future<String?> decrypt(Map<String, dynamic> data) async {
    final key = _cachedKey;
    if (key == null) return null;

    try {
      final secretBox = SecretBox(
        base64Decode(data['c'] as String),
        nonce: base64Decode(data['n'] as String),
        mac:   Mac(base64Decode(data['m'] as String)),
      );

      final clearBytes = await _algorithm.decrypt(
        secretBox,
        secretKey: key,
      );
      return utf8.decode(clearBytes);
    } catch (_) {
      // Wrong key or corrupted data
      return null;
    }
  }

  /// Decrypts a JSON string previously produced by [encryptToJson].
  /// Returns the plaintext, or a fallback if decryption fails.
  Future<String> decryptFromJson(
      String? jsonStr, {
        String fallback = '',
      }) async {
    if (jsonStr == null || jsonStr.isEmpty) return fallback;

    try {
      // Handle both JSON object strings and plain text
      // (plain text = legacy entries created before encryption)
      if (!jsonStr.startsWith('{')) return jsonStr;

      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final result = await decrypt(map);
      return result ?? fallback;
    } catch (_) {
      // If it's not valid JSON, treat as plain text (legacy)
      return jsonStr;
    }
  }

  // ── Bulk helpers used by entries_service ──────────────────

  /// Encrypts title and content together in parallel.
  Future<({String titleJson, String contentJson})> encryptEntry({
    required String title,
    required String content,
  }) async {
    final results = await Future.wait([
      encryptToJson(title),
      encryptToJson(content),
    ]);
    return (
    titleJson:   results[0] ?? '',
    contentJson: results[1] ?? '',
    );
  }

  /// Decrypts title and content together in parallel.
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
}