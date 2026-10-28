import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:intl/intl.dart';

import '../../core/constants/enums.dart';
import '../../core/utils/duty_utils.dart';
import '../../core/utils/event_list_utils.dart';
import '../models/player_absence/player_absence.dart';
import 'base_repository.dart';

/// Provider for PlayerAbsenceRepository
final playerAbsenceRepositoryProvider = Provider<PlayerAbsenceRepository>((ref) {
  return PlayerAbsenceRepository(ref);
});

/// Repository for planned absences (Ionic: PlayerAbsenceService).
///
/// Tables:
/// - player_absences: uses snake_case `tenant_id`
/// - tenant_role_permissions: uses snake_case `tenant_id`
/// - person_attendances: has NO tenant column; tenant isolation is enforced
///   via `attendance:attendance_id!inner(...)` + `attendance.tenantId` filter.
class PlayerAbsenceRepository extends BaseRepository with TenantAwareRepository {
  PlayerAbsenceRepository(super.ref);

  /// Absences of one person, ordered by start date.
  Future<List<PlayerAbsence>> getAbsencesForPerson(int personId) async {
    try {
      final response = await supabase
          .from('player_absences')
          .select('*')
          .eq('person_id', personId)
          .eq('tenant_id', currentTenantId)
          .order('from_date');

      return (response as List)
          .map((e) => PlayerAbsence.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getAbsencesForPerson');
      rethrow;
    }
  }

  /// All absences of the current tenant.
  Future<List<PlayerAbsence>> getAbsencesForTenant() async {
    try {
      final response = await supabase
          .from('player_absences')
          .select('*')
          .eq('tenant_id', currentTenantId);

      return (response as List)
          .map((e) => PlayerAbsence.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getAbsencesForTenant');
      rethrow;
    }
  }

  /// Create an absence. `tenant_id` is always the current tenant.
  Future<PlayerAbsence> addAbsence({
    required int personId,
    required String fromDate,
    required String untilDate,
    required String reason,
  }) async {
    ensureNotDemo('addAbsence'); // DEMO_GUARD
    try {
      final data = <String, dynamic>{
        'person_id': personId,
        'from_date': fromDate,
        'until_date': untilDate,
        'reason': reason,
      };
      data['tenant_id'] = currentTenantId;

      final response = await supabase
          .from('player_absences')
          .insert(data)
          .select()
          .single();

      return PlayerAbsence.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'addAbsence');
      rethrow;
    }
  }

  /// Delete an absence (id AND tenant_id).
  Future<void> deleteAbsence(String id) async {
    ensureNotDemo('deleteAbsence'); // DEMO_GUARD
    try {
      await supabase
          .from('player_absences')
          .delete()
          .eq('id', id)
          .eq('tenant_id', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'deleteAbsence');
      rethrow;
    }
  }

  /// Upcoming person_attendances of [personId] in the current tenant whose
  /// attendance date lies within [fromDate]..[untilDate].
  ///
  /// LOGIC_SELF: like Ionic (confirmAbsence/deleteAbsence work on the loaded
  /// upcoming list) a Termin counts while it has not ended, so a running
  /// multi-day Termin that started before today is included.
  Future<List<Map<String, dynamic>>> _upcomingInRange(
    int personId,
    String fromDate,
    String untilDate,
  ) async {
    final response = await supabase
        .from('person_attendances')
        .select('id, status, notes, duty_state, attendance:attendance_id!inner(date, duration_days, type_id, tenantId, attType:type_id(duty_mode))')
        .eq('person_id', personId)
        .eq('attendance.tenantId', currentTenantId)
        // One day of slack: the exact local-day check happens below.
        .gte('attendance.date', _dayBefore(fromDate));

    return (response as List)
        .where((row) => row['attendance'] != null)
        .map((e) => e as Map<String, dynamic>)
        .where((row) => isUpcomingInAbsenceRange(
              (row['attendance']['date'] ?? '').toString(),
              _intOrNull(row['attendance']['duration_days']),
              fromDate,
              untilDate,
            ))
        .toList();
  }

  static String _dayBefore(String date) {
    final parsed = DateTime.tryParse(date.length >= 10 ? date.substring(0, 10) : date);
    if (parsed == null) return date;
    return DateFormat('yyyy-MM-dd').format(parsed.subtract(const Duration(days: 1)));
  }

  static int? _intOrNull(dynamic raw) =>
      raw is int ? raw : int.tryParse(raw?.toString() ?? '');

  /// LOGIC_SELF: Ionic filter of confirmAbsence/deleteAbsence — the Termin
  /// has not ended yet (`attendanceHasEnded`) and its day lies within
  /// [fromDate]..[untilDate] (`isBefore/isAfter(…, 'day')`).
  static bool isUpcomingInAbsenceRange(
    String date,
    int? durationDays,
    String fromDate,
    String untilDate, {
    DateTime? now,
  }) {
    final parsed = EventListUtils.parse(date);
    if (parsed == null) return false;
    if (EventListUtils.hasEnded(date, durationDays, now: now)) return false;
    final day = DateFormat('yyyy-MM-dd').format(parsed);
    final from = fromDate.length >= 10 ? fromDate.substring(0, 10) : fromDate;
    final until = untilDate.length >= 10 ? untilDate.substring(0, 10) : untilDate;
    return day.compareTo(from) >= 0 && day.compareTo(until) <= 0;
  }

  /// Duty fields for a status change of [row] (from [_upcomingInRange]).
  Map<String, dynamic> _dutySync(Map<String, dynamic> row, AttendanceStatus status) =>
      dutySyncFieldsForStatus(
        isDutyTermin: row['attendance']?['attType']?['duty_mode'] == true,
        currentDutyState: row['duty_state'] as String?,
        newStatus: status,
        userId: supabase.auth.currentUser?.id,
      );

  static int _statusOf(dynamic raw) {
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '') ?? AttendanceStatus.neutral.value;
  }

