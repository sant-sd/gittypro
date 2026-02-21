/// Security configuration constants for Gitty.
/// All cryptographic parameters are defined here for easy auditing and rotation.
abstract final class SecurityConfig {
  // ── AES-256-GCM Parameters ────────────────────────────────────────────────
  /// Key length in bytes (256-bit)
  static const int aesKeyLength = 32;

  /// IV (Initialization Vector) length in bytes for GCM mode
  static const int aesIvLength = 12;

  /// GCM authentication tag length in bytes
  static const int aesTagLength = 16;

  // ── PBKDF2 Key Derivation ─────────────────────────────────────────────────
  /// Iterations for PBKDF2 — NIST recommends ≥ 600,000 for SHA-256
  static const int pbkdf2Iterations = 600000;

  /// Salt length in bytes
  static const int saltLength = 32;

  // ── Secure Storage Keys ───────────────────────────────────────────────────
  static const String patKey = 'gitty_github_pat_v2';
  static const String encryptionSaltKey = 'gitty_enc_salt_v1';
  static const String encryptionKeyKey = 'gitty_enc_key_v1';

  // ── PAT Validation ────────────────────────────────────────────────────────
  /// GitHub Fine-grained PAT prefix
  static const String patPrefixFineGrained = 'github_pat_';

  /// GitHub Classic PAT prefix
  static const String patPrefixClassic = 'ghp_';

  /// GitHub OAuth token prefix
  static const String patPrefixOAuth = 'gho_';

  /// Minimum PAT length
  static const int patMinLength = 20;

  // ── Session ───────────────────────────────────────────────────────────────
  /// Duration after which a cached PAT is considered stale and re-read from storage
  static const Duration patCacheTtl = Duration(minutes: 5);

  // ── SSL Pinning ───────────────────────────────────────────────────────────
  static const String certificateAssetPath =
      'assets/certificates/github_api.pem';

  /// SHA-256 fingerprints for api.github.com (update when GitHub rotates certs)
  static const List<String> pinnedFingerprints = [
    'sha256/ORJolSe4KyvuvM0Y8sSqsRXlQE2J8kIpIRioSGFbHk4=',
    'sha256/c+vdpSn7Rb04P8soiHxT8SObO8LBGE6Gf7VkfB03VKc=',
  ];
}
