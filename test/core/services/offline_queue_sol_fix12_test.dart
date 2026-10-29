// SOL_FIX12: (a) an online write for a record with a pending queued write
// goes through the queue (merged, replayed in order) so a later replay can
// never overwrite it with the older offline value; (b) a write that could
// not be persisted in the queue is never reported as queued.
import 'dart:async';

import 'package:attendix/core/providers/connectivity_provider.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/services/offline_queue_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent;

class _MockPrefs extends Mock implements SharedPreferences {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late bool online;
  late List<Map<String, dynamic>> written;
  late Future<void> Function(QueuedWrite entry) onFlush;

  ProviderContainer createContainer({OfflineQueueStore? store}) {
    final authEvents = StreamController<AuthChangeEvent>.broadcast();
    addTearDown(authEvents.close);
    final container = ProviderContainer(overrides: [
      connectivityProvider.overrideWith((ref) => const Stream<bool>.empty()),
      connectivityCheckProvider.overrideWithValue(() async => online),
      currentTenantIdProvider.overrideWithValue(42),
      offlineQueueUserIdProvider.overrideWithValue(() => 'u1'),
      offlineQueueSessionIdProvider.overrideWithValue(() => 's1'),
      offlineQueueAuthEventsProvider.overrideWithValue(authEvents.stream),
      offlineFlushFnProvider.overrideWithValue((entry, _) => onFlush(entry)),
      if (store != null) offlineQueueStoreProvider.overrideWithValue(store),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  QueuedWrite pending(String pa, Map<String, dynamic> payload, {String user = 'u1'}) => QueuedWrite(
        id: 'q-$pa-$user',
        personAttendanceId: pa,
        payload: payload,
        tenantId: 42,
        userId: user,
        createdAt: '2026-10-28T10:00:00',
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    online = true;
    written = [];
    onFlush = (entry) async => written.add({'pa': entry.personAttendanceId, ...entry.payload});
  });

  group('online write vs. pending queued write of the same record', () {
    test('is merged into the queue entry and replayed (newest value wins)', () async {
      await OfflineQueueStore().save([pending('pa1', {'status': 2, 'notes': 'offline'})]);
      final notifier = createContainer().read(offlineQueueNotifierProvider.notifier);

      expect(await notifier.enqueueIfOffline('pa1', {'status': 1}), isTrue);

      expect(written, [
        {'pa': 'pa1', 'status': 1, 'notes': 'offline'},
      ]);
      expect(await OfflineQueueStore().load(), isEmpty);
    });

    test('a replay already running with the old value is followed by the new one', () async {
      await OfflineQueueStore().save([pending('pa1', {'status': 2})]);
      final release = Completer<void>();
      onFlush = (entry) async {
        if (written.isEmpty) await release.future;
        written.add({'pa': entry.personAttendanceId, ...entry.payload});
      };
      final notifier = createContainer().read(offlineQueueNotifierProvider.notifier);

      final replay = notifier.flush(); // snapshot holds the old value
      await Future<void>.delayed(Duration.zero);
      final routed = notifier.enqueueIfOffline('pa1', {'status': 1});
      await Future<void>.delayed(const Duration(milliseconds: 10));
      release.complete();
      await replay;
      expect(await routed, isTrue);

      expect(written.map((w) => w['status']), [2, 1]);
      expect(await OfflineQueueStore().load(), isEmpty);
    });

    test('without a pending write of that record the caller writes directly', () async {
      await OfflineQueueStore().save([
        pending('pa2', {'status': 2}),
        pending('pa1', {'status': 2}, user: 'other'),
      ]);
      final notifier = createContainer().read(offlineQueueNotifierProvider.notifier);

      expect(await notifier.enqueueIfOffline('pa1', {'status': 1}), isFalse);
      expect(written, isEmpty);
      expect((await OfflineQueueStore().load()).length, 2);
    });
  });

  group('queue persistence failures', () {
    test('save throws when setString returns false', () async {
      final prefs = _MockPrefs();
      when(() => prefs.setString(any(), any())).thenAnswer((_) async => false);
      final store = OfflineQueueStore(prefs: () async => prefs);
      await expectLater(
        store.save([pending('pa1', {'status': 1})]),
        throwsA(isA<OfflineQueuePersistException>()),
      );
    });

    test('save throws when the storage throws', () async {
      final store = OfflineQueueStore(prefs: () async => throw StateError('no storage'));
      await expectLater(
        store.save(const []),
        throwsA(isA<OfflineQueuePersistException>()),
      );
    });

    test('enqueueIfOffline does not report an unpersisted write as queued', () async {
      online = false;
      final prefs = _MockPrefs();
      when(() => prefs.getString(any())).thenReturn(null);
      when(() => prefs.setString(any(), any())).thenAnswer((_) async => false);
      final container = createContainer(store: OfflineQueueStore(prefs: () async => prefs));
      final notifier = container.read(offlineQueueNotifierProvider.notifier);

      await expectLater(
        notifier.enqueueIfOffline('pa1', {'status': 1}),
        throwsA(isA<OfflineQueuePersistException>()),
      );
      expect(container.read(offlinePendingCountProvider), 0);
    });

    test('the exception carries a user-facing text', () {
      expect(const OfflineQueuePersistException().toString(),
          'Die Änderung konnte nicht offline gespeichert werden');
    });
  });
}
