import 'dart:math' as math;

import 'package:dio/dio.dart';

import 'package:gitty/core/network/api_constants.dart';

/// Implements exponential backoff with jitter for transient network failures.
///
/// Retry conditions:
/// - Network connectivity errors (no internet)
/// - Server errors (5xx)
/// - Rate limit errors (429) — waits for X-RateLimit-Reset header
/// - Timeout errors
///
/// Does NOT retry:
/// - Client errors (4xx except 429)
/// - Auth errors (401, 403)
/// - Request cancellations
class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required Dio dio,
    int maxAttempts = ApiConstants.maxRetryAttempts,
    Duration baseDelay = ApiConstants.retryBaseDelay,
    Duration maxDelay = ApiConstants.retryMaxDelay,
  })  : _dio = dio,
        _maxAttempts = maxAttempts,
        _baseDelay = baseDelay,
        _maxDelay = maxDelay;

  final Dio _dio;
  final int _maxAttempts;
  final Duration _baseDelay;
  final Duration _maxDelay;
  final math.Random _random = math.Random();

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final requestOptions = err.requestOptions;
    final attempt = (requestOptions.extra['retryAttempt'] as int? ?? 0) + 1;

    if (!_shouldRetry(err) || attempt > _maxAttempts) {
      return handler.next(err);
    }

    // Mark this attempt on the request
    requestOptions.extra['retryAttempt'] = attempt;

    final delay = _calculateDelay(
      attempt: attempt,
      rateLimitReset: _extractRateLimitReset(err.response),
    );

    // Log retry attempt
    requestOptions.extra['retryInfo'] = {
      'attempt': attempt,
      'maxAttempts': _maxAttempts,
      'delayMs': delay.inMilliseconds,
      'reason': _retryReason(err),
    };

    await Future<void>.delayed(delay);

    try {
      final response = await _dio.fetch<dynamic>(requestOptions);
      return handler.resolve(response);
    } on DioException catch (retryErr) {
      return handler.next(retryErr);
    }
  }

  // ── Decision Logic ─────────────────────────────────────────────────────────

  bool _shouldRetry(DioException err) {
    // Never retry auth failures or client mistakes
    final statusCode = err.response?.statusCode;
    if (statusCode != null) {
      if (statusCode == ApiConstants.statusUnauthorized) return false;
      if (statusCode == ApiConstants.statusForbidden) return false;
      if (statusCode == ApiConstants.statusNotFound) return false;
      if (statusCode == ApiConstants.statusUnprocessable) return false;

      // Retry rate limits (429) and server errors (5xx)
      if (statusCode == ApiConstants.statusRateLimit) return true;
      if (statusCode >= ApiConstants.statusServerError) return true;

      // Don't retry other 4xx
      if (statusCode >= 400 && statusCode < 500) return false;
    }

    // Retry network-level errors
    return switch (err.type) {
      DioExceptionType.connectionTimeout => true,
      DioExceptionType.receiveTimeout => true,
      DioExceptionType.sendTimeout => true,
      DioExceptionType.connectionError => true,
      DioExceptionType.unknown => true,
      _ => false,
    };
  }

  String _retryReason(DioException err) {
    final statusCode = err.response?.statusCode;
    if (statusCode == ApiConstants.statusRateLimit) return 'rate_limit_429';
    if (statusCode != null && statusCode >= 500)
      return 'server_error_${statusCode}';
    return err.type.name;
  }

  // ── Delay Calculation ──────────────────────────────────────────────────────

  /// Calculates delay using exponential backoff with full jitter.
  ///
  /// Formula: min(maxDelay, baseDelay * 2^attempt) + random jitter
  /// Full jitter prevents thundering herd when many clients retry simultaneously.
  Duration _calculateDelay({
    required int attempt,
    DateTime? rateLimitReset,
  }) {
    // If GitHub tells us when the rate limit resets, respect that
    if (rateLimitReset != null) {
      final resetDelay = rateLimitReset.difference(DateTime.now());
      if (resetDelay.isNegative) return Duration.zero;
      // Add small buffer to avoid hitting the reset boundary
      return resetDelay + const Duration(milliseconds: 500);
    }

    // Exponential backoff: 1s, 2s, 4s, 8s...
    final exponentialDelay = _baseDelay * math.pow(2, attempt - 1).toInt();
    final cappedDelay =
        exponentialDelay > _maxDelay ? _maxDelay : exponentialDelay;

    // Full jitter: random value between 0 and cappedDelay
    final jitter = Duration(
      milliseconds: _random.nextInt(cappedDelay.inMilliseconds + 1),
    );

    return jitter;
  }

  DateTime? _extractRateLimitReset(Response? response) {
    if (response?.statusCode != ApiConstants.statusRateLimit) return null;

    final resetHeader = response?.headers.value('x-ratelimit-reset');
    if (resetHeader == null) return null;

    final resetTimestamp = int.tryParse(resetHeader);
    if (resetTimestamp == null) return null;

    return DateTime.fromMillisecondsSinceEpoch(resetTimestamp * 1000);
  }
}
