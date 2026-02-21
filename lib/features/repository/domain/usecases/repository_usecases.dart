import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gitty/core/error/failures.dart';
import 'package:gitty/features/repository/domain/entities/repository_entity.dart';
import 'package:gitty/features/repository/data/repositories/repository_repository_impl.dart';


// ── Repository Contract ────────────────────────────────────────────────────────

abstract interface class RepositoryRepository {
  Future<Either<Failure, List<RepositoryEntity>>> getUserRepositories({
    int page = 1,
    int perPage = 30,
    String sort = 'pushed',
  });

  Future<Either<Failure, RepositoryEntity>> getRepository(
    String owner,
    String repoName,
  );

  Future<Either<Failure, List<BranchEntity>>> getBranches(
    String owner,
    String repoName,
  );

  Future<Either<Failure, BranchEntity>> getBranch(
    String owner,
    String repoName,
    String branch,
  );
}

// ── Use Cases ──────────────────────────────────────────────────────────────────

class GetUserRepositoriesUseCase {
  const GetUserRepositoriesUseCase(this._repository);
  final RepositoryRepository _repository;

  Future<Either<Failure, List<RepositoryEntity>>> call({
    int page = 1,
    int perPage = 30,
    String sort = 'pushed',
  }) =>
      _repository.getUserRepositories(
        page: page,
        perPage: perPage,
        sort: sort,
      );
}

class GetRepositoryUseCase {
  const GetRepositoryUseCase(this._repository);
  final RepositoryRepository _repository;

  Future<Either<Failure, RepositoryEntity>> call(
          String owner, String repoName) =>
      _repository.getRepository(owner, repoName);
}

class GetBranchesUseCase {
  const GetBranchesUseCase(this._repository);
  final RepositoryRepository _repository;

  Future<Either<Failure, List<BranchEntity>>> call(
          String owner, String repoName) =>
      _repository.getBranches(owner, repoName);
}

// ── Providers ──────────────────────────────────────────────────────────────────

final getUserRepositoriesUseCaseProvider = Provider<GetUserRepositoriesUseCase>((ref) =>
    GetUserRepositoriesUseCase(ref.watch(repositoryRepositoryProvider)));

final getRepositoryUseCaseProvider = Provider<GetRepositoryUseCase>((ref) =>
    GetRepositoryUseCase(ref.watch(repositoryRepositoryProvider)));

final getBranchesUseCaseProvider = Provider<GetBranchesUseCase>((ref) =>
    GetBranchesUseCase(ref.watch(repositoryRepositoryProvider)));
