import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gitty/core/error/failures.dart';
import 'package:gitty/features/auth/presentation/notifiers/auth_notifier.dart';
import 'package:gitty/features/repository/domain/entities/repository_entity.dart';
import 'package:gitty/features/upload/domain/entities/git_entities.dart';
import 'package:gitty/features/upload/presentation/notifiers/upload_notifier.dart';

class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({
    super.key,
    required this.repository,
    required this.branch,
  });

  final RepositoryEntity repository;
  final BranchEntity branch;

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  final _commitMessageController = TextEditingController();
  final _repoPathController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _commitMessageController.dispose();
    _repoPathController.dispose();
    super.dispose();
  }

  // ── Handlers ───────────────────────────────────────────────────────────

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    if (result == null || result.paths.isEmpty) return;
    final paths = result.paths.whereType<String>().toList();
    ref.read(uploadNotifierProvider.notifier).selectFiles(paths);
  }

  Future<void> _startUpload() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final user = ref.read(currentUserProvider);

    await ref.read(uploadNotifierProvider.notifier).startUpload(
          owner: widget.repository.owner,
          repoName: widget.repository.name,
          branch: widget.branch.name,
          commitMessage: _commitMessageController.text,
          repoBasePath: _repoPathController.text.trim(),
          authorName: user?.displayName,
          authorEmail: user?.email,
        );
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final uploadState = ref.watch(uploadNotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.repository.fullName,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Text(widget.branch.name,
                style: TextStyle(
                    fontSize: 12, color: colorScheme.onSurfaceVariant)),
          ],
        ),
        actions: [
          if (!uploadState.maybeMap(
              uploading: (_) => true, orElse: () => false))
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Reset',
              onPressed: () =>
                  ref.read(uploadNotifierProvider.notifier).reset(),
            ),
        ],
      ),
      body: uploadState.map(
        idle: (_) => _buildFileSelector(context),
        filesSelected: (s) => _buildUploadForm(context, s.filePaths),
        uploading: (s) => _buildProgressView(context, s.job),
        success: (s) => _buildSuccessView(context, s.commitSha, s.commitUrl),
        failure: (s) => _buildFailureView(context, s.failure, s.job),
      ),
    );
  }

  // ── File Selector ─────────────────────────────────────────────────────

  Widget _buildFileSelector(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.upload_file_rounded,
                  size: 48, color: colorScheme.onPrimaryContainer),
            ),
            const SizedBox(height: 24),
            Text(
              'Select Files to Upload',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose one or more files to commit\nto ${widget.repository.fullName}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _pickFiles,
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('Browse Files'),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Upload Form ───────────────────────────────────────────────────────

  Widget _buildUploadForm(BuildContext context, List<String> filePaths) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selected files list
            _SectionLabel(label: 'Selected Files (${filePaths.length})'),
            const SizedBox(height: 8),
            _FileList(filePaths: filePaths),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _pickFiles,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add More Files'),
            ),
            const SizedBox(height: 24),

            // Repo base path
            _SectionLabel(label: 'Target Directory (optional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _repoPathController,
              decoration: InputDecoration(
                hintText: 'e.g. src/assets/',
                prefixIcon: const Icon(Icons.folder_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                helperText: 'Leave empty to place files at repo root',
              ),
            ),
            const SizedBox(height: 24),

            // Commit message
            _SectionLabel(label: 'Commit Message'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _commitMessageController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Add files via Gitty',
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 40),
                  child: Icon(Icons.commit_rounded),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Commit message is required'
                  : null,
            ),
            const SizedBox(height: 32),

            // Upload button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _startUpload,
                icon: const Icon(Icons.cloud_upload_rounded),
                label: const Text(
                  'Commit & Push',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Progress View ─────────────────────────────────────────────────────

  Widget _buildProgressView(BuildContext context, UploadJobEntity job) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall progress bar
          _PhaseProgressBar(job: job),
          const SizedBox(height: 32),

          // Phase steps
          _PhaseStepList(currentPhase: job.phase),
          const SizedBox(height: 32),

          // Per-file blob progress
          if (job.phase == UploadPhase.creatingBlobs) ...[
            Text(
              'Uploading files (${job.completedBlobs}/${job.totalFiles})',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            ...job.files.map((f) => _FileProgressTile(file: f)),
          ],

          const Spacer(),
          Center(
            child: TextButton.icon(
              onPressed: () =>
                  ref.read(uploadNotifierProvider.notifier).cancelUpload(),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancel'),
              style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  // ── Success View ──────────────────────────────────────────────────────

  Widget _buildSuccessView(BuildContext context, String sha, String commitUrl) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  size: 48, color: Colors.green),
            ),
            const SizedBox(height: 24),
            Text('Push Successful!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.green,
                    )),
            const SizedBox(height: 8),
            Text('Committed to ${widget.repository.fullName}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    )),
            const SizedBox(height: 16),
            // Commit SHA chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                sha.length > 7 ? sha.substring(0, 7) : sha,
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () =>
                  ref.read(uploadNotifierProvider.notifier).reset(),
              icon: const Icon(Icons.upload_rounded),
              label: const Text('Upload More Files'),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Failure View ──────────────────────────────────────────────────────

  Widget _buildFailureView(
      BuildContext context, Failure failure, UploadJobEntity job) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Icon(Icons.error_rounded, size: 64, color: colorScheme.error),
          const SizedBox(height: 16),
          Text('Upload Failed',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w700,
                  )),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              failure.userMessage,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Failed at: ${job.phase.label}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      ref.read(uploadNotifierProvider.notifier).reset(),
                  child: const Text('Start Over'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _startUpload,
                  child: const Text('Retry'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Sub-Widgets ───────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      );
}

class _FileList extends ConsumerWidget {
  const _FileList({required this.filePaths});
  final List<String> filePaths;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: filePaths.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: colorScheme.outlineVariant,
        ),
        itemBuilder: (context, i) {
          final path = filePaths[i];
          final name = path.split('/').last;
          return ListTile(
            dense: true,
            leading: const Icon(Icons.insert_drive_file_outlined, size: 20),
            title: Text(name,
                style:
                    const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 13)),
            subtitle: Text(path,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11, color: colorScheme.onSurfaceVariant)),
            trailing: IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () =>
                  ref.read(uploadNotifierProvider.notifier).removeFile(path),
            ),
          );
        },
      ),
    );
  }
}

