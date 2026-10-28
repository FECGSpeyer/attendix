// SOL_FIX13: external review findings (offline queue session guard on the
// online path, unreadable queue never overwritten, account creation bound to
// the tenant of its person list, protocol save chain on dispose, hash-route
// app links).
import 'dart:async';
import 'dart:io';

import 'package:attendix/core/providers/connectivity_provider.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/providers/user_registration_providers.dart';
import 'package:attendix/core/services/offline_queue_service.dart';
import 'package:attendix/data/models/person/person.dart';
import 'package:attendix/data/repositories/attendance_repository.dart';
import 'package:attendix/data/repositories/user_registration_repository.dart';
import 'package:attendix/features/auth/data/auth_link_listener.dart';
import 'package:attendix/features/settings/presentation/pages/settings_page.dart'
    show playersOfCurrentTenant;
import 'package:attendix/features/team_organization/presentation/pages/protocol_page.dart'
    show chainProtocolSectionSave;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent;

import '../../factories/test_factories.dart';

String _read(String path) => File(path).readAsStringSync();

/// Runs [onUpdate] (e.g. an account switch) while the queue update is in
/// progress, i.e. during the storage await of `_mergeIntoPending`.
class _SwitchingStore extends OfflineQueueStore {
  _SwitchingStore(this.onUpdate);
  final void Function() onUpdate;

  @override
  Future<List<QueuedWrite>> update(
    List<QueuedWrite> Function(List<QueuedWrite> current) change,
  ) async {
    final result = await super.update(change);
    onUpdate();
    return result;
  }
}

class _FakeRegistrationRepo extends UserRegistrationRepository {
  _FakeRegistrationRepo(super.ref, this.created);
  final List<int?> created;

  @override
  Future<int?> getMainGroupId() async => null;

