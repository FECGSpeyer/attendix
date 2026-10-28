import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/attendance/attendance.dart';
import '../models/dashboard/dashboard_event.dart';
import '../models/dashboard/dashboard_models.dart';
import '../models/person/person.dart';
import 'base_repository.dart';

/// Provider for DashboardRepository
final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref);
});

/// Read-only queries backing the home dashboard cards
/// (Ionic `home-dashboard/components/*`).
///
/// Every query is scoped to the current tenant.
class DashboardRepository extends BaseRepository with TenantAwareRepository {
  DashboardRepository(super.ref);

  static const _attendanceWithPersonsSelect = '''*, persons:person_attendances(
          *, person:person_id(
            firstName, lastName, img, instrument(id, name), joined
          )
        )''';

  /// All non-pending persons of the tenant INCLUDING archived ones
  /// (Ionic `getPlayers(true)`). Cards filter `left` themselves.
  Future<List<Person>> getAllPersons() async {
    try {
      final response = await supabase
          .from('player')
          .select('*')
          .eq('tenantId', currentTenantId)
          .isFilter('pending', false);

      return (response as List)
          .map((e) => Person.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getAllPersons');
      rethrow;
    }
  }

  /// Termine around today with their person attendances, for the
  /// "Termine" card (last finished + next upcoming Termin).
  ///
  /// Ionic loads every Termin since season start; we only fetch the few rows
  /// around today that can become "last" or "next" (a multi-day Termin that
  /// started earlier but is still running counts as upcoming).
  Future<List<DashboardEvent>> getEventsAroundToday({String? seasonStart}) async {
    try {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);

      var pastQuery = supabase
          .from('attendance')
          .select(_attendanceWithPersonsSelect)
          .eq('tenantId', currentTenantId)
          .lt('date', startOfToday.toIso8601String());
      if (seasonStart != null && seasonStart.isNotEmpty) {
        pastQuery = pastQuery.gt('date', seasonStart);
      }

      final results = await Future.wait([
        pastQuery.order('date', ascending: false).limit(5),
        supabase
            .from('attendance')
            .select(_attendanceWithPersonsSelect)
            .eq('tenantId', currentTenantId)
            .gte('date', startOfToday.toIso8601String())
            .order('date')
            .limit(5),
      ]);

      return [
        for (final rows in results)
          for (final row in rows as List) _parseEvent(row as Map<String, dynamic>),
      ];
    } catch (e, stack) {
      handleError(e, stack, 'getEventsAroundToday');
      rethrow;
    }
  }

  /// Upcoming Termine incl. multi-day Termine that are still running
  /// (Ionic `getUpcomingAttendances(undefined, true)`), ascending by date.
  Future<List<DashboardEvent>> getUpcomingEventsIncludingRunning() async {
    try {
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 31));

      final response = await supabase
          .from('attendance')
          .select('*')
          .eq('tenantId', currentTenantId)
          .gt('date', from.toIso8601String())
          .order('date');

      return (response as List)
          .map((e) => _parseEvent(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getUpcomingEventsIncludingRunning');
      rethrow;
    }
  }

  /// Absences of the tenant (Ionic `PlayerAbsenceService.getAbsencesForTenant`).
  ///
  /// NOTE: `player_absences` names its tenant column `tenant_id` (snake_case).
  Future<List<DashboardAbsence>> getAbsences() async {
    try {
      final response = await supabase
          .from('player_absences')
          .select('*')
          .eq('tenant_id', currentTenantId);

      return (response as List)
          .map((e) => DashboardAbsence.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getAbsences');
      rethrow;
    }
  }

  /// Raw `history` rows planned from today on, with song, conductor and
  /// Termin (Ionic `getCurrentSongs`). Grouping happens in the provider.
  Future<List<Map<String, dynamic>>> getCurrentSongHistory() async {
    try {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);

      final response = await supabase
          .from('history')
          .select('''
            id,
            person_id (
              firstName, lastName
            ),
            date,
            otherConductor,
            song:songId (*),
            attendance_id (
              id,
              date,
              type_id,
              typeInfo
            )
          ''')
          .eq('tenantId', currentTenantId)
          .gt('date', startOfToday.toIso8601String());

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e, stack) {
      handleError(e, stack, 'getCurrentSongHistory');
      rethrow;
    }
  }

  /// Tenant flag `shift_excused_as_present` (not part of the shared Tenant
  /// model). The `tenants` table is keyed by `id` = current tenant id.
  Future<bool> getShiftExcusedAsPresent() async {
    try {
      final response = await supabase
          .from('tenants')
          .select('shift_excused_as_present')
          .eq('id', currentTenantId)
          .maybeSingle();
      return response?['shift_excused_as_present'] == true;
    } catch (e, stack) {
      handleError(e, stack, 'getShiftExcusedAsPresent');
      rethrow;
    }
  }

  DashboardEvent _parseEvent(Map<String, dynamic> row) {
    final data = Map<String, dynamic>.from(row);
    final rawPersons = data.remove('persons') as List?;
    final rawExtraPlans = data['extra_plans'];

    final persons = <PersonAttendance>[];
    for (final raw in rawPersons ?? const []) {
      final pa = Map<String, dynamic>.from(raw as Map);
      final person = pa.remove('person') as Map<String, dynamic>?;
      final instrument = person?['instrument'];
      persons.add(PersonAttendance.fromJson({
        ...pa,
        'firstName': person?['firstName'],
        'lastName': person?['lastName'],
        'img': person?['img'],
        'joined': person?['joined'],
        if (instrument is Map) 'instrument': instrument['id'],
        if (instrument is Map) 'groupName': instrument['name'],
      }));
    }

    return DashboardEvent(
      attendance: Attendance.fromJson(data),
      persons: persons,
      extraPlans: rawExtraPlans is List
          ? rawExtraPlans
              .whereType<Map>()
              .map((p) => Map<String, dynamic>.from(p))
              .toList()
          : const [],
    );
  }
}
