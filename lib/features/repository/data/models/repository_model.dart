import 'package:gitty/features/repository/domain/entities/repository_entity.dart';

class RepositoryModel {
  const RepositoryModel({
    required this.id,
    required this.name,
    required this.fullName,
    required this.owner,
    this.description,
    this.defaultBranch = 'main',
    required this.cloneUrl,
    required this.htmlUrl,
    this.stargazersCount = 0,
    this.forksCount = 0,
    this.openIssuesCount = 0,
    this.isPrivate = false,
    this.isFork = false,
    this.isArchived = false,
    required this.updatedAt,
    required this.pushedAt,
    this.language,
    this.sizeKb = 0,
    this.topics = const [],
  });

  final int id;
  final String name;
  final String fullName;
  final OwnerModel owner;
  final String? description;
  final String defaultBranch;
  final String cloneUrl;
  final String htmlUrl;
  final int stargazersCount;
  final int forksCount;
  final int openIssuesCount;
  final bool isPrivate;
  final bool isFork;
  final bool isArchived;
  final String updatedAt;
  final String pushedAt;
  final String? language;
  final int sizeKb;
  final List<String> topics;

  factory RepositoryModel.fromJson(Map<String, dynamic> json) =>
      RepositoryModel(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String? ?? '',
        fullName: json['full_name'] as String? ?? '',
        owner:
            OwnerModel.fromJson(json['owner'] as Map<String, dynamic>? ?? {}),
        description: json['description'] as String?,
        defaultBranch: json['default_branch'] as String? ?? 'main',
        cloneUrl: json['clone_url'] as String? ?? '',
        htmlUrl: json['html_url'] as String? ?? '',
        stargazersCount: (json['stargazers_count'] as num?)?.toInt() ?? 0,
        forksCount: (json['forks_count'] as num?)?.toInt() ?? 0,
        openIssuesCount: (json['open_issues_count'] as num?)?.toInt() ?? 0,
        isPrivate: json['private'] as bool? ?? false,
        isFork: json['fork'] as bool? ?? false,
        isArchived: json['archived'] as bool? ?? false,
        updatedAt:
            json['updated_at'] as String? ?? DateTime.now().toIso8601String(),
        pushedAt:
            json['pushed_at'] as String? ?? DateTime.now().toIso8601String(),
        language: json['language'] as String?,
        sizeKb: (json['size'] as num?)?.toInt() ?? 0,
        topics: (json['topics'] as List<dynamic>?)?.cast<String>() ?? const [],
      );

  RepositoryEntity toEntity() => RepositoryEntity(
        id: id.toString(),
        name: name,
        fullName: fullName,
        owner: owner.login,
        description: description ?? '',
        defaultBranch: defaultBranch,
        cloneUrl: cloneUrl,
        htmlUrl: htmlUrl,
        stargazersCount: stargazersCount,
        forksCount: forksCount,
        openIssuesCount: openIssuesCount,
        isPrivate: isPrivate,
        isFork: isFork,
        isArchived: isArchived,
        updatedAt: DateTime.tryParse(updatedAt) ?? DateTime.now(),
        pushedAt: DateTime.tryParse(pushedAt) ?? DateTime.now(),
        language: language ?? '',
        sizeKb: sizeKb,
        topics: topics,
      );
}

class OwnerModel {
  const OwnerModel(
      {required this.login, required this.id, required this.avatarUrl});
  final String login;
  final int id;
  final String avatarUrl;

  factory OwnerModel.fromJson(Map<String, dynamic> json) => OwnerModel(
        login: json['login'] as String? ?? '',
        id: (json['id'] as num?)?.toInt() ?? 0,
        avatarUrl: json['avatar_url'] as String? ?? '',
      );
}

class BranchModel {
  const BranchModel(
      {required this.name, required this.commit, this.isProtected = false});
  final String name;
  final BranchCommitModel commit;
  final bool isProtected;

  factory BranchModel.fromJson(Map<String, dynamic> json) => BranchModel(
        name: json['name'] as String? ?? '',
        commit: BranchCommitModel.fromJson(
            json['commit'] as Map<String, dynamic>? ?? {}),
        isProtected: json['protected'] as bool? ?? false,
      );

  BranchEntity toEntity({bool isDefault = false}) => BranchEntity(
        name: name,
        sha: commit.sha,
        isProtected: isProtected,
        isDefault: isDefault,
      );
}

class BranchCommitModel {
  const BranchCommitModel({required this.sha, required this.url});
  final String sha;
  final String url;

  factory BranchCommitModel.fromJson(Map<String, dynamic> json) =>
      BranchCommitModel(
        sha: json['sha'] as String? ?? '',
        url: json['url'] as String? ?? '',
      );
}
