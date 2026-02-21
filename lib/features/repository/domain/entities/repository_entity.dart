/// Represents a GitHub repository in the Domain layer.
class RepositoryEntity {
  const RepositoryEntity({
    required this.id,
    required this.name,
    required this.fullName,
    required this.owner,
    required this.description,
    required this.defaultBranch,
    required this.cloneUrl,
    required this.htmlUrl,
    required this.stargazersCount,
    required this.forksCount,
    required this.openIssuesCount,
    required this.isPrivate,
    required this.isFork,
    required this.isArchived,
    required this.updatedAt,
    required this.pushedAt,
    required this.language,
    required this.sizeKb,
    required this.topics,
  });

  final String id;
  final String name;
  final String fullName;
  final String owner;
  final String description;
  final String defaultBranch;
  final String cloneUrl;
  final String htmlUrl;
  final int stargazersCount;
  final int forksCount;
  final int openIssuesCount;
  final bool isPrivate;
  final bool isFork;
  final bool isArchived;
  final DateTime updatedAt;
  final DateTime pushedAt;
  final String language;
  final int sizeKb;
  final List<String> topics;

  bool get canPush => !isArchived;
  String get displayName => name;
  String get sizeDisplay =>
      sizeKb < 1024 ? '${sizeKb}KB' : '${(sizeKb / 1024).toStringAsFixed(1)}MB';
}

/// Represents a Git branch.
class BranchEntity {
  const BranchEntity({
    required this.name,
    required this.sha,
    required this.isProtected,
    required this.isDefault,
  });
  final String name;
  final String sha;
  final bool isProtected;
  final bool isDefault;

  BranchEntity copyWith(
          {String? name, String? sha, bool? isProtected, bool? isDefault}) =>
      BranchEntity(
        name: name ?? this.name,
        sha: sha ?? this.sha,
        isProtected: isProtected ?? this.isProtected,
        isDefault: isDefault ?? this.isDefault,
      );
}

/// Lightweight repo reference for lists.
class RepositoryRef {
  const RepositoryRef({
    required this.id,
    required this.fullName,
    required this.defaultBranch,
    required this.isPrivate,
  });
  final String id;
  final String fullName;
  final String defaultBranch;
  final bool isPrivate;
}
