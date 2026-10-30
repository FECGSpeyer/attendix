import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/attendance/attendance.dart';
import '../../data/models/person/person.dart';
import '../config/supabase_config.dart';
import 'tenant_providers.dart';
import '../services/attendance_detail_cache.dart';
import '../services/offline_queue_service.dart'
    show
        OfflineQueueStore,
        connectivityCheckProvider,
        offlineQueueStoreProvider,
        offlineQueueUserIdProvider; // LEFTOVERS, SOL_FIX1, SOL_FIX4

/// SOL_FIX7: offline cache keys are bound to the signed-in user + tenant;
/// null (no user) disables the cache.
String? _detailCacheKey(Ref ref, int tenantId, int attendanceId, String part) {
  final userId = ref.read(offlineQueueUserIdProvider)();
  return userId == null
      ? null
      : AttendanceDetailCache.keyFor(userId, tenantId, attendanceId, part);
}

String? _playersCacheKey(Ref ref, int tenantId) {
  final userId = ref.read(offlineQueueUserIdProvider)();
  return userId == null ? null : AttendanceDetailCache.playersKeyFor(userId, tenantId);
}

/// SOL_FIX8: user + tenant whose offline copies are purged on 401/403.
OfflineCacheScope? _cacheScope(Ref ref, int tenantId) {
  final userId = ref.read(offlineQueueUserIdProvider)();
  return userId == null ? null : (userId: userId, tenantId: tenantId);
}

/// Provider for attendance detail with tenant-scoped query
final attendanceDetailProvider = FutureProvider.autoDispose.family<Attendance?, int>((ref, attendanceId) async {
  ref.watch(currentAuthUserIdProvider); // SOL_FIX15: reload per account (RLS)
  final supabase = ref.watch(supabaseClientProvider);
  final tenant = ref.watch(currentTenantProvider);

  if (tenant?.id == null) return null;

  // LEFTOVERS: offline read cache (Ionic getAttendanceByIdRobust)
  final response = await const AttendanceDetailCache().fetchWithCache<Map<String, dynamic>>(
    key: _detailCacheKey(ref, tenant!.id!, attendanceId, 'attendance'),
    scope: _cacheScope(ref, tenant.id!),
    currentUserId: ref.read(offlineQueueUserIdProvider),
    isOnline: ref.read(connectivityCheckProvider),
    fetch: () => supabase
        .from('attendance')
        .select('*')
        .eq('id', attendanceId)
        .eq('tenantId', tenant.id!)
        .maybeSingle(),
  );

  if (response == null) return null;
  return Attendance.fromJson(response);
});

/// Provider for attendance type of a specific attendance
/// FN-005: Added tenant_id filter for multi-tenant security
final attendanceTypeForAttendanceProvider = FutureProvider.autoDispose.family<AttendanceType?, int>((ref, attendanceId) async {
  ref.watch(currentAuthUserIdProvider); // SOL_FIX15: reload per account (RLS)
  final attendance = await ref.watch(attendanceDetailProvider(attendanceId).future);
  if (attendance?.typeId == null) return null;

  final supabase = ref.watch(supabaseClientProvider);
  final tenant = ref.watch(currentTenantProvider);

  if (tenant?.id == null) return null;

  // LEFTOVERS: offline read cache (Ionic keeps the types in memory)
  final response = await const AttendanceDetailCache().fetchWithCache<Map<String, dynamic>>(
    key: _detailCacheKey(ref, tenant!.id!, attendanceId, 'type'),
    scope: _cacheScope(ref, tenant.id!),
    currentUserId: ref.read(offlineQueueUserIdProvider),
    isOnline: ref.read(connectivityCheckProvider),
    fetch: () => supabase
        .from('attendance_types')
        .select('*')
        .eq('id', attendance!.typeId!)
        .eq('tenant_id', tenant.id!)
        .maybeSingle(),
  );

  if (response == null) return null;
  return AttendanceType.fromJson(response);
});

