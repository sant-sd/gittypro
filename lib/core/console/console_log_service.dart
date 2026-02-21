import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:collection';



// ── Log Level ──────────────────────────────────────────────────────────────────

enum ConsoleLogLevel {
  verbose,
  debug,
  info,
  request,
  success,
  warning,
  error,
  fatal;

  String get label => switch (this) {
        ConsoleLogLevel.verbose => 'VRB',
        ConsoleLogLevel.debug   => 'DBG',
        ConsoleLogLevel.info    => 'INF',
        ConsoleLogLevel.request => 'REQ',
        ConsoleLogLevel.success => 'OK ',
        ConsoleLogLevel.warning => 'WRN',
        ConsoleLogLevel.error   => 'ERR',
        ConsoleLogLevel.fatal   => 'FTL',
      };

  /// ANSI color codes for terminal / console rendering
  String get ansiColor => switch (this) {
        ConsoleLogLevel.verbose => '\x1B[37m',   // White
        ConsoleLogLevel.debug   => '\x1B[36m',   // Cyan
        ConsoleLogLevel.info    => '\x1B[34m',   // Blue
        ConsoleLogLevel.request => '\x1B[35m',   // Magenta
        ConsoleLogLevel.success => '\x1B[32m',   // Green
        ConsoleLogLevel.warning => '\x1B[33m',   // Yellow
        ConsoleLogLevel.error   => '\x1B[31m',   // Red
        ConsoleLogLevel.fatal   => '\x1B[41m',   // Red background
      };
}

// ── Log Entry ──────────────────────────────────────────────────────────────────

final class ConsoleLogEntry {
  const ConsoleLogEntry({
    required this.id,
    required this.timestamp,
    required this.level,
    required this.message,
    required this.tag,
    this.details,
    this.error,
    this.stackTrace,
  });

  final int id;
  final DateTime timestamp;
  final ConsoleLogLevel level;
  final String message;
  final String tag;
  final String? details;
  final Object? error;
  final StackTrace? stackTrace;

  String get formattedTime =>
      '${timestamp.hour.toString().padLeft(2, '0')}:'
      '${timestamp.minute.toString().padLeft(2, '0')}:'
      '${timestamp.second.toString().padLeft(2, '0')}.'
      '${timestamp.millisecond.toString().padLeft(3, '0')}';

  /// Returns a color-coded string for terminal output
  String toAnsiString() {
    final reset = '\x1B[0m';
    final color = level.ansiColor;
    return '$color[${level.label}]$reset [$formattedTime] [$tag] $message';
  }

  @override
  String toString() => '[${level.label}] [$formattedTime] [$tag] $message';
}

// ── Console Log Service ────────────────────────────────────────────────────────

/// Central service that captures, stores, and streams log entries.
/// Acts as the data source for the Developer Console screen.
/// Maintains a circular buffer of [maxEntries] to prevent memory growth.
class ConsoleLogService {
  ConsoleLogService({int maxEntries = 1000}) : _maxEntries = maxEntries;

  final int _maxEntries;
  int _idCounter = 0;

  final Queue<ConsoleLogEntry> _entries = Queue();
  final StreamController<ConsoleLogEntry> _streamController =
      StreamController<ConsoleLogEntry>.broadcast();

  // ── Public API ─────────────────────────────────────────────────────────────

  /// All captured log entries (most recent last).
  List<ConsoleLogEntry> get entries => List.unmodifiable(_entries);

  /// Stream of new log entries as they arrive. Use in Developer Console.
  Stream<ConsoleLogEntry> get stream => _streamController.stream;

  /// Emits a new log entry.
  void log({
    required String message,
    required ConsoleLogLevel level,
    String tag = 'Gitty',
    String? details,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final entry = ConsoleLogEntry(
      id: ++_idCounter,
      timestamp: DateTime.now(),
      level: level,
      message: message,
      tag: tag,
      details: details,
      error: error,
      stackTrace: stackTrace,
    );

    _addEntry(entry);

    // Also print to dart:developer in debug builds
    assert(() {
      // ignore: avoid_print
      print(entry.toAnsiString());
      return true;
    }());
  }

  // Convenience methods
  void verbose(String message, {String tag = 'Gitty'}) =>
      log(message: message, level: ConsoleLogLevel.verbose, tag: tag);

  void debug(String message, {String tag = 'Gitty'}) =>
      log(message: message, level: ConsoleLogLevel.debug, tag: tag);

  void info(String message, {String tag = 'Gitty'}) =>
      log(message: message, level: ConsoleLogLevel.info, tag: tag);

  void success(String message, {String tag = 'Gitty'}) =>
      log(message: message, level: ConsoleLogLevel.success, tag: tag);

  void warning(String message, {String tag = 'Gitty'}) =>
      log(message: message, level: ConsoleLogLevel.warning, tag: tag);

  void error(
    String message, {
    String tag = 'Gitty',
    Object? error,
    StackTrace? stackTrace,
  }) =>
      log(
        message: message,
        level: ConsoleLogLevel.error,
        tag: tag,
        error: error,
        stackTrace: stackTrace,
      );

  /// Clears all log entries.
  void clear() {
    _entries.clear();
  }

  /// Exports all entries as a plain-text string (for share/copy).
  String export() {
    final buffer = StringBuffer()
      ..writeln('=== Gitty Developer Console Export ===')
      ..writeln('Exported: ${DateTime.now().toIso8601String()}')
      ..writeln('Total entries: ${_entries.length}')
      ..writeln('=' * 40)
      ..writeln();
    for (final entry in _entries) {
      buffer
        ..writeln(entry.toString())
        ..writeln(entry.details ?? '')
        ..writeln(entry.error != null ? '  Error: ${entry.error}' : '');
    }
    return buffer.toString();
  }

  void dispose() {
    _streamController.close();
  }

  // ── Private ────────────────────────────────────────────────────────────────

  void _addEntry(ConsoleLogEntry entry) {
    if (_entries.length >= _maxEntries) {
      _entries.removeFirst(); // Circular buffer
    }
    _entries.addLast(entry);
    _streamController.add(entry);
  }
}

// ── Riverpod Provider ──────────────────────────────────────────────────────────

final consoleLogServiceProvider = Provider<ConsoleLogService>((ref) {
  final service = ConsoleLogService();
  ref.onDispose(service.dispose);
  return service;
});
