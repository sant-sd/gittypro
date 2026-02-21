import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


/// Keys for all Remote Config parameters.
/// Centralised here to avoid magic strings across the codebase.
abstract final class RemoteConfigKeys {
  // Kill Switch
  static const String killSwitchEnabled = 'kill_switch_enabled';
  static const String killSwitchMessage = 'kill_switch_message';
  static const String killSwitchUpdateUrl = 'kill_switch_update_url';

  // Feature Flags
  static const String enableConsoleScreen = 'enable_console_screen';
  static const String enableRetryLogic    = 'enable_retry_logic';
  static const String maxUploadFileSizeMb = 'max_upload_file_size_mb';
  static const String maxFilesPerCommit   = 'max_files_per_commit';

  // API
  static const String rateLimitWarningThreshold = 'rate_limit_warning_threshold';
  static const String maxRetryAttempts          = 'max_retry_attempts';
}

/// Default values used before Remote Config values are fetched.
const Map<String, dynamic> _remoteConfigDefaults = {
  RemoteConfigKeys.killSwitchEnabled:        false,
  RemoteConfigKeys.killSwitchMessage:        'This version of Gitty is no longer supported. Please update.',
  RemoteConfigKeys.killSwitchUpdateUrl:      '',
  RemoteConfigKeys.enableConsoleScreen:      true,
  RemoteConfigKeys.enableRetryLogic:         true,
  RemoteConfigKeys.maxUploadFileSizeMb:      100,
  RemoteConfigKeys.maxFilesPerCommit:        100,
  RemoteConfigKeys.rateLimitWarningThreshold: 100,
  RemoteConfigKeys.maxRetryAttempts:         3,
};

/// Wraps [FirebaseRemoteConfig] with typed accessors and automatic refresh.
class RemoteConfigService {
  RemoteConfigService({FirebaseRemoteConfig? remoteConfig})
      : _config = remoteConfig ?? FirebaseRemoteConfig.instance;

  final FirebaseRemoteConfig _config;

  /// Initializes Remote Config with defaults and fetches latest values.
  /// Call once at app startup, before checking Kill Switch.
  Future<void> initialize() async {
    await _config.setDefaults(_remoteConfigDefaults);

    await _config.setConfigSettings(
      RemoteConfigSettings(
        // Fetch every hour in production
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ),
    );

    try {
      await _config.fetchAndActivate();
    } on Exception {
      // Non-fatal: use defaults / cached values if fetch fails
      // App can still function with stale config
    }
  }

  // ── Kill Switch ────────────────────────────────────────────────────────────

  bool get isKillSwitchEnabled =>
      _config.getBool(RemoteConfigKeys.killSwitchEnabled);

  String get killSwitchMessage =>
      _config.getString(RemoteConfigKeys.killSwitchMessage);

  String? get killSwitchUpdateUrl {
    final url = _config.getString(RemoteConfigKeys.killSwitchUpdateUrl);
    return url.isEmpty ? null : url;
  }

  // ── Feature Flags ──────────────────────────────────────────────────────────

  bool get isConsoleScreenEnabled =>
      _config.getBool(RemoteConfigKeys.enableConsoleScreen);

  bool get isRetryLogicEnabled =>
      _config.getBool(RemoteConfigKeys.enableRetryLogic);

  // ── Upload Limits ──────────────────────────────────────────────────────────

  int get maxUploadFileSizeMb =>
      _config.getInt(RemoteConfigKeys.maxUploadFileSizeMb);

  int get maxUploadFileSizeBytes => maxUploadFileSizeMb * 1024 * 1024;

  int get maxFilesPerCommit =>
      _config.getInt(RemoteConfigKeys.maxFilesPerCommit);

  // ── API Settings ───────────────────────────────────────────────────────────

  int get rateLimitWarningThreshold =>
      _config.getInt(RemoteConfigKeys.rateLimitWarningThreshold);

  int get maxRetryAttempts =>
      _config.getInt(RemoteConfigKeys.maxRetryAttempts);

  // ── Stream of config updates ───────────────────────────────────────────────

  /// Emits whenever Remote Config values are updated (real-time updates).
  Stream<RemoteConfigUpdate> get onConfigUpdated =>
      _config.onConfigUpdated;
}

final remoteConfigServiceProvider = Provider<RemoteConfigService>((ref) {
  return RemoteConfigService();
});
