import 'dart:async';

import 'package:attendix/core/services/push/push_messaging_client.dart';
import 'package:attendix/core/services/push/push_service.dart';
import 'package:attendix/core/services/tracking/tracking_event.dart';
import 'package:attendix/data/repositories/device_token_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeClient implements PushMessagingClient {
  bool available = true;
  PushPermission permission = PushPermission.granted;
  PushPermission requestResult = PushPermission.granted;
  String? token = 'tok-1';
  PushMessage? initial;
  int requests = 0;
  int badgeClears = 0;
  int deletes = 0;
  final foreground = StreamController<PushMessage>.broadcast();
  final opened = StreamController<PushMessage>.broadcast();
  final refresh = StreamController<String>.broadcast();

  @override
  Future<bool> initialize() async => available;
  @override
  Future<PushPermission> checkPermission() async => permission;
  @override
  Future<PushPermission> requestPermission() async {
    requests++;
    return requestResult;
  }

  @override
  Future<String?> getToken() async => token;
  @override
  Future<void> deleteToken() async => deletes++;
  @override
  Stream<String> get onTokenRefresh => refresh.stream;
  @override
  Stream<PushMessage> get onForegroundMessage => foreground.stream;
  @override
  Stream<PushMessage> get onMessageOpened => opened.stream;
  @override
  Future<PushMessage?> getInitialMessage() async => initial;
  @override
  Future<void> clearBadge() async => badgeClears++;
}

class FakeTokens implements DeviceTokenStore {
  final saved = <String>[];
  final removed = <String>[];
  final pushEnabled = <bool>[];
  @override
  Future<void> saveToken(String token, String platform) async =>
      saved.add('$platform:$token');
  @override
  Future<void> removeToken(String token) async => removed.add(token);
  @override
  Future<void> setPushEnabled(bool enabled) async => pushEnabled.add(enabled);
}

class FakePrompt implements PushPromptStore {
  bool shown = false;
  @override
  Future<bool> wasShown() async => shown;
  @override
  Future<void> markShown() async => shown = true;
}

class FakeHost implements PushHost {
  bool? confirmAnswer = true;
  bool showAnswer = false;
  int confirms = 0;
  final alerts = <PushMessage>[];
  final navigations = <Map<String, dynamic>>[];
  final events = <TrackingEvent>[];

  @override
  Future<bool?> confirmEnablePush() async {
    confirms++;
    return confirmAnswer;
  }

  @override
  Future<bool> showForegroundAlert(PushMessage message) async {
    alerts.add(message);
    return showAnswer;
  }

  @override
  Future<void> waitUntilReadyForNavigation() async {}

  @override
  Future<void> navigateFromData(Map<String, dynamic> data) async =>
      navigations.add(data);

  @override
  void track(TrackingEvent event) => events.add(event);
}

