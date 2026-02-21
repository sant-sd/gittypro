import 'package:gitty/features/upload/domain/entities/git_entities.dart';

// ── Blob ──────────────────────────────────────────────────────────────────────

class CreateBlobRequest {
  const CreateBlobRequest({required this.content, this.encoding = 'base64'});
  final String content;
  final String encoding;
  Map<String, dynamic> toJson() => {'content': content, 'encoding': encoding};
}

class BlobResponse {
  const BlobResponse({required this.sha, required this.url, this.size = 0});
  final String sha;
  final String url;
  final int size;

  factory BlobResponse.fromJson(Map<String, dynamic> json) => BlobResponse(
        sha: json['sha'] as String? ?? '',
        url: json['url'] as String? ?? '',
        size: (json['size'] as num?)?.toInt() ?? 0,
      );
  GitBlobEntity toEntity(String path) =>
      GitBlobEntity(sha: sha, path: path, size: size, url: url);
}

// ── Tree ──────────────────────────────────────────────────────────────────────

class CreateTreeRequest {
  const CreateTreeRequest({required this.baseTree, required this.tree});
  final String baseTree;
  final List<TreeEntryRequest> tree;
  Map<String, dynamic> toJson() => {
        'base_tree': baseTree,
        'tree': tree.map((e) => e.toJson()).toList(),
      };
}

class TreeEntryRequest {
  const TreeEntryRequest(
      {required this.path,
      required this.mode,
      required this.type,
      required this.sha});
  final String path;
  final String mode;
  final String type;
  final String sha;
  Map<String, dynamic> toJson() =>
      {'path': path, 'mode': mode, 'type': type, 'sha': sha};
}

class TreeResponse {
  const TreeResponse(
      {required this.sha,
      required this.url,
      this.tree = const [],
      this.truncated = false});
  final String sha;
  final String url;
  final List<TreeEntryResponse> tree;
  final bool truncated;

