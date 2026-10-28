import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../services/attendance_list_cache.dart';
import '../services/attendance_detail_cache.dart'
    show
        OfflineReadCacheGuard,
        isOfflineFallbackError,
        purgeOfflineCachesOnAuthError; // SOL_FIX7, SOL_FIX8, SOL_FIX9, SOL_FIX10
import '../services/offline_queue_service.dart'
    show connectivityCheckProvider, offlineQueueUserIdProvider;
import '../utils/attendance_percentage_utils.dart';
import '../../data/models/attendance/attendance.dart';
import '../../data/models/person/person.dart';
import 'attendance_type_providers.dart';
import 'player_providers.dart';
import 'tenant_providers.dart';
import 'group_providers.dart';
import '../utils/paged_query.dart'; // SOL_FIX1

// Keep alive counter: incrementing forces providers watching it to refetch.
final attendanceRefetchCounter = StateProvider<int>((ref) => 0);

/// Provider for realtime player changes subscription
///
/// Subscribes to the player table and invalidates the player list
/// when changes occur. Enriches players with group names.
final realtimePlayersProvider = StreamProvider.autoDispose<List<Person>>((ref) async* {
  final supabase = ref.watch(supabaseClientProvider);
  final tenantId = ref.watch(currentTenantIdProvider);
  final playerRepo = ref.watch(playerRepositoryWithTenantProvider);

  if (tenantId == null) {
    yield [];
    return;
  }

  // Get groups map for enrichment
  final groupsMap = await ref.watch(groupsMapProvider.future);

  // Helper function to enrich players with group names
  List<Person> enrichPlayers(List<Person> players) {
    return players.map((person) {
      final groupName = person.instrument != null
          ? groupsMap[person.instrument]
          : null;
      return person.copyWith(groupName: groupName);
    }).toList();
  }

  // Initial data
  final initialData = await playerRepo.getPlayers();
  yield enrichPlayers(initialData);

  // Create a stream controller to manage updates
  final controller = StreamController<List<Person>>();
  var knownIds = initialData.map((p) => p.id).whereType<int>().toSet();

  Future<void> refetchPlayers() async {
    // Fetch fresh data when changes occur
    try {
      final freshData = await playerRepo.getPlayers();
      knownIds = freshData.map((p) => p.id).whereType<int>().toSet();
      if (!controller.isClosed) {
        controller.add(enrichPlayers(freshData));
      }
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(e);
      }
    }
  }

  // Setup realtime channel
  final channel = supabase
      .channel('player_changes_$tenantId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'player',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'tenantId',
          value: tenantId,
        ),
        callback: (payload) => refetchPlayers(),
      )
      // Supabase does not apply column filters to DELETE events, so deletes
      // are received unfiltered and matched by id (Ionic list.page: old.id).
      .onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'player',
        callback: (payload) {
          final id = (payload.oldRecord['id'] as num?)?.toInt();
          if (id != null && knownIds.contains(id)) refetchPlayers();
        },
      )
      .subscribe();

  // Cleanup on dispose
  ref.onDispose(() {
    channel.unsubscribe();
    controller.close();
  });

  // Yield updates from the controller
  await for (final data in controller.stream) {
    yield data;
  }
});

/// Ids of the attendances currently loaded by [realtimeAttendanceListProvider].
///
/// A plain mutable holder (no notifications): the list writes it after each
/// load, the realtime subscription reads it to drop DELETE events of other
/// tenants. The subscription cannot read the list provider itself because
/// the list watches the subscription (circular dependency).
class LoadedAttendanceIds {
  Set<int>? ids;
}

final loadedAttendanceIdsProvider =
    Provider<LoadedAttendanceIds>((ref) => LoadedAttendanceIds());

