import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import 'package:gitty/core/error/error_handler.dart';
import 'package:gitty/core/error/failures.dart';
import 'package:gitty/core/network/api_constants.dart';
import 'package:gitty/core/network/dio_client.dart';
import 'package:gitty/core/security/pat_storage_service.dart';
import 'package:gitty/features/auth/domain/entities/user_entity.dart';
import 'package:gitty/features/auth/domain/repositories/auth_repository.dart';
import 'package:gitty/features/auth/data/models/user_model.dart';


class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required Dio dio,
    required PatStorageService patStorageService,
  })  : _dio = dio,
        _patStorage = patStorageService;

  final Dio _dio;
  final PatStorageService _patStorage;

  // In-memory user cache
  UserEntity? _cachedUser;

  // ── Sign In ─────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, UserEntity>> signIn(String pat) async {
    return guardFuture(() async {
      // 1. Validate PAT format before hitting the network
      final validation = PatStorageService.validate(pat);
      if (!validation.isValid) {
        throw Exception(validation.message);
      }

      // 2. Temporarily set the PAT as a header for this one request
      final response = await _dio.get<Map<String, dynamic>>(
        ApiConstants.currentUser,
        options: Options(
          headers: {
            'Authorization': 'Bearer $pat',
            'Accept': ApiConstants.acceptHeader,
            'X-GitHub-Api-Version': ApiConstants.apiVersionHeader,
          },
        ),
      );

      if (response.statusCode != ApiConstants.statusOk) {
        throw Exception('Unexpected status: ${response.statusCode}');
      }

      // 3. Parse scopes from response header
      final scopesHeader = response.headers.value('x-oauth-scopes') ?? '';
      final scopes = scopesHeader
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      // 4. Map response to entity
      final user = UserModel.fromJson(response.data!).toEntity(scopes: scopes);

      // 5. Warn if token lacks necessary scopes
      if (!user.hasGitScopes) {
        throw Exception(
          'Token is missing required scope. '
          'Please generate a token with "repo" or "public_repo" scope.',
        );
      }

      // 6. Persist PAT securely only after successful verification
      await _patStorage.writePat(pat);
      _cachedUser = user;

      return user;
    });
  }

  // ── Sign Out ────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, Unit>> signOut() async {
    return guardFuture(() async {
      _cachedUser = null;
      await _patStorage.deletePat();
      return unit;
    });
  }

  // ── Get Current User ────────────────────────────────────────────────────

  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() async {
    // Return cache if available
    if (_cachedUser != null) return Right(_cachedUser!);

    return guardFuture(() async {
      final hasPat = await _patStorage.hasPat();
      if (!hasPat) throw Exception('No token stored');

      final response = await _dio.get<Map<String, dynamic>>(
        ApiConstants.currentUser,
      );

      final scopesHeader = response.headers.value('x-oauth-scopes') ?? '';
      final scopes = scopesHeader
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final user = UserModel.fromJson(response.data!).toEntity(scopes: scopes);
      _cachedUser = user;
      return user;
    });
  }

  // ── Is Authenticated ────────────────────────────────────────────────────

  @override
  Future<bool> isAuthenticated() => _patStorage.hasPat();
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepositoryImpl(
      dio: ref.watch(dioProvider),
      patStorageService: ref.watch(patStorageServiceProvider),
    ));
