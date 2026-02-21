
/// Sealed Failure hierarchy — single source of truth for all domain errors.
sealed class Failure {
  const Failure();

  // ── Factories ──────────────────────────────────────────────────────────────
  const factory Failure.noInternet() = NoInternetFailure;
  const factory Failure.timeout({
    String operation,
    int timeoutSeconds,
  }) = TimeoutFailure;
  const factory Failure.server({
    required int statusCode,
    required String message,
    String? githubDocUrl,
  }) = ServerFailure;
  const factory Failure.unauthorized({String message}) = UnauthorizedFailure;
  const factory Failure.forbidden({
    String message,
    String? requiredScope,
  }) = ForbiddenFailure;
  const factory Failure.tokenMissing() = TokenMissingFailure;
  const factory Failure.rateLimit({
    int remaining,
    DateTime? resetAt,
  }) = RateLimitFailure;
  const factory Failure.blobCreation({
    required String filePath,
    required String reason,
  }) = BlobCreationFailure;
  const factory Failure.treeCreation({
    required String reason,
    List<String>? failedPaths,
  }) = TreeCreationFailure;
  const factory Failure.commitCreation({
    required String reason,
    String? parentSha,
  }) = CommitCreationFailure;
  const factory Failure.refUpdate({
    required String branch,
    required String reason,
    bool requiresForce,
  }) = RefUpdateFailure;
  const factory Failure.repoNotFound({
    String? fullName,
    String? owner,
    String? repoName,
  }) = RepoNotFoundFailure;
  const factory Failure.branchNotFound({required String branch}) = BranchNotFoundFailure;
  const factory Failure.storage({
    String operation,
    required String reason,
  }) = StorageFailure;
  const factory Failure.encryption({required String reason}) = EncryptionFailure;
  const factory Failure.validation({required String message}) = ValidationFailure;
  const factory Failure.fileNotFound({required String path}) = FileNotFoundFailure;
  const factory Failure.fileTooLarge({
    required String path,
    int sizeBytes,
    required int maxBytes,
  }) = FileTooLargeFailure;
  const factory Failure.appDisabled({
    String? message,
    String? reason,
    String? updateUrl,
  }) = AppDisabledFailure;
  const factory Failure.unknown({
    required String message,
    Object? error,
  }) = UnknownFailure;

  // ── User-facing message ────────────────────────────────────────────────────
  String get userMessage => switch (this) {
    NoInternetFailure()    => 'No internet connection.',
    TimeoutFailure(:final operation, :final timeoutSeconds) =>
        timeoutSeconds > 0
            ? 'Request timed out after ${timeoutSeconds}s ($operation).'
            : 'Request timed out. Please try again.',
    ServerFailure(:final message) =>
        message.isNotEmpty ? message : 'Server error.',
    UnauthorizedFailure(:final message) =>
        message.isNotEmpty ? message : 'Invalid or expired token.',
    ForbiddenFailure(:final message) =>
        message.isNotEmpty ? message : 'Access denied.',
    TokenMissingFailure() => 'No GitHub token found. Please sign in.',
    RateLimitFailure(:final resetAt) => resetAt != null
        ? 'Rate limit exceeded. Resets at ${resetAt.toLocal()}.'
        : 'GitHub rate limit exceeded.',
    BlobCreationFailure(:final filePath, :final reason) =>
        'Failed to upload "$filePath": $reason',
    TreeCreationFailure(:final reason) => 'Failed to build tree: $reason',
    CommitCreationFailure(:final reason) => 'Failed to create commit: $reason',
    RefUpdateFailure(:final branch, :final reason) =>
        'Failed to update branch "$branch": $reason',
    RepoNotFoundFailure(:final fullName, :final owner, :final repoName) =>
        fullName != null
            ? 'Repository "$fullName" not found.'
            : 'Repository "${owner ?? ''}/${repoName ?? ''}" not found.',
    BranchNotFoundFailure(:final branch) => 'Branch "$branch" not found.',
    StorageFailure(:final reason)     => 'Storage error: $reason',
    EncryptionFailure(:final reason)  => 'Encryption error: $reason',
    ValidationFailure(:final message) => message,
    FileNotFoundFailure(:final path)  => 'File not found: $path',
    FileTooLargeFailure(:final path, :final maxBytes) =>
        'File "$path" exceeds limit of ${maxBytes ~/ (1024 * 1024)}MB.',
    AppDisabledFailure(:final message, :final reason) =>
        message ?? reason ?? 'App is temporarily unavailable.',
    UnknownFailure(:final message) =>
        message.isNotEmpty ? message : 'An unexpected error occurred.',
  };

