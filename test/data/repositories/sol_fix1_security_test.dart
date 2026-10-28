// SOL_FIX1: fixes for the external review of PR #225.
import 'dart:io';

import 'package:attendix/core/providers/attendance_providers.dart';
import 'package:attendix/core/providers/player_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/services/offline_queue_service.dart';
import 'package:attendix/core/utils/paged_query.dart';
import 'package:attendix/data/repositories/player_repository.dart';
import 'package:attendix/data/repositories/song_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

/// Body of [method] in [source] (from its signature to the next method doc).
String _method(String source, String signature) {
  final start = source.indexOf(signature);
  expect(start, isNot(-1), reason: '$signature not found');
  final next = source.indexOf('\n  /// ', start + signature.length);
  return source.substring(start, next == -1 ? source.length : next);
}

QueuedWrite _write(String paId, Map<String, dynamic> payload, int tenantId) =>
    QueuedWrite(
      id: 'q-$paId-$tenantId',
      personAttendanceId: paId,
      payload: payload,
      tenantId: tenantId,
      userId: 'u1',
      createdAt: '2026-10-28T10:00:00Z',
    );

void main() {
  group('Multi-Tenant Security: SOL_FIX1 per-tenant repository instances', () {
    test('a bound repository cannot switch tenant', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final repo = container.read(playerRepositoryForTenantProvider(1));
      expect(repo.currentTenantId, 1);
      expect(() => repo.setTenantId(2), throwsStateError);
      repo.setTenantId(1); // same tenant stays allowed
      expect(repo.currentTenantId, 1);
    });

    test('tenant switch A→B gives a new instance, A keeps its tenant', () {
      var tenant = 1;
      final container = ProviderContainer(overrides: [
        currentTenantIdProvider.overrideWith((ref) => tenant),
      ]);
      addTearDown(container.dispose);

      final playerA = container.read(playerRepositoryWithTenantProvider);
      final attA = container.read(attendanceRepositoryWithTenantProvider);

      tenant = 2;
      container.invalidate(currentTenantIdProvider);

      final playerB = container.read(playerRepositoryWithTenantProvider);
      final attB = container.read(attendanceRepositoryWithTenantProvider);

      expect(identical(playerA, playerB), isFalse);
      expect(identical(attA, attB), isFalse);
      // A running flow on the A instance still queries tenant A.
      expect(playerA.currentTenantId, 1);
      expect(attA.currentTenantId, 1);
      expect(playerB.currentTenantId, 2);
      expect(attB.currentTenantId, 2);
    });

    test('no tenant → unbound instance without tenant id', () {
      final container = ProviderContainer(overrides: [
        currentTenantIdProvider.overrideWith((ref) => null),
      ]);
      addTearDown(container.dispose);
      expect(container.read(playerRepositoryWithTenantProvider).hasTenantId,
          isFalse);
    });

    test('song instances are per (tenant, song source)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final a = container.read(songRepositoryForTenantProvider(
          (tenantId: 1, songSourceTenantId: null)));
      final aSynced = container.read(songRepositoryForTenantProvider(
          (tenantId: 1, songSourceTenantId: 9)));
      final b = container.read(songRepositoryForTenantProvider(
          (tenantId: 2, songSourceTenantId: null)));
      expect(a.songTenantId, 1);
      expect(aSynced.songTenantId, 9);
      expect(b.songTenantId, 2);
      expect(() => a.setTenantId(2), throwsStateError);
    });

    test('WithTenant providers never mutate the shared instance', () {
      final player = _read('lib/core/providers/player_providers.dart');
      final song = _read('lib/core/providers/song_providers.dart');
      final att = _read('lib/core/providers/attendance_providers.dart');
      final stats = _read('lib/core/providers/statistics_providers.dart');
      expect(player, contains('playerRepositoryForTenantProvider(tenant)'));
      expect(att, contains('attendanceRepositoryForTenantProvider(tenant)'));
      expect(song, contains('songRepositoryForTenantProvider('));
      for (final src in [player, song, att, stats]) {
        expect(src, isNot(contains('repo.setTenantId(')));
        expect(src, isNot(contains('..setTenantId(')));
      }
    });

    test('getSongs uses one captured tenant for queries and cache key', () {
      final body = _method(_read('lib/data/repositories/song_repository.dart'),
          'Future<List<Song>> getSongs()');
      expect(body, contains('final tenantId = songTenantId;'));
      expect(body, contains(".eq('tenantId', tenantId)"));
      expect(body, isNot(contains(".eq('tenantId', songTenantId)")));
      // SOL_FIX7: the cache key is derived from the captured tenant (+ user).
      expect(body, contains('final cacheKey = _offlineSongsKey(tenantId);'));
      expect(body, contains('_writeOfflineSongs(cacheKey'));
    });

    test('player flows use their own registration repository instance', () {
      final src = _read('lib/data/repositories/player_repository.dart');
      final body = _method(src, 'UserRegistrationRepository _registration()');
      expect(body, contains('UserRegistrationRepository(ref)'));
      expect(body, contains('bindTenantId(currentTenantId)'));
      expect(body, isNot(contains('userRegistrationRepositoryProvider')));
    });
  });

  group('Multi-Tenant Security: SOL_FIX1 account access', () {
    final src = _read('lib/data/repositories/player_repository.dart');

    test('archivePlayer revokes access whenever an appId exists', () {
      final body = _method(src, 'Future<void> archivePlayer(');
      expect(body, contains('if (appId != null && appId.isNotEmpty) {'));
      expect(body, contains('removeUserFromTenant(appId, personId: player.id)'));
      expect(body, isNot(contains('player.email')));
    });

    test('delete and decline revoke access based on appId only', () {
      final del = _method(src, 'Future<void> deletePlayer(');
      expect(del, contains('removeUserFromTenant(appId, personId: playerId)'));
      expect(del, isNot(contains('email')));
      final decline = _method(src, 'Future<void> declinePlayer(');
      expect(decline, contains('removeUserFromTenant(player.appId!'));
      expect(decline, isNot(contains('email')));
    });

    test('removeUserFromTenant keeps admin and multi-link checks', () {
      final body = _method(src, 'Future<void> removeUserFromTenant(');
      expect(body, contains(".eq('role', Role.admin.value)"));
      expect(body, contains(".neq('id', personId)"));
    });
  });

  group('SOL_FIX1 shift status in backfill', () {
    final src = _read('lib/data/repositories/player_repository.dart');

    test('addPlayerToAttendancesByDate uses the type default like Ionic (PARITY_A D4)',
        () {
      final body = _method(src, 'Future<void> addPlayerToAttendancesByDate(');
      expect(body, isNot(contains('_loadShiftPlan(')));
      expect(body, isNot(contains('_initialStatus(')));
      expect(body, contains("'notes': '',"));
      expect(body, contains("'status': type.defaultStatus,"));
    });

    test('auto unpause history text matches Ionic (PARITY_A D5)', () {
      expect(src, contains("'Automatisch reaktiviert (Pausendatum erreicht)'"));
      expect(src, isNot(contains('Pausenzeit abgelaufen')));
    });

    test('addToUpcomingAttendances shares the same computation', () {
      final body = _method(src, 'Future<void> addToUpcomingAttendances(');
      expect(body, contains('_initialStatus(player, type, att, shift)'));
      final helper = _method(src, '({int status, String notes}) _initialStatus(');
      expect(helper, contains('peopleStatusByShift('));
      expect(helper, contains('type.allDay'));
    });
  });

  group('SOL_FIX1 pagination', () {
    test('fetchAllPages loads until a short page', () async {
      final calls = <(int, int)>[];
      final rows = await fetchAllPages<int>((from, to) async {
        calls.add((from, to));
        final total = 2500;
        final end = to + 1 > total ? total : to + 1;
        return [for (var i = from; i < end; i++) i];
      });
      expect(rows.length, 2500);
      expect(rows.toSet().length, 2500);
      expect(calls, [(0, 999), (1000, 1999), (2000, 2999)]);
    });

    test('exact multiple of the page size stops on the empty page', () async {
      var pages = 0;
      final rows = await fetchAllPages<int>((from, to) async {
        pages++;
        return from >= 2000 ? <int>[] : List.filled(1000, 0);
      });
      expect(rows.length, 2000);
      expect(pages, 3);
    });

    test('all-rows queries are paged, ordered and tenant filtered', () {
      final stats = _read('lib/core/providers/statistics_providers.dart');
      final list = _read('lib/core/providers/realtime_providers.dart');
      final plan = _read('lib/data/repositories/plan_repository.dart');
      final pct = _read('lib/core/providers/attendance_providers.dart');
      for (final src in [stats, list, plan]) {
        expect(src, contains('fetchAllPages<dynamic>('));
        expect(src, contains('.range(from, to)'));
      }
      expect(stats, contains(".eq('attendance.tenantId', tenantId)"));
      expect(stats, contains(".order('id', ascending: true)"));
      expect(list, contains(".eq('tenantId', tenantId)"));
      expect(list, contains(".order('id', ascending: false)"));
      expect(plan, contains(".eq('tenantId', tenantId)"));
      expect(plan, contains(".order('id', ascending: false)"));
      expect(pct, contains(".order('id', ascending: true)"));
    });
  });

  group('Multi-Tenant Security: SOL_FIX1 offline overlay', () {
    test('pending writes of the tenant override cached rows', () {
      final rows = [
        {'id': 'a', 'status': 1, 'notes': ''},
        {'id': 'b', 'status': 1, 'notes': 'x'},
      ];
      final result = OfflineQueueStore.overlayPending(rows, [
        _write('a', {'status': 2}, 7),
        _write('a', {'notes': 'krank'}, 7),
        _write('b', {'status': 4}, 8), // other tenant → ignored
      ], tenantId: 7, userId: 'u1');
      expect(result[0], {'id': 'a', 'status': 2, 'notes': 'krank'});
      expect(result[1], {'id': 'b', 'status': 1, 'notes': 'x'});
      // Source rows are not mutated (the cache keeps server data).
      expect(rows[0]['status'], 1);
    });

    test('empty queue returns the rows unchanged', () {
      final rows = [
        {'id': 'a', 'status': 1}
      ];
      expect(
          identical(
              OfflineQueueStore.overlayPending(rows, const [],
                  tenantId: 1, userId: 'u1'),
              rows),
          isTrue);
    });

    test('detail provider overlays the queue on cached persons', () {
      final src = _read('lib/core/providers/attendance_detail_providers.dart');
      expect(src, contains('OfflineQueueStore.overlayPending('));
      expect(src, contains('ref.read(offlineQueueStoreProvider).load()'));
      expect(src, contains('tenantId: tenantId'));
    });
  });
}
