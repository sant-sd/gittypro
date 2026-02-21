import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gitty/core/firebase/kill_switch_service.dart';
import 'package:gitty/features/auth/presentation/notifiers/auth_notifier.dart';
import 'package:gitty/features/auth/presentation/screens/auth_screen.dart';
import 'package:gitty/features/console/presentation/screens/console_screen.dart';
import 'package:gitty/features/repository/domain/entities/repository_entity.dart';
import 'package:gitty/features/repository/presentation/screens/repository_list_screen.dart';
import 'package:gitty/features/upload/presentation/screens/upload_screen.dart';
import 'package:gitty/core/router/kill_switch_screen.dart';
import 'package:gitty/core/router/splash_screen.dart';

abstract final class AppRoutes {
  static const splash       = '/';
  static const auth         = '/auth';
  static const repositories = '/repositories';
  static const console      = '/console';
  static const killSwitch   = '/kill-switch';
  static String uploadPath(String owner, String repo) => '/repositories/$owner/$repo/upload';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState      = ref.watch(authNotifierProvider);
  final killSwitchAsync = ref.watch(killSwitchStateProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    redirect: (context, state) {
      final path = state.matchedLocation;

      // Kill switch
      final killSwitch = killSwitchAsync.value;
      if (killSwitch is KillSwitchTriggered && path != AppRoutes.killSwitch) {
        return AppRoutes.killSwitch;
      }

      final isAuthenticated = authState is AuthStateAuthenticated;
      final isLoading = authState is AuthStateInitial || authState is AuthStateLoading;

      if (isLoading && path != AppRoutes.splash) return AppRoutes.splash;
      if (!isLoading && path == AppRoutes.splash) {
        return isAuthenticated ? AppRoutes.repositories : AppRoutes.auth;
      }

      final isPublic = path == AppRoutes.auth || path == AppRoutes.killSwitch;
      if (!isAuthenticated && !isLoading && !isPublic) return AppRoutes.auth;
      if (isAuthenticated && path == AppRoutes.auth) return AppRoutes.repositories;

      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(
        path: AppRoutes.killSwitch,
        builder: (_, state) {
          final ks = (state.extra as KillSwitchTriggered?) ??
              const KillSwitchTriggered(message: 'App is temporarily disabled.');
          return KillSwitchScreen(state: ks);
        },
      ),
      GoRoute(
        path: AppRoutes.auth,
        pageBuilder: (_, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const AuthScreen(),
          transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
        ),
      ),
      GoRoute(
        path: AppRoutes.repositories,
        pageBuilder: (_, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const RepositoryListScreen(),
          transitionsBuilder: _slide,
        ),
        routes: [
          GoRoute(
            path: ':owner/:repo/upload',
            pageBuilder: (_, state) {
              final extra = state.extra as Map<String, dynamic>;
              return CustomTransitionPage(
                key: state.pageKey,
                child: UploadScreen(
                  repository: extra['repository'] as RepositoryEntity,
                  branch: extra['branch'] as BranchEntity,
                ),
                transitionsBuilder: _slide,
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.console,
        pageBuilder: (_, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const ConsoleScreen(),
          transitionsBuilder: (_, a, __, child) => SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 48),
          const SizedBox(height: 16),
          Text('Route not found: ${state.uri}'),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => context.go(AppRoutes.repositories), child: const Text('Go Home')),
        ],
      )),
    ),
  );
});

Widget _slide(BuildContext c, Animation<double> a, Animation<double> s, Widget child) =>
    SlideTransition(
      position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
      child: child,
    );
