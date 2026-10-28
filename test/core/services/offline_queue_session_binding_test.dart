// SOL_FIX9: the offline queue replay is bound to the auth session it
// started in; an account switch / new session / sign-out mid-replay stops
// it and keeps the remaining writes for their author.
import 'dart:async';
import 'dart:convert';

import 'package:attendix/core/providers/connectivity_provider.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/services/offline_queue_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String? currentUser;
  late String? currentSession;
  late List<QueuedWrite> flushed;
  late StreamController<AuthChangeEvent> authEvents;
  late Future<void> Function(QueuedWrite entry)? onReplay;

  ProviderContainer createContainer() {
    final container = ProviderContainer(overrides: [
      connectivityProvider.overrideWith((ref) => const Stream<bool>.empty()),
      connectivityCheckProvider.overrideWithValue(() async => true),
      currentTenantIdProvider.overrideWithValue(42),
      offlineQueueUserIdProvider.overrideWithValue(() => currentUser),
      offlineQueueSessionIdProvider.overrideWithValue(() => currentSession),
      offlineQueueAuthEventsProvider.overrideWithValue(authEvents.stream),
      offlineFlushFnProvider.overrideWithValue((entry) async {
        flushed.add(entry);
        await onReplay?.call(entry);
      }),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  Future<OfflineQueueNotifier> queueFor(
      ProviderContainer container, String userId, List<String> paIds) async {
    final notifier = container.read(offlineQueueNotifierProvider.notifier);
    for (final pa in paIds) {
      await notifier.enqueue(pa, {'status': 1}, tenantId: 42, userId: userId);
    }
    return notifier;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    currentUser = 'u1';
    currentSession = 's1';
    flushed = [];
    onReplay = null;
    authEvents = StreamController<AuthChangeEvent>.broadcast();
    addTearDown(authEvents.close);
  });

  test('account switch mid-replay stops it; the rest stays queued for u1', () async {
    final container = createContainer();
    final notifier = await queueFor(container, 'u1', ['pa1', 'pa2', 'pa3']);
    onReplay = (entry) async {
      currentUser = 'u2';
      currentSession = 's2';
    };

    await notifier.flush();

    expect(flushed.map((e) => e.personAttendanceId), ['pa1']);
    final left = await OfflineQueueStore().load();
    expect(left.map((e) => e.personAttendanceId), ['pa2', 'pa3']);
    expect(left.every((e) => e.userId == 'u1'), isTrue);
    expect(container.read(offlinePendingCountProvider), 0,
        reason: 'u2 has no pending writes');
  });

  test('a new auth session of the same user also stops the replay', () async {
    final container = createContainer();
    final notifier = await queueFor(container, 'u1', ['pa1', 'pa2']);
    onReplay = (entry) async => currentSession = 's1-new';

    await notifier.flush();

    expect(flushed.map((e) => e.personAttendanceId), ['pa1']);
    expect((await OfflineQueueStore().load()).single.personAttendanceId, 'pa2');
  });

  test('a sign-out event mid-replay stops it', () async {
    final container = createContainer();
    final notifier = await queueFor(container, 'u1', ['pa1', 'pa2']);
    onReplay = (entry) async {
      // user/session still look unchanged; only the event arrives
      authEvents.add(AuthChangeEvent.signedOut);
      await Future<void>.delayed(Duration.zero);
    };

    await notifier.flush();

    expect(flushed.map((e) => e.personAttendanceId), ['pa1']);
    expect((await OfflineQueueStore().load()).single.personAttendanceId, 'pa2');
  });

  test('token refresh events do not stop the replay', () async {
    final container = createContainer();
    final notifier = await queueFor(container, 'u1', ['pa1', 'pa2']);
    onReplay = (entry) async {
      authEvents.add(AuthChangeEvent.tokenRefreshed);
      await Future<void>.delayed(Duration.zero);
    };

    await notifier.flush();

    expect(flushed.map((e) => e.personAttendanceId), ['pa1', 'pa2']);
    expect(await OfflineQueueStore().load(), isEmpty);
  });

  test('user change mid-replay: u1 stops, then u2\'s writes are replayed', () async {
    final container = createContainer();
    final notifier = await queueFor(container, 'u1', ['pa1', 'pa2']);
    await notifier.enqueue('pb1', {'status': 2}, tenantId: 42, userId: 'u2');
    var switched = false;
    onReplay = (entry) async {
      if (switched) return;
      switched = true;
      currentUser = 'u2';
      currentSession = 's2';
      await notifier.onUserChanged(); // app listener on account switch
    };

    await notifier.flush();

    expect(
      flushed.map((e) => (e.userId, e.personAttendanceId)),
      [('u1', 'pa1'), ('u2', 'pb1')],
    );
    final left = await OfflineQueueStore().load();
    expect(left.map((e) => (e.userId, e.personAttendanceId)), [('u1', 'pa2')]);
    expect(container.read(offlinePendingCountProvider), 0);
  });

  test('authSessionIdentity reads the session_id claim of the JWT', () {
    String jwt(Map<String, dynamic> claims) =>
        'h.${base64Url.encode(utf8.encode(jsonEncode(claims))).replaceAll('=', '')}.s';
    expect(authSessionIdentity(jwt({'sub': 'u1', 'session_id': 'abc'})), 'abc');
    expect(authSessionIdentity(jwt({'sub': 'u1'})), isNull);
    expect(authSessionIdentity('not-a-jwt'), isNull);
  });
}
