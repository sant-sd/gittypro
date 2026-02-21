import 'package:dartz/dartz.dart';

import 'package:gitty/core/error/failures.dart';
import 'package:gitty/features/auth/domain/entities/user_entity.dart';

/// Contract for authentication operations.
/// Implemented in the Data layer; consumed by Use Cases.
abstract interface class AuthRepository {
  /// Validates the PAT and retrieves the authenticated user.
  /// Persists the PAT securely on success.
  Future<Either<Failure, UserEntity>> signIn(String pat);

  /// Clears the stored PAT and user session.
  Future<Either<Failure, Unit>> signOut();

  /// Returns the currently authenticated user, or Left if unauthenticated.
  Future<Either<Failure, UserEntity>> getCurrentUser();

  /// Returns true if a valid PAT is stored locally.
  Future<bool> isAuthenticated();
}
