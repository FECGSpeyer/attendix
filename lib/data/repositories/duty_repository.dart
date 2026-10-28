import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/enums.dart';
import '../../core/utils/duty_utils.dart';
import '../models/attendance/attendance.dart';
import '../models/duty/person_unavailability.dart';
import 'base_repository.dart';
import '../../l10n/l10n.dart';

/// Provider for DutyRepository
final dutyRepositoryProvider = Provider<DutyRepository>((ref) {
  return DutyRepository(ref);
});

/// Result of "Ich übernehme" (RPC `duty_take`).
enum DutyTakeResult { ok, full, notMember, notAllowed, past }

/// Notification types of the `duty-notify` edge function.
enum DutyNotifyType { assigned, understaffed, filled }

/// An upcoming duty Termin with its persons ("Offene Dienste", distribution).
class DutyTermin {
  const DutyTermin({
    required this.attendance,
    required this.type,
    required this.required,
    required this.occupied,
    required this.persons,
  });

  final Attendance attendance;
  final AttendanceType type;
  final int required;
  final int occupied;
  final List<PersonAttendance> persons;

  int get open => required - occupied;

  String get title {
    final info = attendance.typeInfo;
    if (info != null && info.isNotEmpty) return info;
    return type.name.isNotEmpty ? type.name : l10nWithoutContext.dutyDuty;
  }
}

/// Repository for the Dienstplan (duty roster), ported from Ionic
/// `services/duty/duty.service.ts`.
///
/// Multi-tenant notes:
/// - `attendance` is filtered by `tenantId`.
/// - `person_unavailability` is filtered by `tenant_id`.
/// - `person_attendances` has no tenant column: every read joins the parent
///   attendance with `!inner` and filters `attendance.tenantId`; every write
///   first validates the ids via [_validIdsForTenant].
class DutyRepository extends BaseRepository with TenantAwareRepository {
  DutyRepository(super.ref);

  String? get _userId => supabase.auth.currentUser?.id;

  String _nowIso() => DateTime.now().toUtc().toIso8601String();

  /// Returns the subset of [ids] whose attendance belongs to the current tenant.
  Future<List<String>> _validIdsForTenant(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await supabase
        .from('person_attendances')
        .select('id, attendance:attendance_id!inner(tenantId)')
        .inFilter('id', ids)
        .eq('attendance.tenantId', currentTenantId);
    return (rows as List).map((r) => r['id'].toString()).toList();
  }

  /// Leadership assigns persons; they get a push and have to confirm.
  Future<void> assign(List<String> personAttendanceIds, int attendanceId) async {
    if (personAttendanceIds.isEmpty) return;
    ensureNotDemo('assignDuty'); // DEMO_GUARD
    try {
      final validIds = await _validIdsForTenant(personAttendanceIds);
      if (validIds.isEmpty) {
        throw RepositoryException(message: l10nWithoutContext.coreFlutterRepoNoValidPersons, operation: 'assign');
      }
      // person_attendances has no tenantId: ids validated above via attendance.tenantId
      await supabase.from('person_attendances').update({
        'duty_state': DutyState.requested,
        'status': AttendanceStatus.neutral.value,
        'notes': '',
        'duty_assigned_by': _userId,
        'duty_assigned_at': _nowIso(),
        'duty_reminder_sent': false,
        'changed_by': _userId,
        'changed_at': _nowIso(),
      }).inFilter('id', validIds);

      await notify(DutyNotifyType.assigned, attendanceId, personAttendanceIds: validIds);
    } catch (e, stack) {
      handleError(e, stack, 'assign');
      rethrow;
    }
  }

  /// Removes an assignment; the person is a stand-in again.
  Future<void> unassign(String personAttendanceId) async {
    try {
      final validIds = await _validIdsForTenant([personAttendanceId]);
      if (validIds.isEmpty) {
        throw RepositoryException(message: l10nWithoutContext.coreFlutterAccessDenied, operation: 'unassign');
      }
      // person_attendances has no tenantId: id validated above via attendance.tenantId
      await supabase.from('person_attendances').update({
        'duty_state': null,
        'status': AttendanceStatus.neutral.value,
        'notes': '',
        'duty_assigned_by': null,
        'duty_assigned_at': null,
        'changed_by': _userId,
        'changed_at': _nowIso(),
      }).eq('id', validIds.first);
    } catch (e, stack) {
      handleError(e, stack, 'unassign');
      rethrow;
    }
  }

