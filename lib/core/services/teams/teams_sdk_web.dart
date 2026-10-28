import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';

import 'teams_sdk_base.dart';

export 'teams_sdk_base.dart';

/// Web: talks to the teams-js UMD bundle (`window.microsoftTeams`), which
/// web/index.html injects only when the page is framed.
TeamsSdk createTeamsSdk() => _WebTeamsSdk();

// --- globals set by web/index.html -------------------------------------------

@JS('attendixInIframe')
external JSBoolean? get _attendixInIframe;

@JS('attendixTeamsSdk')
external JSPromise<JSBoolean>? get _attendixTeamsSdk;

@JS('microsoftTeams')
external _MsTeams? get _microsoftTeams;

// --- teams-js surface (only what the app uses) --------------------------------

extension type _MsTeams._(JSObject _) implements JSObject {
  external _MsApp get app;
  external _MsAuthentication get authentication;
  external _MsPages get pages;
}

extension type _MsApp._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> initialize();
  external void notifySuccess();
  external JSPromise<_MsContext> getContext();
  external void registerOnThemeChangeHandler(JSFunction handler);
}

extension type _MsContext._(JSObject _) implements JSObject {
  external _MsAppInfo? get app;
}

extension type _MsAppInfo._(JSObject _) implements JSObject {
  external JSString? get theme;
}

extension type _MsAuthentication._(JSObject _) implements JSObject {
  external JSPromise<JSString> getAuthToken();
}

extension type _MsPages._(JSObject _) implements JSObject {
  external _MsPagesConfig get config;
}

extension type _MsPagesConfig._(JSObject _) implements JSObject {
  external void registerOnSaveHandler(JSFunction handler);
  external JSPromise<JSAny?> setConfig(JSObject config);
  external void setValidityState(JSBoolean valid);
}

extension type _MsSaveEvent._(JSObject _) implements JSObject {
  external void notifySuccess();
  external void notifyFailure(JSString reason);
}

class _WebTeamsSdk implements TeamsSdk {
  _MsTeams get _sdk {
    final sdk = _microsoftTeams;
    if (sdk == null) throw StateError('teams-js not loaded');
    return sdk;
  }

  @override
  bool get isFramed {
    try {
      return _attendixInIframe?.toDart ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> ensureLoaded() async {
    try {
      if (_microsoftTeams != null) return true;
      final loading = _attendixTeamsSdk;
      if (loading == null) return false;
      final ok = (await loading.toDart).toDart;
      return ok && _microsoftTeams != null;
    } catch (e) {
      debugPrint('[teams] SDK load failed: $e');
      return false;
    }
  }

  @override
  Future<void> initialize() async {
    await _sdk.app.initialize().toDart;
  }

  @override
  void notifySuccess() {
    try {
      _sdk.app.notifySuccess();
    } catch (_) {}
  }

  @override
  Future<String?> getTheme() async {
    final ctx = await _sdk.app.getContext().toDart;
    return ctx.app?.theme?.toDart;
  }

  @override
  void onThemeChange(void Function(String theme) handler) {
    try {
      _sdk.app.registerOnThemeChangeHandler(
        ((JSString theme) => handler(theme.toDart)).toJS,
      );
    } catch (e) {
      debugPrint('[teams] theme handler failed: $e');
    }
  }

  @override
  Future<String> getAuthToken() async {
    final token = await _sdk.authentication.getAuthToken().toDart;
    return token.toDart;
  }

  @override
  void registerConfigSaveHandler(
    TeamsTabConfig? Function() buildConfig,
    String failureMessage,
  ) {
    try {
      _sdk.pages.config.registerOnSaveHandler(
        ((_MsSaveEvent saveEvent) {
          final config = buildConfig();
          if (config == null) {
            saveEvent.notifyFailure(failureMessage.toJS);
            return;
          }
          final jsConfig = <String, Object>{
            'entityId': config.entityId,
            'contentUrl': config.contentUrl,
            'websiteUrl': config.websiteUrl,
            'suggestedDisplayName': config.suggestedDisplayName,
          }.jsify()! as JSObject;
          _sdk.pages.config.setConfig(jsConfig).toDart.then(
            (_) => saveEvent.notifySuccess(),
            onError: (Object _) =>
                saveEvent.notifyFailure(failureMessage.toJS),
          );
        }).toJS,
      );
    } catch (e) {
      debugPrint('[teams] registerOnSaveHandler failed: $e');
    }
  }

  @override
  void setValidityState(bool valid) {
    try {
      _sdk.pages.config.setValidityState(valid.toJS);
    } catch (_) {}
  }
}
