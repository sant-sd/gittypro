import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gitty/core/error/failures.dart';
import 'package:gitty/features/auth/domain/entities/user_entity.dart';
import 'package:gitty/features/auth/domain/usecases/auth_usecases.dart';

// ── State ─────────────────────────────────────────────────────────────────────

sealed class AuthState {
  const AuthState();
}

final class AuthStateInitial extends AuthState {
  const AuthStateInitial();
}

final class AuthStateLoading extends AuthState {
  const AuthStateLoading();
}

final class AuthStateAuthenticated extends AuthState {
  const AuthStateAuthenticated({required this.user});
  final UserEntity user;
}

final class AuthStateUnauthenticated extends AuthState {
  const AuthStateUnauthenticated();
}

final class AuthStateError extends AuthState {
  const AuthStateError({required this.failure});
  final Failure failure;
}

extension AuthStateX on AuthState {
  T maybeMap<T>({
    T Function(AuthStateInitial)? initial,
    T Function(AuthStateLoading)? loading,
    T Function(AuthStateAuthenticated)? authenticated,
    T Function(AuthStateUnauthenticated)? unauthenticated,
    T Function(AuthStateError)? error,
    required T Function() orElse,
  }) =>
      switch (this) {
        AuthStateInitial s => initial?.call(s) ?? orElse(),
        AuthStateLoading s => loading?.call(s) ?? orElse(),
        AuthStateAuthenticated s => authenticated?.call(s) ?? orElse(),
        AuthStateUnauthenticated s => unauthenticated?.call(s) ?? orElse(),
        AuthStateError s => error?.call(s) ?? orElse(),
      };
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    _restoreSession();
    return const AuthStateInitial();
  }

  Future<void> signIn(String pat) async {
    state = const AuthStateLoading();
    final result = await ref.read(signInUseCaseProvider).call(pat);
    state = result.fold(
      (f) => AuthStateError(failure: f),
      (u) => AuthStateAuthenticated(user: u),
    );
  }

  Future<void> signOut() async {
    state = const AuthStateLoading();
    final result = await ref.read(signOutUseCaseProvider).call();
    state = result.fold(
      (f) => AuthStateError(failure: f),
      (_) => const AuthStateUnauthenticated(),
    );
  }

  void clearError() => state = const AuthStateUnauthenticated();

  Future<void> _restoreSession() async {
    state = const AuthStateLoading();
    final result = await ref.read(getCurrentUserUseCaseProvider).call();
    state = result.fold(
      (_) => const AuthStateUnauthenticated(),
      (u) => AuthStateAuthenticated(user: u),
    );
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final authNotifierProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

final isAuthenticatedProvider = Provider<bool>(
    (ref) => ref.watch(authNotifierProvider) is AuthStateAuthenticated);

final currentUserProvider = Provider<UserEntity?>((ref) {
  final s = ref.watch(authNotifierProvider);
  return s is AuthStateAuthenticated ? s.user : null;
});
