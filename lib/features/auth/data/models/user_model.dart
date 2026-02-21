import 'package:gitty/features/auth/domain/entities/user_entity.dart';

/// Data model for GitHub /user API response.
class UserModel {
  const UserModel({
    required this.id,
    required this.login,
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.htmlUrl,
    required this.publicRepos,
    required this.totalPrivateRepos,
    required this.followers,
    required this.following,
    required this.createdAt,
    required this.siteAdmin,
  });

  final int id;
  final String login;
  final String name;
  final String? email;
  final String avatarUrl;
  final String htmlUrl;
  final int publicRepos;
  final int totalPrivateRepos;
  final int followers;
  final int following;
  final String createdAt;
  final bool siteAdmin;

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: (json['id'] as num).toInt(),
        login: json['login'] as String? ?? '',
        name: json['name'] as String? ?? '',
        email: json['email'] as String?,
        avatarUrl: json['avatar_url'] as String? ?? '',
        htmlUrl: json['html_url'] as String? ?? '',
        publicRepos: (json['public_repos'] as num?)?.toInt() ?? 0,
        totalPrivateRepos: (json['total_private_repos'] as num?)?.toInt() ?? 0,
        followers: (json['followers'] as num?)?.toInt() ?? 0,
        following: (json['following'] as num?)?.toInt() ?? 0,
        createdAt:
            json['created_at'] as String? ?? DateTime.now().toIso8601String(),
        siteAdmin: json['site_admin'] as bool? ?? false,
      );

  UserEntity toEntity({List<String> scopes = const []}) => UserEntity(
        id: id.toString(),
        login: login,
        name: name,
        email: email ?? '',
        avatarUrl: avatarUrl,
        profileUrl: htmlUrl,
        publicRepos: publicRepos,
        privateRepos: totalPrivateRepos,
        followers: followers,
        following: following,
        createdAt: DateTime.parse(createdAt),
        scopes: scopes,
        isSiteAdmin: siteAdmin,
      );
}
