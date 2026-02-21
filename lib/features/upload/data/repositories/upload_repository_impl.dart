import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:gitty/core/error/error_handler.dart';
import 'package:gitty/core/error/failures.dart';
import 'package:gitty/core/network/api_constants.dart';
import 'package:gitty/core/network/dio_client.dart';
import 'package:gitty/features/upload/domain/entities/git_entities.dart';
import 'package:gitty/features/upload/domain/repositories/upload_repository.dart';
import 'package:gitty/features/upload/data/models/git_object_models.dart';


class UploadRepositoryImpl implements UploadRepository {
  UploadRepositoryImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  // ── Phase 1: Blob Creation ─────────────────────────────────────────────────

  @override
  Future<Either<Failure, GitBlobEntity>> createBlob({
    required String owner,
    required String repoName,
    required List<int> fileBytes,
    required String filePath,
  }) =>
      guardFuture(() async {
        // GitHub requires files encoded as Base64 strings
        final base64Content = base64.encode(fileBytes);

        final request = CreateBlobRequest(content: base64Content);

        final response = await _dio.post<Map<String, dynamic>>(
          '${ApiConstants.repo(owner, repoName)}/${ApiConstants.blobs}',
          data: request.toJson(),
        );

        if (response.statusCode != ApiConstants.statusCreated) {
          throw Exception(
              'Blob creation failed with status ${response.statusCode}');
        }

        return BlobResponse.fromJson(response.data!).toEntity(filePath);
      });

  // ── Phase 2: Tree Building ─────────────────────────────────────────────────

  @override
  Future<Either<Failure, GitTreeEntity>> createTree({
    required String owner,
    required String repoName,
    required String baseTreeSha,
    required List<GitTreeEntryEntity> entries,
  }) =>
      guardFuture(() async {
        final request = CreateTreeRequest(
          baseTree: baseTreeSha,
          tree: entries
              .map((e) => TreeEntryRequest(
                    path: e.path,
                    mode: e.mode,
                    type: e.type,
                    sha: e.sha,
                  ))
              .toList(),
        );

        final response = await _dio.post<Map<String, dynamic>>(
          '${ApiConstants.repo(owner, repoName)}/${ApiConstants.trees}',
          data: request.toJson(),
        );

        if (response.statusCode != ApiConstants.statusCreated) {
          throw Exception(
              'Tree creation failed with status ${response.statusCode}');
        }

        return TreeResponse.fromJson(response.data!).toEntity();
      });

  // ── Phase 3: Commit Creation ───────────────────────────────────────────────

  @override
  Future<Either<Failure, GitCommitEntity>> createCommit({
    required String owner,
    required String repoName,
    required String message,
    required String treeSha,
    required String parentSha,
    String? authorName,
    String? authorEmail,
  }) =>
      guardFuture(() async {
        final now = DateTime.now().toUtc().toIso8601String();

        final request = CreateCommitRequest(
          message: message,
          tree: treeSha,
          parents: [parentSha],
          author: (authorName != null && authorEmail != null)
              ? CommitAuthorRequest(
                  name: authorName,
                  email: authorEmail,
                  date: now,
                )
              : null,
        );

        final response = await _dio.post<Map<String, dynamic>>(
          '${ApiConstants.repo(owner, repoName)}/${ApiConstants.commits}',
          data: request.toJson(),
        );

        if (response.statusCode != ApiConstants.statusCreated) {
          throw Exception(
              'Commit creation failed with status ${response.statusCode}');
        }

        return CommitResponse.fromJson(response.data!).toEntity();
      });

  // ── Phase 4: Ref Update ────────────────────────────────────────────────────

  @override
  Future<Either<Failure, GitRefEntity>> updateRef({
    required String owner,
    required String repoName,
    required String branch,
    required String commitSha,
    bool force = false,
  }) =>
      guardFuture(() async {
        final request = UpdateRefRequest(sha: commitSha, force: force);

        final response = await _dio.patch<Map<String, dynamic>>(
          '${ApiConstants.repo(owner, repoName)}/${ApiConstants.refs(branch)}',
          data: request.toJson(),
        );

        if (response.statusCode != ApiConstants.statusOk) {
          throw Exception(
              'Ref update failed with status ${response.statusCode}');
        }

        return RefResponse.fromJson(response.data!).toEntity();
      });

  // ── Helpers ────────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, String>> getHeadCommitSha({
    required String owner,
    required String repoName,
    required String branch,
  }) =>
      guardFuture(() async {
        // GET /repos/{owner}/{repo}/git/refs/heads/{branch}
        final response = await _dio.get<Map<String, dynamic>>(
          '${ApiConstants.repo(owner, repoName)}/${ApiConstants.refs(branch)}',
        );

        final ref = RefResponse.fromJson(response.data!);
        return ref.object.sha;
      });

  @override
  Future<Either<Failure, String>> getCommitTreeSha({
    required String owner,
    required String repoName,
    required String commitSha,
  }) =>
      guardFuture(() async {
        // GET /repos/{owner}/{repo}/git/commits/{commit_sha}
        final response = await _dio.get<Map<String, dynamic>>(
          '${ApiConstants.repo(owner, repoName)}/${ApiConstants.commits}/$commitSha',
        );

        final detail = CommitDetailResponse.fromJson(response.data!);
        return detail.commit.tree.sha;
      });
}

final uploadRepositoryProvider = Provider<UploadRepository>((ref) =>
    UploadRepositoryImpl(dio: ref.watch(dioProvider)));
