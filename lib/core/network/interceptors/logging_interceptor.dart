import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import 'package:gitty/core/console/console_log_service.dart';

/// Intercepts all HTTP traffic and emits structured, colored log entries
/// to the [ConsoleLogService] (visible in Developer Console screen).
/// In release builds, sensitive data (Authorization headers) is redacted.
class LoggingInterceptor extends Interceptor {
  LoggingInterceptor({
    required ConsoleLogService consoleLogService,
    Logger? logger,
  })  : _console = consoleLogService,
        _logger = logger ?? Logger(printer: PrettyPrinter(methodCount: 0));

  final ConsoleLogService _console;
  final Logger _logger;

  // Track request timing
  final Map<String, DateTime> _requestTimestamps = {};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final requestId = _generateRequestId();
    options.extra['requestId'] = requestId;
    options.extra['startTime'] = DateTime.now().millisecondsSinceEpoch;

    _requestTimestamps[requestId] = DateTime.now();

    final sanitizedHeaders = _sanitizeHeaders(options.headers);

    final logMessage = '''
┌─ REQUEST [$requestId] ────────────────────────────────
│ ${options.method.toUpperCase()} ${options.uri}
│ Headers: ${_prettyJson(sanitizedHeaders)}
${options.data != null ? '│ Body: ${_prettyJson(options.data)}' : ''}
└───────────────────────────────────────────────────────''';

    _console.log(
      message: '${options.method} ${options.path}',
      level: ConsoleLogLevel.request,
      details: logMessage,
      tag: 'Network',
    );

    _logger.d(logMessage);

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final requestId = response.requestOptions.extra['requestId'] as String?;
    final startTime = response.requestOptions.extra['startTime'] as int? ??
        DateTime.now().millisecondsSinceEpoch;
    final duration = DateTime.now().millisecondsSinceEpoch - startTime;

    if (requestId != null) _requestTimestamps.remove(requestId);

    final statusCode = response.statusCode ?? 0;
    final level = statusCode >= 200 && statusCode < 300
        ? ConsoleLogLevel.success
        : ConsoleLogLevel.warning;

    // Check for rate limit warning injected by AuthInterceptor
    final rateLimitWarning =
        response.requestOptions.extra['rateLimitWarning'] as String?;
    if (rateLimitWarning != null) {
      _console.log(
        message: rateLimitWarning,
        level: ConsoleLogLevel.warning,
        tag: 'RateLimit',
      );
    }

    final logMessage = '''
┌─ RESPONSE [$requestId] [$duration ms] ────────────────
│ ${statusCode} ${response.statusMessage}
│ ${response.requestOptions.method} ${response.requestOptions.path}
│ Body: ${_truncateBody(response.data)}
└───────────────────────────────────────────────────────''';

    _console.log(
      message: '${statusCode} ${response.requestOptions.path} (${duration}ms)',
      level: level,
      details: logMessage,
      tag: 'Network',
    );

    _logger.i(logMessage);

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final requestId = err.requestOptions.extra['requestId'] as String?;
    final startTime = err.requestOptions.extra['startTime'] as int? ??
        DateTime.now().millisecondsSinceEpoch;
    final duration = DateTime.now().millisecondsSinceEpoch - startTime;

    if (requestId != null) _requestTimestamps.remove(requestId);

    final logMessage = '''
┌─ ERROR [$requestId] [$duration ms] ───────────────────
│ ${err.type.name.toUpperCase()}: ${err.message}
│ ${err.requestOptions.method} ${err.requestOptions.path}
│ Status: ${err.response?.statusCode}
│ Response: ${_truncateBody(err.response?.data)}
└───────────────────────────────────────────────────────''';

    _console.log(
      message: 'ERROR ${err.requestOptions.path} — ${err.message}',
      level: ConsoleLogLevel.error,
      details: logMessage,
      tag: 'Network',
    );

    _logger.e(logMessage);

    handler.next(err);
  }

  // ── Private Helpers ──────────────────────────────────────────────────────

  String _generateRequestId() {
    final now = DateTime.now();
    return '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}'
        '${now.millisecond.toString().padLeft(3, '0')}';
  }

  /// Redacts Authorization header in release builds.
  Map<String, dynamic> _sanitizeHeaders(Map<String, dynamic> headers) {
    final sanitized = Map<String, dynamic>.from(headers);

    bool isRelease = true;
    assert(() {
      isRelease = false;
      return true;
    }());

    if (isRelease && sanitized.containsKey('Authorization')) {
      sanitized['Authorization'] = 'Bearer [REDACTED]';
    }

    return sanitized;
  }

  String _prettyJson(dynamic data) {
    if (data == null) return 'null';
    try {
      return const JsonEncoder.withIndent('  ').convert(data);
    } on Exception {
      return data.toString();
    }
  }

  String _truncateBody(dynamic data) {
    final raw = _prettyJson(data);
    const maxLength = 500;
    if (raw.length <= maxLength) return raw;
    return '${raw.substring(0, maxLength)}... [truncated ${raw.length - maxLength} chars]';
  }
}
