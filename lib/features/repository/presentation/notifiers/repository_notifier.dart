import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gitty/core/error/failures.dart';
import 'package:gitty/features/repository/domain/entities/repository_entity.dart';
import 'package:gitty/features/repository/domain/usecases/repository_usecases.dart';

// ════════════════════════════════════════════════════════════════════════════
// Repository State
// ════════════════════════════════════════════════════════════════════════════

sealed class RepositoryState {
  const RepositoryState();
}

final class RepositoryStateInitial extends RepositoryState {
  const RepositoryStateInitial();
}

final class RepositoryStateLoading extends RepositoryState {
  const RepositoryStateLoading();
}

final class RepositoryStateLoaded extends RepositoryState {
  const RepositoryStateLoaded({
    required this.repositories,
    required this.hasMore,
    required this.currentPage,
  });

  final List<RepositoryEntity> repositories;
  final bool hasMore;
  final int currentPage;

  RepositoryStateLoaded copyWith({
    List<RepositoryEntity>? repositories,
    bool? hasMore,
    int? currentPage,
  }) =>
      RepositoryStateLoaded(
        repositories: repositories ?? this.repositories,
        hasMore: hasMore ?? this.hasMore,
        currentPage: currentPage ?? this.currentPage,
      );
}

final class RepositoryStateError extends RepositoryState {
  const RepositoryStateError({required this.failure});
  final Failure failure;
}

// ── Pattern-match extension ───────────────────────────────────────────────────

extension RepositoryStateX on RepositoryState {
  /// Full exhaustive match — all branches required.
  T map<T>({
    required T Function(RepositoryStateInitial) initial,
    required T Function(RepositoryStateLoading) loading,
    required T Function(RepositoryStateLoaded) loaded,
    required T Function(RepositoryStateError) error,
  }) =>
      switch (this) {
        RepositoryStateInitial s => initial(s),
        RepositoryStateLoading s => loading(s),
        RepositoryStateLoaded s  => loaded(s),
        RepositoryStateError s   => error(s),
      };

  /// Partial match — unhandled cases fall through to orElse.
  T maybeMap<T>({
    T Function(RepositoryStateLoaded)? loaded,
    required T Function() orElse,
  }) =>
      this is RepositoryStateLoaded
          ? loaded?.call(this as RepositoryStateLoaded) ?? orElse()
          : orElse();
}

// ════════════════════════════════════════════════════════════════════════════
// Branch State
// ════════════════════════════════════════════════════════════════════════════

sealed class BranchState {
  const BranchState();
}

final class BranchStateInitial extends BranchState {
  const BranchStateInitial();
}

final class BranchStateLoading extends BranchState {
  const BranchStateLoading();
}

final class BranchStateLoaded extends BranchState {
  const BranchStateLoaded({
    required this.branches,
    required this.selectedBranch,
  });

  final List<BranchEntity> branches;
  final BranchEntity selectedBranch;

  BranchStateLoaded copyWith({
    List<BranchEntity>? branches,
    BranchEntity? selectedBranch,
  }) =>
      BranchStateLoaded(
        branches: branches ?? this.branches,
        selectedBranch: selectedBranch ?? this.selectedBranch,
      );
}

final class BranchStateError extends BranchState {
  const BranchStateError({required this.failure});
  final Failure failure;
}

extension BranchStateX on BranchState {
  T map<T>({
    required T Function(BranchStateInitial) initial,
    required T Function(BranchStateLoading) loading,
    required T Function(BranchStateLoaded) loaded,
    required T Function(BranchStateError) error,
  }) =>
      switch (this) {
        BranchStateInitial s => initial(s),
        BranchStateLoading s => loading(s),
        BranchStateLoaded s  => loaded(s),
        BranchStateError s   => error(s),
      };
}

// ════════════════════════════════════════════════════════════════════════════
// Repository Notifier — Riverpod 3.x
// ════════════════════════════════════════════════════════════════════════════

class RepositoryNotifier extends Notifier<RepositoryState> {
  static const _perPage = 30;

  @override
  RepositoryState build() {
    loadRepositories();
    return const RepositoryStateInitial();
  }

  Future<void> loadRepositories({bool refresh = false}) async {
    final current = state;
    final page = refresh
        ? 1
        : current.maybeMap(
            loaded: (s) => s.currentPage + 1,
            orElse: () => 1,
          );

    if (page == 1) state = const RepositoryStateLoading();

    final result = await ref
        .read(getUserRepositoriesUseCaseProvider)
        .call(page: page, perPage: _perPage);

    final existing = (!refresh && current is RepositoryStateLoaded)
        ? current.repositories
        : <RepositoryEntity>[];

    state = result.fold(
      (f) => RepositoryStateError(failure: f),
      (repos) => RepositoryStateLoaded(
        repositories: [...existing, ...repos],
        hasMore: repos.length >= _perPage,
        currentPage: page,
      ),
    );
  }

  Future<void> refresh() => loadRepositories(refresh: true);
}

/// Riverpod 3.x provider declaration.
final repositoryNotifierProvider =
    NotifierProvider<RepositoryNotifier, RepositoryState>(
  RepositoryNotifier.new,
);

//═══════════════════════════════════════════════════════════════════
// Branch Notifier — Riverpod Family (باستخدام Notifier العادي)
// ═══════════════════════════════════════════════════════════════════

typedef BranchArg = ({
  String owner,
  String repoName,
  String defaultBranch,
});

// ✅ التصحيح: استخدام Notifier مباشرة بدلاً من FamilyNotifier
class BranchNotifier extends Notifier<BranchState> {
  late BranchArg _arg;

  @override
  BranchState build() {
    // لا يمكن استقبال arg هنا مباشرة، نترك الحالة ابتدائية حتى يتم استدعاء init
    return const BranchStateInitial();
  }

  // دالة لتهيئة الـ notifier بالـ argument وبدء التحميل
  void init(BranchArg arg) {
    _arg = arg;
    _load();
  }

  Future<void> _load() async {
    state = const BranchStateLoading();

    final result = await ref
        .read(getBranchesUseCaseProvider)
        .call(_arg.owner, _arg.repoName);

    state = result.fold(
      (f) => BranchStateError(failure: f),
      (branches) {
        final selected = branches.firstWhere(
          (b) => b.name == _arg.defaultBranch,
          orElse: () => branches.first,
        );
        return BranchStateLoaded(
          branches: branches,
          selectedBranch: selected,
        );
      },
    );
  }

  void selectBranch(BranchEntity branch) {
    final currentState = state;
    if (currentState is BranchStateLoaded) {
      state = currentState.copyWith(selectedBranch: branch);
    }
  }
}

// ✅ التصحيح: تعريف provider عائلي يستدعي init بعد إنشاء الـ notifier
final branchNotifierProvider = NotifierProvider.family<BranchNotifier, BranchState, BranchArg>(
  (arg) => BranchNotifier()..init(arg),
);