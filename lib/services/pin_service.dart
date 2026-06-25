import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:poppy/core/constants.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — PIN Security Service
//  Location: lib/services/pin_service.dart
// ─────────────────────────────────────────────────────────────

/// Manages the application-level PIN lock lifecycle.
///
/// This service handles the storage and verification of a 4-digit security PIN.
/// The PIN is distinct from the account password and is used to protect access
/// to the application on a per-device basis.
class PinService {
  final _storage = const FlutterSecureStorage();

  // ─────────────────────────────────────────────────────────────
  //  PIN Management
  // ─────────────────────────────────────────────────────────────

  /// Persists a new PIN hash to secure storage and enables the lock state.
  Future<void> savePin(String pin) async {
    await _storage.write(key: StorageKeys.pinHash, value: _hash(pin));
    await _storage.write(key: StorageKeys.pinEnabled, value: 'true');
  }

  /// Verifies if the provided [pin] matches the stored hash.
  Future<bool> verify(String pin) async {
    final stored = await _storage.read(key: StorageKeys.pinHash);
    if (stored == null) return false;
    return _hash(pin) == stored;
  }

  /// Wipes the PIN hash from secure storage and disables the lock state.
  Future<void> removePin() async {
    await _storage.delete(key: StorageKeys.pinHash);
    await _storage.write(key: StorageKeys.pinEnabled, value: 'false');
  }

  /// Checks if a PIN lock is currently enabled on this device.
  Future<bool> isPinEnabled() async {
    final value = await _storage.read(key: StorageKeys.pinEnabled);
    return value == 'true';
  }

  /// Updates the PIN after verifying the [oldPin].
  Future<bool> changePin({
    required String oldPin,
    required String newPin,
  }) async {
    final isCorrect = await verify(oldPin);
    if (!isCorrect) return false;
    await savePin(newPin);
    return true;
  }

  // ─────────────────────────────────────────────────────────────
  //  Internal Helpers
  // ─────────────────────────────────────────────────────────────

  /// Generates a SHA-256 hash of the given [pin].
  String _hash(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
