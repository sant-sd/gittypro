/// Base class for all infrastructure-level exceptions in Gitty.
/// These are thrown in the Data layer and mapped to [Failure]s in repositories.
sealed class AppException implements Exception {
  const AppException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() =>
      '$runtimeType: $message${cause != null ? ' (caused by: $cause)' : ''}';
}

// ── Network Exceptions ─────────────────────────────────────────────────────────

final class NetworkException extends AppException {
  const NetworkException(super.message, {super.cause});
}

final class NoInternetException extends AppException {
  const NoInternetException() : super('No internet connection available');
}

final class TimeoutException extends AppException {
  const TimeoutException(
      {required this.operation, required this.timeoutSeconds})
      : super('Request timed out after ${timeoutSeconds}s during "$operation"');

  final String operation;
  final int timeoutSeconds;
}

final class ServerException extends AppException {
  const ServerException({
    required this.statusCode,
    required String message,
    this.githubDocUrl,
  }) : super(message);

  final int statusCode;
  final String? githubDocUrl;
}

// ── Auth Exceptions ────────────────────────────────────────────────────────────

final class UnauthorizedException extends AppException {
  const UnauthorizedException([
    super.message = 'GitHub token is invalid or expired',
  ]);
}

final class ForbiddenException extends AppException {
  const ForbiddenException(super.message, {this.requiredScope});
  final String? requiredScope;
}

final class TokenMissingException extends AppException {
  const TokenMissingException()
      : super('No GitHub token found. Please authenticate.');
}

// ── Rate Limit Exception ───────────────────────────────────────────────────────

final class RateLimitException extends AppException {
  const RateLimitException({
    required this.remaining,
    required this.resetAt,
  }) : super('GitHub API rate limit exceeded');

  final int remaining;
  final DateTime resetAt;
}

// ── Git Plumbing Exceptions ────────────────────────────────────────────────────

final class GitBlobException extends AppException {
  const GitBlobException({required this.filePath, required String reason})
      : super(reason);

  final String filePath;
}

final class GitTreeException extends AppException {
  const GitTreeException({required String reason, this.failedPaths})
      : super(reason);

  final List<String>? failedPaths;
}

final class GitCommitException extends AppException {
  const GitCommitException({required String reason, this.parentSha})
      : super(reason);

  final String? parentSha;
}

final class GitRefException extends AppException {
  const GitRefException({
    required this.branch,
    required String reason,
    this.requiresForce = false,
  }) : super(reason);

  final String branch;
  final bool requiresForce;
}

final class RepoNotFoundException extends AppException {
  const RepoNotFoundException({required this.owner, required this.repoName})
      : super('Repository "$owner/$repoName" not found');

  final String owner;
  final String repoName;
}

// ── Storage Exceptions ─────────────────────────────────────────────────────────

final class StorageException extends AppException {
  const StorageException({required String operation, required String reason})
      : super('Storage "$operation" failed: $reason');
}

final class EncryptionException extends AppException {
  const EncryptionException(super.message);
}

// ── File System Exceptions ─────────────────────────────────────────────────────

final class FileNotFoundException extends AppException {
  const FileNotFoundException(this.path) : super('File not found: $path');
  final String path;
}

final class FileTooLargeException extends AppException {
  const FileTooLargeException({
    required this.path,
    required this.sizeBytes,
    required this.maxBytes,
  }) : super(
          '$path (${sizeBytes ~/ 1024}KB) exceeds limit of ${maxBytes ~/ 1024 ~/ 1024}MB',
        );

  final String path;
  final int sizeBytes;
  final int maxBytes;
}

// ── Firebase / Kill Switch ─────────────────────────────────────────────────────

final class AppDisabledException extends AppException {
  const AppDisabledException({required String reason, this.updateUrl})
      : super(reason);

  final String? updateUrl;
}
