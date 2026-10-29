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
    this.tokenResolveTimeout = const Duration(seconds: 12),
  });

  /// SOL_FIX18: how long [removeToken] waits for the device token (iOS
  /// waits up to 10 s for APNs, see FirebasePushMessagingClient.getToken).
  final Duration tokenResolveTimeout;

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

  /// SOL_FIX16: one shared initialisation (Firebase + listeners). Everything
  /// that reads [_available] awaits it first, so a sign-in processed while
  /// the bootstrap's unawaited [start] is still initialising waits for it
  /// instead of giving up.
  Future<void>? _initialization;
  Future<void>? _startup;
  bool _available = false;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  StreamSubscription<String>? _tokenRefreshSub;

  /// SOL_FIX17: push session generation. [removeToken] (logout) bumps it
  /// synchronously; every registration ([promptAndEnable], [initPush]) and
  /// the token refresh listener capture it at their start and re-check it
  /// after each await and right before every upsert, so a registration
  /// that finishes after the logout never recreates the deleted row.
  int _generation = 0;

  bool _isStale(int generation) => generation != _generation;

  /// SOL_FIX17: token writes that are still running; [removeToken] awaits
  /// them before its final delete.
  final Set<Future<void>> _pendingWrites = {};

  /// SOL_FIX17: tokens written (or being written) in this generation – all
  /// of them are deleted on logout, not only the last one.
  final Set<String> _sessionTokens = {};

  /// SOL_FIX19/SOL_FIX20: the tail of the logout cleanup chain
  /// ([removeToken]). Cleanups never run in parallel: each new one is
  /// chained after the previous tail, so an older cleanup's FCM
  /// `deleteToken` always finishes before a newer one starts. Every
  /// registration awaits the whole chain (the tail) before it touches FCM
  /// or device_tokens, so no cleanup's token lookup, row delete or FCM
  /// `deleteToken` overlaps the next session – that one gets a fresh token
  /// afterwards.
  Future<void>? _cleanup;

  /// SOL_FIX19: set when a registration is requested after the last
  /// cleanup. Without one, a second [removeToken] (signedOut listener after
  /// the logout button) joins the last cleanup instead of running again.
  bool _sessionSinceCleanup = false;

  /// SOL_FIX19/SOL_FIX20: waits for the whole cleanup chain (never throws).
  /// If another cleanup is appended while waiting, waits for the new tail
  /// as well.
  Future<void> _awaitCleanup() async {
    while (true) {
      final tail = _cleanup;
      if (tail == null) return;
      try {
        await tail;
      } catch (_) {}
      if (identical(tail, _cleanup)) return;
    }
  }

  void _log(String message, [Object? error]) {
    if (kDebugMode) debugPrint('[push] $message${error != null ? ': $error' : ''}');
  }

  /// Ionic constructor → setupPushListeners(): foreground pushes and taps,
  /// plus the notification that cold-started the app. Idempotent: every
  /// call returns the same run.
  Future<void> start() {
    if (!isNativePlatform) return Future.value();
    return _startup ??= _start();
  }

  Future<void> _start() async {
    await _ensureInitialized();
    if (!_available) return;
    try {
      final initial = await client.getInitialMessage();
      if (initial != null) await onNotificationTapped(initial);
    } catch (e) {
      _log('initial message failed', e);
    }
  }

  /// SOL_FIX16: the shared initialisation, started once.
  Future<void> _ensureInitialized() => _initialization ??= _initialize();

  /// SOL_FIX16: makes sure [start] runs (cold-start handling) and waits for
  /// the shared initialisation – not for the cold-start navigation.
  Future<void> _ready() {
    unawaited(start());
    return _ensureInitialized();
  }

  Future<void> _initialize() async {
    try {
      _available = await client.initialize();
    } catch (e) {
      _log('initialize failed', e);
      _available = false;
    }
    if (!_available) return;

    _subscriptions.add(client.onForegroundMessage.listen(_onForegroundMessage));
    _subscriptions.add(client.onMessageOpened.listen(onNotificationTapped));
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
  int? _promptGeneration;

  /// Ionic promptAndEnable (after SIGNED_IN): ask once, then register.
  /// Concurrent calls (sign-in + restored session) share one run – of the
  /// same generation only (SOL_FIX17): a sign-in after a logout starts a new
  /// run instead of joining the cancelled one.
  Future<void> promptAndEnable() {
    if (!isNativePlatform) return Future.value();
    _sessionSinceCleanup = true;
    final generation = _generation;
    final running = _promptInFlight;
    if (running != null && _promptGeneration == generation) return running;
    late final Future<void> run;
    run = _promptAndEnable(generation).whenComplete(() {
      if (identical(_promptInFlight, run)) {
        _promptInFlight = null;
        _promptGeneration = null;
      }
    });
    _promptGeneration = generation;
    return _promptInFlight = run;
  }

  Future<void> _promptAndEnable(int generation) async {
    // SOL_FIX19: a logout cleanup still running finishes first.
    await _awaitCleanup();
    await _ready();
    if (!_available || _isStale(generation)) return;

    if (await promptStore.wasShown()) {
      await _initPush(generation);
      return;
    }

    final permission = await client.checkPermission();
    if (_isStale(generation)) return;
    if (permission == PushPermission.granted) {
      await promptStore.markShown();
      await _initPush(generation);
      return;
    }
    if (permission == PushPermission.denied) {
      await promptStore.markShown();
      return;
    }

    final answer = await host.confirmEnablePush();
    if (answer == null) return; // dismissed: ask again next time (Ionic backdrop)
    await promptStore.markShown();
    if (answer && !_isStale(generation)) {
      await _initPush(generation);
      if (!_isStale(generation)) await _setPushEnabled(true);
    }
  }

  /// Ionic initPush: permission → FCM token → device_tokens, clear badge.
  Future<void> initPush() {
    if (!isNativePlatform) return Future.value();
    _sessionSinceCleanup = true;
    return _initPush(_generation);
  }

  Future<void> _initPush(int generation) async {
    // SOL_FIX19: never register while a logout cleanup runs – its FCM
    // deleteToken would revoke the token this session is about to save.
    await _awaitCleanup();
    await _ready();
    if (!_available || _isStale(generation)) return;

    final permission = await client.checkPermission();
    if (_isStale(generation)) return;
    if (permission == PushPermission.prompt) {
      final result = await client.requestPermission();
      if (result != PushPermission.granted || _isStale(generation)) return;
    } else if (permission != PushPermission.granted) {
      return;
    }

    // SOL_FIX17: the listener belongs to this generation; removeToken
    // cancels it, the next sign-in subscribes again.
    _tokenRefreshSub ??= client.onTokenRefresh.listen((token) async {
      if (token.isEmpty || _isStale(generation)) return;
      _currentToken = token;
      await _saveToken(token, generation);
    });

    final token = await client.getToken();
    if (_isStale(generation)) return;
    if (token != null && token.isNotEmpty) {
      _currentToken = token;
      await _saveToken(token, generation);
    } else {
      _log('Push Error: no FCM token received from getToken()');
    }

    // Clear badge when app initializes push
    await clearBadge();
  }

  /// SOL_FIX17: tracked in [_pendingWrites]; the store re-checks the
  /// generation before each of its writes (last one: the upsert).
  Future<void> _saveToken(String token, int generation) {
    if (_isStale(generation)) return Future.value();
    _sessionTokens.add(token);
    final write = _write(token, generation);
    _pendingWrites.add(write);
    unawaited(write.whenComplete(() => _pendingWrites.remove(write)));
    return write;
  }

  Future<void> _write(String token, int generation) async {
    try {
      await tokens.saveToken(
        token,
        platform,
        isCurrent: () => !_isStale(generation),
      );
    } catch (e) {
      _log('Save Token Exception', e);
    }
  }

  /// Ionic removeToken (logout): deletes this device's token row and the
  /// FCM token. Call BEFORE `auth.signOut()` so RLS still allows the delete.
  ///
  /// SOL_FIX17: first ends the push session synchronously (new generation,
  /// token refresh listener stopped) so no running registration can write
  /// again, then waits for the writes already in flight, and only then
  /// deletes the rows – a late upsert cannot recreate them.
  ///
  /// SOL_FIX18: also deletes the rows of the device token it resolves
  /// itself (registration not finished yet), and always revokes the FCM
  /// token.
  ///
  /// SOL_FIX19: one cleanup per session. A second call without a
  /// registration in between (signedOut listener after the logout button)
  /// returns the same run. The user id is captured synchronously at the
  /// start and only that account's rows are deleted, even when another
  /// account signs in meanwhile; that account's registration waits for
  /// this cleanup (see [_awaitCleanup]) and then gets a fresh token.
  ///
  /// SOL_FIX20: the session is ended synchronously (user captured,
  /// generation bumped, tokens taken), but the cleanup work itself is
  /// chained after the previous cleanup, so cleanups are fully serialised:
  /// logout A → login B → logout B → login C can no longer let A's late
  /// FCM `deleteToken` revoke C's freshly registered token.
  Future<void> removeToken() {
    if (!isNativePlatform) return Future.value();
    final last = _cleanup;
    if (last != null && !_sessionSinceCleanup) return last;
    _sessionSinceCleanup = false;
    final session = _endSession();
    final Future<void> previous = last ?? Future<void>.value();
    final run = previous
        .catchError((Object _) {})
        .then((_) => _cleanupSession(session))
        .catchError((Object e) {
      _log('logout cleanup failed', e);
    });
    _cleanup = run;
    return run;
  }

  /// SOL_FIX20: the synchronous part of a logout – ends the push session
  /// before any await so no running registration can write again.
  _EndedSession _endSession() {
    // SOL_FIX19: the account this cleanup belongs to, read before any await.
    final userId = _currentUserId();
    _generation++;
    _promptInFlight = null;
    _promptGeneration = null;
    final refresh = _tokenRefreshSub;
    _tokenRefreshSub = null;
    Future<void>? refreshCancel;
    try {
      refreshCancel = refresh?.cancel();
    } catch (e) {
      _log('token refresh cancel failed', e);
    }
    final current = _currentToken;
    _currentToken = null;
    final toDelete = <String>{if (current != null) current, ..._sessionTokens};
    _sessionTokens.clear();
    return _EndedSession(
      userId: userId,
      toDelete: toDelete,
      inFlight: _pendingWrites.toList(),
      refreshCancel: refreshCancel,
    );
  }

  Future<void> _cleanupSession(_EndedSession session) async {
    final toDelete = session.toDelete;
    try {
      await session.refreshCancel;
    } catch (e) {
      _log('token refresh cancel failed', e);
    }
    // SOL_FIX18: after an app restart the logout can come before the
    // registration's getToken() returned – [toDelete] is then empty although
    // the rows of the previous app run still carry this device's token.
    // Resolve the device token here as well, independent of the
    // registration, so those rows are deleted too.
    final resolved = await _resolveDeviceToken();
    if (resolved != null) toDelete.add(resolved);
    if (session.inFlight.isNotEmpty) await Future.wait(session.inFlight);

    // Scoped by token value and the captured user
    // (DeviceTokenRepository.removeToken). Without a signed-in user (signed
    // out elsewhere) RLS would reject the delete anyway – nothing to do.
    final userId = session.userId;
    if (userId != null) {
      for (final token in toDelete) {
        try {
          await tokens.removeToken(token, userId: userId);
        } catch (e) {
          _log('removeToken failed', e);
        }
      }
    }
    // Ionic deletes the FCM token on iOS only; SOL_FIX17: on Android too,
    // so the token of the signed-out account stops being valid. SOL_FIX18:
    // always, also when no token was known or resolved. The client never
    // throws (no-op without Firebase); guarded anyway (PWA rule).
    try {
      await client.deleteToken();
    } catch (e) {
      _log('Failed to delete FCM token', e);
    }
  }

  String? _currentUserId() {
    try {
      return tokens.currentUserId;
    } catch (e) {
      _log('reading the user failed', e);
      return null;
    }
  }

  /// SOL_FIX18: this device's current FCM token, or null (no Firebase, no
  /// token, or no answer within [tokenResolveTimeout] – the logout must not
  /// hang). Waits for the shared initialisation first.
  Future<String?> _resolveDeviceToken() async {
    try {
      await _ensureInitialized();
      if (!_available) return null;
      final token = await client
          .getToken()
          .timeout(tokenResolveTimeout, onTimeout: () => null);
      return token != null && token.isNotEmpty ? token : null;
    } catch (e) {
      _log('resolving the device token failed', e);
      return null;
    }
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

/// SOL_FIX20: what a logout captured synchronously for its (chained)
/// cleanup.
class _EndedSession {
  _EndedSession({
    required this.userId,
    required this.toDelete,
    required this.inFlight,
    required this.refreshCancel,
  });

  final String? userId;
  final Set<String> toDelete;
  final List<Future<void>> inFlight;
  final Future<void>? refreshCancel;
}
