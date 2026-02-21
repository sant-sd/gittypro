import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:gitty/core/console/console_log_service.dart';
import 'package:gitty/features/console/presentation/notifiers/console_notifier.dart';

// تعريف الأنواع المفقودة
enum _ConsoleAction { copy, share, showAll, clear }

class ConsoleScreen extends ConsumerStatefulWidget {
  const ConsoleScreen({super.key});

  @override
  ConsumerState<ConsoleScreen> createState() => _ConsoleScreenState();
}

class _ConsoleScreenState extends ConsumerState<ConsoleScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final consoleState = ref.watch(consoleNotifierProvider);

    // Auto-scroll on new entries
    ref.listen<ConsoleState>(consoleNotifierProvider, (prev, next) {
      if (next.filter.autoScroll &&
          next.filteredCount > (prev?.filteredCount ?? 0)) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117), // GitHub dark background
      appBar: _buildAppBar(context, consoleState),
      body: Column(
        children: [
          // Stats bar
          _StatsBar(consoleState: consoleState),

          // Search bar (toggleable)
          if (_showSearch)
            _SearchBar(
              controller: _searchController,
              onChanged: (q) =>
                  ref.read(consoleNotifierProvider.notifier).setSearchQuery(q),
              onClear: () {
                _searchController.clear();
                ref.read(consoleNotifierProvider.notifier).clearSearch();
              },
            ),

          // Level filter chips
          _LevelFilterBar(filter: consoleState.filter),

          // Log list
          Expanded(
            child: consoleState.filteredEntries.isEmpty
                ? _buildEmptyState(context)
                : _LogList(
                    entries: consoleState.filteredEntries,
                    scrollController: _scrollController,
                  ),
          ),

          // Pause / scroll controls
          _BottomControlBar(
            isPaused: consoleState.filter.isPaused,
            autoScroll: consoleState.filter.autoScroll,
            onPauseToggle: () =>
                ref.read(consoleNotifierProvider.notifier).togglePause(),
            onAutoScrollToggle: () =>
                ref.read(consoleNotifierProvider.notifier).toggleAutoScroll(),
            onScrollToBottom: _scrollToBottom,
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, ConsoleState consoleState) {
    return AppBar(
      backgroundColor: const Color(0xFF161B22),
      foregroundColor: Colors.white,
      title: Row(
        children: [
          const Icon(Icons.terminal_rounded, size: 20),
          const SizedBox(width: 8),
          const Text('Developer Console',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${consoleState.filteredCount}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            _showSearch ? Icons.search_off_rounded : Icons.search_rounded,
          ),
          tooltip: 'Search',
          onPressed: () => setState(() => _showSearch = !_showSearch),
        ),
        PopupMenuButton<_ConsoleAction>(
          icon: const Icon(Icons.more_vert_rounded),
          color: const Color(0xFF21262D),
          onSelected: (action) => _handleAction(action, consoleState),
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: _ConsoleAction.copy,
              child: _MenuRow(Icons.copy_rounded, 'Copy All'),
            ),
            const PopupMenuItem(
              value: _ConsoleAction.share,
              child: _MenuRow(Icons.share_rounded, 'Share Logs'),
            ),
            const PopupMenuItem(
              value: _ConsoleAction.showAll,
              child: _MenuRow(Icons.visibility_rounded, 'Show All Levels'),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: _ConsoleAction.clear,
              child: _MenuRow(Icons.delete_outline_rounded, 'Clear Logs',
                  color: Colors.redAccent),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleAction(_ConsoleAction action, ConsoleState state) async {
    switch (action) {
      case _ConsoleAction.copy:
        final text = ref.read(consoleNotifierProvider.notifier).exportLogs();
        await Clipboard.setData(ClipboardData(text: text));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Logs copied to clipboard')),
          );
        }
        break;
      case _ConsoleAction.share:
        final text = ref.read(consoleNotifierProvider.notifier).exportLogs();
        await Share.share(
          text,
          subject: 'Gitty Console Logs',
        );
        break;
      case _ConsoleAction.showAll:
        ref.read(consoleNotifierProvider.notifier).showAllLevels();
        break;
      case _ConsoleAction.clear:
        _showClearConfirm();
        break;
    }
  }

  void _showClearConfirm() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF21262D),
        title: const Text('Clear Logs', style: TextStyle(color: Colors.white)),
        content: const Text('This will remove all log entries.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(consoleNotifierProvider.notifier).clearLogs();
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.terminal_rounded, size: 48, color: Colors.white24),
          SizedBox(height: 16),
          Text('No logs yet',
              style: TextStyle(color: Colors.white38, fontSize: 16)),
          SizedBox(height: 8),
          Text('Perform actions to see log output here.',
              style: TextStyle(color: Colors.white24, fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Sub-Widgets ───────────────────────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.consoleState});
  final ConsoleState consoleState;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF161B22),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          _StatChip(
            label: '${consoleState.errorCount} errors',
            color: Colors.redAccent,
            icon: Icons.error_outline_rounded,
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: '${consoleState.warningCount} warnings',
            color: Colors.amber,
            icon: Icons.warning_amber_rounded,
          ),
          const Spacer(),
          Text(
            '${consoleState.totalCount} total',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip(
      {required this.label, required this.color, required this.icon});
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar(
      {required this.controller,
      required this.onChanged,
      required this.onClear});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF161B22),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        autofocus: true,
        style: const TextStyle(
            color: Colors.white, fontFamily: 'JetBrainsMono', fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Filter logs…',
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon:
              const Icon(Icons.search_rounded, color: Colors.white38, size: 18),
          suffixIcon: IconButton(
            icon: const Icon(Icons.close_rounded,
                color: Colors.white38, size: 18),
            onPressed: onClear,
          ),
          filled: true,
          fillColor: const Color(0xFF0D1117),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.white12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.white12),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }
}

class _LevelFilterBar extends ConsumerWidget {
  const _LevelFilterBar({required this.filter});
  final ConsoleFilterState filter;

  static const _levels = [
    ConsoleLogLevel.error,
    ConsoleLogLevel.warning,
    ConsoleLogLevel.success,
    ConsoleLogLevel.request,
    ConsoleLogLevel.info,
    ConsoleLogLevel.debug,
    ConsoleLogLevel.verbose,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: const Color(0xFF161B22),
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: _levels.map((level) {
          final isVisible = filter.isLevelVisible(level);
          final color = _levelColor(level);
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => ref
                  .read(consoleNotifierProvider.notifier)
                  .toggleLevel(level),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isVisible ? color.withValues(alpha: 0.15) : Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isVisible ? color.withValues(alpha: 0.5) : Colors.white12,
                  ),
                ),
                child: Text(
                  level.label,
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isVisible ? color : Colors.white24,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _levelColor(ConsoleLogLevel level) => switch (level) {
        ConsoleLogLevel.verbose => Colors.white54,
        ConsoleLogLevel.debug   => const Color(0xFF79C0FF),
        ConsoleLogLevel.info    => const Color(0xFF58A6FF),
        ConsoleLogLevel.request => const Color(0xFFD2A8FF),
        ConsoleLogLevel.success => const Color(0xFF56D364),
        ConsoleLogLevel.warning => const Color(0xFFE3B341),
        ConsoleLogLevel.error   => const Color(0xFFF85149),
        ConsoleLogLevel.fatal   => const Color(0xFFFF4444),
      };
}

class _LogList extends StatelessWidget {
  const _LogList({
    required this.entries,
    required this.scrollController,
  });

  final List<ConsoleLogEntry> entries;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: entries.length,
      itemBuilder: (_, i) => _LogTile(entry: entries[i]),
    );
  }
}

class _LogTile extends StatefulWidget {
  const _LogTile({required this.entry});
  final ConsoleLogEntry entry;

  @override
  State<_LogTile> createState() => _LogTileState();
}

class _LogTileState extends State<_LogTile> {
  bool _expanded = false;

  Color _levelColor(ConsoleLogLevel level) => switch (level) {
        ConsoleLogLevel.verbose => Colors.white38,
        ConsoleLogLevel.debug   => const Color(0xFF79C0FF),
        ConsoleLogLevel.info    => const Color(0xFF58A6FF),
        ConsoleLogLevel.request => const Color(0xFFD2A8FF),
        ConsoleLogLevel.success => const Color(0xFF56D364),
        ConsoleLogLevel.warning => const Color(0xFFE3B341),
        ConsoleLogLevel.error   => const Color(0xFFF85149),
        ConsoleLogLevel.fatal   => const Color(0xFFFF4444),
      };

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(widget.entry.level);
    final hasDetails =
        widget.entry.details != null || widget.entry.error != null;

    return GestureDetector(
      onTap: hasDetails ? () => setState(() => _expanded = !_expanded) : null,
      onLongPress: () {
        final text = widget.entry.toString();
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Log entry copied'),
            duration: Duration(seconds: 1),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: _expanded ? const Color(0x0DFFFFFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: _expanded
              ? Border.all(color: color.withValues(alpha: 0.3))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Level badge
                Container(
                  width: 32,
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    widget.entry.level.label,
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Timestamp
                Text(
                  widget.entry.formattedTime,
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 10,
                    color: Colors.white38,
                  ),
                ),
                const SizedBox(width: 8),

                // Tag
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    widget.entry.tag,
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 10,
                      color: Colors.white54,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Expand indicator
                if (hasDetails)
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 14,
                    color: Colors.white24,
                  ),
              ],
            ),
            const SizedBox(height: 3),

            // Message
            Text(
              widget.entry.message,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
                color: color,
                height: 1.4,
              ),
            ),

            // Expanded details
            if (_expanded && widget.entry.details != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  widget.entry.details!,
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 11,
                    color: Colors.white54,
                    height: 1.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomControlBar extends StatelessWidget {
  const _BottomControlBar({
    required this.isPaused,
    required this.autoScroll,
    required this.onPauseToggle,
    required this.onAutoScrollToggle,
    required this.onScrollToBottom,
  });

  final bool isPaused;
  final bool autoScroll;
  final VoidCallback onPauseToggle;
  final VoidCallback onAutoScrollToggle;
  final VoidCallback onScrollToBottom;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF161B22),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Pause / Resume
          _ControlButton(
            icon: isPaused
                ? Icons.play_arrow_rounded
                : Icons.pause_rounded,
            label: isPaused ? 'Resume' : 'Pause',
            color: isPaused ? Colors.green : Colors.amber,
            onTap: onPauseToggle,
          ),
          const SizedBox(width: 12),

          // Auto-scroll toggle
          _ControlButton(
            icon: Icons.vertical_align_bottom_rounded,
            label: 'Auto-scroll',
            color: autoScroll
                ? const Color(0xFF58A6FF)
                : Colors.white38,
            onTap: onAutoScrollToggle,
          ),
          const Spacer(),

          // Scroll to bottom
          _ControlButton(
            icon: Icons.arrow_downward_rounded,
            label: 'Bottom',
            color: Colors.white54,
            onTap: onScrollToBottom,
          ),
        ],
      ),
    );
  }
}

// ── تعريف القطع المفقودة ─────────────────────────────────────────────────────

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label, {this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color ?? Colors.white),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: color ?? Colors.white)),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}