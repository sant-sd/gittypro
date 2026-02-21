import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:gitty/core/network/api_constants.dart';
import 'package:gitty/core/error/exceptions.dart';
import 'package:gitty/core/error/failures.dart';

/// Maps infrastructure-level exceptions to domain [Failure]s.
abstract final class ErrorHandler {
  static Failure handle(Object error, [StackTrace? stackTrace]) {
    return switch (error) {
      // ── Dio HTTP errors ─────────────────────────────────────────────────
      DioException(:final type, :final response) => _handleDio(type, response),

      // ── Network exceptions ──────────────────────────────────────────────
      NoInternetException() => const NoInternetFailure(),
      TimeoutException(:final operation, :final timeoutSeconds) =>
          TimeoutFailure(operation: operation, timeoutSeconds: timeoutSeconds),
      UnauthorizedException(:final message) =>
          UnauthorizedFailure(message: message),
      ForbiddenException(:final message, :final requiredScope) =>
          ForbiddenFailure(message: message, requiredScope: requiredScope),
      TokenMissingException() => const TokenMissingFailure(),
      RateLimitException(:final remaining, :final resetAt) =>
          RateLimitFailure(remaining: remaining, resetAt: resetAt),

      // ── Git plumbing exceptions ─────────────────────────────────────────
      GitBlobException(:final filePath, :final message) =>
          BlobCreationFailure(filePath: filePath, reason: message),
      GitTreeException(:final message, :final failedPaths) =>
          TreeCreationFailure(reason: message, failedPaths: failedPaths),
      GitCommitException(:final message, :final parentSha) =>
          CommitCreationFailure(reason: message, parentSha: parentSha),
      GitRefException(:final branch, :final message, :final requiresForce) =>
          RefUpdateFailure(branch: branch, reason: message, requiresForce: requiresForce),
      RepoNotFoundException(:final owner, :final repoName) =>
          RepoNotFoundFailure(owner: owner, repoName: repoName),

      // ── Storage exceptions ──────────────────────────────────────────────
      EncryptionException(:final message) =>
          EncryptionFailure(reason: message),
      StorageException(:final message) =>
          StorageFailure(operation: 'unknown', reason: message),

      // ── File system exceptions ──────────────────────────────────────────
      FileNotFoundException(:final path) => FileNotFoundFailure(path: path),
      FileTooLargeException(:final path, :final sizeBytes, :final maxBytes) =>
          FileTooLargeFailure(path: path, sizeBytes: sizeBytes, maxBytes: maxBytes),

      // ── Firebase / Kill switch ──────────────────────────────────────────
      AppDisabledException(:final message, :final updateUrl) =>
          AppDisabledFailure(reason: message, updateUrl: updateUrl),

      // ── Fallthrough ─────────────────────────────────────────────────────
      _ => UnknownFailure(message: error.toString(), error: error),
    };
  }

  // ── Dio mapping ───────────────────────────────────────────────────────────

  static Failure _handleDio(DioExceptionType type, Response? response) {
    if (response != null) return _handleHttpStatus(response);
    return switch (type) {
      DioExceptionType.connectionTimeout =>
          const TimeoutFailure(operation: 'connect', timeoutSeconds: 15),
      DioExceptionType.receiveTimeout =>
          const TimeoutFailure(operation: 'receive', timeoutSeconds: 30),
      DioExceptionType.sendTimeout =>
          const TimeoutFailure(operation: 'send', timeoutSeconds: 60),
      DioExceptionType.connectionError => const NoInternetFailure(),
      _ => const NoInternetFailure(),
    };
  }

  static Failure _handleHttpStatus(Response<dynamic> response) {
    final status = response.statusCode ?? 0;
    final message = _extractMessage(response) ?? 'Unknown error';

    return switch (status) {
      ApiConstants.statusUnauthorized =>
          UnauthorizedFailure(message: message),
      ApiConstants.statusForbidden =>
          ForbiddenFailure(message: message, requiredScope: _extractScope(response)),
      ApiConstants.statusNotFound =>
          const ServerFailure(statusCode: 404, message: 'Resource not found'),
      ApiConstants.statusUnprocessable =>
          ServerFailure(
            statusCode: 422,
            message: message,
            githubDocUrl: _extractDocUrl(response),
          ),
      ApiConstants.statusRateLimit =>
          RateLimitFailure(remaining: 0, resetAt: _extractRateLimitReset(response)),
      _ when status >= ApiConstants.statusServerError =>
          ServerFailure(statusCode: status, message: message),
      _ => ServerFailure(statusCode: status, message: message),
    };
  }

  // ── Response parsing helpers ──────────────────────────────────────────────

  static String? _extractMessage(Response<dynamic> response) {
    try {
      final data = response.data as Map<String, dynamic>?;
      final msg = data?['message'] as String?;
      final errors = data?['errors'] as List<dynamic>?;
      if (errors != null && errors.isNotEmpty) {
        final detail = errors
            .whereType<Map<String, dynamic>>()
            .map((e) => e['message']?.toString() ?? e['code']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .join(', ');
        if (detail.isNotEmpty) return '$msg: $detail';
      }
      return msg;
    } on Exception {
      return null;
    }
  }

  static String? _extractScope(Response<dynamic> response) {
    try {
      final data = response.data as Map<String, dynamic>?;
      return data?['documentation_url']?.toString();
    } on Exception {
      return null;
    }
  }

  static String? _extractDocUrl(Response<dynamic> response) {
    try {
      final data = response.data as Map<String, dynamic>?;
      return data?['documentation_url']?.toString();
    } on Exception {
      return null;
    }
  }

  static DateTime _extractRateLimitReset(Response<dynamic> response) {
    final reset = response.headers.value('x-ratelimit-reset');
    if (reset != null) {
      final epoch = int.tryParse(reset);
      if (epoch != null) return DateTime.fromMillisecondsSinceEpoch(epoch * 1000);
    }
    return DateTime.now().add(const Duration(minutes: 1));
  }
}

// ── Either convenience wrapper ─────────────────────────────────────────────────

extension EitherX<L, R> on Either<L, R> {
  R getOrThrow() => fold((l) => throw Exception(l), (r) => r);
  Either<L, T> flatMap<T>(Either<L, T> Function(R r) f) => fold(Left.new, f);
}

Future<Either<Failure, T>> guardFuture<T>(Future<T> Function() call) async {
  try {
    return Right(await call());
  } on Exception catch (e, st) {
    return Left(ErrorHandler.handle(e, st));
  }
}
