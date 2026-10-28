/// Tab configuration saved by the Teams config dialog
/// (`pages.config.setConfig` in teams-js).
class TeamsTabConfig {
  const TeamsTabConfig({
    required this.entityId,
    required this.contentUrl,
    required this.websiteUrl,
    required this.suggestedDisplayName,
  });

  final String entityId;
  final String contentUrl;
  final String websiteUrl;
  final String suggestedDisplayName;

  @override
  bool operator ==(Object other) =>
      other is TeamsTabConfig &&
      other.entityId == entityId &&
      other.contentUrl == contentUrl &&
      other.websiteUrl == websiteUrl &&
      other.suggestedDisplayName == suggestedDisplayName;

  @override
  int get hashCode =>
      Object.hash(entityId, contentUrl, websiteUrl, suggestedDisplayName);
}

/// Thin abstraction over the teams-js calls the app uses (Ionic TeamsService /
/// TeamsConfigPage). Synchronous methods never throw; async methods may
/// throw and callers catch.
abstract class TeamsSdk {
  /// True when the page runs framed (Teams tabs always are). Outside an
  /// iframe the SDK is not even loaded.
  bool get isFramed;

  /// Waits until the SDK script is loaded; false if it is not available.
  Future<bool> ensureLoaded();

  /// `app.initialize()` – never completes outside Teams (caller races it).
  Future<void> initialize();

  /// `app.notifySuccess()` – stops the Teams loading spinner.
  void notifySuccess();

  /// `app.getContext()` → `context.app.theme` ('default' | 'dark' | 'contrast').
  Future<String?> getTheme();

  /// `app.registerOnThemeChangeHandler`.
  void onThemeChange(void Function(String theme) handler);

  /// `authentication.getAuthToken()` – Entra (AAD) token for the SSO exchange.
  Future<String> getAuthToken();

  /// `pages.config.registerOnSaveHandler` + `setConfig` +
  /// `saveEvent.notifySuccess/notifyFailure(failureMessage)`.
  /// [buildConfig] returning null fails the save.
  void registerConfigSaveHandler(
    TeamsTabConfig? Function() buildConfig,
    String failureMessage,
  );

  /// `pages.config.setValidityState` – enables the Teams "Save" button.
  void setValidityState(bool valid);
}