  @override
  Future<String> createPlayerAccount(Person person, {int? mainGroupId}) async {
    created.add(person.id);
    return 'app-${person.id}';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('offline queue: session guard on the online path', () {
    late String? currentUser;
    late String? currentSession;
    late int tenant;

    ProviderContainer createContainer({OfflineQueueStore? store, bool online = true}) {
      final authEvents = StreamController<AuthChangeEvent>.broadcast();
      addTearDown(authEvents.close);
      late ProviderContainer container;
      container = ProviderContainer(overrides: [
        connectivityProvider.overrideWith((ref) => const Stream<bool>.empty()),
        connectivityCheckProvider.overrideWithValue(() async => online),
        currentTenantIdProvider.overrideWith((ref) => tenant),
        offlineQueueUserIdProvider.overrideWithValue(() => currentUser),
        offlineQueueSessionIdProvider.overrideWithValue(() => currentSession),
        offlineQueueAuthEventsProvider.overrideWithValue(authEvents.stream),
        offlineFlushFnProvider.overrideWithValue((entry, _) async {}),
        if (store != null) offlineQueueStoreProvider.overrideWithValue(store),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      currentUser = 'u1';
      currentSession = 's1';
      tenant = 42;
    });

    test('account switch during the queue access throws instead of false', () async {
      final store = _SwitchingStore(() {
        currentUser = 'u2';
        currentSession = 's2';
      });
      final notifier =
          createContainer(store: store).read(offlineQueueNotifierProvider.notifier);

      await expectLater(
        notifier.enqueueIfOffline('pa1', {'status': 1}),
        throwsA(isA<OfflineSessionChangedException>()),
      );
      expect(await OfflineQueueStore().load(), isEmpty);
    });

    test('tenant switch during the queue access throws as well', () async {
      late ProviderContainer container;
      final store = _SwitchingStore(() {
        tenant = 43;
        container.invalidate(currentTenantIdProvider);
      });
      container = createContainer(store: store);
      final notifier = container.read(offlineQueueNotifierProvider.notifier);

      await expectLater(
        notifier.enqueueIfOffline('pa1', {'status': 1}),
        throwsA(isA<OfflineSessionChangedException>()),
      );
    });

    test('without a switch the online write is left to the caller', () async {
      final notifier =
          createContainer().read(offlineQueueNotifierProvider.notifier);
      expect(await notifier.enqueueIfOffline('pa1', {'status': 1}), isFalse);
    });

    test('a captured write session ends with the account / tenant', () {
      final container = createContainer();
      final notifier = container.read(offlineQueueNotifierProvider.notifier);
      final session = notifier.captureWriteSession();
      expect(session.userId, 'u1');
      expect(session.tenantId, 42);
      expect(session.isCurrent(), isTrue);

      currentSession = 's2';
      expect(session.isCurrent(), isFalse);
      expect(session.ensureCurrent, throwsA(isA<OfflineSessionChangedException>()));

      currentSession = 's1';
      tenant = 7;
      container.invalidate(currentTenantIdProvider);
      expect(session.isCurrent(), isFalse);
    });

    test('a session captured before an awaited dialog is enforced', () async {
      final notifier =
          createContainer().read(offlineQueueNotifierProvider.notifier);
      final session = notifier.captureWriteSession();
      currentUser = 'u2'; // switch while e.g. a sheet was open
      await expectLater(
        notifier.enqueueIfOffline('pa1', {'status': 1}, session: session),
        throwsA(isA<OfflineSessionChangedException>()),
      );
    });

    test('every direct person_attendances write on the Termin page is guarded', () {
      final page = _read(
          'lib/features/attendance/presentation/pages/attendance_detail_page.dart');
      final writes = RegExp(r'repo\.updatePersonAttendance\(([^;]*);')
          .allMatches(page)
          .toList();
      expect(writes, isNotEmpty);
      for (final w in writes) {
        expect(w.group(1), contains('isSessionCurrent: writeSession.isCurrent'));
        expect(w.group(1), contains('actingUserId: writeSession.userId'));
      }
      final enqueues =
          RegExp(r'enqueueIfOffline\(([^;]*?)\)\)?').allMatches(page).toList();
      for (final e in enqueues) {
        expect(e.group(1), contains('session: writeSession'));
      }
    });
  });

  group('offline queue: unreadable queue is never overwritten', () {
    QueuedWrite write(String pa) => QueuedWrite(
          id: 'q-$pa',
          personAttendanceId: pa,
          payload: {'status': 1},
          tenantId: 42,
          userId: 'u1',
          createdAt: '2026-10-28T10:00:00',
        );

    test('undecodable storage throws and update writes nothing', () async {
      SharedPreferences.setMockInitialValues({OfflineQueueStore.queueKey: '[{"id":'});
      final store = OfflineQueueStore();
      await expectLater(store.load(), throwsA(isA<OfflineQueueLoadException>()));
      await expectLater(
        store.update((q) => OfflineQueueStore.merge(q, write('pa1'))),
        throwsA(isA<OfflineQueueLoadException>()),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(OfflineQueueStore.queueKey), '[{"id":');
    });

    test('a non-list queue is not treated as empty', () async {
      SharedPreferences.setMockInitialValues({OfflineQueueStore.queueKey: '{"a":1}'});
      await expectLater(
        OfflineQueueStore().update((q) => [...q, write('pa1')]),
        throwsA(isA<OfflineQueueLoadException>()),
      );
    });

    test('a single invalid entry is skipped but kept; valid ones stay', () async {
      SharedPreferences.setMockInitialValues({});
      final store = OfflineQueueStore();
      await store.save([write('pa1')], preserveRaw: [
        {'id': 'broken'},
      ]);
      expect((await store.load()).map((e) => e.personAttendanceId), ['pa1']);

      await store.update((q) => OfflineQueueStore.merge(q, write('pa2')));

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(OfflineQueueStore.queueKey)!;
      expect(raw, contains('"broken"'));
      expect((await store.load()).map((e) => e.personAttendanceId), ['pa1', 'pa2']);
    });

    test('enqueue fails (not queued) when the queue is unreadable', () async {
      SharedPreferences.setMockInitialValues({OfflineQueueStore.queueKey: 'nope'});
      final authEvents = StreamController<AuthChangeEvent>.broadcast();
      addTearDown(authEvents.close);
      final container = ProviderContainer(overrides: [
        connectivityProvider.overrideWith((ref) => const Stream<bool>.empty()),
        connectivityCheckProvider.overrideWithValue(() async => false),
        currentTenantIdProvider.overrideWithValue(42),
        offlineQueueUserIdProvider.overrideWithValue(() => 'u1'),
        offlineQueueSessionIdProvider.overrideWithValue(() => 's1'),
        offlineQueueAuthEventsProvider.overrideWithValue(authEvents.stream),
        offlineFlushFnProvider.overrideWithValue((entry, _) async {}),
      ]);
      addTearDown(container.dispose);
      final notifier = container.read(offlineQueueNotifierProvider.notifier);

      await expectLater(
        notifier.enqueueIfOffline('pa1', {'status': 1}),
        throwsA(isA<OfflineQueuePersistException>()),
      );
      await notifier.flush(); // must not throw or overwrite
      await notifier.onUserChanged();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(OfflineQueueStore.queueKey), 'nope');
    });
  });

  group('"Fehlende Accounts erstellen" is bound to its tenant', () {
    test('a stale / loading / foreign list is not offered', () {
      final a = TestFactories.createPersonList(2, tenantId: 1);
      expect(playersOfCurrentTenant(AsyncValue.data(a), 1), a);
      expect(playersOfCurrentTenant(AsyncValue.data(a), 2), isEmpty);
      expect(playersOfCurrentTenant(AsyncValue.data(a), null), isEmpty);
      expect(
        playersOfCurrentTenant(
            const AsyncLoading<List<Person>>().copyWithPrevious(AsyncValue.data(a)), 1),
        isEmpty,
      );
    });

    ProviderContainer container(int tenant, List<int?> created) {
      final c = ProviderContainer(overrides: [
        currentTenantIdProvider.overrideWithValue(tenant),
        userRegistrationRepositoryForTenantProvider.overrideWith(
          (ref, tenantId) => _FakeRegistrationRepo(ref, created)..bindTenantId(tenantId!),
        ),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('nothing is registered when the bound tenant is not the list tenant', () async {
      final created = <int?>[];
      final result = await container(2, created)
          .read(accountCreationNotifierProvider.notifier)
          .createAccounts(TestFactories.createPersonList(2, tenantId: 1),
              expectedTenantId: 1);
      expect(created, isEmpty);
      expect(result.created, 0);
      expect(result.hasErrors, isTrue);
    });

    test('persons of another tenant are rejected before registration', () async {
      final created = <int?>[];
      final persons = [
        TestFactories.createPerson(id: 1, tenantId: 2),
        TestFactories.createPerson(id: 2, tenantId: 1),
      ];
      final result = await container(2, created)
          .read(accountCreationNotifierProvider.notifier)
          .createAccounts(persons, expectedTenantId: 2);
      expect(created, [1]);
      expect(result.created, 1);
      expect(result.errors, hasLength(1));
    });

    test('createPlayerAccount checks membership before registering', () {
      final src = _read('lib/data/repositories/user_registration_repository.dart');
      final start = src.indexOf('Future<String> createPlayerAccount(');
      final body = src.substring(start);
      final membership = body.indexOf(".eq('tenantId', currentTenantId)");
      expect(membership, isNot(-1));
      expect(body.indexOf(".eq('id', person.id!)"), lessThan(membership));
      expect(membership, lessThan(body.indexOf('await registerUser(')));
    });

    test('settings page captures the tenant and passes it to the job', () {
      final src = _read('lib/features/settings/presentation/pages/settings_page.dart');
      final start = src.indexOf('Future<void> createMissingAccounts(');
      final body = src.substring(start);
      final capture = body.indexOf('final tenantId = ref.read(currentTenantIdProvider);');
      expect(capture, isNot(-1));
      expect(capture, lessThan(body.indexOf('await ')));
      expect(body, contains('expectedTenantId: tenantId'));
      expect(src, contains('playersOfCurrentTenant('));
    });
  });

  group('protocol: saves of a section never overlap', () {
    test('a later save waits for the running one (newest wins)', () async {
      final inFlight = <String, Future<bool>>{};
      final stored = <String>[];
      final release = Completer<void>();
      final first = chainProtocolSectionSave(inFlight, 'top1', () async {
        await release.future;
        stored.add('old');
        return true;
      });
      final second = chainProtocolSectionSave(inFlight, 'top1', () async {
        stored.add('new');
        return true;
      });
      await Future<void>.delayed(Duration.zero);
      expect(stored, isEmpty);
      release.complete();
      expect(await first, isTrue);
      expect(await second, isTrue);
      expect(stored, ['old', 'new']);
      expect(inFlight, isEmpty);
    });

    test('a failed save does not break the chain', () async {
      final inFlight = <String, Future<bool>>{};
      final first = chainProtocolSectionSave(inFlight, 'g', () async => throw StateError('x'));
      final second = chainProtocolSectionSave(inFlight, 'g', () async => true);
      expect(await first, isFalse);
      expect(await second, isTrue);
    });

    test('dispose saves through the chain with the captured document', () {
      final src = _read(
          'lib/features/team_organization/presentation/pages/protocol_page.dart');
      final start = src.indexOf('void dispose()');
      final body = src.substring(start, src.indexOf('super.dispose();', start));
      expect(body, contains('chainProtocolSectionSave(_inFlight, id'));
      expect(body, isNot(contains('unawaited(_repo.saveSection')));
      expect(body.indexOf('final doc = _currentDoc(id);'),
          lessThan(body.indexOf('c.dispose()')));
    });
  });

  group('app links with hash routes', () {
    test('web-generated #/ links keep route and query', () {
      expect(appLinkLocation(Uri.parse('https://attendix.de/#/plan?key=abc')),
          '/plan?key=abc');
      expect(appLinkLocation(Uri.parse('https://www.attendix.de/#/tabs/attendance/5')),
          '/tabs/attendance/5');
      expect(appLinkLocation(Uri.parse('https://attendix.de/?tenantId=3#/plan?key=abc')),
          '/plan?tenantId=3&key=abc');
    });

    test('path links and non-route fragments are unchanged', () {
      expect(appLinkLocation(Uri.parse('https://attendix.de/tabs/attendance/5?tenantId=3')),
          '/tabs/attendance/5?tenantId=3');
      expect(appLinkLocation(Uri.parse('https://attendix.de/login#access_token=x')),
          '/login');
      expect(appLinkLocation(Uri.parse('https://attendix.de')), '/');
    });
  });
}
