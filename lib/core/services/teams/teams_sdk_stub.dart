import 'teams_sdk_base.dart';

export 'teams_sdk_base.dart';

/// Non-web targets: Teams tabs only exist on the web, so everything is a no-op.
TeamsSdk createTeamsSdk() => const NoopTeamsSdk();

/// Bridge that reports "not framed" and does nothing.
class NoopTeamsSdk implements TeamsSdk {
  const NoopTeamsSdk();

  @override
  bool get isFramed => false;

  @override
  Future<bool> ensureLoaded() async => false;

  @override
  Future<void> initialize() =>
      Future.error(StateError('Teams SDK unavailable'));

  @override
  void notifySuccess() {}

  @override
  Future<String?> getTheme() async => null;

  @override
  void onThemeChange(void Function(String theme) handler) {}

  @override
  Future<String> getAuthToken() =>
      Future.error(StateError('Teams SDK unavailable'));

  @override
  void registerConfigSaveHandler(
    TeamsTabConfig? Function() buildConfig,
    String failureMessage,
  ) {}

  @override
  void setValidityState(bool valid) {}
}
