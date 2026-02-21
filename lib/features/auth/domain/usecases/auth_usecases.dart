import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gitty/core/error/failures.dart';
import 'package:gitty/features/auth/domain/entities/user_entity.dart';
import 'package:gitty/features/auth/domain/repositories/auth_repository.dart';
import 'package:gitty/features/auth/data/repositories/auth_repository_impl.dart';


// ── Sign In ───────────────────────────────────────────────────────────────────

class SignInUseCase {
  const SignInUseCase({required AuthRepository repository})
      : _repository = repository;

  final AuthRepository _repository;

  Future<Either<Failure, UserEntity>> call(String pat) =>
      _repository.signIn(pat.trim());
}

final signInUseCaseProvider = Provider<SignInUseCase>((ref) =>
    SignInUseCase(repository: ref.watch(authRepositoryProvider)));

// ── Sign Out ──────────────────────────────────────────────────────────────────

class SignOutUseCase {
  const SignOutUseCase({required AuthRepository repository})
      : _repository = repository;

  final AuthRepository _repository;

  Future<Either<Failure, Unit>> call() => _repository.signOut();
}

final signOutUseCaseProvider = Provider<SignOutUseCase>((ref) =>
    SignOutUseCase(repository: ref.watch(authRepositoryProvider)));

// ── Get Current User ──────────────────────────────────────────────────────────

class GetCurrentUserUseCase {
  const GetCurrentUserUseCase({required AuthRepository repository})
      : _repository = repository;

  final AuthRepository _repository;

  Future<Either<Failure, UserEntity>> call() => _repository.getCurrentUser();
}

final getCurrentUserUseCaseProvider = Provider<GetCurrentUserUseCase>((ref) =>
    GetCurrentUserUseCase(repository: ref.watch(authRepositoryProvider)));
