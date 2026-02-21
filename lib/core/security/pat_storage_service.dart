import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gitty/core/security/encryption_service.dart';
import 'package:gitty/core/security/security_config.dart';


/// Result of a PAT validation check.
enum PatValidationResult {
  valid,
  empty,
  tooShort,
  invalidFormat,
  invalidPrefix;

  bool get isValid => this == PatValidationResult.valid;

  String get message => switch (this) {
        PatValidationResult.valid         => 'Token is valid',
        PatValidationResult.empty         => 'Token cannot be empty',
        PatValidationResult.tooShort      => 'Token is too short',
        PatValidationResult.invalidFormat => 'Token contains invalid characters',
        PatValidationResult.invalidPrefix =>
          'Invalid token format. Expected github_pat_, ghp_, or gho_ prefix',
      };
}

/// Manages the full lifecycle of the GitHub Personal Access Token:
/// validation → encryption → secure storage → cached retrieval.
///
/// Storage Strategy:
///   - Encrypt PAT with AES-256-GCM via [EncryptionService]
///   - Store encrypted blob in Keychain (iOS) / Keystore (Android)
///   - Cache decrypted PAT in memory with TTL to reduce storage reads
class PatStorageService {
  PatStorageService({
    required EncryptionService encryptionService,
    FlutterSecureStorage? storage,
  })  : _encryption = encryptionService,
        _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                keyCipherAlgorithm:
                    KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
                storageCipherAlgorithm:
                    StorageCipherAlgorithm.AES_GCM_NoPadding,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  final EncryptionService _encryption;
  final FlutterSecureStorage _storage;

  String? _cachedPat;
  DateTime? _cachedAt;

  // ── Write ────────────────────────────────────────────────────────────────

  Future<void> writePat(String pat) async {
    final validation = validate(pat);
    if (!validation.isValid) {
      throw PatStorageException(validation.message);
    }

    final trimmed = pat.trim();
    final encrypted = await _encryption.encrypt(trimmed);

    await _storage.write(key: SecurityConfig.patKey, value: encrypted);
    _cachedPat = trimmed;
    _cachedAt = DateTime.now();
  }

  // ── Read ─────────────────────────────────────────────────────────────────

  Future<String?> readPat() async {
    if (_isCacheValid()) return _cachedPat;

    final encrypted = await _storage.read(key: SecurityConfig.patKey);
    if (encrypted == null) return null;

    try {
      final decrypted = await _encryption.decrypt(encrypted);
      _cachedPat = decrypted;
      _cachedAt = DateTime.now();
      return decrypted;
    } on EncryptionException {
      await deletePat();
      return null;
    }
  }

  // ── Delete ───────────────────────────────────────────────────────────────

  Future<void> deletePat() async {
    _clearCache();
    await _storage.delete(key: SecurityConfig.patKey);
    _encryption.clearCache();
  }

  // ── Query ────────────────────────────────────────────────────────────────

  Future<bool> hasPat() async {
    final pat = await readPat();
    return pat != null && pat.isNotEmpty;
  }

  Future<String?> maskedPat() async {
    final pat = await readPat();
    if (pat == null) return null;
    if (pat.length <= 8) return '••••••••';
    final visible = pat.substring(pat.length - 4);
    return '${'•' * (pat.length - 4)}$visible';
  }

  // ── Validation ───────────────────────────────────────────────────────────

  static PatValidationResult validate(String pat) {
    final trimmed = pat.trim();
    if (trimmed.isEmpty) return PatValidationResult.empty;
    if (trimmed.length < SecurityConfig.patMinLength) return PatValidationResult.tooShort;
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(trimmed)) return PatValidationResult.invalidFormat;

    final hasValidPrefix =
        trimmed.startsWith(SecurityConfig.patPrefixFineGrained) ||
        trimmed.startsWith(SecurityConfig.patPrefixClassic) ||
        trimmed.startsWith(SecurityConfig.patPrefixOAuth);

    if (!hasValidPrefix) return PatValidationResult.invalidPrefix;
    return PatValidationResult.valid;
  }

  bool _isCacheValid() =>
      _cachedPat != null &&
      _cachedAt != null &&
      DateTime.now().difference(_cachedAt!) < SecurityConfig.patCacheTtl;

  void _clearCache() {
    _cachedPat = null;
    _cachedAt = null;
  }
}

final class PatStorageException implements Exception {
  const PatStorageException(this.message);
  final String message;

  @override
  String toString() => 'PatStorageException: $message';
}

final patStorageServiceProvider = Provider<PatStorageService>((ref) {
  final encryption = ref.watch(encryptionServiceProvider);
  return PatStorageService(encryptionService: encryption);
});
