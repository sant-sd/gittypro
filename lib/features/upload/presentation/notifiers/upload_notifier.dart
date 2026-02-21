import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gitty/core/error/failures.dart';
import 'package:gitty/features/upload/domain/entities/git_entities.dart';
import 'package:gitty/features/upload/domain/usecases/upload_files_usecase.dart';

// ── State ─────────────────────────────────────────────────────────────────────

sealed class UploadState {
  const UploadState();
}

final class UploadStateIdle extends UploadState {
  const UploadStateIdle();
}

final class UploadStateFilesSelected extends UploadState {
  const UploadStateFilesSelected({required this.filePaths});
  final List<String> filePaths;
}

final class UploadStateUploading extends UploadState {
  const UploadStateUploading({required this.job});
  final UploadJobEntity job;
}

final class UploadStateSuccess extends UploadState {
  const UploadStateSuccess(
      {required this.job, required this.commitSha, required this.commitUrl});
  final UploadJobEntity job;
  final String commitSha;
  final String commitUrl;
}

final class UploadStateFailure extends UploadState {
  const UploadStateFailure({required this.failure, required this.job});
  final Failure failure;
  final UploadJobEntity job;
}

extension UploadStateX on UploadState {
  T map<T>({
    required T Function(UploadStateIdle) idle,
    required T Function(UploadStateFilesSelected) filesSelected,
    required T Function(UploadStateUploading) uploading,
    required T Function(UploadStateSuccess) success,
    required T Function(UploadStateFailure) failure,
  }) =>
      switch (this) {
        UploadStateIdle s => idle(s),
        UploadStateFilesSelected s => filesSelected(s),
        UploadStateUploading s => uploading(s),
        UploadStateSuccess s => success(s),
        UploadStateFailure s => failure(s),
      };

  T maybeMap<T>({
    T Function(UploadStateFilesSelected)? filesSelected,
    T Function(UploadStateUploading)? uploading,
    required T Function() orElse,
  }) =>
      switch (this) {
        UploadStateFilesSelected s => filesSelected?.call(s) ?? orElse(),
        UploadStateUploading s => uploading?.call(s) ?? orElse(),
        _ => orElse(),
      };
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class UploadNotifier extends Notifier<UploadState> {
  StreamSubscription<UploadJobEntity>? _sub;

  @override
  UploadState build() {
    ref.onDispose(() => _sub?.cancel());
    return const UploadStateIdle();
  }

  void selectFiles(List<String> paths) {
    if (paths.isEmpty) return;
    state = UploadStateFilesSelected(filePaths: paths);
  }

  void clearSelection() => state = const UploadStateIdle();

  void removeFile(String path) {
    if (state is UploadStateFilesSelected) {
      final s = state as UploadStateFilesSelected;
      final updated = s.filePaths.where((p) => p != path).toList();
      state = updated.isEmpty
          ? const UploadStateIdle()
          : UploadStateFilesSelected(filePaths: updated);
    }
  }

  Future<void> startUpload({
    required String owner,
    required String repoName,
    required String branch,
    required String commitMessage,
    required String repoBasePath,
    String? authorName,
    String? authorEmail,
  }) async {
    final filePaths = state is UploadStateFilesSelected
        ? (state as UploadStateFilesSelected).filePaths
        : <String>[];
    if (filePaths.isEmpty) return;

    await _sub?.cancel();
    final params = UploadFilesParams(
      owner: owner,
      repoName: repoName,
      branch: branch,
      commitMessage: commitMessage.trim(),
      filePaths: filePaths,
      repoBasePath: repoBasePath,
      authorName: authorName,
      authorEmail: authorEmail,
    );

    _sub = ref.read(uploadFilesUseCaseProvider).call(params).listen(
      (job) {
        if (job.isComplete) {
          state = UploadStateSuccess(
            job: job,
            commitSha: job.commitSha ?? '',
            commitUrl:
                'https://github.com/$owner/$repoName/commit/${job.commitSha}',
          );
        } else if (job.hasFailed) {
          state = UploadStateFailure(
            failure:
                UnknownFailure(message: job.errorMessage ?? 'Upload failed'),
            job: job,
          );
        } else {
          state = UploadStateUploading(job: job);
        }
      },
      onError: (Object e) {
        final emptyJob = UploadJobEntity(
          id: '',
          owner: owner,
          repoName: repoName,
          branch: branch,
          commitMessage: commitMessage,
          files: const [],
          phase: UploadPhase.failed,
          startedAt: DateTime.now(),
        );
        state = UploadStateFailure(
            failure: UnknownFailure(message: e.toString()), job: emptyJob);
      },
    );
  }

  Future<void> cancelUpload() async {
    await _sub?.cancel();
    _sub = null;
    state = const UploadStateIdle();
  }

  void reset() {
    _sub?.cancel();
    _sub = null;
    state = const UploadStateIdle();
  }
}

final uploadNotifierProvider =
    NotifierProvider<UploadNotifier, UploadState>(UploadNotifier.new);
