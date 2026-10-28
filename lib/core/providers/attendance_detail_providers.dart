import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/attendance/attendance.dart';
import '../../data/models/person/person.dart';
import '../config/supabase_config.dart';
import 'tenant_providers.dart';
import '../services/attendance_detail_cache.dart'; // LEFTOVERS
import '../services/offline_queue_service.dart'
    show
        OfflineQueueStore,
        connectivityCheckProvider,
        offlineQueueStoreProvider,
        offlineQueueUserIdProvider; // LEFTOVERS, SOL_FIX1, SOL_FIX4

/// Provider for attendance detail with tenant-scoped query
final attendanceDetailProvider = FutureProvider.autoDispose.family<Attendance?, int>((ref, attendanceId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final tenant = ref.watch(currentTenantProvider);

  if (tenant?.id == null) return null;

  // LEFTOVERS: offline read cache (Ionic getAttendanceByIdRobust)
  final response = await const AttendanceDetailCache().fetchWithCache<Map<String, dynamic>>(
    key: AttendanceDetailCache.keyFor(tenant!.id!, attendanceId, 'attendance'),
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
  final attendance = await ref.watch(attendanceDetailProvider(attendanceId).future);
  if (attendance?.typeId == null) return null;

  final supabase = ref.watch(supabaseClientProvider);
  final tenant = ref.watch(currentTenantProvider);

  if (tenant?.id == null) return null;

  // LEFTOVERS: offline read cache (Ionic keeps the types in memory)
  final response = await const AttendanceDetailCache().fetchWithCache<Map<String, dynamic>>(
    key: AttendanceDetailCache.keyFor(tenant!.id!, attendanceId, 'type'),
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
  final supabase = ref.watch(supabaseClientProvider);
  final tenant = ref.watch(currentTenantProvider);

  if (tenant == null) return [];

  // Get all persons with their attendance status for this attendance
  // SEC-017: Use inner join with attendance to filter by tenant
  // LEFTOVERS: offline read cache (Ionic getAttendanceByIdRobust persons)
  final tenantId = tenant.id!;
  final loaded = await const AttendanceDetailCache().fetchWithCache<List<dynamic>>(
        key: AttendanceDetailCache.keyFor(tenantId, attendanceId, 'persons'),
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
    userId: ref.read(offlineQueueUserIdProvider)(), // SOL_FIX4
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
  final supabase = ref.watch(supabaseClientProvider);
  final tenant = ref.watch(currentTenantProvider);

  if (tenant == null) return [];

  // LEFTOVERS: offline read cache for the Termin page
  final response = await const AttendanceDetailCache().fetchWithCache<List<dynamic>>(
        key: AttendanceDetailCache.playersKeyFor(tenant.id!),
        isOnline: ref.read(connectivityCheckProvider),
        fetch: () => supabase
            .from('player')
            .select('*, instrument:instrument(id, name)')
            .eq('tenantId', tenant.id!)
            .order('lastName', ascending: true),
      ) ??
      const [];

  return response.map((e) {
    final instrumentData = e['instrument'] as Map<String, dynamic>?;
    return Person.fromJson(e as Map<String, dynamic>).copyWith(
      groupName: instrumentData?['name'] as String?,
    );
  }).toList();
});

/// Persons for the Termin page. LOGIC_ATT: not filtered by paused/left –
/// the page shows exactly the persons that have a row in the Termin
/// (Ionic attendance.persons), whatever their current state.
final filteredPersonsForAttendanceProvider = FutureProvider.autoDispose.family<List<Person>, int>((ref, attendanceId) async {
  return ref.watch(allPersonsForAttendanceProvider.future);
});
