import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:poppy/core/constants.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — PIN Security Service
//  Location: lib/features/auth/data/services/pin_service.dart
// ─────────────────────────────────────────────────────────────

class PinService {
  final _storage = const FlutterSecureStorage();

  Future<void> savePin(String pin) async {
    await _storage.write(key: StorageKeys.pinHash, value: _hash(pin));
    await _storage.write(key: StorageKeys.pinEnabled, value: 'true');
  }

  Future<bool> verify(String pin) async {
    final stored = await _storage.read(key: StorageKeys.pinHash);
    if (stored == null) return false;
    return _hash(pin) == stored;
  }

  Future<void> removePin() async {
    await _storage.delete(key: StorageKeys.pinHash);
    await _storage.write(key: StorageKeys.pinEnabled, value: 'false');
  }

  Future<bool> isPinEnabled() async {
    final value = await _storage.read(key: StorageKeys.pinEnabled);
    return value == 'true';
  }

  Future<bool> changePin({
    required String oldPin,
    required String newPin,
  }) async {
    final isCorrect = await verify(oldPin);
    if (!isCorrect) return false;
    await savePin(newPin);
    return true;
  }

  String _hash(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
