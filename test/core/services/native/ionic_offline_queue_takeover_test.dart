import 'dart:convert';

import 'package:attendix/core/services/native/ionic_offline_queue_takeover.dart';
import 'package:attendix/core/services/native/native_platform.dart';
import 'package:attendix/core/services/offline_queue_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _ionic(String id, String paId, Map<String, dynamic> payload,
        {String? userId}) =>
    {
      'id': id,
      'personAttendanceId': paId,
      'payload': payload,
      if (userId != null) 'userId': userId,
      'createdAt': '2026-10-01T10:00:00.000Z',
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parseIonicOfflineQueue', () {
    test('reads the localforage value, merges per record, skips invalid', () {
      final raw = jsonEncode({
        'value': [
          _ionic('1', 'pa-1', {'status': 2}, userId: 'u1'),
          {'id': 'broken'},
          _ionic('2', 'pa-1', {'notes': 'x'}),
          _ionic('3', 'pa-2', {'status': 1}),
        ],
      });
      final entries = parseIonicOfflineQueue(raw);
      expect(entries.map((e) => e.personAttendanceId), ['pa-1', 'pa-2']);
      expect(entries.first.id, '1');
      expect(entries.first.payload, {'status': 2, 'notes': 'x'});
      expect(entries.first.userId, 'u1');
    });

    test('missing database or key and the localStorage driver string', () {
      expect(parseIonicOfflineQueue(null), isEmpty);
      expect(parseIonicOfflineQueue(jsonEncode({'value': null})), isEmpty);
      final fromLocalStorage = jsonEncode({
        'value': jsonEncode([_ionic('1', 'pa-1', {'status': 2})]),
      });
      expect(parseIonicOfflineQueue(fromLocalStorage), hasLength(1));
    });
  });

  group('importIonicOfflineQueue', () {
    late OfflineQueueStore store;
    late List<List<String>> resolveCalls;

    Future<Map<String, IonicQueueTarget>> resolve(List<String> ids) async {
      resolveCalls.add(ids);
      // pa-3 belongs to an instance the user is not a member of.
      const known = <String, IonicQueueTarget>{
        'pa-1': (tenantId: 42, attendanceId: 7),
        'pa-2': (tenantId: 43, attendanceId: 8),
        'pa-4': (tenantId: 42, attendanceId: 9),
      };
      return {for (final id in ids) if (known[id] != null) id: known[id]!};
    }

    void setPending(List<Map<String, dynamic>> entries,
        {Map<String, Object> extra = const {}}) {
      SharedPreferences.setMockInitialValues({
        ionicQueuePendingKey: jsonEncode(entries),
        ...extra,
      });
    }

    setUp(() {
      store = OfflineQueueStore();
      resolveCalls = [];
    });

    test('adds tenant, Termin and user; drops unresolvable and foreign writes',
        () async {
      setPending([
        _ionic('1', 'pa-1', {'status': 2}, userId: 'u1'),
        // Only person_attendances columns are replayed (Ionic
        // pickPersonAttendanceFields).
        _ionic('2', 'pa-2',
            {'status': 3, 'notes': 'krank', 'firstName': 'Anna', 'person_id': 9}),
        _ionic('3', 'pa-3', {'status': 1}),
        _ionic('4', 'pa-4', {'status': 1}, userId: 'other'),
      ]);

      final added = await importIonicOfflineQueue(
          store: store, userId: 'u1', resolve: resolve);

      expect(added, 2);
      expect(resolveCalls.single, ['pa-1', 'pa-2', 'pa-3'],
          reason: 'writes of another Ionic user are not resolved');
      final queue = await store.load();
      expect(queue.map((e) => e.id), ['ionic:1', 'ionic:2']);
      expect(queue[0].tenantId, 42);
      expect(queue[0].attendanceId, 7);
      expect(queue[0].userId, 'u1');
      expect(queue[1].tenantId, 43);
      expect(queue[1].attendanceId, 8);
      expect(queue[1].userId, 'u1', reason: 'Ionic writes without user');
      expect(queue[1].payload, {'status': 3, 'notes': 'krank'});

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(ionicQueueDoneKey), isTrue);
      expect(prefs.containsKey(ionicQueuePendingKey), isFalse);
    });

    test('runs only once and never adds an entry twice', () async {
      setPending([_ionic('1', 'pa-1', {'status': 2})]);

      final results = await Future.wait([
        importIonicOfflineQueue(store: store, userId: 'u1', resolve: resolve),
        importIonicOfflineQueue(store: store, userId: 'u1', resolve: resolve),
      ]);
      expect(results, [1, 0]);

      // Replayed and removed by the flush: a later call adds nothing again,
      // even if the pending copy were still there.
      await store.save(const []);
      final prefs = await SharedPreferences.getInstance();
      expect(
          await importIonicOfflineQueue(
              store: store, userId: 'u1', resolve: resolve),
          0);
      await prefs.setString(ionicQueuePendingKey,
          jsonEncode([_ionic('1', 'pa-1', {'status': 2})]));
      await prefs.remove(ionicQueueDoneKey);
      await store.save([
        QueuedWrite(
          id: 'ionic:1',
          personAttendanceId: 'pa-1',
          payload: const {'status': 2},
          tenantId: 42,
          userId: 'u1',
          createdAt: 'x',
        ),
      ]);
      expect(
          await importIonicOfflineQueue(
              store: store, userId: 'u1', resolve: resolve),
          0);
      expect(await store.load(), hasLength(1));
      expect(resolveCalls, hasLength(2));
    });

    test('keeps a newer pending Flutter write of the same record', () async {
      setPending([_ionic('1', 'pa-1', {'status': 2})]);
      await store.save([
        QueuedWrite(
          id: 'flutter-1',
          personAttendanceId: 'pa-1',
          payload: const {'status': 1},
          tenantId: 42,
          userId: 'u1',
          createdAt: 'x',
        ),
      ]);

      expect(
          await importIonicOfflineQueue(
              store: store, userId: 'u1', resolve: resolve),
          0);
      final queue = await store.load();
      expect(queue.single.id, 'flutter-1');
      expect(queue.single.payload, {'status': 1});
    });

    test('network error or session change keeps the entries for later',
        () async {
      setPending([_ionic('1', 'pa-1', {'status': 2})]);

      expect(
          await importIonicOfflineQueue(
            store: store,
            userId: 'u1',
            resolve: (_) async => throw Exception('offline'),
          ),
          0);
      expect(
          await importIonicOfflineQueue(
            store: store,
            userId: 'u1',
            resolve: resolve,
            isCurrent: () => false,
          ),
          0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(ionicQueueDoneKey), isNull);
      expect(await store.load(), isEmpty);

      expect(
          await importIonicOfflineQueue(
              store: store, userId: 'u1', resolve: resolve),
          1);
    });
  });

  group('prepareIonicOfflineQueueTakeover', () {
    setUp(() => debugIsNativeAppOverride = true);
    tearDown(() => debugIsNativeAppOverride = null);

    test('skips the takeover when a Flutter version already ran', () async {
      SharedPreferences.setMockInitialValues(
          {'ionic_session_takeover_done': true});
      await prepareIonicOfflineQueueTakeover();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(ionicQueueDoneKey), isTrue);
    });

    test('first start after the Ionic app: takeover stays open', () async {
      SharedPreferences.setMockInitialValues({});
      await prepareIonicOfflineQueueTakeover();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(ionicQueueDoneKey), isFalse);
    });
  });
}