  bool get isRecoverable => switch (this) {
    NoInternetFailure() || TimeoutFailure() || RateLimitFailure() => true,
    ServerFailure(:final statusCode) => statusCode >= 500,
    _ => false,
  };
}

// ── Concrete failure classes ───────────────────────────────────────────────────

final class NoInternetFailure extends Failure {
  const NoInternetFailure();
}

final class TimeoutFailure extends Failure {
  const TimeoutFailure({this.operation = 'request', this.timeoutSeconds = 0});
  final String operation;
  final int timeoutSeconds;
}

final class ServerFailure extends Failure {
  const ServerFailure({
    required this.statusCode,
    required this.message,
    this.githubDocUrl,
  });
  final int statusCode;
  final String message;
  final String? githubDocUrl;
}

final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({this.message = ''});
  final String message;
}

final class ForbiddenFailure extends Failure {
  const ForbiddenFailure({this.message = '', this.requiredScope});
  final String message;
  final String? requiredScope;
}

final class TokenMissingFailure extends Failure {
  const TokenMissingFailure();
}

final class RateLimitFailure extends Failure {
  const RateLimitFailure({this.remaining = 0, this.resetAt});
  final int remaining;
  final DateTime? resetAt;
}

final class BlobCreationFailure extends Failure {
  const BlobCreationFailure({required this.filePath, required this.reason});
  final String filePath;
  final String reason;
}

final class TreeCreationFailure extends Failure {
  const TreeCreationFailure({required this.reason, this.failedPaths});
  final String reason;
  final List<String>? failedPaths;
}

final class CommitCreationFailure extends Failure {
  const CommitCreationFailure({required this.reason, this.parentSha});
  final String reason;
  final String? parentSha;
}

final class RefUpdateFailure extends Failure {
  const RefUpdateFailure({
    required this.branch,
    required this.reason,
    this.requiresForce = false,
  });
  final String branch;
  final String reason;
  final bool requiresForce;
}

final class RepoNotFoundFailure extends Failure {
  const RepoNotFoundFailure({this.fullName, this.owner, this.repoName});
  final String? fullName;
  final String? owner;
  final String? repoName;
}

final class BranchNotFoundFailure extends Failure {
  const BranchNotFoundFailure({required this.branch});
  final String branch;
}

final class StorageFailure extends Failure {
  const StorageFailure({this.operation = 'unknown', required this.reason});
  final String operation;
  final String reason;
}

final class EncryptionFailure extends Failure {
  const EncryptionFailure({required this.reason});
  final String reason;
}

final class ValidationFailure extends Failure {
  const ValidationFailure({required this.message});
  final String message;
}

final class FileNotFoundFailure extends Failure {
  const FileNotFoundFailure({required this.path});
  final String path;
}

final class FileTooLargeFailure extends Failure {
  const FileTooLargeFailure({
    required this.path,
    this.sizeBytes = 0,
    required this.maxBytes,
  });
  final String path;
  final int sizeBytes;
  final int maxBytes;
}

final class AppDisabledFailure extends Failure {
  const AppDisabledFailure({this.message, this.reason, this.updateUrl});
  final String? message;
  final String? reason;
  final String? updateUrl;
}

final class UnknownFailure extends Failure {
  const UnknownFailure({required this.message, this.error});
  final String message;
  final Object? error;
}