  /// Excuse all upcoming attendances in the absence range that are not yet
  /// excused (status = Entschuldigt, notes = reason). Returns the count.
  Future<int> excuseUpcomingAttendances({
    required int personId,
    required String fromDate,
    required String untilDate,
    required String reason,
  }) async {
    try {
      final rows = await _upcomingInRange(personId, fromDate, untilDate);
      final toExcuse = rows
          .where((r) => _statusOf(r['status']) != AttendanceStatus.excused.value)
          .toList();

      for (final row in toExcuse) {
        // Row ids come from the tenant-filtered inner join above.
        await supabase
            .from('person_attendances')
            .update({
              'status': AttendanceStatus.excused.value,
              'notes': reason,
              'changed_at': DateTime.now().toUtc().toIso8601String(),
              'changed_by': supabase.auth.currentUser?.id,
              // PARITY_A (D2): Ionic updatePersonAttendance → syncDutyWithStatus
              ..._dutySync(row, AttendanceStatus.excused),
            })
            .eq('id', row['id'])
            .eq('person_id', personId);
      }
      return toExcuse.length;
    } catch (e, stack) {
      handleError(e, stack, 'excuseUpcomingAttendances');
      rethrow;
    }
  }

  /// After deleting an absence: reset upcoming attendances in its range that
  /// are excused with exactly the absence reason back to the attendance
  /// type's default status (fallback Neutral) with empty notes.
  Future<int> resetExcusedAttendances({
    required PlayerAbsence absence,
  }) async {
    try {
      final rows = await _upcomingInRange(
        absence.personId,
        absence.fromDate,
        absence.untilDate,
      );
      final toReset = rows
          .where((r) =>
              _statusOf(r['status']) == AttendanceStatus.excused.value &&
              (r['notes'] ?? '').toString() == absence.reason)
          .toList();
      if (toReset.isEmpty) return 0;

      final types = await supabase
          .from('attendance_types')
          .select('id, default_status')
          .eq('tenant_id', currentTenantId);
      final defaultStatusByType = <String, int>{};
      for (final t in types as List) {
        defaultStatusByType[t['id'].toString()] =
            _parseDefaultStatus(t['default_status']);
      }

      for (final row in toReset) {
        final typeId = row['attendance']['type_id']?.toString();
        final status = defaultStatusByType[typeId] ?? AttendanceStatus.neutral.value;
        await supabase
            .from('person_attendances')
            .update({
              'status': status,
              'notes': '',
              'changed_at': DateTime.now().toUtc().toIso8601String(),
              'changed_by': supabase.auth.currentUser?.id,
              // PARITY_A (D2): Ionic updatePersonAttendance → syncDutyWithStatus
              ..._dutySync(row, AttendanceStatus.fromValue(status)),
            })
            .eq('id', row['id'])
            .eq('person_id', absence.personId);
      }
      return toReset.length;
    } catch (e, stack) {
      handleError(e, stack, 'resetExcusedAttendances');
      rethrow;
    }
  }

  /// attendance_types.default_status is stored as int or as enum name.
  static int _parseDefaultStatus(dynamic raw) {
    if (raw is int) return raw;
    if (raw is String) {
      final asInt = int.tryParse(raw);
      if (asInt != null) return asInt;
      return AttendanceStatus.values
          .firstWhere((s) => s.name == raw, orElse: () => AttendanceStatus.neutral)
          .value;
    }
    return AttendanceStatus.neutral.value;
  }
}
