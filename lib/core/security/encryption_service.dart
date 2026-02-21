import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';

import 'security_config.dart';


/// Provides AES-256-GCM encryption for sensitive data stored locally.
///
/// Key Derivation Flow:
///   1. Generate random 32-byte salt (stored in Secure Storage)
///   2. Derive 256-bit key via PBKDF2-SHA256 (600,000 iterations)
///   3. Encrypt data with AES-256-GCM + random 12-byte IV
///   4. Store: Base64(IV + CipherText + GCM Tag)
///
/// This provides an extra encryption layer on top of Keychain/Keystore.
class EncryptionService {
  EncryptionService({required FlutterSecureStorage storage})
      : _storage = storage;

  final FlutterSecureStorage _storage;
  final _random = Random.secure();

  // Cached derived key to avoid re-deriving on every operation
  Uint8List? _cachedKey;
  DateTime? _keyDerivedAt;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Encrypts [plainText] using AES-256-GCM.
  /// Returns Base64-encoded string: IV (12) + CipherText + Tag (16)
  Future<String> encrypt(String plainText) async {
    final key = await _getDerivedKey();
    final iv = _generateIv();

    final encKey = enc.Key(key);
    final encIv = enc.IV(iv);
    final encrypter = enc.Encrypter(
      enc.AES(encKey, mode: enc.AESMode.gcm),
    );

    final encrypted = encrypter.encrypt(plainText, iv: encIv);

    // Prepend IV to ciphertext for storage: IV || CipherText
    final combined = Uint8List(SecurityConfig.aesIvLength + encrypted.bytes.length);
    combined
      ..setAll(0, iv)
      ..setAll(SecurityConfig.aesIvLength, encrypted.bytes);

    return base64.encode(combined);
  }

  /// Decrypts a Base64-encoded string produced by [encrypt].
  Future<String> decrypt(String encryptedBase64) async {
    final key = await _getDerivedKey();
    final combined = base64.decode(encryptedBase64);

    if (combined.length < SecurityConfig.aesIvLength) {
      throw const EncryptionException('Invalid ciphertext: too short');
    }

    // Extract IV and ciphertext
    final iv = combined.sublist(0, SecurityConfig.aesIvLength);
    final cipherBytes = combined.sublist(SecurityConfig.aesIvLength);

    final encKey = enc.Key(key);
    final encIv = enc.IV(iv);
    final encrypter = enc.Encrypter(
      enc.AES(encKey, mode: enc.AESMode.gcm),
    );

    try {
      return encrypter.decrypt(enc.Encrypted(cipherBytes), iv: encIv);
    } on Exception catch (e) {
      throw EncryptionException('Decryption failed: $e');
    }
  }

  /// Clears the cached derived key, forcing re-derivation on next use.
  void clearCache() {
    _cachedKey = null;
    _keyDerivedAt = null;
  }

  // ── Key Derivation ─────────────────────────────────────────────────────────

  /// Returns the derived AES key, using cache if still fresh.
  Future<Uint8List> _getDerivedKey() async {
    final now = DateTime.now();
    if (_cachedKey != null &&
        _keyDerivedAt != null &&
        now.difference(_keyDerivedAt!) < SecurityConfig.patCacheTtl) {
      return _cachedKey!;
    }

    final salt = await _getOrCreateSalt();
    _cachedKey = _deriveKey(salt);
    _keyDerivedAt = now;
    return _cachedKey!;
  }

  /// Derives a 256-bit key using PBKDF2-HMAC-SHA256.
  Uint8List _deriveKey(Uint8List salt) {
    // Device-specific key material: combine device ID + app package name
    // In production this should include device fingerprint from device_info_plus
    const password = 'gitty_enc_v2_key_material';
    final passwordBytes = Uint8List.fromList(password.codeUnits);

    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    pbkdf2.init(
      Pbkdf2Parameters(
        salt,
        SecurityConfig.pbkdf2Iterations,
        SecurityConfig.aesKeyLength,
      ),
    );
    return pbkdf2.process(passwordBytes);
  }

  /// Retrieves the stored salt, or generates and stores a new one.
  Future<Uint8List> _getOrCreateSalt() async {
    final stored = await _storage.read(key: SecurityConfig.encryptionSaltKey);
    if (stored != null) {
      return base64.decode(stored);
    }

    final salt = _generateBytes(SecurityConfig.saltLength);
    await _storage.write(
      key: SecurityConfig.encryptionSaltKey,
      value: base64.encode(salt),
    );
    return salt;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Uint8List _generateIv() => _generateBytes(SecurityConfig.aesIvLength);

  Uint8List _generateBytes(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }
}

// ── Exception ──────────────────────────────────────────────────────────────────

final class EncryptionException implements Exception {
  const EncryptionException(this.message);
  final String message;

  @override
  String toString() => 'EncryptionException: $message';
}

// ── Provider ──────────────────────────────────────────────────────────────────

final encryptionServiceProvider = Provider<EncryptionService>((ref) {
  return EncryptionService(
    storage: const FlutterSecureStorage(),
  );
});
