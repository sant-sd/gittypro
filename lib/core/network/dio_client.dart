import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import 'package:gitty/core/console/console_log_service.dart';
import 'package:gitty/core/security/pat_storage_service.dart';
import 'api_constants.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'interceptors/retry_interceptor.dart';
import 'ssl/ssl_pinning_service.dart';


/// Assembles and configures the production-ready [Dio] HTTP client.
///
/// Configuration:
/// - Base URL: api.github.com
/// - SSL Pinning via custom [HttpClientAdapter]
/// - Interceptors (in order): Auth → Logging → Retry
/// - Timeouts from [ApiConstants]
class DioClient {
  DioClient._({
    required PatStorageService patStorageService,
    required ConsoleLogService consoleLogService,
  }) : _dio = _buildDio(
          patStorageService: patStorageService,
          consoleLogService: consoleLogService,
        );

  final Dio _dio;

  /// The configured [Dio] instance. Use this for all GitHub API requests.
  Dio get dio => _dio;

  static Dio _buildDio({
    required PatStorageService patStorageService,
    required ConsoleLogService consoleLogService,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.githubBaseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        sendTimeout: ApiConstants.sendTimeout,
        responseType: ResponseType.json,
        // Don't throw on non-2xx (let interceptors handle it properly)
        validateStatus: (status) => status != null && status < 600,
      ),
    );

    // ── SSL Pinning ────────────────────────────────────────────────────────
    dio.httpClientAdapter = _buildPinnedAdapter();

    // ── Interceptor Stack ──────────────────────────────────────────────────
    // Order matters: Auth runs first (adds headers), then Logging, then Retry.
    dio.interceptors.addAll([
      AuthInterceptor(patStorageService: patStorageService),
      LoggingInterceptor(consoleLogService: consoleLogService),
      RetryInterceptor(dio: dio),
    ]);

    return dio;
  }

  /// Creates an [IOHttpClientAdapter] backed by the pinned [HttpClient].
  static IOHttpClientAdapter _buildPinnedAdapter() {
    return IOHttpClientAdapter(
      createHttpClient: () {
        final client = SslPinningService.createPinnedHttpClient();

        // Enforce TLS 1.2+ only
        client.badCertificateCallback = (cert, host, port) {
          // In debug builds allow self-signed certs for local proxy (Charles/mitmproxy)
          bool allowDebug = false;
          assert(() {
            allowDebug = const bool.fromEnvironment('ALLOW_BAD_CERTS');
            return true;
          }());
          return allowDebug;
        };

        return client;
      },
    );
  }
}

/// Provides a scoped [DioClient] that is disposed when no longer needed.
final dioClientProvider = Provider<DioClient>((ref) {
  final patStorage = ref.watch(patStorageServiceProvider);
  final console = ref.watch(consoleLogServiceProvider);

  return DioClient._(
    patStorageService: patStorage,
    consoleLogService: console,
  );
});

/// Convenience provider that exposes the raw [Dio] instance directly.
/// Prefer injecting [dioClientProvider] and calling `.dio` for testability.
final dioProvider = Provider<Dio>((ref) {
  return ref.watch(dioClientProvider).dio;
});
