import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:poppy/core/constants.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — PIN Service
//  Location: lib/services/pin_service.dart
//
//  Handles PIN setup and verification.
//  The raw PIN is never stored — only its SHA-256 hash.
// ─────────────────────────────────────────────────────────────

class PinService {
  final _storage = const FlutterSecureStorage();

  // ── Hash ──────────────────────────────────────────────────

  String _hash(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ── Save a new PIN ────────────────────────────────────────

  Future<void> savePin(String pin) async {
    await _storage.write(
      key: StorageKeys.pinHash,
      value: _hash(pin),
    );
    await _storage.write(
      key: StorageKeys.pinEnabled,
      value: 'true',
    );
  }

  // ── Verify entered PIN ────────────────────────────────────

  Future<bool> verify(String pin) async {
    final stored = await _storage.read(key: StorageKeys.pinHash);
    if (stored == null) return false;
    return _hash(pin) == stored;
  }

  // ── Remove PIN ────────────────────────────────────────────

  Future<void> removePin() async {
    await _storage.delete(key: StorageKeys.pinHash);
    await _storage.write(
      key: StorageKeys.pinEnabled,
      value: 'false',
    );
  }

  // ── Check if PIN is set ───────────────────────────────────

  Future<bool> isPinEnabled() async {
    final value = await _storage.read(key: StorageKeys.pinEnabled);
    return value == 'true';
  }

  // ── Change PIN ────────────────────────────────────────────
  // Verifies the old PIN before saving the new one.

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