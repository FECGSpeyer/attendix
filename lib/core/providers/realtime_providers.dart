import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../constants/enums.dart';
import '../../data/models/attendance/attendance.dart';
import '../../data/models/person/person.dart';
import 'player_providers.dart';
import 'tenant_providers.dart';
import 'group_providers.dart';

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
        callback: (payload) async {
          // Fetch fresh data when changes occur
          try {
            final freshData = await playerRepo.getPlayers();
            if (!controller.isClosed) {
              controller.add(enrichPlayers(freshData));
            }
          } catch (e) {
            if (!controller.isClosed) {
              controller.addError(e);
            }
          }
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

  final response = await supabase
      .from('attendance')
      .select('*, person_attendances(status)')
      .eq('tenantId', tenant!.id!)
      .order('date', ascending: false)
      .limit(50);

  return (response as List).map((e) {
    final attendance = Attendance.fromJson(e as Map<String, dynamic>);
    final personAttendances = e['person_attendances'] as List?;
    if (personAttendances != null && personAttendances.isNotEmpty) {
      final total = personAttendances.length;
      final present = personAttendances.where((pa) {
        final status = AttendanceStatus.fromValue(pa['status'] as int? ?? 0);
        return status.countsAsPresent;
      }).length;
      return attendance.copyWith(
        percentage: (present / total * 100).roundToDouble(),
      );
    }
    return attendance;
  }).toList();
});

/// Internal: manages Supabase realtime subscription for the attendance table.
/// Bumps the refetch counter when attendance or person_attendances rows change,
/// triggering a refetch of the list with fresh percentages.
final _attendanceRealtimeSubscriptionProvider = Provider.autoDispose<void>((ref) {
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
        callback: (payload) async {
          // MEDIA_REALTIME: like Ionic settings.page.ts — refetch for new
          // pending registrations and for any update/delete (old.id set).
          final isPendingInsert = payload.newRecord['pending'] == true;
          final hasOld = payload.oldRecord['id'] != null;
          if (!isPendingInsert && !hasOld) return;
          try {
            final freshData = await playerRepo.getPendingPlayers();
            if (!controller.isClosed) {
              controller.add(freshData);
            }
          } catch (e) {
            if (!controller.isClosed) {
              controller.addError(e);
            }
          }
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
