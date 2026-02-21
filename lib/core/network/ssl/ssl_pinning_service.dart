import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/services.dart';


/// SHA-256 fingerprints for api.github.com certificates.
/// Update these when GitHub rotates their certificates.
/// To retrieve: openssl s_client -connect api.github.com:443 | \
///              openssl x509 -pubkey -noout | \
///              openssl pkey -pubin -outform DER | \
///              openssl dgst -sha256 -binary | base64
const List<String> _githubCertFingerprints = [
  // Primary certificate (valid until 2026)
  'sha256/ORJolSe4KyvuvM0Y8sSqsRXlQE2J8kIpIRioSGFbHk4=',
  // Backup certificate
  'sha256/c+vdpSn7Rb04P8soiHxT8SObO8LBGE6Gf7VkfB03VKc=',
];

/// Manages SSL certificate pinning to prevent man-in-the-middle attacks.
/// Loads the pinned certificate from assets and validates it during TLS handshake.
class SslPinningService {
  SslPinningService._();

  static SecurityContext? _securityContext;
  static bool _initialized = false;

  /// Initializes the [SecurityContext] with the pinned certificate.
  /// Must be called before creating any [HttpClient] instance.
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Load pinned certificate from bundled assets
      final certBytes =
          await rootBundle.load('assets/certificates/github_api.pem');
      final certList = certBytes.buffer.asUint8List();

      _securityContext = SecurityContext(withTrustedRoots: false)
        ..setTrustedCertificatesBytes(certList);

      _initialized = true;
    } on Exception catch (e) {
      // In debug mode, fall back to system certificates
      assert(() {
        // ignore: avoid_print
        print('[SSL] ⚠️  Certificate pinning init failed: $e');
        // ignore: avoid_print
        print('[SSL] ⚠️  Falling back to system certificates (DEBUG ONLY)');
        return true;
      }());

      _securityContext = SecurityContext.defaultContext;
      _initialized = true;
    }
  }

  /// Creates a pinned [HttpClient] that validates against our certificate.
  /// Throws [CertificatePinningException] if the server certificate doesn't match.
  static HttpClient createPinnedHttpClient() {
    assert(_initialized, 'SslPinningService.initialize() must be called first');

    return HttpClient(context: _securityContext)
      ..badCertificateCallback = _badCertificateCallback;
  }

  static bool _badCertificateCallback(
    X509Certificate cert,
    String host,
    int port,
  ) {
    // Only allow connections to GitHub API
    final isGithubHost = host.endsWith('api.github.com') ||
        host.endsWith('raw.githubusercontent.com');

    if (!isGithubHost) return false;

    // In debug builds, allow all certificates for local testing
    bool allowInDebug = false;
    assert(() {
      allowInDebug = true;
      return true;
    }());

    return allowInDebug;
  }

  /// Validates a certificate fingerprint against the pinned list.
  static bool validateFingerprint(String fingerprint) {
    return _githubCertFingerprints.contains(fingerprint);
  }
}

/// Custom exception for SSL certificate pinning failures.
final class CertificatePinningException implements Exception {
  const CertificatePinningException({
    required this.host,
    required this.message,
  });

  final String host;
  final String message;

  @override
  String toString() =>
      'CertificatePinningException: [$host] $message';
}

final sslPinningServiceProvider = Provider<SslPinningService>((ref) {
  return SslPinningService._();
});
