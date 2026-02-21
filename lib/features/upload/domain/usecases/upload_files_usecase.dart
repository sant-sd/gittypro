import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'package:gitty/core/error/failures.dart';
import 'package:gitty/features/upload/domain/entities/git_entities.dart';
import 'package:gitty/features/upload/domain/repositories/upload_repository.dart';
import 'package:gitty/features/upload/data/repositories/upload_repository_impl.dart';

class UploadFilesParams {
  const UploadFilesParams({
    required this.owner,
    required this.repoName,
    required this.branch,
    required this.commitMessage,
    required this.filePaths,
    required this.repoBasePath,
    this.authorName,
    this.authorEmail,
  });
  final String owner;
  final String repoName;
  final String branch;
  final String commitMessage;
  final List<String> filePaths;
  final String repoBasePath;
  final String? authorName;
  final String? authorEmail;
}

class UploadFilesUseCase {
  const UploadFilesUseCase({required UploadRepository repository})
      : _repository = repository;
  final UploadRepository _repository;

  Stream<UploadJobEntity> call(UploadFilesParams params) async* {
    final jobId = const Uuid().v4();
    final startedAt = DateTime.now();

    final fileEntries = params.filePaths.map((localPath) {
      final file = File(localPath);
      return UploadFileEntry(
        localPath: localPath,
        repoPath: _buildRepoPath(localPath, params.repoBasePath),
        sizeBytes: file.existsSync() ? file.lengthSync() : 0,
        mimeType: lookupMimeType(localPath) ?? 'application/octet-stream',
      );
    }).toList();

    var job = UploadJobEntity(
      id: jobId,
      owner: params.owner,
      repoName: params.repoName,
      branch: params.branch,
      commitMessage: params.commitMessage,
      files: fileEntries,
      phase: UploadPhase.idle,
      startedAt: startedAt,
    );
    yield job;

    // Step 0: Fetch HEAD
    final headResult = await _repository.getHeadCommitSha(
        owner: params.owner, repoName: params.repoName, branch: params.branch);
    if (headResult.isLeft()) {
      yield* _fail(job,
          headResult.swap().getOrElse(() => const UnknownFailure(message: '')));
      return;
    }
    final headSha = headResult.getOrElse(() => '');

    final treeShaResult = await _repository.getCommitTreeSha(
        owner: params.owner, repoName: params.repoName, commitSha: headSha);
    if (treeShaResult.isLeft()) {
      yield* _fail(
          job,
          treeShaResult
              .swap()
              .getOrElse(() => const UnknownFailure(message: '')));
      return;
    }
    final baseTreeSha = treeShaResult.getOrElse(() => '');

    // Phase 1: Blobs
    job = job.copyWith(phase: UploadPhase.creatingBlobs);
    yield job;

    final blobEntries = <GitTreeEntryEntity>[];
    final updatedFiles = List<UploadFileEntry>.from(job.files);

    for (var i = 0; i < updatedFiles.length; i++) {
      final entry = updatedFiles[i];
      updatedFiles[i] = entry.copyWith(status: UploadFileStatus.encoding);
      job = job.copyWith(files: List.unmodifiable(updatedFiles));
      yield job;

      final file = File(entry.localPath);
      if (!file.existsSync()) {
        yield* _fail(job, FileNotFoundFailure(path: entry.localPath));
        return;
      }
      final bytes = await file.readAsBytes();

      updatedFiles[i] = entry.copyWith(status: UploadFileStatus.blobCreating);
      job = job.copyWith(files: List.unmodifiable(updatedFiles));
      yield job;

      final blobResult = await _repository.createBlob(
          owner: params.owner,
          repoName: params.repoName,
          fileBytes: bytes,
          filePath: entry.repoPath);
      if (blobResult.isLeft()) {
        final failure = blobResult.swap().getOrElse(() =>
            BlobCreationFailure(filePath: entry.repoPath, reason: 'Unknown'));
        updatedFiles[i] = entry.copyWith(
            status: UploadFileStatus.failed, errorMessage: failure.userMessage);
        job = job.copyWith(files: List.unmodifiable(updatedFiles));
        yield* _fail(job, failure);
        return;
      }
      final blob = blobResult.getOrElse(() => throw StateError('unreachable'));
      updatedFiles[i] = entry.copyWith(
          status: UploadFileStatus.blobCreated, blobSha: blob.sha);
      blobEntries.add(GitTreeEntryEntity(
          path: entry.repoPath,
          mode: GitTreeEntryEntity.modeFile,
          type: 'blob',
          sha: blob.sha));
      job = job.copyWith(
          files: List.unmodifiable(updatedFiles), completedBlobs: i + 1);
      yield job;
    }

    // Phase 2: Tree
    job = job.copyWith(phase: UploadPhase.buildingTree);
    yield job;
    final treeResult = await _repository.createTree(
        owner: params.owner,
        repoName: params.repoName,
        baseTreeSha: baseTreeSha,
        entries: blobEntries);
    if (treeResult.isLeft()) {
      yield* _fail(job,
          treeResult.swap().getOrElse(() => const UnknownFailure(message: '')));
      return;
    }
    final tree = treeResult.getOrElse(() => throw StateError('unreachable'));
    job = job.copyWith(treeSha: tree.sha);
    yield job;

    // Phase 3: Commit
    job = job.copyWith(phase: UploadPhase.creatingCommit);
    yield job;
    final commitResult = await _repository.createCommit(
        owner: params.owner,
        repoName: params.repoName,
        message: params.commitMessage,
        treeSha: tree.sha,
        parentSha: headSha,
        authorName: params.authorName,
        authorEmail: params.authorEmail);
    if (commitResult.isLeft()) {
      yield* _fail(
          job,
          commitResult
              .swap()
              .getOrElse(() => const UnknownFailure(message: '')));
      return;
    }
    final commit =
        commitResult.getOrElse(() => throw StateError('unreachable'));
    job = job.copyWith(commitSha: commit.sha);
    yield job;

    // Phase 4: Ref
    job = job.copyWith(phase: UploadPhase.updatingRef);
    yield job;
    final refResult = await _repository.updateRef(
        owner: params.owner,
        repoName: params.repoName,
        branch: params.branch,
        commitSha: commit.sha);
    if (refResult.isLeft()) {
      yield* _fail(job,
          refResult.swap().getOrElse(() => const UnknownFailure(message: '')));
      return;
    }

    job = job.copyWith(phase: UploadPhase.done, completedAt: DateTime.now());
    yield job;
  }

  Stream<UploadJobEntity> _fail(UploadJobEntity job, Failure failure) async* {
    yield job.copyWith(
        phase: UploadPhase.failed,
        errorMessage: failure.userMessage,
        completedAt: DateTime.now());
  }

  String _buildRepoPath(String localPath, String basePath) {
    final fileName = p.basename(localPath);
    if (basePath.isEmpty) return fileName;
    final base = basePath.endsWith('/') ? basePath : '$basePath/';
    return '$base$fileName';
  }
}

final uploadFilesUseCaseProvider = Provider<UploadFilesUseCase>((ref) =>
    UploadFilesUseCase(repository: ref.watch(uploadRepositoryProvider)));
