import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gitty/core/console/console_log_service.dart';

// ── Filter State ──────────────────────────────────────────────────────────────

class ConsoleFilterState {
  const ConsoleFilterState({
    this.hiddenLevels = const {},
    this.searchQuery = '',
    this.isPaused = false,
    this.autoScroll = true,
  });

  final Set<ConsoleLogLevel> hiddenLevels;
  final String searchQuery;
  final bool isPaused;
  final bool autoScroll;

  bool isLevelVisible(ConsoleLogLevel level) => !hiddenLevels.contains(level);

  List<ConsoleLogEntry> applyTo(List<ConsoleLogEntry> entries) {
    var filtered = entries.where((e) => isLevelVisible(e.level)).toList();
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      filtered = filtered
          .where((e) =>
              e.message.toLowerCase().contains(q) ||
              e.tag.toLowerCase().contains(q) ||
              (e.details?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    return filtered;
  }

  ConsoleFilterState copyWith({
    Set<ConsoleLogLevel>? hiddenLevels,
    String? searchQuery,
    bool? isPaused,
    bool? autoScroll,
  }) =>
      ConsoleFilterState(
        hiddenLevels: hiddenLevels ?? this.hiddenLevels,
        searchQuery: searchQuery ?? this.searchQuery,
        isPaused: isPaused ?? this.isPaused,
        autoScroll: autoScroll ?? this.autoScroll,
      );
}

// ── Console State ─────────────────────────────────────────────────────────────

class ConsoleState {
  const ConsoleState({
    required this.allEntries,
    required this.filteredEntries,
    required this.filter,
  });

  final List<ConsoleLogEntry> allEntries;
  final List<ConsoleLogEntry> filteredEntries;
  final ConsoleFilterState filter;

  int get totalCount => allEntries.length;
  int get filteredCount => filteredEntries.length;
  int get errorCount => allEntries
      .where((e) =>
          e.level == ConsoleLogLevel.error || e.level == ConsoleLogLevel.fatal)
      .length;
  int get warningCount =>
      allEntries.where((e) => e.level == ConsoleLogLevel.warning).length;

  ConsoleState copyWith({
    List<ConsoleLogEntry>? allEntries,
    List<ConsoleLogEntry>? filteredEntries,
    ConsoleFilterState? filter,
  }) =>
      ConsoleState(
        allEntries: allEntries ?? this.allEntries,
        filteredEntries: filteredEntries ?? this.filteredEntries,
        filter: filter ?? this.filter,
      );
}

// ── Console Notifier ──────────────────────────────────────────────────────────

class ConsoleNotifier extends Notifier<ConsoleState> {
  StreamSubscription<ConsoleLogEntry>? _subscription;

  @override
  ConsoleState build() {
    final service = ref.watch(consoleLogServiceProvider);
    _subscription?.cancel();
    _subscription = service.stream.listen(_onNewEntry);
    ref.onDispose(() => _subscription?.cancel());
    return ConsoleState(
      allEntries: List.of(service.entries),
      filteredEntries: List.of(service.entries),
      filter: const ConsoleFilterState(),
    );
  }

  void _onNewEntry(ConsoleLogEntry entry) {
    if (state.filter.isPaused) return;
    final updated = [...state.allEntries, entry];
    state = state.copyWith(
      allEntries: updated,
      filteredEntries: state.filter.applyTo(updated),
    );
  }

  void toggleLevel(ConsoleLogLevel level) {
    final hidden = Set<ConsoleLogLevel>.from(state.filter.hiddenLevels);
    if (hidden.contains(level)) {
      hidden.remove(level);
    } else {
      hidden.add(level);
    }
    _updateFilter(state.filter.copyWith(hiddenLevels: hidden));
  }

  void setSearchQuery(String query) =>
      _updateFilter(state.filter.copyWith(searchQuery: query));
  void clearSearch() => _updateFilter(state.filter.copyWith(searchQuery: ''));
  void showAllLevels() =>
      _updateFilter(state.filter.copyWith(hiddenLevels: {}));
  void togglePause() =>
      _updateFilter(state.filter.copyWith(isPaused: !state.filter.isPaused));
  void toggleAutoScroll() => _updateFilter(
      state.filter.copyWith(autoScroll: !state.filter.autoScroll));

  void clearLogs() {
    ref.read(consoleLogServiceProvider).clear();
    state = state.copyWith(allEntries: [], filteredEntries: []);
  }

  String exportLogs() => ref.read(consoleLogServiceProvider).export();

  void _updateFilter(ConsoleFilterState filter) => state = state.copyWith(
        filter: filter,
        filteredEntries: filter.applyTo(state.allEntries),
      );
}

final consoleNotifierProvider =
    NotifierProvider<ConsoleNotifier, ConsoleState>(ConsoleNotifier.new);
