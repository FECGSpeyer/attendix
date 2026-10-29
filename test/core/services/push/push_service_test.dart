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

  /// SOL_FIX16: when set, initialize() waits for it.
  Completer<void>? initGate;
  int initializations = 0;

  @override
  Future<bool> initialize() async {
    initializations++;
    final gate = initGate;
    if (gate != null) await gate.future;
    return available;
  }
  @override
  Future<PushPermission> checkPermission() async => permission;
  @override
  Future<PushPermission> requestPermission() async {
    requests++;
    return requestResult;
  }

  /// SOL_FIX17: when set, the next getToken waits for it (one-shot).
  Completer<void>? tokenGate;

  /// SOL_FIX18: when set, EVERY getToken waits for it (APNs not there yet).
  Completer<void>? sharedTokenGate;
  int tokenCalls = 0;

  @override
  Future<String?> getToken() async {
    tokenCalls++;
    final gate = tokenGate;
    tokenGate = null;
    if (gate != null) await gate.future;
    final shared = sharedTokenGate;
    if (shared != null) await shared.future;
    return token;
  }
  /// SOL_FIX19: shared order log with [FakeTokens.log] (set by the test).
  List<String>? log;

  @override
  Future<void> deleteToken() async {
    deletes++;
    // SOL_FIX20: a slow FCM delete (one-shot).
    final gate = deleteGate;
    deleteGate = null;
    if (gate != null) await gate.future;
    log?.add('fcm-delete');
    // FCM hands out a new token after deleteToken.
    if (rotateOnDelete != null) token = rotateOnDelete;
  }

  /// SOL_FIX20: when set, the next deleteToken waits for it (one-shot).
  Completer<void>? deleteGate;

  /// SOL_FIX19: the token getToken returns after a deleteToken.
  String? rotateOnDelete;
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

  /// SOL_FIX17: delayed writes. [beforeCheckGate] holds the save before its
  /// generation check (like the two deletes of the real repository),
  /// [afterCheckGate] holds the upsert itself after the check passed.
  /// Both one-shot. [log] records the order of upserts and deletes.
  Completer<void>? beforeCheckGate;
  Completer<void>? afterCheckGate;
  final log = <String>[];

  @override
  Future<void> saveToken(String token, String platform, {bool Function()? isCurrent}) async {
    final before = beforeCheckGate;
    beforeCheckGate = null;
    if (before != null) await before.future;
    if (isCurrent != null && !isCurrent()) {
      log.add('skipped:$token');
      return;
    }
    final after = afterCheckGate;
    afterCheckGate = null;
    if (after != null) await after.future;
    saved.add('$platform:$token');
    log.add('upsert:$token');
  }

  /// SOL_FIX20: when true, removeToken throws.
  bool throwOnRemove = false;

  /// SOL_FIX19: the signed-in user; the cleanup captures it at its start.
  String? userId = 'user-a';
  final removedFor = <String>[];

  @override
  String? get currentUserId => userId;

  @override
  Future<void> removeToken(String token, {required String userId}) async {
    if (throwOnRemove) throw StateError('rls');
    removed.add(token);
    removedFor.add(userId);
    log.add('delete:$token');
  }
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

  PushService build({
    bool native = true,
    String platform = 'android',
    Duration tokenResolveTimeout = const Duration(seconds: 12),
  }) =>
      PushService(
        client: client,
        tokens: tokens,
        promptStore: prompt,
        host: host,
        isNativePlatform: native,
        platform: platform,
        tokenResolveTimeout: tokenResolveTimeout,
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

  test('removeToken deletes the row and the FCM token (SOL_FIX17: Android too)', () async {
    final android = build();
    await android.initPush();
    await android.removeToken();
    expect(tokens.removed, ['tok-1']);
    expect(client.deletes, 1);
    expect(android.currentToken, isNull);
    // SOL_FIX19: the signedOut event after the logout button joins the
    // finished cleanup instead of running (and revoking FCM) again.
    await android.removeToken();
    expect(tokens.removed, ['tok-1']);
    expect(client.deletes, 1);
    client.deletes = 0;

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

  // SOL_FIX16: the bootstrap starts start() without awaiting it; a sign-in
  // (initialSession) processed meanwhile must wait for the initialisation
  // instead of giving up with "not available".
  group('shared initialisation', () {
    test('sign-in during the bootstrap init waits and registers the token', () async {
      final gate = Completer<void>();
      client.initGate = gate;
      final s = build();
      unawaited(s.start()); // bootstrap
      final enabling = s.promptAndEnable(); // initialSession right away
      await pumpEventQueue();
      expect(tokens.saved, isEmpty);

      gate.complete();
      await enabling;
      expect(tokens.saved, ['android:tok-1']);
      expect(client.initializations, 1);
    });

    test('initPush during the bootstrap init waits too', () async {
      final gate = Completer<void>();
      client.initGate = gate;
      final s = build();
      unawaited(s.start());
      final registering = s.initPush();
      await pumpEventQueue();
      gate.complete();
      await registering;
      expect(tokens.saved, ['android:tok-1']);
      expect(client.initializations, 1);
    });

    test('start() is one shared run; listeners are added once', () async {
      final s = build();
      final a = s.start();
      final b = s.start();
      expect(identical(a, b), isTrue);
      await Future.wait([a, b, s.initPush(), s.promptAndEnable()]);
      expect(client.initializations, 1);
      client.foreground.add(const PushMessage(title: 'T', data: {'type': 'x'}));
      await pumpEventQueue();
      expect(host.alerts.length, 1);
    });

    test('promptAndEnable without bootstrap still handles the cold start', () async {
      client.initial = const PushMessage(data: {'type': 'task', 'taskId': '2'});
      final s = build();
      await s.promptAndEnable();
      await pumpEventQueue();
      expect(host.navigations.single['taskId'], '2');
    });

    test('a failing initialize is no crash and registers nothing', () async {
      final s = PushService(
        client: _ThrowingClient(),
        tokens: tokens,
        promptStore: prompt,
        host: host,
        isNativePlatform: true,
        platform: 'android',
      );
      await s.start();
      await s.promptAndEnable();
      expect(tokens.saved, isEmpty);
    });
  });

  // SOL_FIX17: Sol review of 2c0550c – registrations and token refreshes
  // racing the logout must never recreate the deleted device_tokens row.
  group('logout during registration', () {
    test('a save in flight is awaited and stops before its upsert', () async {
      final gate = Completer<void>();
      tokens.beforeCheckGate = gate;
      final s = build();
      final registering = s.initPush();
      await pumpEventQueue();

      final removing = s.removeToken();
      await pumpEventQueue();
      expect(tokens.removed, isEmpty, reason: 'delete waits for the write');

      gate.complete();
      await removing;
      await registering;
      expect(tokens.log, ['skipped:tok-1', 'delete:tok-1']);
      expect(tokens.saved, isEmpty);
      expect(client.deletes, 1);
    });

    test('an upsert already running lands before the final delete', () async {
      final gate = Completer<void>();
      tokens.afterCheckGate = gate;
      final s = build();
      final registering = s.initPush();
      await pumpEventQueue();

      final removing = s.removeToken();
      await pumpEventQueue();
      expect(tokens.removed, isEmpty);

      gate.complete();
      await removing;
      await registering;
      expect(tokens.log, ['upsert:tok-1', 'delete:tok-1']);
    });

    test('getToken returning after logout saves nothing', () async {
      final gate = Completer<void>();
      client.tokenGate = gate;
      final s = build();
      final registering = s.initPush();
      await pumpEventQueue();
      await s.removeToken();

      gate.complete();
      await registering;
      expect(tokens.saved, isEmpty);
      // SOL_FIX18: the logout resolved the device token itself.
      expect(tokens.log, ['delete:tok-1']);
      expect(s.currentToken, isNull);
    });

    test('token refresh listener is stopped on logout', () async {
      final s = build();
      await s.initPush();
      expect(client.refresh.hasListener, isTrue);
      await s.removeToken();
      expect(client.refresh.hasListener, isFalse);

      client.refresh.add('tok-late');
      await pumpEventQueue();
      expect(tokens.saved, ['android:tok-1']);
      expect(s.currentToken, isNull);
    });

    test('a refresh save in flight at logout is awaited and deleted', () async {
      final s = build();
      await s.initPush();
      final gate = Completer<void>();
      tokens.afterCheckGate = gate;
      client.refresh.add('tok-2');
      await pumpEventQueue();

      final removing = s.removeToken();
      await pumpEventQueue();
      gate.complete();
      await removing;
      expect(tokens.log, ['upsert:tok-1', 'upsert:tok-2', 'delete:tok-2', 'delete:tok-1']);
    });

    test('sign-in after logout registers again; the stale run does not', () async {
      final gate = Completer<void>();
      client.tokenGate = gate;
      final s = build();
      final stale = s.promptAndEnable();
      await pumpEventQueue();
      await s.removeToken();

      // New session: a fresh run, not the cancelled one.
      final next = s.promptAndEnable();
      expect(identical(next, stale), isFalse);
      await next;
      expect(tokens.saved, ['android:tok-1']);
      expect(client.refresh.hasListener, isTrue);

      gate.complete();
      await stale;
      expect(tokens.saved, ['android:tok-1'], reason: 'stale run wrote nothing');
      expect(s.currentToken, 'tok-1');
    });
  });

  // SOL_FIX18: Sol review of 1c9b642 – after an app restart the logout can
  // come before getToken() returned; the rows of the previous app run must
  // still be deleted and the FCM token revoked.
  group('logout before the device token is known', () {
    test('app restart: logout waits for the device token and deletes it', () async {
      final apns = Completer<void>();
      client.sharedTokenGate = apns;
      final s = build(platform: 'ios');
      unawaited(s.start()); // bootstrap
      final registering = s.promptAndEnable(); // initialSession
      await pumpEventQueue();
      expect(s.currentToken, isNull, reason: 'registration still waiting');

      final removing = s.removeToken();
      await pumpEventQueue();
      expect(tokens.removed, isEmpty, reason: 'waits for the token');
      expect(client.deletes, 0, reason: 'FCM token revoked after the rows');

      apns.complete();
      await removing;
      await registering;
      expect(tokens.log, ['delete:tok-1'], reason: 'old row deleted, none written');
      expect(tokens.saved, isEmpty);
      expect(client.deletes, 1);
      expect(s.currentToken, isNull);
    });

    test('logout without any registration in this app run deletes the token', () async {
      final s = build();
      await s.removeToken();
      expect(client.initializations, 1);
      expect(tokens.removed, ['tok-1']);
      expect(client.deletes, 1);
    });

    test('no token at all: no row delete, FCM token revoked anyway', () async {
      client.token = null;
      final s = build();
      await s.removeToken();
      expect(tokens.removed, isEmpty);
      expect(client.deletes, 1);
    });

    test('a token that never comes does not block the logout', () async {
      client.sharedTokenGate = Completer<void>(); // never completes
      final s = build(tokenResolveTimeout: const Duration(milliseconds: 20));
      await s.removeToken();
      expect(tokens.removed, isEmpty);
      expect(client.deletes, 1);
    });

    test('missing Firebase: no token lookup, delete call is a harmless no-op', () async {
      client.available = false;
      final s = build();
      await s.removeToken();
      expect(client.tokenCalls, 0);
      expect(tokens.removed, isEmpty);
      expect(client.deletes, 1);
    });

    test('a resolved token is deleted once next to the session tokens', () async {
      final s = build();
      await s.initPush();
      client.token = 'tok-new';
      await s.removeToken();
      expect(tokens.removed, ['tok-1', 'tok-new']);
      expect(client.deletes, 1);
    });
  });

  // SOL_FIX19: Sol review of afa5b15 – the signedOut cleanup must not
  // overlap the next login's registration.
  group('logout cleanup vs. next login', () {
    test('button + signedOut share one cleanup run', () async {
      final apns = Completer<void>();
      client.sharedTokenGate = apns;
      final s = build(platform: 'ios');
      final button = s.removeToken();
      final signedOut = s.removeToken(); // listener, cleanup still running
      expect(identical(button, signedOut), isTrue);
      apns.complete();
      await Future.wait([button, signedOut]);
      expect(tokens.removed, ['tok-1']);
      expect(client.deletes, 1);
      expect(client.tokenCalls, 1);

      // Still the same run after it finished (no registration in between).
      expect(identical(s.removeToken(), button), isTrue);
      expect(client.deletes, 1);
    });

    test('a login during the cleanup waits for it and registers a fresh token', () async {
      client.log = tokens.log; // one order log for rows and FCM
      final apns = Completer<void>();
      client.sharedTokenGate = apns; // the cleanup's token lookup is slow
      client.rotateOnDelete = 'tok-b';
      final s = build(platform: 'ios');

      final cleanup = s.removeToken(); // signedOut of user A
      await pumpEventQueue();
      // User B signs in while A's cleanup still resolves the token.
      tokens.userId = 'user-b';
      final registering = s.promptAndEnable();
      await pumpEventQueue();
      expect(tokens.saved, isEmpty, reason: 'registration waits');
      expect(client.deletes, 0);

      apns.complete();
      await cleanup;
      await registering;
      // A's cleanup: captured user A, deletes A's row with the old token,
      // revokes it – all before B asks FCM for its token.
      expect(tokens.removedFor, ['user-a']);
      expect(tokens.removed, ['tok-1']);
      expect(client.deletes, 1);
      expect(tokens.log, ['delete:tok-1', 'fcm-delete', 'upsert:tok-b']);
      expect(tokens.saved, ['ios:tok-b']);
      expect(s.currentToken, 'tok-b');
    });

    test('the cleanup keeps the user captured at its start', () async {
      final gate = Completer<void>();
      tokens.afterCheckGate = gate;
      final s = build();
      final registering = s.initPush(); // A's upsert in flight
      await pumpEventQueue();

      final cleanup = s.removeToken(); // A logs out
      tokens.userId = 'user-b'; // B is signed in before the delete runs
      gate.complete();
      await cleanup;
      await registering;
      expect(tokens.removedFor, everyElement('user-a'));
      expect(tokens.removedFor, isNotEmpty);
    });

    test('signed out elsewhere (no user): no row delete, FCM revoked', () async {
      tokens.userId = null;
      final s = build();
      await s.removeToken();
      expect(tokens.removed, isEmpty);
      expect(client.deletes, 1);
    });

    test('a logout after the next registration runs a new cleanup', () async {
      final s = build();
      await s.initPush();
      await s.removeToken();
      expect(client.deletes, 1);

      tokens.userId = 'user-b';
      await s.promptAndEnable();
      await s.removeToken();
      expect(client.deletes, 2);
      expect(tokens.removedFor, ['user-a', 'user-b']);
    });

    // SOL_FIX20: logout A → login B → logout B → login C while A's FCM
    // delete is still running. Before the fix B's cleanup ran in parallel,
    // C only waited for B and A's late deleteToken revoked C's token.
    test('cleanups are serialised: a late FCM delete of A never hits C', () async {
      client.log = tokens.log;
      final slowDelete = Completer<void>();
      client.deleteGate = slowDelete; // A's FCM delete hangs
      client.rotateOnDelete = 'tok-new';
      final s = build(platform: 'ios');

      final logoutA = s.removeToken(); // user A
      await pumpEventQueue();
      expect(client.deletes, 1, reason: "A's FCM delete is running");

      tokens.userId = 'user-b';
      final loginB = s.promptAndEnable();
      await pumpEventQueue();
      final logoutB = s.removeToken();
      expect(identical(logoutA, logoutB), isFalse, reason: 'B needs its own cleanup');
      await pumpEventQueue();
      expect(client.deletes, 1, reason: "B's cleanup waits for A's");
      expect(client.tokenCalls, 1, reason: "B's cleanup has not started");

      tokens.userId = 'user-c';
      final loginC = s.promptAndEnable();
      await pumpEventQueue();
      expect(tokens.saved, isEmpty, reason: 'C waits for the whole chain');

      slowDelete.complete();
      await Future.wait([logoutA, loginB, logoutB, loginC]);

      expect(client.deletes, 2);
      expect(tokens.removedFor, ['user-a', 'user-b']);
      expect(tokens.saved, ['ios:tok-new']);
      expect(s.currentToken, 'tok-new');
      // Both FCM deletes land before C's registration.
      expect(tokens.log.last, 'upsert:tok-new');
      expect(tokens.log.where((e) => e == 'fcm-delete'), hasLength(2));
      expect(
        tokens.log.lastIndexOf('fcm-delete'),
        lessThan(tokens.log.indexOf('upsert:tok-new')),
      );
    });

    test('a failing cleanup does not break the chain', () async {
      final s = build();
      tokens.throwOnRemove = true;
      final a = s.removeToken();
      await s.promptAndEnable();
      tokens.throwOnRemove = false;
      final b = s.removeToken();
      await Future.wait([a, b]);
      expect(client.deletes, 2);
    });
  });
}

class _ThrowingClient extends FakeClient {
  @override
  Future<bool> initialize() async => throw StateError('no firebase');
}