  factory TreeResponse.fromJson(Map<String, dynamic> json) => TreeResponse(
        sha: json['sha'] as String? ?? '',
        url: json['url'] as String? ?? '',
        truncated: json['truncated'] as bool? ?? false,
        tree: (json['tree'] as List<dynamic>? ?? [])
            .map((e) => TreeEntryResponse.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
  GitTreeEntity toEntity() => GitTreeEntity(
        sha: sha,
        url: url,
        truncated: truncated,
        entries: tree.map((e) => e.toEntity()).toList(),
      );
}

class TreeEntryResponse {
  const TreeEntryResponse(
      {required this.path,
      required this.mode,
      required this.type,
      required this.sha,
      this.size = 0,
      this.url = ''});
  final String path;
  final String mode;
  final String type;
  final String sha;
  final int size;
  final String url;

  factory TreeEntryResponse.fromJson(Map<String, dynamic> json) =>
      TreeEntryResponse(
        path: json['path'] as String? ?? '',
        mode: json['mode'] as String? ?? '',
        type: json['type'] as String? ?? '',
        sha: json['sha'] as String? ?? '',
        size: (json['size'] as num?)?.toInt() ?? 0,
        url: json['url'] as String? ?? '',
      );
  GitTreeEntryEntity toEntity() =>
      GitTreeEntryEntity(path: path, mode: mode, type: type, sha: sha);
}

// ── Commit ────────────────────────────────────────────────────────────────────

class CreateCommitRequest {
  const CreateCommitRequest(
      {required this.message,
      required this.tree,
      required this.parents,
      this.author});
  final String message;
  final String tree;
  final List<String> parents;
  final CommitAuthorRequest? author;
  Map<String, dynamic> toJson() => {
        'message': message,
        'tree': tree,
        'parents': parents,
        if (author != null) 'author': author!.toJson(),
      };
}

class CommitAuthorRequest {
  const CommitAuthorRequest(
      {required this.name, required this.email, required this.date});
  final String name;
  final String email;
  final String date;
  Map<String, dynamic> toJson() => {'name': name, 'email': email, 'date': date};
}

class CommitResponse {
  const CommitResponse(
      {required this.sha,
      required this.message,
      required this.url,
      this.htmlUrl = '',
      required this.tree,
      this.parents = const [],
      required this.author});
  final String sha;
  final String message;
  final String url;
  final String htmlUrl;
  final CommitTreeRef tree;
  final List<CommitParentRef> parents;
  final CommitAuthorResponse author;

  factory CommitResponse.fromJson(Map<String, dynamic> json) => CommitResponse(
        sha: json['sha'] as String? ?? '',
        message: json['message'] as String? ?? '',
        url: json['url'] as String? ?? '',
        htmlUrl: json['html_url'] as String? ?? '',
        tree:
            CommitTreeRef.fromJson(json['tree'] as Map<String, dynamic>? ?? {}),
        parents: (json['parents'] as List<dynamic>? ?? [])
            .map((e) => CommitParentRef.fromJson(e as Map<String, dynamic>))
            .toList(),
        author: CommitAuthorResponse.fromJson(
            json['author'] as Map<String, dynamic>? ?? {}),
      );
  GitCommitEntity toEntity() => GitCommitEntity(
        sha: sha,
        message: message,
        url: url,
        htmlUrl: htmlUrl,
        treeSha: tree.sha,
        parentShas: parents.map((p) => p.sha).toList(),
        author: author.toEntity(),
        committedAt: DateTime.tryParse(author.date) ?? DateTime.now(),
      );
}

class CommitTreeRef {
  const CommitTreeRef({required this.sha, required this.url});
  final String sha;
  final String url;
  factory CommitTreeRef.fromJson(Map<String, dynamic> json) => CommitTreeRef(
      sha: json['sha'] as String? ?? '', url: json['url'] as String? ?? '');
}

class CommitParentRef {
  const CommitParentRef({required this.sha, required this.url});
  final String sha;
  final String url;
  factory CommitParentRef.fromJson(Map<String, dynamic> json) =>
      CommitParentRef(
          sha: json['sha'] as String? ?? '', url: json['url'] as String? ?? '');
}

class CommitAuthorResponse {
  const CommitAuthorResponse(
      {required this.name, required this.email, required this.date});
  final String name;
  final String email;
  final String date;
  factory CommitAuthorResponse.fromJson(Map<String, dynamic> json) =>
      CommitAuthorResponse(
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        date: json['date'] as String? ?? DateTime.now().toIso8601String(),
      );
  GitAuthorEntity toEntity() => GitAuthorEntity(
      name: name,
      email: email,
      date: DateTime.tryParse(date) ?? DateTime.now());
}

// ── Ref ───────────────────────────────────────────────────────────────────────

class UpdateRefRequest {
  const UpdateRefRequest({required this.sha, this.force = false});
  final String sha;
  final bool force;
  Map<String, dynamic> toJson() => {'sha': sha, 'force': force};
}

class RefResponse {
  const RefResponse(
      {required this.ref, required this.url, required this.object});
  final String ref;
  final String url;
  final RefObjectResponse object;
  factory RefResponse.fromJson(Map<String, dynamic> json) => RefResponse(
        ref: json['ref'] as String? ?? '',
        url: json['url'] as String? ?? '',
        object: RefObjectResponse.fromJson(
            json['object'] as Map<String, dynamic>? ?? {}),
      );
  GitRefEntity toEntity() => GitRefEntity(ref: ref, sha: object.sha, url: url);
}

class RefObjectResponse {
  const RefObjectResponse(
      {required this.sha, required this.type, required this.url});
  final String sha;
  final String type;
  final String url;
  factory RefObjectResponse.fromJson(Map<String, dynamic> json) =>
      RefObjectResponse(
        sha: json['sha'] as String? ?? '',
        type: json['type'] as String? ?? '',
        url: json['url'] as String? ?? '',
      );
}

// ── Commit Detail ─────────────────────────────────────────────────────────────

class CommitDetailResponse {
  const CommitDetailResponse({required this.sha, required this.commit});
  final String sha;
  final CommitDetailInner commit;
  factory CommitDetailResponse.fromJson(Map<String, dynamic> json) =>
      CommitDetailResponse(
        sha: json['sha'] as String? ?? '',
        commit: CommitDetailInner.fromJson(
            json['commit'] as Map<String, dynamic>? ?? {}),
      );
}

class CommitDetailInner {
  const CommitDetailInner({required this.tree, required this.message});
  final CommitTreeRef tree;
  final String message;
  factory CommitDetailInner.fromJson(Map<String, dynamic> json) =>
      CommitDetailInner(
        tree:
            CommitTreeRef.fromJson(json['tree'] as Map<String, dynamic>? ?? {}),
        message: json['message'] as String? ?? '',
      );
}
