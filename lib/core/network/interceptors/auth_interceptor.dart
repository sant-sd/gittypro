import 'package:dio/dio.dart';

import 'package:gitty/core/security/pat_storage_service.dart';
import 'package:gitty/core/network/api_constants.dart';

/// Intercepts every outgoing request and injects the GitHub Personal Access Token.
/// Also handles 401 responses by clearing the stored token and throwing [UnauthorizedException].
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required PatStorageService patStorageService})
      : _patStorageService = patStorageService;

  final PatStorageService _patStorageService;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final pat = await _patStorageService.readPat();

    if (pat != null && pat.isNotEmpty) {
      options.headers.addAll({
        'Authorization': 'Bearer $pat',
        'Accept': ApiConstants.acceptHeader,
        'X-GitHub-Api-Version': ApiConstants.apiVersionHeader,
        'Content-Type': 'application/json',
        'User-Agent': 'Gitty-Mobile-Client/1.0',
      });
    } else {
      // No token available — still set required headers
      options.headers.addAll({
        'Accept': ApiConstants.acceptHeader,
        'X-GitHub-Api-Version': ApiConstants.apiVersionHeader,
        'User-Agent': 'Gitty-Mobile-Client/1.0',
      });
    }

    return handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // Warn if rate limit is running low
    final remaining = int.tryParse(
      response.headers.value('x-ratelimit-remaining') ?? '',
    );

    if (remaining != null &&
        remaining < ApiConstants.rateLimitWarningThreshold) {
      // Emit warning — will be picked up by LoggingInterceptor
      response.requestOptions.extra['rateLimitWarning'] =
          'GitHub rate limit low: $remaining requests remaining';
    }

    return handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == ApiConstants.statusUnauthorized) {
      // Token is invalid or expired — clear it
      _patStorageService.deletePat().ignore();

      return handler.next(
        err.copyWith(
          error: UnauthorizedException(
            'GitHub token is invalid or expired. Please re-authenticate.',
          ),
        ),
      );
    }

    if (err.response?.statusCode == ApiConstants.statusForbidden) {
      final message = _extractErrorMessage(err.response);
      return handler.next(
        err.copyWith(
          error: ForbiddenException(message),
        ),
      );
    }

    return handler.next(err);
  }

  String _extractErrorMessage(Response? response) {
    try {
      final data = response?.data as Map<String, dynamic>?;
      return data?['message']?.toString() ?? 'Access forbidden';
    } on Exception {
      return 'Access forbidden';
    }
  }
}

// ── Auth-specific exceptions ──────────────────────────────────────────────────

final class UnauthorizedException implements Exception {
  const UnauthorizedException(this.message);
  final String message;

  @override
  String toString() => 'UnauthorizedException: $message';
}

final class ForbiddenException implements Exception {
  const ForbiddenException(this.message);
  final String message;

  @override
  String toString() => 'ForbiddenException: $message';
}
