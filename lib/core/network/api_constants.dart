/// Central registry for all GitHub API constants used across the network layer.
/// All values are compile-time constants to enable tree-shaking in release builds.
abstract final class ApiConstants {
  // ── Base URLs ──────────────────────────────────────────────────────────────
  static const String githubBaseUrl = 'https://api.github.com';
  static const String githubRawUrl = 'https://raw.githubusercontent.com';

  // ── API Version ────────────────────────────────────────────────────────────
  static const String acceptHeader = 'application/vnd.github+json';
  static const String apiVersionHeader = '2022-11-28';

  // ── Timeouts ───────────────────────────────────────────────────────────────
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 60); // Large uploads

  // ── Retry Configuration ────────────────────────────────────────────────────
  static const int maxRetryAttempts = 3;
  static const Duration retryBaseDelay = Duration(seconds: 1);
  static const Duration retryMaxDelay = Duration(seconds: 30);

  // ── Git Plumbing Endpoints ─────────────────────────────────────────────────
  static const String blobs = 'git/blobs';
  static const String trees = 'git/trees';
  static const String commits = 'git/commits';

  static String refs(String branch) => 'git/refs/heads/$branch';
  static String refsHeads() => 'git/refs/heads';

  // ── Repo Endpoints ─────────────────────────────────────────────────────────
  static String repo(String owner, String repo) => 'repos/$owner/$repo';
  static String repoContents(String owner, String repo, String path) =>
      'repos/$owner/$repo/contents/$path';
  static String repoBranches(String owner, String repo) =>
      'repos/$owner/$repo/branches';
  static String repoCommit(String owner, String repo, String sha) =>
      'repos/$owner/$repo/commits/$sha';

  // ── User Endpoints ─────────────────────────────────────────────────────────
  static const String currentUser = 'user';
  static const String userRepos = 'user/repos';
  static String userOrgs(String username) => 'users/$username/orgs';

  // ── Rate Limiting ──────────────────────────────────────────────────────────
  static const String rateLimit = 'rate_limit';
  static const int rateLimitWarningThreshold = 100; // Warn when < 100 remaining

  // ── HTTP Status Codes ──────────────────────────────────────────────────────
  static const int statusOk = 200;
  static const int statusCreated = 201;
  static const int statusNoContent = 204;
  static const int statusUnauthorized = 401;
  static const int statusForbidden = 403;
  static const int statusNotFound = 404;
  static const int statusUnprocessable = 422;
  static const int statusRateLimit = 429;
  static const int statusServerError = 500;
}
