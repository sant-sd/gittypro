/// Represents an authenticated GitHub user in the Domain layer.
class UserEntity {
  const UserEntity({
    required this.id,
    required this.login,
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.profileUrl,
    required this.publicRepos,
    required this.privateRepos,
    required this.followers,
    required this.following,
    required this.createdAt,
    required this.scopes,
    required this.isSiteAdmin,
  });

  final String id;
  final String login;
  final String name;
  final String email;
  final String avatarUrl;
  final String profileUrl;
  final int publicRepos;
  final int privateRepos;
  final int followers;
  final int following;
  final DateTime createdAt;
  final List<String> scopes;
  final bool isSiteAdmin;

  String get displayName => name.isNotEmpty ? name : login;
  bool get hasGitScopes =>
      scopes.contains('repo') || scopes.contains('public_repo');
  bool get canWritePrivate => scopes.contains('repo');

  UserEntity copyWith({
    String? id,
    String? login,
    String? name,
    String? email,
    String? avatarUrl,
    String? profileUrl,
    int? publicRepos,
    int? privateRepos,
    int? followers,
    int? following,
    DateTime? createdAt,
    List<String>? scopes,
    bool? isSiteAdmin,
  }) =>
      UserEntity(
        id: id ?? this.id,
        login: login ?? this.login,
        name: name ?? this.name,
        email: email ?? this.email,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        profileUrl: profileUrl ?? this.profileUrl,
        publicRepos: publicRepos ?? this.publicRepos,
        privateRepos: privateRepos ?? this.privateRepos,
        followers: followers ?? this.followers,
        following: following ?? this.following,
        createdAt: createdAt ?? this.createdAt,
        scopes: scopes ?? this.scopes,
        isSiteAdmin: isSiteAdmin ?? this.isSiteAdmin,
      );
}
