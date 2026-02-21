import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gitty/core/error/exceptions.dart';
import 'package:gitty/core/firebase/remote_config_service.dart';

sealed class KillSwitchState {
  const KillSwitchState();
}

final class KillSwitchActive extends KillSwitchState {
  const KillSwitchActive();
}

final class KillSwitchTriggered extends KillSwitchState {
  const KillSwitchTriggered({required this.message, this.updateUrl});
  final String message;
  final String? updateUrl;
}

final class KillSwitchLoading extends KillSwitchState {
  const KillSwitchLoading();
}

class KillSwitchService {
  KillSwitchService({required RemoteConfigService remoteConfigService})
      : _remoteConfig = remoteConfigService;
  final RemoteConfigService _remoteConfig;

  KillSwitchState get currentState => _remoteConfig.isKillSwitchEnabled
      ? KillSwitchTriggered(
          message: _remoteConfig.killSwitchMessage,
          updateUrl: _remoteConfig.killSwitchUpdateUrl)
      : const KillSwitchActive();

  bool get isAppEnabled => !_remoteConfig.isKillSwitchEnabled;

  void assertAppEnabled() {
    if (_remoteConfig.isKillSwitchEnabled) {
      throw AppDisabledException(
        reason: _remoteConfig.killSwitchMessage,
        updateUrl: _remoteConfig.killSwitchUpdateUrl,
      );
    }
  }

  Stream<KillSwitchState> get stateStream =>
      _remoteConfig.onConfigUpdated.map((_) => currentState);
}

final killSwitchServiceProvider = Provider<KillSwitchService>((ref) =>
    KillSwitchService(
        remoteConfigService: ref.watch(remoteConfigServiceProvider)));

final killSwitchStateProvider = FutureProvider<KillSwitchState>((ref) async {
  final remoteConfig = ref.watch(remoteConfigServiceProvider);
  await remoteConfig.initialize();
  return ref.watch(killSwitchServiceProvider).currentState;
});
