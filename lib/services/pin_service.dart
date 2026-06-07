import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:poppy/core/constants.dart';

/// Service for managing PIN-based app locking.
/// 
/// Stores a salted SHA-256 hash of the PIN in secure storage.
class PinService {
  final _storage = const FlutterSecureStorage();

  /// Generates a SHA-256 hash of the given PIN.
  String _hash(String pin) {
    final bytes  = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Hashes and saves a new PIN, enabling the PIN lock.
  Future<void> savePin(String pin) async {
    await _storage.write(key: StorageKeys.pinHash,    value: _hash(pin));
    await _storage.write(key: StorageKeys.pinEnabled, value: 'true');
  }

  /// Verifies if the provided PIN matches the stored hash.
  Future<bool> verify(String pin) async {
    final stored = await _storage.read(key: StorageKeys.pinHash);
    if (stored == null) return false;
    return _hash(pin) == stored;
  }

  /// Removes the stored PIN and disables the PIN lock.
  Future<void> removePin() async {
    await _storage.delete(key: StorageKeys.pinHash);
    await _storage.write(key: StorageKeys.pinEnabled, value: 'false');
  }

  /// Checks if the PIN lock is currently enabled.
  Future<bool> isPinEnabled() async {
    final value = await _storage.read(key: StorageKeys.pinEnabled);
    return value == 'true';
  }

  /// Updates the PIN if the [oldPin] is correct.
  Future<bool> changePin({
    required String oldPin,
    required String newPin,
  }) async {
    final isCorrect = await verify(oldPin);
    if (!isCorrect) return false;
    await savePin(newPin);
    return true;
  }
}
