import 'package:attendix/core/providers/connectivity_provider.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/services/offline_queue_service.dart';
import 'package:attendix/core/services/telegram_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

QueuedWrite _write(String paId, Map<String, dynamic> payload) => QueuedWrite(
      id: 'id-$paId-${payload.hashCode}',
      personAttendanceId: paId,
      payload: payload,
      tenantId: 42,
      createdAt: '2026-01-01T00:00:00.000',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfflineQueueStore.merge (last-write-wins)', () {
    test('appends writes for different personAttendances', () {
      var queue = <QueuedWrite>[];
      queue = OfflineQueueStore.merge(queue, _write('a', {'status': 1}));
      queue = OfflineQueueStore.merge(queue, _write('b', {'status': 2}));
      expect(queue.length, 2);
    });

    test('merges payload for the same personAttendance', () {
      var queue = <QueuedWrite>[];
      queue = OfflineQueueStore.merge(queue, _write('a', {'status': 1}));
      final firstId = queue.first.id;
      queue = OfflineQueueStore.merge(
          queue, _write('a', {'status': 2, 'notes': 'x'}));
      expect(queue.length, 1);
      expect(queue.first.id, firstId, reason: 'keeps the original entry id');
      expect(queue.first.payload, {'status': 2, 'notes': 'x'});
    });

    test('QueuedWrite JSON round trip', () {
      final w = QueuedWrite(
        id: '1',
        personAttendanceId: 'pa',
        payload: const {'status': 3},
        tenantId: 7,
        attendanceId: 9,
        createdAt: 'now',
      );
      final back = QueuedWrite.fromJson(w.toJson());
      expect(back.personAttendanceId, 'pa');
      expect(back.tenantId, 7);
      expect(back.attendanceId, 9);
      expect(back.payload['status'], 3);
    });
  });

  group('OfflineQueueNotifier', () {
    late bool online;
    late List<QueuedWrite> flushed;
    late bool failFlush;

    ProviderContainer createContainer() {
      final container = ProviderContainer(overrides: [
        connectivityProvider.overrideWith((ref) => const Stream<bool>.empty()),
        connectivityCheckProvider.overrideWithValue(() async => online),
        currentTenantIdProvider.overrideWithValue(42),
        offlineFlushFnProvider.overrideWithValue((entry) async {
          if (failFlush) throw Exception('network');
          flushed.add(entry);
        }),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      online = true;
      flushed = [];
      failFlush = false;
    });

    test('does not queue while online', () async {
      final container = createContainer();
      final queued = await container
          .read(offlineQueueNotifierProvider.notifier)
          .enqueueIfOffline('pa1', {'status': 1});
      expect(queued, isFalse);
      expect(container.read(offlinePendingCountProvider), 0);
    });

    test('queues while offline and persists with tenant id', () async {
      online = false;
      final container = createContainer();
      final notifier = container.read(offlineQueueNotifierProvider.notifier);
      expect(await notifier.enqueueIfOffline('pa1', {'status': 1}), isTrue);
      expect(await notifier.enqueueIfOffline('pa1', {'status': 2}), isTrue);
      expect(await notifier.enqueueIfOffline('pa2', {'status': 3}), isTrue);
      expect(container.read(offlinePendingCountProvider), 2);

      final stored = await OfflineQueueStore().load();
      expect(stored.length, 2);
      expect(stored.first.tenantId, 42);
      expect(stored.first.payload['status'], 2);
    });

    test('flush replays all writes and empties the queue', () async {
      online = false;
      final container = createContainer();
      final notifier = container.read(offlineQueueNotifierProvider.notifier);
      await notifier.enqueueIfOffline('pa1', {'status': 1}, attendanceId: 5);
      await notifier.enqueueIfOffline('pa2', {'status': 2}, attendanceId: 5);

      online = true;
      await notifier.flush();
      expect(flushed.map((e) => e.personAttendanceId), ['pa1', 'pa2']);
      expect(container.read(offlinePendingCountProvider), 0);
      expect(await OfflineQueueStore().load(), isEmpty);
    });

    test('failed writes stay in the queue', () async {
      online = false;
      final container = createContainer();
      final notifier = container.read(offlineQueueNotifierProvider.notifier);
      await notifier.enqueueIfOffline('pa1', {'status': 1});

      failFlush = true;
      await notifier.flush();
      expect(container.read(offlinePendingCountProvider), 1);
      expect((await OfflineQueueStore().load()).length, 1);
    });

    // SOL_FIX2: serialized queue access
    test('concurrent enqueues do not overwrite each other', () async {
      final container = createContainer();
      final notifier = container.read(offlineQueueNotifierProvider.notifier);
      await Future.wait([
        for (var i = 0; i < 20; i++) notifier.enqueue('pa$i', {'status': i}, tenantId: 42),
      ]);
      final stored = await OfflineQueueStore().load();
      expect(stored.map((e) => e.personAttendanceId).toSet().length, 20);
      expect(container.read(offlinePendingCountProvider), 20);
    });

    test('entries added during a flush are kept', () async {
      late ProviderContainer container;
      var injected = false;
      container = ProviderContainer(overrides: [
        connectivityProvider.overrideWith((ref) => const Stream<bool>.empty()),
        connectivityCheckProvider.overrideWithValue(() async => online),
        currentTenantIdProvider.overrideWithValue(42),
        offlineFlushFnProvider.overrideWithValue((entry) async {
          if (!injected) {
            injected = true;
            // a new write and a merge into the entry being replayed
            await container.read(offlineQueueNotifierProvider.notifier).enqueue('paNew', {'status': 9}, tenantId: 42);
            await container.read(offlineQueueNotifierProvider.notifier).enqueue('pa1', {'notes': 'later'}, tenantId: 42);
          }
          flushed.add(entry);
        }),
      ]);
      addTearDown(container.dispose);
      final notifier = container.read(offlineQueueNotifierProvider.notifier);
      await notifier.enqueue('pa1', {'status': 1}, tenantId: 42);

      await notifier.flush();
      final stored = await OfflineQueueStore().load();
      expect(stored.map((e) => e.personAttendanceId).toSet(), {'pa1', 'paNew'});
      expect(stored.firstWhere((e) => e.personAttendanceId == 'pa1').payload, {'status': 1, 'notes': 'later'});
      expect(container.read(offlinePendingCountProvider), 2);

      await notifier.flush();
      expect(await OfflineQueueStore().load(), isEmpty);
    });

    test('removeConfirmed matches id and revision', () {
      final a = _write('a', {'status': 1});
      final merged = OfflineQueueStore.merge([a], _write('a', {'status': 2}));
      expect(OfflineQueueStore.removeConfirmed(merged, [a]), hasLength(1));
      expect(OfflineQueueStore.removeConfirmed(merged, merged), isEmpty);
    });

    test('init loads persisted queue and flushes when online', () async {
      online = false;
      final first = createContainer();
      await first
          .read(offlineQueueNotifierProvider.notifier)
          .enqueueIfOffline('pa1', {'status': 1});

      online = true;
      final second = createContainer();
      await second.read(offlineQueueNotifierProvider.notifier).init();
      expect(flushed.length, 1);
      expect(second.read(offlinePendingCountProvider), 0);
    });
  });

  group('NotificationConfig (Ionic parity)', () {
    test('enabled_tenants: missing list means no tenant enabled', () {
      final config = NotificationConfig(id: 'u');
      expect(config.isTenantEnabled(1), isFalse);
    });

    test('toggleTenant adds and removes tenants', () {
      var config = NotificationConfig(id: 'u');
      config = config.toggleTenant(1);
      expect(config.isTenantEnabled(1), isTrue);
      config = config.toggleTenant(1);
      expect(config.isTenantEnabled(1), isFalse);
    });

    test('fromJson maps string tenant ids and new categories', () {
      final config = NotificationConfig.fromJson({
        'id': 'u',
        'enabled_tenants': ['3', 4],
        'tasks': false,
        'messages': true,
        'duties': null,
      });
      expect(config.enabledTenants, [3, 4]);
      expect(config.tasks, isFalse);
      expect(config.messages, isTrue);
      expect(config.duties, isNull);
      expect(config.toJson().containsKey('duties'), isFalse);
    });
  });
}
