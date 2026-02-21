// ── Blob ──────────────────────────────────────────────────────────────────────

class GitBlobEntity {
  const GitBlobEntity(
      {required this.sha,
      required this.path,
      required this.size,
      required this.url});
  final String sha;
  final String path;
  final int size;
  final String url;
}

// ── Tree Entry ────────────────────────────────────────────────────────────────

class GitTreeEntryEntity {
  const GitTreeEntryEntity(
      {required this.path,
      required this.mode,
      required this.type,
      required this.sha});
  final String path;
  final String mode;
  final String type;
  final String sha;

  static const String modeFile = '100644';
  static const String modeExecutable = '100755';
  static const String modeDirectory = '040000';
}

// ── Tree ──────────────────────────────────────────────────────────────────────

class GitTreeEntity {
  const GitTreeEntity(
      {required this.sha,
      required this.url,
      required this.entries,
      required this.truncated});
  final String sha;
  final String url;
  final List<GitTreeEntryEntity> entries;
  final bool truncated;
}

// ── Commit ────────────────────────────────────────────────────────────────────

class GitCommitEntity {
  const GitCommitEntity({
    required this.sha,
    required this.message,
    required this.url,
    required this.htmlUrl,
    required this.treeSha,
    required this.parentShas,
    required this.author,
    required this.committedAt,
  });
  final String sha;
  final String message;
  final String url;
  final String htmlUrl;
  final String treeSha;
  final List<String> parentShas;
  final GitAuthorEntity author;
  final DateTime committedAt;
}

class GitAuthorEntity {
  const GitAuthorEntity(
      {required this.name, required this.email, required this.date});
  final String name;
  final String email;
  final DateTime date;
}

// ── Ref ───────────────────────────────────────────────────────────────────────

class GitRefEntity {
  const GitRefEntity({required this.ref, required this.sha, required this.url});
  final String ref;
  final String sha;
  final String url;
  String get branchName => ref.replaceFirst('refs/heads/', '');
}

// ── Upload File Entry ─────────────────────────────────────────────────────────

enum UploadFileStatus { pending, encoding, blobCreating, blobCreated, failed }

class UploadFileEntry {
  const UploadFileEntry({
    required this.localPath,
    required this.repoPath,
    required this.sizeBytes,
    required this.mimeType,
    this.status = UploadFileStatus.pending,
    this.blobSha,
    this.errorMessage,
  });
  final String localPath;
  final String repoPath;
  final int sizeBytes;
  final String mimeType;
  final UploadFileStatus status;
  final String? blobSha;
  final String? errorMessage;

  String get fileName => localPath.split('/').last;
  bool get isReady => status == UploadFileStatus.blobCreated;
  bool get hasFailed => status == UploadFileStatus.failed;

  UploadFileEntry copyWith({
    String? localPath,
    String? repoPath,
    int? sizeBytes,
    String? mimeType,
    UploadFileStatus? status,
    String? blobSha,
    String? errorMessage,
  }) =>
      UploadFileEntry(
        localPath: localPath ?? this.localPath,
        repoPath: repoPath ?? this.repoPath,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        mimeType: mimeType ?? this.mimeType,
        status: status ?? this.status,
        blobSha: blobSha ?? this.blobSha,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

// ── Upload Job ────────────────────────────────────────────────────────────────

enum UploadPhase {
  idle,
  creatingBlobs,
  buildingTree,
  creatingCommit,
  updatingRef,
  done,
  failed;

  String get label => switch (this) {
        UploadPhase.idle => 'Ready',
        UploadPhase.creatingBlobs => 'Uploading files…',
        UploadPhase.buildingTree => 'Building tree…',
        UploadPhase.creatingCommit => 'Creating commit…',
        UploadPhase.updatingRef => 'Updating branch…',
        UploadPhase.done => 'Complete',
        UploadPhase.failed => 'Failed',
      };

  double get overallProgress => switch (this) {
        UploadPhase.idle => 0.0,
        UploadPhase.creatingBlobs => 0.1,
        UploadPhase.buildingTree => 0.6,
        UploadPhase.creatingCommit => 0.75,
        UploadPhase.updatingRef => 0.9,
        UploadPhase.done => 1.0,
        UploadPhase.failed => 0.0,
      };
}

class UploadJobEntity {
  const UploadJobEntity({
    required this.id,
    required this.owner,
    required this.repoName,
    required this.branch,
    required this.commitMessage,
    required this.files,
    required this.phase,
    required this.startedAt,
    this.completedBlobs = 0,
    this.treeSha,
    this.commitSha,
    this.errorMessage,
    this.completedAt,
  });

  final String id;
  final String owner;
  final String repoName;
  final String branch;
  final String commitMessage;
  final List<UploadFileEntry> files;
  final UploadPhase phase;
  final DateTime startedAt;
  final int completedBlobs;
  final String? treeSha;
  final String? commitSha;
  final String? errorMessage;
  final DateTime? completedAt;

  int get totalFiles => files.length;
  double get blobProgress => totalFiles == 0 ? 0 : completedBlobs / totalFiles;
  bool get isComplete => phase == UploadPhase.done;
  bool get hasFailed => phase == UploadPhase.failed;
  bool get isRunning => !isComplete && !hasFailed;
  Duration? get elapsed => completedAt?.difference(startedAt);

  UploadJobEntity copyWith({
    String? id,
    String? owner,
    String? repoName,
    String? branch,
    String? commitMessage,
    List<UploadFileEntry>? files,
    UploadPhase? phase,
    DateTime? startedAt,
    int? completedBlobs,
    String? treeSha,
    String? commitSha,
    String? errorMessage,
    DateTime? completedAt,
  }) =>
      UploadJobEntity(
        id: id ?? this.id,
        owner: owner ?? this.owner,
        repoName: repoName ?? this.repoName,
        branch: branch ?? this.branch,
        commitMessage: commitMessage ?? this.commitMessage,
        files: files ?? this.files,
        phase: phase ?? this.phase,
        startedAt: startedAt ?? this.startedAt,
        completedBlobs: completedBlobs ?? this.completedBlobs,
        treeSha: treeSha ?? this.treeSha,
        commitSha: commitSha ?? this.commitSha,
        errorMessage: errorMessage ?? this.errorMessage,
        completedAt: completedAt ?? this.completedAt,
      );
}
