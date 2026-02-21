import 'package:dartz/dartz.dart';

import 'package:gitty/core/error/failures.dart';
import 'package:gitty/features/upload/domain/entities/git_entities.dart';

/// Contract for the Git Plumbing Engine.
/// Each method maps to one phase of the Git object model.
abstract interface class UploadRepository {
  // ── Phase 1: Blobs ─────────────────────────────────────────────────────────

  /// Encodes [fileBytes] as Base64 and POSTs to GitHub's blob endpoint.
  /// Returns the created blob's SHA.
  Future<Either<Failure, GitBlobEntity>> createBlob({
    required String owner,
    required String repoName,
    required List<int> fileBytes,
    required String filePath,
  });

  // ── Phase 2: Tree ──────────────────────────────────────────────────────────

  /// Builds a new Git Tree from a list of blob SHAs and their paths.
  /// [baseTreeSha] — the existing tree SHA to build on top of (preserves
  /// files not included in this upload).
  Future<Either<Failure, GitTreeEntity>> createTree({
    required String owner,
    required String repoName,
    required String baseTreeSha,
    required List<GitTreeEntryEntity> entries,
  });

  // ── Phase 3: Commit ────────────────────────────────────────────────────────

  /// Creates a Git Commit object pointing to [treeSha].
  /// [parentSha] — the current HEAD commit (ensures linear history).
  Future<Either<Failure, GitCommitEntity>> createCommit({
    required String owner,
    required String repoName,
    required String message,
    required String treeSha,
    required String parentSha,
    String? authorName,
    String? authorEmail,
  });

  // ── Phase 4: Ref Update ────────────────────────────────────────────────────

  /// Moves the branch pointer to the new commit SHA.
  /// This is the final step that makes the commit visible in the repo.
  Future<Either<Failure, GitRefEntity>> updateRef({
    required String owner,
    required String repoName,
    required String branch,
    required String commitSha,
    bool force = false,
  });

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Fetches the current HEAD commit SHA for a branch.
  Future<Either<Failure, String>> getHeadCommitSha({
    required String owner,
    required String repoName,
    required String branch,
  });

  /// Fetches the tree SHA for a given commit.
  Future<Either<Failure, String>> getCommitTreeSha({
    required String owner,
    required String repoName,
    required String commitSha,
  });
}