/// Provider for person attendances for a specific attendance
/// NOTE: This is different from personAttendancesProvider in attendance_providers.dart
/// which gets attendances for a specific PERSON. This one gets persons for a specific ATTENDANCE.
/// SEC-017: Added tenant filter via inner join with attendance table
final personAttendancesForAttendanceProvider = FutureProvider.autoDispose.family<List<PersonAttendance>, int>((ref, attendanceId) async {
  ref.watch(currentAuthUserIdProvider); // SOL_FIX15: reload per account (RLS)
  final supabase = ref.watch(supabaseClientProvider);
  final tenant = ref.watch(currentTenantProvider);

  final tenantId = tenant?.id;
  if (tenantId == null) return [];

  // Get all persons with their attendance status for this attendance
  // SEC-017: Use inner join with attendance to filter by tenant
  // LEFTOVERS: offline read cache (Ionic getAttendanceByIdRobust persons)
  final loaded = await const AttendanceDetailCache().fetchWithCache<List<dynamic>>(
        key: _detailCacheKey(ref, tenantId, attendanceId, 'persons'),
        scope: _cacheScope(ref, tenantId),
        currentUserId: ref.read(offlineQueueUserIdProvider),
        isOnline: ref.read(connectivityCheckProvider),
        fetch: () => supabase
            .from('person_attendances')
            .select('*, player:person_id(firstName, lastName, img, instrument, left, paused), attendance:attendance_id!inner(tenantId)')
            .eq('attendance_id', attendanceId)
            .eq('attendance.tenantId', tenantId),
      ) ??
      const [];

  // SOL_FIX1: pending offline writes (not yet replayed) win over the cached
  // or loaded rows, so an offline status/notes change survives reopening.
  final response = OfflineQueueStore.overlayPending(
    loaded,
    await ref.read(offlineQueueStoreProvider).load(),
    tenantId: tenantId,
    userId: ref.read(offlineQueueUserIdProvider)(),
  );

  return response.map((e) {
    // Extract player data from nested structure - handle potential type mismatch
    final playerData = e['player'];
    final playerMap = playerData is Map<String, dynamic> ? playerData : null;
    return PersonAttendance.fromJson({
      ...e,
      'firstName': playerMap?['firstName'],
      'lastName': playerMap?['lastName'],
      'img': playerMap?['img'],
      'instrument': playerMap?['instrument'],
      'left': playerMap?['left'],
      'paused': playerMap?['paused'],
    });
  }).toList();
});

/// Person attendances shown on the Termin page.
///
/// LOGIC_ATT: Ionic shows every person_attendances row of the Termin
/// (initializeAttObjects), also for paused or left persons, so header
/// counts match the stored rows. Kept as a separate provider for callers.
final filteredPersonAttendancesForAttendanceProvider = FutureProvider.autoDispose.family<List<PersonAttendance>, int>((ref, attendanceId) async {
  return ref.watch(personAttendancesForAttendanceProvider(attendanceId).future);
});

/// Provider for all persons in tenant (for attendance taking)
final allPersonsForAttendanceProvider = FutureProvider.autoDispose<List<Person>>((ref) async {
  ref.watch(currentAuthUserIdProvider); // SOL_FIX15: reload per account (RLS)
  final supabase = ref.watch(supabaseClientProvider);
  final tenant = ref.watch(currentTenantProvider);

  final tenantId = tenant?.id;
  if (tenantId == null) return [];

  // LEFTOVERS: offline read cache for the Termin page
  final response = await const AttendanceDetailCache().fetchWithCache<List<dynamic>>(
        key: _playersCacheKey(ref, tenantId),
        scope: _cacheScope(ref, tenantId),
        currentUserId: ref.read(offlineQueueUserIdProvider),
        isOnline: ref.read(connectivityCheckProvider),
        fetch: () => supabase
            .from('player')
            .select('*, instrument:instrument(id, name)')
            .eq('tenantId', tenantId)
            .order('lastName', ascending: true),
      ) ??
      const [];

  return response
      .map((e) => personFromPlayerRowWithGroup(e as Map<String, dynamic>))
      .toList();
});

/// GROUP_ORDER: a `player` row loaded with `instrument:instrument(id, name)`
/// carries the group as an embedded object, not as the id. `Person.instrument`
/// must stay the group id (Ionic `getModifiedAttendanceData`:
/// `instrument = person.instrument.id`, `groupName = person.instrument.name`),
/// otherwise every person has `instrument == null` and the Ionic group order
/// (main group first, group sort_order, name) and the helper group filter
/// silently fall back to the query order.
Person personFromPlayerRowWithGroup(Map<String, dynamic> row) {
  final instrumentData = row['instrument'];
  if (instrumentData is Map) {
    final id = instrumentData['id'];
    return Person.fromJson({
      ...row,
      'instrument': id is int ? id : int.tryParse('$id'),
    }).copyWith(groupName: instrumentData['name']?.toString());
  }
  // Older cache entries / plain rows: `instrument` is already the id.
  return Person.fromJson(row);
}

/// Persons for the Termin page. LOGIC_ATT: not filtered by paused/left –
/// the page shows exactly the persons that have a row in the Termin
/// (Ionic attendance.persons), whatever their current state.
final filteredPersonsForAttendanceProvider = FutureProvider.autoDispose.family<List<Person>, int>((ref, attendanceId) async {
  return ref.watch(allPersonsForAttendanceProvider.future);
});