void main() {
  late FakeClient client;
  late FakeTokens tokens;
  late FakePrompt prompt;
  late FakeHost host;

  PushService build({bool native = true, String platform = 'android'}) =>
      PushService(
        client: client,
        tokens: tokens,
        promptStore: prompt,
        host: host,
        isNativePlatform: native,
        platform: platform,
      );

  setUp(() {
    client = FakeClient();
    tokens = FakeTokens();
    prompt = FakePrompt();
    host = FakeHost();
  });

  test('web (not native): everything is a no-op', () async {
    final s = build(native: false);
    await s.start();
    await s.promptAndEnable();
    await s.initPush();
    await s.removeToken();
    await s.clearBadge();
    expect(tokens.saved, isEmpty);
    expect(host.confirms, 0);
    expect(client.badgeClears, 0);
  });

  test('missing Firebase config: no crash, nothing registered', () async {
    client.available = false;
    final s = build();
    await s.promptAndEnable();
    expect(tokens.saved, isEmpty);
    expect(host.confirms, 0);
  });

  test('permission already granted: no prompt, token saved, badge cleared', () async {
    final s = build();
    await s.promptAndEnable();
    expect(host.confirms, 0);
    expect(prompt.shown, isTrue);
    expect(tokens.saved, ['android:tok-1']);
    expect(s.currentToken, 'tok-1');
    expect(client.badgeClears, 1);
  });

  test('permission denied: remembered, no prompt, no token', () async {
    client.permission = PushPermission.denied;
    final s = build();
    await s.promptAndEnable();
    expect(host.confirms, 0);
    expect(prompt.shown, isTrue);
    expect(tokens.saved, isEmpty);
  });

  test('prompt "Aktivieren": registers and sets push_enabled', () async {
    client.permission = PushPermission.prompt;
    final s = build(platform: 'ios');
    await s.promptAndEnable();
    expect(host.confirms, 1);
    expect(client.requests, 1);
    expect(tokens.saved, ['ios:tok-1']);
    expect(tokens.pushEnabled, [true]);
    expect(prompt.shown, isTrue);
  });

  test('prompt "Später": remembered, nothing registered', () async {
    client.permission = PushPermission.prompt;
    host.confirmAnswer = false;
    final s = build();
    await s.promptAndEnable();
    expect(prompt.shown, isTrue);
    expect(tokens.saved, isEmpty);
    expect(tokens.pushEnabled, isEmpty);
  });

  test('prompt already shown: initPush directly', () async {
    prompt.shown = true;
    client.permission = PushPermission.prompt;
    client.requestResult = PushPermission.denied;
    final s = build();
    await s.promptAndEnable();
    expect(host.confirms, 0);
    expect(client.requests, 1);
    expect(tokens.saved, isEmpty);
  });

  test('token refresh is saved', () async {
    final s = build();
    await s.initPush();
    client.refresh.add('tok-2');
    await Future<void>.delayed(Duration.zero);
    expect(tokens.saved.last, 'android:tok-2');
    expect(s.currentToken, 'tok-2');
  });

  test('removeToken deletes the row; FCM token only on iOS', () async {
    final android = build();
    await android.initPush();
    await android.removeToken();
    expect(tokens.removed, ['tok-1']);
    expect(client.deletes, 0);
    expect(android.currentToken, isNull);
    await android.removeToken(); // idempotent
    expect(tokens.removed, hasLength(1));

    final ios = build(platform: 'ios');
    await ios.initPush();
    await ios.removeToken();
    expect(client.deletes, 1);
  });

  test('togglePush updates push_enabled and registers when enabled', () async {
    final s = build();
    await s.togglePush(false);
    expect(tokens.pushEnabled, [false]);
    expect(tokens.saved, isEmpty);
    await s.togglePush(true);
    expect(tokens.pushEnabled, [false, true]);
    expect(tokens.saved, ['android:tok-1']);
  });

  test('tap: clears badge, tracks push_opened and navigates', () async {
    final s = build();
    await s.start();
    client.opened.add(const PushMessage(data: {'type': 'attendance', 'attendanceId': '3'}));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(client.badgeClears, 1);
    expect(host.events, [TrackingEvent.pushOpened]);
    expect(host.navigations.single['attendanceId'], '3');
    expect(s.pendingPushData, isNull);
  });

  test('cold start: the launching notification is handled', () async {
    client.initial = const PushMessage(data: {'type': 'task', 'taskId': '1'});
    final s = build();
    await s.start();
    expect(host.navigations.single['taskId'], '1');
  });

  test('foreground: alert, push_received, navigate on "Anzeigen"', () async {
    final s = build();
    await s.start();
    client.foreground.add(const PushMessage(title: 'T', body: 'B', data: {'type': 'x'}));
    await Future<void>.delayed(Duration.zero);
    expect(host.alerts.single.title, 'T');
    expect(host.events, [TrackingEvent.pushReceived]);
    expect(host.navigations, isEmpty);

    host.showAnswer = true;
    client.foreground.add(const PushMessage(data: {'type': 'y'}));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(host.navigations.single['type'], 'y');
  });

  test('foreground live_plan push is silent', () async {
    final s = build();
    await s.start();
    client.foreground.add(const PushMessage(data: {'type': 'live_plan'}));
    await Future<void>.delayed(Duration.zero);
    expect(host.alerts, isEmpty);
    expect(host.events, isEmpty);
  });

  test('concurrent promptAndEnable calls share one run', () async {
    client.permission = PushPermission.prompt;
    final s = build();
    await Future.wait([s.promptAndEnable(), s.promptAndEnable()]);
    expect(host.confirms, 1);
  });
}
