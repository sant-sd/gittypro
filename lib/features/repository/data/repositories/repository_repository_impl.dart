import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import 'package:gitty/core/error/error_handler.dart';
import 'package:gitty/core/error/failures.dart';
import 'package:gitty/core/network/api_constants.dart';
import 'package:gitty/core/network/dio_client.dart';
import 'package:gitty/features/repository/domain/entities/repository_entity.dart';
import 'package:gitty/features/repository/domain/usecases/repository_usecases.dart';
import 'package:gitty/features/repository/data/models/repository_model.dart';


class RepositoryRepositoryImpl implements RepositoryRepository {
  RepositoryRepositoryImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<Either<Failure, List<RepositoryEntity>>> getUserRepositories({
    int page = 1,
    int perPage = 30,
    String sort = 'pushed',
  }) =>
      guardFuture(() async {
        final response = await _dio.get<List<dynamic>>(
          ApiConstants.userRepos,
          queryParameters: {
            'page': page,
            'per_page': perPage,
            'sort': sort,
            'affiliation': 'owner,collaborator,organization_member',
          },
        );

        return (response.data ?? [])
            .cast<Map<String, dynamic>>()
            .map(RepositoryModel.fromJson)
            .map((m) => m.toEntity())
            .toList();
      });

  @override
  Future<Either<Failure, RepositoryEntity>> getRepository(
    String owner,
    String repoName,
  ) =>
      guardFuture(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          ApiConstants.repo(owner, repoName),
        );
        return RepositoryModel.fromJson(response.data!).toEntity();
      });

  @override
  Future<Either<Failure, List<BranchEntity>>> getBranches(
    String owner,
    String repoName,
  ) =>
      guardFuture(() async {
        // Fetch repo to know the default branch name
        final repoResult = await getRepository(owner, repoName);
        final defaultBranch = repoResult.fold((_) => 'main', (r) => r.defaultBranch);

        final response = await _dio.get<List<dynamic>>(
          ApiConstants.repoBranches(owner, repoName),
          queryParameters: {'per_page': 100},
        );

        return (response.data ?? [])
            .cast<Map<String, dynamic>>()
            .map(BranchModel.fromJson)
            .map((m) => m.toEntity(isDefault: m.name == defaultBranch))
            .toList();
      });

  @override
  Future<Either<Failure, BranchEntity>> getBranch(
    String owner,
    String repoName,
    String branch,
  ) =>
      guardFuture(() async {
        final repoResult = await getRepository(owner, repoName);
        final defaultBranch = repoResult.fold((_) => 'main', (r) => r.defaultBranch);

        final response = await _dio.get<Map<String, dynamic>>(
          '${ApiConstants.repo(owner, repoName)}/branches/$branch',
        );

        return BranchModel.fromJson(response.data!)
            .toEntity(isDefault: branch == defaultBranch);
      });
}

final repositoryRepositoryProvider = Provider<RepositoryRepository>((ref) =>
    RepositoryRepositoryImpl(dio: ref.watch(dioProvider)));
