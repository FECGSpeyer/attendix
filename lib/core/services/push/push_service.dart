// PUSH: port of Ionic src/app/services/push/push.service.ts.
//
// Native only (iOS/Android) – on the web every method is a no-op, exactly
// like Ionic (`Capacitor.isNativePlatform()`).
//
// The UI / router side (dialogs, tenant switch, navigation) lives behind
// [PushHost] (see core/providers/push_providers.dart) so this class can be
// unit tested with fakes.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/device_token_repository.dart';
import '../tracking/tracking_event.dart';
import 'push_messaging_client.dart';
import 'push_navigation.dart';

/// localStorage key of Ionic (`push_prompt_shown`).
const String kPushPromptShownKey = 'push_prompt_shown';

/// Persists whether the "Push-Benachrichtigungen aktivieren?" prompt was
/// answered (Ionic localStorage `push_prompt_shown`).
abstract class PushPromptStore {
  Future<bool> wasShown();
  Future<void> markShown();
}

/// UI / navigation side of push handling.
abstract class PushHost {
  /// Ionic alert `svc.pushTitle` / `svc.pushPrompt` with "Später" /
  /// "Aktivieren": true = activate, false = later, null = dismissed.
  Future<bool?> confirmEnablePush();

  /// Ionic foreground alert (title, body, "OK" / "Anzeigen"):
  /// true when the user chose "Anzeigen".
  Future<bool> showForegroundAlert(PushMessage message);

  /// Waits until the startup redirect (login → tenant → home) has landed so
  /// the push navigation runs last and wins (Ionic: first NavigationEnd +
  /// `db.checkToken()`).
  Future<void> waitUntilReadyForNavigation();

  /// Ionic navigateFromData: tenant switch, mark read, navigate.
  Future<void> navigateFromData(Map<String, dynamic> data);

  void track(TrackingEvent event);
}

class PushService {
  PushService({
    required this.client,
    required this.tokens,
    required this.promptStore,
    required this.host,
    required this.isNativePlatform,
    required this.platform,
  });

  final PushMessagingClient client;
  final DeviceTokenStore tokens;
  final PushPromptStore promptStore;
  final PushHost host;

  /// `Capacitor.isNativePlatform()` – false on the web (PWA).
  final bool isNativePlatform;

  /// `Capacitor.getPlatform()`: 'ios' or 'android' (device_tokens.platform).
  final String platform;

  String? _currentToken;
  String? get currentToken => _currentToken;

  /// Set when a push tap arrives; consumed by [handlePendingPushNavigation]
  /// once the startup redirect has landed (Ionic `pendingPushData`).
  Map<String, dynamic>? pendingPushData;

  bool _started = false;
  bool _available = false;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  StreamSubscription<String>? _tokenRefreshSub;

  void _log(String message, [Object? error]) {
    if (kDebugMode) debugPrint('[push] $message${error != null ? ': $error' : ''}');
  }

  /// Ionic constructor → setupPushListeners(): foreground pushes and taps,
  /// plus the notification that cold-started the app.
  Future<void> start() async {
    if (!isNativePlatform || _started) return;
    _started = true;
    _available = await client.initialize();
    if (!_available) return;

    _subscriptions.add(client.onForegroundMessage.listen(_onForegroundMessage));
    _subscriptions.add(client.onMessageOpened.listen(onNotificationTapped));

    final initial = await client.getInitialMessage();
    if (initial != null) await onNotificationTapped(initial);
  }