  /// The assigned person confirms the duty.
  Future<void> confirm(String personAttendanceId) async {
    try {
      final validIds = await _validIdsForTenant([personAttendanceId]);
      if (validIds.isEmpty) {
        throw RepositoryException(message: l10nWithoutContext.coreFlutterAccessDenied, operation: 'confirm');
      }
      // person_attendances has no tenantId: id validated above via attendance.tenantId
      await supabase.from('person_attendances').update({
        'duty_state': DutyState.confirmed,
        'status': AttendanceStatus.present.value,
        'notes': '',
        'changed_by': _userId,
        'changed_at': _nowIso(),
      }).eq('id', validIds.first);
    } catch (e, stack) {
      handleError(e, stack, 'confirm');
      rethrow;
    }
  }

  /// "Kann nicht": the person cancels (Entschuldigt with reason) and the group
  /// is informed when the duty becomes understaffed. duty_state is kept.
  Future<void> decline(String personAttendanceId, int attendanceId, String reason) async {
    try {
      final validIds = await _validIdsForTenant([personAttendanceId]);
      if (validIds.isEmpty) {
        throw RepositoryException(message: l10nWithoutContext.coreFlutterAccessDenied, operation: 'decline');
      }
      // person_attendances has no tenantId: id validated above via attendance.tenantId
      await supabase.from('person_attendances').update({
        'status': AttendanceStatus.excused.value,
        'notes': reason,
        'changed_by': _userId,
        'changed_at': _nowIso(),
      }).eq('id', validIds.first);
      await notify(DutyNotifyType.understaffed, attendanceId);
    } catch (e, stack) {
      handleError(e, stack, 'decline');
      rethrow;
    }
  }

  /// "Ich übernehme": atomic on the server (RPC checks membership), first one wins.
  Future<DutyTakeResult> take(int attendanceId) async {
    try {
      // Ensure the Termin belongs to the current tenant before calling the RPC.
      final att = await supabase
          .from('attendance')
          .select('id')
          .eq('id', attendanceId)
          .eq('tenantId', currentTenantId)
          .maybeSingle();
      if (att == null) return DutyTakeResult.notMember;

      final data = await supabase.rpc('duty_take', params: {'p_attendance_id': attendanceId});
      final result = switch (data?.toString()) {
        'ok' => DutyTakeResult.ok,
        'full' => DutyTakeResult.full,
        'past' => DutyTakeResult.past,
        'not_allowed' => DutyTakeResult.notAllowed,
        _ => DutyTakeResult.notMember,
      };
      if (result == DutyTakeResult.ok) {
        await notify(DutyNotifyType.filled, attendanceId);
      }
      return result;
    } catch (e, stack) {
      handleError(e, stack, 'take');
      rethrow;
    }
  }