class _PhaseProgressBar extends StatelessWidget {
  const _PhaseProgressBar({required this.job});
  final UploadJobEntity job;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = job.phase == UploadPhase.creatingBlobs
        ? job.phase.overallProgress +
            (job.blobProgress * 0.5) // blobs go from 10% to 60%
        : job.phase.overallProgress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(job.phase.label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
            Text('${(progress * 100).toInt()}%',
                style: TextStyle(
                    color: colorScheme.primary, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

class _PhaseStepList extends StatelessWidget {
  const _PhaseStepList({required this.currentPhase});
  final UploadPhase currentPhase;

  static const _phases = [
    (UploadPhase.creatingBlobs, Icons.upload_file_rounded, 'Create Blobs'),
    (UploadPhase.buildingTree, Icons.account_tree_rounded, 'Build Tree'),
    (UploadPhase.creatingCommit, Icons.commit_rounded, 'Create Commit'),
    (UploadPhase.updatingRef, Icons.merge_type_rounded, 'Update Branch'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _phases.map((phase) {
        final (phaseEnum, icon, label) = phase;
        final isDone = phaseEnum.index < currentPhase.index;
        final isActive = phaseEnum == currentPhase;
        final colorScheme = Theme.of(context).colorScheme;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone
                      ? Colors.green
                      : isActive
                          ? colorScheme.primary
                          : colorScheme.surfaceContainerHighest,
                ),
                child: Icon(
                  isDone ? Icons.check_rounded : icon,
                  size: 18,
                  color: isDone || isActive
                      ? Colors.white
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          isActive ? FontWeight.w700 : FontWeight.normal,
                      color: isDone
                          ? Colors.green
                          : isActive
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                    ),
              ),
              if (isActive) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _FileProgressTile extends StatelessWidget {
  const _FileProgressTile({required this.file});
  final UploadFileEntry file;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final (icon, color) = switch (file.status) {
      UploadFileStatus.blobCreated => (
          Icons.check_circle_rounded,
          Colors.green
        ),
      UploadFileStatus.failed => (Icons.error_rounded, colorScheme.error),
      UploadFileStatus.blobCreating || UploadFileStatus.encoding => (
          Icons.pending_rounded,
          colorScheme.primary
        ),
      _ => (Icons.radio_button_unchecked_rounded, colorScheme.onSurfaceVariant),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              file.fileName,
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (file.status == UploadFileStatus.blobCreating)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}
