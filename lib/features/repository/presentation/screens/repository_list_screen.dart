import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gitty/core/router/app_router.dart';
import 'package:gitty/features/auth/presentation/notifiers/auth_notifier.dart';
import 'package:gitty/features/repository/domain/entities/repository_entity.dart';
import 'package:gitty/features/repository/presentation/notifiers/repository_notifier.dart';

class RepositoryListScreen extends ConsumerWidget {
  const RepositoryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repoState = ref.watch(repositoryNotifierProvider);
    final user      = ref.watch(currentUserProvider);
    final cs        = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (user?.avatarUrl != null)
              CircleAvatar(
                radius: 16,
                backgroundImage: CachedNetworkImageProvider(user!.avatarUrl),
              ),
            const SizedBox(width: 10),
            Text(
              user?.displayName ?? 'Repositories',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.terminal_rounded),
            tooltip: 'Developer Console',
            onPressed: () => context.push(AppRoutes.console),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () =>
                ref.read(repositoryNotifierProvider.notifier).refresh(),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'signout') {
                await ref.read(authNotifierProvider.notifier).signOut();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'signout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Sign Out'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),

      // ── Body: pattern-match on RepositoryState via extension ──────────────
      body: repoState.map(
        initial: (_) => const SizedBox.shrink(),
        loading: (_) => const Center(child: CircularProgressIndicator()),
        loaded: (s) => _buildList(context, ref, s.repositories, s.hasMore),
        error: (s) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded, size: 48, color: cs.error),
                const SizedBox(height: 16),
                Text(
                  s.failure.userMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      ref.read(repositoryNotifierProvider.notifier).refresh(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<RepositoryEntity> repos,
    bool hasMore,
  ) {
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(repositoryNotifierProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: repos.length + (hasMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == repos.length) {
            // Load-more trigger
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref
                  .read(repositoryNotifierProvider.notifier)
                  .loadRepositories();
            });
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _RepoTile(repo: repos[i]);
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Repo tile
// ════════════════════════════════════════════════════════════════════════════

class _RepoTile extends ConsumerWidget {
  const _RepoTile({required this.repo});
  final RepositoryEntity repo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showBranchPicker(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Name row ─────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Text(
                      repo.name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (repo.isPrivate)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_rounded,
                              size: 11, color: cs.onSurfaceVariant),
                          const SizedBox(width: 3),
                          Text(
                            'Private',
                            style: TextStyle(
                                fontSize: 11, color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              // ── Description ───────────────────────────────────────────────
              if (repo.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  repo.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
              ],

              // ── Meta row ──────────────────────────────────────────────────
              const SizedBox(height: 10),
              Row(
                children: [
                  if (repo.language.isNotEmpty) ...[
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                          color: Colors.blue, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Text(repo.language,
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant)),
                    const SizedBox(width: 12),
                  ],
                  Icon(Icons.star_border_rounded,
                      size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 2),
                  Text('${repo.stargazersCount}',
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant)),
                  const SizedBox(width: 12),
                  Icon(Icons.account_tree_outlined,
                      size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 2),
                  Text(repo.defaultBranch,
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBranchPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _BranchPickerSheet(repo: repo),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Branch picker sheet
// ════════════════════════════════════════════════════════════════════════════

class _BranchPickerSheet extends ConsumerWidget {
  const _BranchPickerSheet({required this.repo});
  final RepositoryEntity repo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchState = ref.watch(
      branchNotifierProvider((
        owner: repo.owner,
        repoName: repo.name,
        defaultBranch: repo.defaultBranch,
      )),
    );
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.85,
      minChildSize: 0.3,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.account_tree_rounded, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Select Branch',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── State body ────────────────────────────────────────────────────
          Expanded(
            child: branchState.map(
              initial: (_) => const SizedBox.shrink(),
              loading: (_) =>
                  const Center(child: CircularProgressIndicator()),
              loaded: (s) => ListView.builder(
                controller: controller,
                itemCount: s.branches.length,
                itemBuilder: (_, i) {
                  final branch = s.branches[i];
                  return ListTile(
                    leading: Icon(
                      branch.isDefault
                          ? Icons.star_rounded
                          : Icons.account_tree_rounded,
                      size: 20,
                      color: branch.isDefault
                          ? Colors.amber
                          : cs.onSurfaceVariant,
                    ),
                    title: Text(
                      branch.name,
                      style: const TextStyle(
                          fontFamily: 'JetBrainsMono', fontSize: 14),
                    ),
                    subtitle: Text(
                      branch.sha.length >= 7
                          ? branch.sha.substring(0, 7)
                          : branch.sha,
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    trailing: branch.isProtected
                        ? Icon(Icons.lock_rounded,
                            size: 16, color: cs.onSurfaceVariant)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      context.push(
                        AppRoutes.uploadPath(repo.owner, repo.name),
                        extra: {
                          'repository': repo,
                          'branch': branch,
                        },
                      );
                    },
                  );
                },
              ),
              error: (s) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    s.failure.userMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.error),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