  /// Tells the `duty-notify` edge function to inform the group or the assigned persons.
  /// Never throws: a failed push must not break the action.
  Future<void> notify(
    DutyNotifyType type,
    int attendanceId, {
    List<String>? personAttendanceIds,
  }) async {
    // DEMO_GUARD: never notify from the demo account (silent, notify never throws).
    if (isDemo) return;
    try {
      await supabase.functions.invoke('duty-notify', body: {
        'type': type.name,
        'tenantId': currentTenantId,
        'attendanceId': attendanceId,
        if (personAttendanceIds != null) 'personAttendanceIds': personAttendanceIds,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[DutyRepository] duty-notify error: $e');
    }
  }

  /// Ionic type-settings: switch "Meine Termine" to the Dienstplan view.
  /// The `tenants` table has no tenantId column; the row id IS the tenant id.
  Future<void> setDutyView(bool enabled) async {
    ensureNotDemo('setDutyView'); // DEMO_GUARD
    try {
      await supabase
          .from('tenants')
          .update({'duty_view': enabled})
          .eq('id', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'setDutyView');
      rethrow;
    }
  }

  /// Sets the persons needed for one Termin.
  Future<void> updateDutyRequired(int attendanceId, int required) async {
    try {
      await supabase
          .from('attendance')
          .update({'duty_required': required})
          .eq('id', attendanceId)
          .eq('tenantId', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'updateDutyRequired');
      rethrow;
    }
  }

  /// Upcoming Termine of duty types (with all persons), oldest first.
  Future<List<DutyTermin>> getUpcomingDutyTermine(
    List<AttendanceType> types, {
    DateTime? from,
    DateTime? until,
  }) async {
    final dutyTypes = types.where((t) => t.dutyMode && t.id != null).toList();
    if (dutyTypes.isEmpty) return const [];
    try {
      final now = DateTime.now();
      final start = from ?? DateTime(now.year, now.month, now.day);
      var query = supabase
          .from('attendance')
          .select('*, persons:person_attendances(id, person_id, status, notes, duty_state, '
              'duty_assigned_at, person:person_id(firstName, lastName, img, appId))')
          .eq('tenantId', currentTenantId)
          .inFilter('type_id', dutyTypes.map((t) => t.id!).toList())
          .gte('date', start.toUtc().toIso8601String());
      if (until != null) {
        query = query.lte('date', until.toUtc().toIso8601String());
      }
      final rows = await query.order('date', ascending: true);

      final result = <DutyTermin>[];
      for (final row in rows as List) {
        final map = Map<String, dynamic>.from(row as Map);
        final personsJson = (map.remove('persons') as List?) ?? const [];
        final attendance = Attendance.fromJson(map);
        final type = dutyTypes.firstWhere((t) => t.id == attendance.typeId);
        final persons = personsJson.map((p) => parseDutyPerson(Map<String, dynamic>.from(p as Map))).toList();
        result.add(DutyTermin(
          attendance: attendance,
          type: type,
          required: dutyRequired(attendance, type),
          occupied: occupiedCount(persons),
          persons: persons,
        ));
      }
      return result;
    } catch (e, stack) {
      handleError(e, stack, 'getUpcomingDutyTermine');
      rethrow;
    }
  }

  /// Number of duties per person (assigned, not cancelled) between [from]
  /// and [to], optionally only for some types. Used for fair assignment.
  Future<Map<int, int>> getDutyCounts(
    List<int> personIds,
    DateTime from,
    DateTime to, {
    List<String>? typeIds,
  }) async {
    final counts = <int, int>{};
    if (personIds.isEmpty) return counts;
    try {
      var query = supabase
          .from('person_attendances')
          .select('person_id, status, duty_state, attendance:attendance_id!inner(date, type_id, tenantId)')
          .inFilter('person_id', personIds)
          .eq('attendance.tenantId', currentTenantId)
          .not('duty_state', 'is', null)
          .gte('attendance.date', from.toUtc().toIso8601String())
          .lte('attendance.date', to.toUtc().toIso8601String());
      if (typeIds != null && typeIds.isNotEmpty) {
        query = query.inFilter('attendance.type_id', typeIds);
      }
      final rows = await query.range(0, 9999);
      for (final row in rows as List) {
        final status = AttendanceStatus.fromValue((row['status'] as num?)?.toInt() ?? 0);
        if (!occupiesDutyRaw(row['duty_state'] as String?, status)) continue;
        final id = (row['person_id'] as num).toInt();
        counts[id] = (counts[id] ?? 0) + 1;
      }
      return counts;
    } catch (e, stack) {
      if (kDebugMode) debugPrint('[DutyRepository] getDutyCounts error: $e\n$stack');
      return counts;
    }
  }

  // ── Regelmäßig verhindert ──────────────────────────────────

  Future<List<PersonUnavailability>> getUnavailabilityForPerson(int personId) async {
    try {
      final rows = await supabase
          .from('person_unavailability')
          .select('*')
          .eq('person_id', personId)
          .eq('tenant_id', currentTenantId)
          .order('created_at');
      return (rows as List)
          .map((r) => PersonUnavailability.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getUnavailabilityForPerson');
      rethrow;
    }
  }

  /// All rules of the tenant. Never throws (creating Termine must still work).
  Future<List<PersonUnavailability>> getUnavailabilityForTenant() async {
    try {
      final rows = await supabase
          .from('person_unavailability')
          .select('*')
          .eq('tenant_id', currentTenantId);
      return (rows as List)
          .map((r) => PersonUnavailability.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[DutyRepository] getUnavailabilityForTenant error: $e');
      return const [];
    }
  }

  Future<PersonUnavailability> saveUnavailability(PersonUnavailability rule) async {
    try {
      final payload = {
        'tenant_id': currentTenantId,
        'person_id': rule.personId,
        'weekdays': rule.weekdays,
        'type_ids': rule.typeIds,
        'reason': rule.reason,
        'valid_until': (rule.validUntil?.isNotEmpty ?? false) ? rule.validUntil : null,
        'created_by': rule.createdBy ?? _userId,
      };
      final Map<String, dynamic> row;
      if (rule.id != null) {
        row = await supabase
            .from('person_unavailability')
            .update(payload)
            .eq('id', rule.id!)
            .eq('tenant_id', currentTenantId)
            .select()
            .single();
      } else {
        row = await supabase.from('person_unavailability').insert(payload).select().single();
      }
      return PersonUnavailability.fromJson(row);
    } catch (e, stack) {
      handleError(e, stack, 'saveUnavailability');
      rethrow;
    }
  }

  Future<void> deleteUnavailability(String id) async {
    try {
      await supabase
          .from('person_unavailability')
          .delete()
          .eq('id', id)
          .eq('tenant_id', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'deleteUnavailability');
      rethrow;
    }
  }

  /// Future person attendances of the rule's person that still have the
  /// type's default status, no assignment and match the rule.
  Future<List<Map<String, dynamic>>> _futureMatches(
    PersonUnavailability rule,
    List<AttendanceType> types,
  ) async {
    final now = DateTime.now();
    final rows = await supabase
        .from('person_attendances')
        .select('id, status, duty_state, attendance:attendance_id!inner(date, type_id, tenantId)')
        .eq('person_id', rule.personId)
        .eq('attendance.tenantId', currentTenantId)
        .gte('attendance.date', DateTime(now.year, now.month, now.day).toUtc().toIso8601String());

    return (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).where((row) {
      final att = row['attendance'] as Map?;
      if (att == null) return false;
      final typeId = att['type_id']?.toString();
      final type = types.where((t) => t.id == typeId).firstOrNull;
      if (type == null || row['duty_state'] != null) return false;
      final status = AttendanceStatus.fromValue((row['status'] as num?)?.toInt() ?? 0);
      if (status != type.defaultStatus) return false;
      if (!(type.availableStatuses?.contains(AttendanceStatus.excused) ?? false)) return false;
      return matchingUnavailability([rule], rule.personId, att['date'].toString(), typeId) != null;
    }).toList();
  }

  /// Counts future Termine a rule would change (for the "auch geplante" hint).
  Future<({int count, List<String> dates})> countFutureMatches(
    PersonUnavailability rule,
    List<AttendanceType> types,
  ) async {
    try {
      final rows = await _futureMatches(rule, types);
      final dates = rows.map((r) => (r['attendance'] as Map)['date'].toString()).toList()..sort();
      return (count: rows.length, dates: dates);
    } catch (_) {
      return (count: 0, dates: const <String>[]);
    }
  }

  /// Sets "Entschuldigt" on already planned Termine the rule matches.
  /// Returns the number of changed Termine.
  Future<int> applyUnavailabilityToFuture(PersonUnavailability rule, List<AttendanceType> types) async {
    try {
      final ids = (await _futureMatches(rule, types)).map((r) => r['id'].toString()).toList();
      if (ids.isEmpty) return 0;
      // person_attendances has no tenantId: ids come from a query filtered by attendance.tenantId
      await supabase.from('person_attendances').update({
        'status': AttendanceStatus.excused.value,
        'notes': unavailabilityNote(rule),
        'changed_by': _userId,
        'changed_at': _nowIso(),
      }).inFilter('id', ids);
      return ids.length;
    } catch (e, stack) {
      handleError(e, stack, 'applyUnavailabilityToFuture');
      rethrow;
    }
  }
}

/// Parses a person_attendances row with an embedded `person` into a
/// [PersonAttendance] with firstName/lastName/img flattened.
PersonAttendance parseDutyPerson(Map<String, dynamic> json) {
  final person = json['person'] as Map?;
  return PersonAttendance.fromJson({
    ...json..remove('person'),
    if (person != null) 'firstName': person['firstName'],
    if (person != null) 'lastName': person['lastName'],
    if (person != null) 'img': person['img'],
  });
}