/// Whether an unfiltered attendance DELETE event concerns the loaded list.
/// Supabase delivers DELETE events without column filters, so events of other
/// tenants arrive too; only ids of the loaded list trigger a refetch.
/// [knownIds] null (list not loaded yet) → relevant.
bool isRelevantAttendanceDelete(
    Map<String, dynamic> oldRecord, Set<int>? knownIds) {
  final id = (oldRecord['id'] as num?)?.toInt();
  if (id == null) return false;
  if (knownIds == null) return true;
  return knownIds.contains(id);
}

/// Attendance list with client-side calculated percentages.
/// Watches the realtime subscription to auto-refresh on DB changes.
final realtimeAttendanceListProvider = FutureProvider.autoDispose<List<Attendance>>((ref) async {
  // Watch the realtime subscription so it stays alive while this provider is active.
  ref.watch(_attendanceRealtimeSubscriptionProvider);
  // Watch the refetch counter so manual invalidation triggers a refetch.
  ref.watch(attendanceRefetchCounter);

  final supabase = ref.watch(supabaseClientProvider);
  final tenant = ref.watch(currentTenantProvider);
  if (tenant?.id == null) return [];

  final tenantId = tenant!.id!;
  const cache = AttendanceListCache();
  // SOL_FIX7: the offline copy belongs to the signed-in user + tenant; no
  // user → no cache.
  final cacheUserId = ref.read(offlineQueueUserIdProvider)();
  // SOL_FIX9: cache session captured before the load; a result arriving
  // after sign-out / account switch is not stored.
  final cacheGuard = cacheUserId == null
      ? null
      : OfflineReadCacheGuard.capture(
          userId: cacheUserId,
          currentUserId: ref.read(offlineQueueUserIdProvider),
        );

  // LOGIC_SELF: Ionic att-list getAttendance — offline the cached list is
  // shown (offline_att_list_v1_<tenant>).
  final online = await ref.read(connectivityCheckProvider)();
  if (!online && cacheUserId != null) {
    final cached = await cache.load(cacheUserId, tenantId);
    if (cached != null) return cached;
  }

  // LOGIC_SELF: Ionic db.getAttendance — everything since the season start
  // (getCurrentAttDate), no row limit.
  final List<dynamic> response;
  final List<AttendanceType> types;
  try {
    // SOL_FIX10: the whole load (attendances AND attendance types) runs
    // inside the auth-error cleanup.
    (response, types) = await purgeOfflineCachesOnAuthError(
      cacheUserId,
      tenantId,
      () async {
        // SOL_FIX1: paged (PostgREST max-rows 1000), stable order date+id.
        final rows = await fetchAllPages<dynamic>((from, to) async => await supabase
            .from('attendance')
            .select('*, person_attendances(status, notes, duty_state)')
            .eq('tenantId', tenantId)
            .gt('date', attendanceListStartDate(tenant.seasonStart))
            .order('date', ascending: false)
            .order('id', ascending: false)
            .range(from, to) as List);
        final loadedTypes = await ref.watch(attendanceTypesProvider.future);
        return (rows, loadedTypes);
      },
    );
  } catch (e) {
    // SOL_FIX7: only network failures fall back to the offline copy;
    // auth/permission errors (revoked access) are shown.
    if (cacheUserId == null || !isOfflineFallbackError(e)) rethrow;
    final cached = await cache.load(cacheUserId, tenantId);
    if (cached != null) return cached;
    rethrow;
  }

  final typesById = {for (final t in types) t.id: t};

  final attendances = response.map((e) {
    final attendance = Attendance.fromJson(e as Map<String, dynamic>);
    final rows = ((e['person_attendances'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    // LOGIC_SELF: Ionic getPercentage(averagePersons(...), shift_excused_as_present)
    return attendance.copyWith(
      percentage: attendanceListPercentage(
        rows,
        typesById[attendance.typeId],
        shiftExcusedAsPresent: tenant.shiftExcusedAsPresent,
      ),
    );
  }).toList();
  ref.read(loadedAttendanceIdsProvider).ids =
      attendances.map((a) => a.id).whereType<int>().toSet();
  if (cacheUserId != null) {
    await cache.save(cacheUserId, tenantId, attendances, guard: cacheGuard);
  }
  return attendances;
});

/// Internal: manages Supabase realtime subscription for the attendance table.
/// Bumps the refetch counter when attendance or person_attendances rows change,
/// triggering a refetch of the list with fresh percentages.
final _attendanceRealtimeSubscriptionProvider = Provider.autoDispose<void>((ref) {
  ref.watch(currentAuthUserIdProvider); // SOL_FIX15: reload per account
  final supabase = ref.watch(supabaseClientProvider);
  final tenant = ref.watch(currentTenantProvider);
  if (tenant?.id == null) return;

  void onChanged(dynamic _) {
    ref.read(attendanceRefetchCounter.notifier).state++;
  }

  final channel = supabase
      .channel('attendance_list_changes_${tenant!.id}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'attendance',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'tenantId',
          value: tenant.id,
        ),
        callback: onChanged,
      )
      // DELETE events are not filtered by Supabase (old record = id only):
      // listen unfiltered and only refetch when the deleted id is in the
      // loaded list (same pattern as players / isRelevantSongDelete).
      .onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'attendance',
        callback: (payload) {
          if (isRelevantAttendanceDelete(
            payload.oldRecord,
            ref.read(loadedAttendanceIdsProvider).ids,
          )) {
            onChanged(payload);
          }
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'person_attendances',
        // No tenant filter possible — person_attendances has no tenantId column.
        // Tenant isolation is in the data query (.eq('tenantId', ...)).
        // Cost of spurious refetch: one tenant-filtered SELECT — negligible.
        callback: onChanged,
      )
      .subscribe();

  ref.onDispose(() => channel.unsubscribe());
});

/// Provider for realtime pending player changes subscription
///
/// Subscribes to the player table filtered by pending=true and invalidates
/// when changes occur (new registrations)
final realtimePendingPlayersProvider = StreamProvider.autoDispose<List<Person>>((ref) async* {
  final supabase = ref.watch(supabaseClientProvider);
  final tenantId = ref.watch(currentTenantIdProvider);
  final playerRepo = ref.watch(playerRepositoryWithTenantProvider);

  if (tenantId == null) {
    yield [];
    return;
  }

  // Initial data
  final initialData = await playerRepo.getPendingPlayers();
  yield initialData;

  // Create a stream controller
  final controller = StreamController<List<Person>>();
  var pendingIds = initialData.map((p) => p.id).whereType<int>().toSet();

  Future<void> refetchPending() async {
    try {
      final freshData = await playerRepo.getPendingPlayers();
      pendingIds = freshData.map((p) => p.id).whereType<int>().toSet();
      if (!controller.isClosed) {
        controller.add(freshData);
      }
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(e);
      }
    }
  }

  // Setup realtime channel — listen for all player changes (pending flag changes)
  final channel = supabase
      .channel('pending_player_changes_$tenantId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'player',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'tenantId',
          value: tenantId,
        ),
        callback: (payload) {
          // MEDIA_REALTIME: like Ionic settings.page.ts — refetch for new
          // pending registrations and for any update/delete (old.id set).
          final isPendingInsert = payload.newRecord['pending'] == true;
          final hasOld = payload.oldRecord['id'] != null;
          if (!isPendingInsert && !hasOld) return;
          refetchPending();
        },
      )
      // DELETE events arrive only without a column filter; refetch when a
      // known pending person was deleted (e.g. registration declined).
      .onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'player',
        callback: (payload) {
          final id = (payload.oldRecord['id'] as num?)?.toInt();
          if (id != null && pendingIds.contains(id)) refetchPending();
        },
      )
      .subscribe();

  ref.onDispose(() {
    channel.unsubscribe();
    controller.close();
  });

  await for (final data in controller.stream) {
    yield data;
  }
});