  Future<void> dispose() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
  }

  Future<void> _onForegroundMessage(PushMessage message) async {
    if (isSilentPush(message.data)) return;
    host.track(TrackingEvent.pushReceived);
    try {
      final show = await host.showForegroundAlert(message);
      if (show) await host.navigateFromData(message.data);
    } catch (e) {
      _log('foreground alert failed', e);
    }
  }

  /// Ionic `notificationActionPerformed`: clear badge, track, navigate.
  Future<void> onNotificationTapped(PushMessage message) async {
    await clearBadge();
    host.track(TrackingEvent.pushOpened);
    pendingPushData = message.data;
    await handlePendingPushNavigation();
  }

  /// Ionic handlePendingPushNavigation (idempotent).
  Future<void> handlePendingPushNavigation() async {
    if (pendingPushData == null) return;
    try {
      await host.waitUntilReadyForNavigation();
    } catch (_) {
      // Router never settled – proceed anyway (Ionic).
    }
    final data = pendingPushData;
    pendingPushData = null;
    if (data == null) return;
    try {
      await host.navigateFromData(data);
    } catch (e) {
      _log('push navigation failed', e);
    }
  }

  Future<void>? _promptInFlight;

  /// Ionic promptAndEnable (after SIGNED_IN): ask once, then register.
  /// Concurrent calls (sign-in + restored session) share one run.
  Future<void> promptAndEnable() {
    if (!isNativePlatform) return Future.value();
    return _promptInFlight ??=
        _promptAndEnable().whenComplete(() => _promptInFlight = null);
  }

  Future<void> _promptAndEnable() async {
    if (!_started) await start();
    if (!_available) return;

    if (await promptStore.wasShown()) {
      await initPush();
      return;
    }

    final permission = await client.checkPermission();
    if (permission == PushPermission.granted) {
      await promptStore.markShown();
      await initPush();
      return;
    }
    if (permission == PushPermission.denied) {
      await promptStore.markShown();
      return;
    }

    final answer = await host.confirmEnablePush();
    if (answer == null) return; // dismissed: ask again next time (Ionic backdrop)
    await promptStore.markShown();
    if (answer) {
      await initPush();
      await _setPushEnabled(true);
    }
  }

  /// Ionic initPush: permission → FCM token → device_tokens, clear badge.
  Future<void> initPush() async {
    if (!isNativePlatform) return;
    if (!_started) await start();
    if (!_available) return;

    final permission = await client.checkPermission();
    if (permission == PushPermission.prompt) {
      final result = await client.requestPermission();
      if (result != PushPermission.granted) return;
    } else if (permission != PushPermission.granted) {
      return;
    }

    _tokenRefreshSub ??= client.onTokenRefresh.listen((token) async {
      if (token.isEmpty) return;
      _currentToken = token;
      await _saveToken(token);
    });

    final token = await client.getToken();
    if (token != null && token.isNotEmpty) {
      _currentToken = token;
      await _saveToken(token);
    } else {
      _log('Push Error: no FCM token received from getToken()');
    }

    // Clear badge when app initializes push
    await clearBadge();
  }

  Future<void> _saveToken(String token) async {
    try {
      await tokens.saveToken(token, platform);
    } catch (e) {
      _log('Save Token Exception', e);
    }
  }

  /// Ionic removeToken (logout): deletes this device's token row and the
  /// FCM token. Call BEFORE `auth.signOut()` so RLS still allows the delete.
  Future<void> removeToken() async {
    if (!isNativePlatform) return;
    final token = _currentToken;
    if (token == null) return;
    _currentToken = null;
    try {
      await tokens.removeToken(token);
    } catch (e) {
      _log('removeToken failed', e);
    }
    // Ionic deletes the FCM token on iOS only.
    if (platform == 'ios') await client.deleteToken();
  }

  /// Ionic togglePush (Einstellungen → Benachrichtigungen).
  Future<void> togglePush(bool enabled) async {
    await _setPushEnabled(enabled);
    if (enabled) await initPush();
  }

  Future<void> _setPushEnabled(bool enabled) async {
    try {
      await tokens.setPushEnabled(enabled);
    } catch (e) {
      _log('setPushEnabled failed', e);
    }
  }

  /// Ionic clearBadge (`Badge.clear()`), also on app resume (autoClear).
  Future<void> clearBadge() async {
    if (!isNativePlatform) return;
    try {
      await client.clearBadge();
    } catch (e) {
      _log('Could not clear badge', e);
    }
  }
}
