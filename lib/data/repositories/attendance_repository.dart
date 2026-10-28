import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../../core/constants/enums.dart';
import '../../core/utils/duty_utils.dart';
import '../../core/utils/shift_utils.dart';
import '../models/attendance/attendance.dart';
import '../models/shift/shift_plan.dart';
import 'base_repository.dart';
import '../../l10n/l10n.dart';

/// Provider for AttendanceRepository
final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository(ref);
});

/// SOL_FIX1: one immutable repository instance per tenant (see
/// playerRepositoryForTenantProvider).
final attendanceRepositoryForTenantProvider =
    Provider.family<AttendanceRepository, int?>((ref, tenantId) {
  final repo = AttendanceRepository(ref);
  if (tenantId != null) repo.bindTenantId(tenantId);
  return repo;
});

/// Repository for attendance operations
class AttendanceRepository extends BaseRepository with TenantAwareRepository {
  AttendanceRepository(super.ref);

  /// Get all attendances for the current tenant
  Future<List<Attendance>> getAttendances({
    DateTime? since,
    bool withPersonAttendances = false,
    int limit = 50,
  }) async {
    try {
      final sinceDate = since ?? DateTime.now().subtract(const Duration(days: 180));
      
      String selectQuery = '*';
      if (withPersonAttendances) {
        selectQuery = '''*, persons:person_attendances(
          *, person:person_id(
            firstName, lastName, img, instrument(id, name), joined
          )
        )''';
      }

      final response = await supabase
          .from('attendance')
          .select(selectQuery)
          .eq('tenantId', currentTenantId)
          .gt('date', sinceDate.toIso8601String())
          .order('date', ascending: false)
          .limit(limit);

      return (response as List)
          .map((e) => _parseAttendance(e as Map<String, dynamic>, withPersonAttendances))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getAttendances');
      rethrow;
    }
  }

  /// Get upcoming attendances (future dates)
  ///
  /// Optionally limit the number of results returned.
  Future<List<Attendance>> getUpcomingAttendances({int? limit}) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final ordered = supabase
          .from('attendance')
          .select('*')
          .eq('tenantId', currentTenantId)
          .gte('date', startOfDay.toIso8601String())
          .order('date');

      final response = limit != null ? await ordered.limit(limit) : await ordered;

      return (response as List)
          .map((e) => Attendance.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getUpcomingAttendances');
      rethrow;
    }
  }

  /// Get a single attendance by ID with person attendances
  Future<Attendance?> getAttendanceById(int id) async {
    try {
      final response = await supabase
          .from('attendance')
          .select('''*, persons:person_attendances(
            *, person:person_id(
              firstName, lastName, img, instrument(id, name), joined, appId, additional_fields
            )
          )''')
          .eq('id', id)
          .eq('tenantId', currentTenantId)
          .maybeSingle();

      if (response == null) return null;
      return _parseAttendance(response, true);
    } catch (e, stack) {
      handleError(e, stack, 'getAttendanceById');
      rethrow;
    }
  }

  /// DB_FIX: `attendance` columns an insert may set. Attendance.toJson also
  /// holds client-only keys (percentage, lateExcused — no `attendance`
  /// columns → PGRST204), id and created_at.
  static const Set<String> insertColumns = {
    'created_by',
    'date',
    'type',
    'type_id',
    'save_in_history',
    'excused',
    'typeInfo',
    'notes',
    'img',
    'plan',
    'songs',
    'criticalPlayers',
    'playerNotes',
    'start_time',
    'end_time',
    'deadline',
    'duration_days',
    'checklist',
    'conductors',
    'players',
    'share_plan',
    'place',
    'files_folder',
    'description',
    'attachment_url',
    'attachment_name',
    'duty_required',
  };

  /// DB_FIX: insert payload of [createAttendance] (without tenantId): only
  /// [insertColumns]; null values are not sent so DB defaults apply (Ionic
  /// inserts only the keys it set).
  static Map<String, dynamic> buildInsertData(Attendance attendance) => {
        for (final e in attendance.toJson().entries)
          if (insertColumns.contains(e.key) && e.value != null) e.key: e.value,
      };

  /// Create a new attendance
  /// BL-002: Checks for duplicate attendances on the same date
  Future<Attendance> createAttendance(Attendance attendance) async {
    ensureNotDemo('createAttendance'); // DEMO_GUARD
    try {
      // BL-002: Check for existing attendance on the same date
      final existing = await supabase
          .from('attendance')
          .select('id')
          .eq('tenantId', currentTenantId)
          .eq('date', attendance.date)
          .maybeSingle();

      if (existing != null) {
        throw DuplicateAttendanceException(
          message: l10nWithoutContext.coreFlutterRepoEventExistsOnDate,
          existingId: existing['id'] as int,
          date: attendance.date,
        );
      }

      final data = buildInsertData(attendance);
      data['tenantId'] = currentTenantId;

      final response = await supabase
          .from('attendance')
          .insert(data)
          .select()
          .single();

      return Attendance.fromJson(response);
    } catch (e, stack) {
      // BL-002: Don't wrap DuplicateAttendanceException
      if (e is DuplicateAttendanceException) rethrow;
      handleError(e, stack, 'createAttendance');
      rethrow;
    }
  }

  /// Update an existing attendance
  Future<Attendance> updateAttendance(int id, Map<String, dynamic> updates) async {
    ensureNotDemo('updateAttendance'); // DEMO_GUARD
    try {
      // Remove read-only fields
      updates.remove('id');
      updates.remove('created_at');
      updates.remove('tenantId');
      updates.remove('persons');

      final response = await supabase
          .from('attendance')
          .update(updates)
          .eq('id', id)
          .eq('tenantId', currentTenantId)
          .select()
          .maybeSingle();

      // RT-008: Handle case where attendance was not found
      if (response == null) {
        throw RepositoryException(
          message: 'Attendance not found or belongs to different tenant',
          operation: 'updateAttendance',
        );
      }

      return Attendance.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'updateAttendance');
      rethrow;
    }
  }

  /// Delete an attendance
  Future<void> deleteAttendance(int id) async {
    ensureNotDemo('deleteAttendance'); // DEMO_GUARD
    try {
      await supabase
          .from('attendance')
          .delete()
          .eq('id', id)
          .eq('tenantId', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'deleteAttendance');
      rethrow;
    }
  }

  /// Get person attendances for a specific person
  /// SEC-016: Added tenant filter via inner join with attendance table
  Future<List<PersonAttendance>> getPersonAttendancesForPerson(
    int personId, {
    DateTime? since,
  }) async {
    try {
      final sinceDate = since ?? DateTime.now().subtract(const Duration(days: 180));

      final response = await supabase
          .from('person_attendances')
          .select('*, attendance:attendance_id!inner(id, date, type, typeInfo, songs, type_id, start_time, end_time, deadline, tenantId)')
          .eq('person_id', personId)
          .eq('attendance.tenantId', currentTenantId)
          .gt('attendance.date', sinceDate.toIso8601String());

      return (response as List)
          .where((row) => row['attendance'] != null)
          .map((e) => _parsePersonAttendanceWithAttendance(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getPersonAttendancesForPerson');
      rethrow;
    }
  }

  /// Get upcoming absences (status 2/4/5) for a list of person IDs.
  ///
  /// Returns raw rows from `person_attendances` joined with the parent
  /// `attendance` row (id, date, type, typeInfo). The caller is responsible
  /// for filtering out past dates and mapping into a domain model — the
  /// nested attendance fields (like typeInfo) are not part of the
  /// PersonAttendance model, so this method exposes the raw shape.
  ///
  /// Multi-tenant safety: the join uses `attendance!inner` with
  /// `attendance.tenantId = currentTenantId`, so cross-tenant rows cannot
  /// leak even though `person_attendances` has no `tenantId` column.
  Future<List<Map<String, dynamic>>> getUpcomingAbsencesForPersons(
    List<int> personIds,
  ) async {
    if (personIds.isEmpty) return [];
    try {
      final response = await supabase
          .from('person_attendances')
          .select('*, attendance:attendance_id!inner(id, date, type, typeInfo, tenantId)')
          .inFilter('person_id', personIds)
          .inFilter('status', [2, 4, 5])
          .eq('attendance.tenantId', currentTenantId);

      return (response as List)
          .where((row) => row['attendance'] != null)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getUpcomingAbsencesForPersons');
      rethrow;
    }
  }

  /// Returns raw person_attendances rows with embedded attendance details
  /// for the given person IDs. Used by parent-portal multi-child views,
  /// which map the results to a UI-specific ChildPersonAttendance type.
  ///
  /// Returns Map rows (not PersonAttendance) because the caller needs
  /// the embedded attendance fields (date, typeInfo, plan, share_plan, etc.)
  /// which are not on the PersonAttendance Freezed model.
  ///
  /// Multi-tenant safety: `person_attendances` has no `tenantId` column,
  /// so the join filters by `attendance.tenantId = currentTenantId` to
  /// prevent cross-tenant leakage.
  Future<List<Map<String, dynamic>>> getPersonAttendancesForPersons(
    List<int> personIds,
  ) async {
    if (personIds.isEmpty) return [];
    try {
      final response = await supabase
          .from('person_attendances')
          .select('''
            *,
            attendance:attendance_id(
              id, date, type, typeInfo, start_time, end_time, deadline, tenantId,
              type_id, plan, share_plan, duration_days, place, description,
              attachment_url, attachment_name
            )
          ''')
          .inFilter('person_id', personIds)
          .eq('attendance.tenantId', currentTenantId)
          .order('attendance(date)', ascending: false);
      return (response as List)
          .where((row) => row['attendance'] != null)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getPersonAttendancesForPersons');
      rethrow;
    }
  }

  /// Ionic `DbService.updateShiftAssignmentsForAttendance`: after the date or
  /// time window of a Termin changed, re-run the shift computation for every
  /// person of the Termin (see [ShiftUtils.shiftUpdatesForAttendance]).
  /// Skips past Termine and all-day types.
  Future<void> updateShiftAssignmentsForAttendance(int attendanceId) async {
    try {
      final att = await supabase
          .from('attendance')
          .select('id, date, start_time, end_time, '
              'attType:type_id(start_time, end_time, all_day, default_status)')
          .eq('id', attendanceId)
          .eq('tenantId', currentTenantId)
          .maybeSingle();
      if (att == null) return;
      final type = att['attType'] as Map<String, dynamic>?;
      if (type == null) return;
      final typeModel = AttendanceType.fromJson({
        'name': '',
        ...type,
      });

      // person_attendances has no tenantId: the Termin was validated above.
      final paRows = await supabase
          .from('person_attendances')
          .select('id, person_id, status, notes')
          .eq('attendance_id', attendanceId);
      final rows = [
        for (final r in (paRows as List).cast<Map<String, dynamic>>())
          if (r['person_id'] != null)
            ShiftAttendanceRow(
              id: r['id'].toString(),
              personId: (r['person_id'] as num).toInt(),
              status: _parseStatus(r['status']),
              notes: r['notes'] as String?,
            ),
      ];
      if (rows.isEmpty) return;

      final players = await supabase
          .from('player')
          .select('id, shift_id, shift_start, shift_name')
          .eq('tenantId', currentTenantId)
          .inFilter('id', rows.map((r) => r.personId).toSet().toList());
      final persons = {
        for (final p in (players as List).cast<Map<String, dynamic>>())
          (p['id'] as num).toInt(): ShiftPerson(
            shiftId: p['shift_id']?.toString(),
            shiftStart: p['shift_start']?.toString(),
            shiftName: p['shift_name']?.toString(),
          ),
      };

      final shiftRows = await supabase
          .from(SupabaseTable.shiftPlans.tableName)
          .select('*')
          .eq('tenant_id', currentTenantId);
      final shifts = [
        for (final s in (shiftRows as List).cast<Map<String, dynamic>>()) ShiftPlan.fromJson(s),
      ];

      final updates = ShiftUtils.shiftUpdatesForAttendance(
        attendanceDate: att['date'] as String,
        attendanceStart: att['start_time'] as String?,
        attendanceEnd: att['end_time'] as String?,
        typeStart: typeModel.startTime,
        typeEnd: typeModel.endTime,
        typeAllDay: typeModel.allDay,
        defaultStatus: typeModel.defaultStatus,
        rows: rows,
        persons: persons,
        shifts: shifts,
      );
      for (final u in updates) {
        await updatePersonAttendance(u.id, {'status': u.status.value, 'notes': u.notes});
      }
    } catch (e, stack) {
      handleError(e, stack, 'updateShiftAssignmentsForAttendance');
      rethrow;
    }
  }

  /// Validate that a person_attendances row belongs to the current tenant.
  ///
  /// person_attendances has no tenantId column, so this joins the parent
  /// attendance row and compares its tenantId. Returns `false` on any error
  /// or mismatch (defense-in-depth: deny by default). Errors are logged via
  /// the base repository's `handleError` so a real RLS/network outage is
  /// observable, but never propagated — the deny-by-default contract is the
  /// safety net.
  Future<bool> validatePersonAttendanceTenant(String personAttendanceId) async {
    try {
      final validation = await supabase
          .from('person_attendances')
          .select('id, attendance:attendance_id!inner(tenantId)')
          .eq('id', personAttendanceId)
          .eq('attendance.tenantId', currentTenantId)
          .maybeSingle();

      return validation != null;
    } catch (e, stack) {
      // Log but never propagate — caller must see `false` on any failure.
      try {
        handleError(e, stack, 'validatePersonAttendanceTenant');
      } catch (_) {
        // handleError rethrows by contract; we swallow the rethrow here so
        // the deny-by-default return path stays intact even when logging
        // succeeds.
      }
      return false;
    }
  }

  /// Delete a single person_attendances row after validating it belongs to
  /// the current tenant. Throws [RepositoryException] on cross-tenant access.
  Future<void> deletePersonAttendance(String personAttendanceId) async {
    try {
      final isValid = await validatePersonAttendanceTenant(personAttendanceId);
      if (!isValid) {
        throw RepositoryException(
          message: 'PersonAttendance not found or belongs to different tenant',
          operation: 'deletePersonAttendance',
        );
      }

      await supabase
          .from('person_attendances')
          .delete()
          .eq('id', personAttendanceId);
    } catch (e, stack) {
      handleError(e, stack, 'deletePersonAttendance');
      rethrow;
    }
  }

  /// Create person attendance records (batch)
  /// SEC-001: Added tenant validation for attendance_id and person_id
  Future<void> createPersonAttendances(List<PersonAttendance> records) async {
    try {
      if (records.isEmpty) return;

      // Extract unique IDs for validation
      final attendanceIds = records
          .map((r) => r.attendanceId)
          .whereType<int>()
          .toSet()
          .toList();
      final personIds = records
          .map((r) => r.personId)
          .whereType<int>()
          .toSet()
          .toList();

      if (attendanceIds.isEmpty || personIds.isEmpty) return;

      // Validate all attendance IDs belong to current tenant
      final validAttendances = await supabase
          .from('attendance')
          .select('id')
          .eq('tenantId', currentTenantId)
          .inFilter('id', attendanceIds);

      final validAttendanceIds = (validAttendances as List)
          .map((a) => a['id'] as int)
          .toSet();

      // Validate all person IDs belong to current tenant
      final validPersons = await supabase
          .from('player')
          .select('id')
          .eq('tenantId', currentTenantId)
          .inFilter('id', personIds);

      final validPersonIds = (validPersons as List)
          .map((p) => p['id'] as int)
          .toSet();

      // Filter records to only include valid combinations
      final validRecords = records.where((r) =>
          r.attendanceId != null &&
          r.personId != null &&
          validAttendanceIds.contains(r.attendanceId) &&
          validPersonIds.contains(r.personId)).toList();

      if (validRecords.isEmpty) return;

      final data = validRecords.map((r) {
        final json = r.toJson();
        // Only include necessary fields
        return {
          'attendance_id': json['attendance_id'],
          'person_id': json['person_id'],
          'status': json['status'],
          'notes': json['notes'],
        };
      }).toList();

      await supabase.from('person_attendances').insert(data);
    } catch (e, stack) {
      handleError(e, stack, 'createPersonAttendances');
      rethrow;
    }
  }

  /// Update a single person attendance
  /// SEC-012: Added tenant validation before update
  Future<PersonAttendance> updatePersonAttendance(
    String id,
    Map<String, dynamic> updates,
  ) async {
    try {
      // Validate that personAttendance belongs to current tenant
      // DUTY: also load duty_state + the type's duty_mode for syncDutyWithStatus
      final validation = await supabase
          .from('person_attendances')
          .select('id, duty_state, attendance:attendance_id(tenantId, type_id, attType:type_id(duty_mode))')
          .eq('id', id)
          .maybeSingle();

      if (validation == null) {
        throw RepositoryException(
          message: 'PersonAttendance not found',
          operation: 'updatePersonAttendance',
        );
      }

      // DUTY: keep assignment and status in sync for Termine of duty types
      // (Ionic syncDutyWithStatus). Explicit duty changes are left alone.
      final isDutyTermin = validation['attendance']?['attType']?['duty_mode'] == true;
      if (isDutyTermin && updates.containsKey('status') && !updates.containsKey('duty_state')) {
        final rawStatus = updates['status'];
        final newStatus = rawStatus is AttendanceStatus
            ? rawStatus
            : AttendanceStatus.fromValue((rawStatus as num?)?.toInt() ?? 0);
        final current = validation['duty_state'] as String?;
        final next = dutyStateAfterStatus(current, newStatus);
        if (next != current) {
          updates['duty_state'] = next;
          if (next == DutyState.confirmed) {
            updates['duty_reminder_sent'] = true;
            if (current == null) {
              updates['duty_assigned_by'] = supabase.auth.currentUser?.id;
              updates['duty_assigned_at'] = DateTime.now().toUtc().toIso8601String();
            }
          }
        }
      }

      final attendanceTenantId = validation['attendance']?['tenantId'];
      if (attendanceTenantId != currentTenantId) {
        throw RepositoryException(
          message: 'Access denied: PersonAttendance belongs to different tenant',
          operation: 'updatePersonAttendance',
        );
      }

      updates.remove('id');
      updates.remove('firstName');
      updates.remove('lastName');
      updates.remove('img');
      updates.remove('instrument');
      updates.remove('groupName');
      updates.remove('joined');
      updates.remove('person');
      updates.remove('attendance');

      // Add changed metadata
      updates['changed_at'] = DateTime.now().toUtc().toIso8601String();
      updates['changed_by'] = supabase.auth.currentUser?.id;

      final response = await supabase
          .from('person_attendances')
          .update(updates)
          .eq('id', id)
          .select()
          .maybeSingle();

      // RT-008: Handle case where personAttendance was not found
      if (response == null) {
        throw RepositoryException(
          message: 'PersonAttendance not found',
          operation: 'updatePersonAttendance',
        );
      }

      return PersonAttendance.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'updatePersonAttendance');
      rethrow;
    }
  }

  /// Delete person attendances for a specific person and attendance IDs
  /// SEC-014: Added tenant validation by verifying attendance IDs belong to current tenant
  Future<void> deletePersonAttendances(int personId, List<int> attendanceIds) async {
    try {
      // Validate that attendance IDs belong to current tenant
      final validAttendances = await supabase
          .from('attendance')
          .select('id')
          .eq('tenantId', currentTenantId)
          .inFilter('id', attendanceIds);

      final validIds = (validAttendances as List)
          .map((a) => a['id'] as int)
          .toList();

      if (validIds.isEmpty) return;

      await supabase
          .from('person_attendances')
          .delete()
          .eq('person_id', personId)
          .inFilter('attendance_id', validIds);
    } catch (e, stack) {
      handleError(e, stack, 'deletePersonAttendances');
      rethrow;
    }
  }

  /// Batch update multiple person attendances with the same status
  /// SEC-013: Added tenant validation for all person attendance IDs
  Future<void> batchUpdatePersonAttendances(
    List<String> personAttendanceIds,
    AttendanceStatus newStatus,
  ) async {
    try {
      // Validate all personAttendances belong to current tenant
      final validation = await supabase
          .from('person_attendances')
          .select('id, attendance:attendance_id(tenantId)')
          .inFilter('id', personAttendanceIds);

      final validIds = <String>[];
      for (final record in validation as List) {
        final attendanceTenantId = record['attendance']?['tenantId'];
        if (attendanceTenantId == currentTenantId) {
          validIds.add(record['id'].toString());
        }
      }

      if (validIds.isEmpty) return;

      await supabase
          .from('person_attendances')
          .update({
            'status': newStatus.value,
            'changed_at': DateTime.now().toUtc().toIso8601String(),
            'changed_by': supabase.auth.currentUser?.id,
          })
          .inFilter('id', validIds);
    } catch (e, stack) {
      handleError(e, stack, 'batchUpdatePersonAttendances');
      rethrow;
    }
  }

  /// Get attendances for a specific date
  Future<List<Attendance>> getAttendancesByDate(DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final response = await supabase
          .from('attendance')
          .select('*')
          .eq('tenantId', currentTenantId)
          .gte('date', startOfDay.toIso8601String())
          .lt('date', endOfDay.toIso8601String())
          .order('date');

      return (response as List)
          .map((e) => Attendance.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getAttendancesByDate');
      rethrow;
    }
  }

  // Helper to parse attendance with optional person attendances
  // STATS_PEOPLE_FIXES
  /// Load person_attendances for the given attendance ids (export).
  ///
  /// Multi-tenant safety: `person_attendances` has no `tenantId` column, so
  /// the inner join filters by `attendance.tenantId = currentTenantId`.
  /// Paginated to bypass the PostgREST 1000-row default limit.
  Future<List<PersonAttendance>> getPersonAttendancesForAttendances(
    List<int> attendanceIds,
  ) async {
    if (attendanceIds.isEmpty) return [];
    try {
      const batchSize = 1000;
      final result = <PersonAttendance>[];
      var offset = 0;
      while (true) {
        final response = await supabase
            .from('person_attendances')
            .select('id, attendance_id, person_id, status, notes, '
                'attendance:attendance_id!inner(tenantId)')
            .inFilter('attendance_id', attendanceIds)
            .eq('attendance.tenantId', currentTenantId)
            .order('id') // stable paging
            .range(offset, offset + batchSize - 1);
        final rows = response as List;
        for (final e in rows) {
          final row = Map<String, dynamic>.from(e as Map)..remove('attendance');
          result.add(PersonAttendance.fromJson(row));
        }
        if (rows.length < batchSize) break;
        offset += batchSize;
      }
      return result;
    } catch (e, stack) {
      handleError(e, stack, 'getPersonAttendancesForAttendances');
      rethrow;
    }
  }

  Attendance _parseAttendance(Map<String, dynamic> data, bool withPersons) {
    // RT-020: Removed unused persons parsing - the Attendance model
    // doesn't have a persons field yet. When needed, add the field to
    // the Attendance model and uncomment the parsing logic.
    return Attendance.fromJson(data);
  }

  PersonAttendance _parsePersonAttendanceWithAttendance(Map<String, dynamic> data) {
    final attendanceData = data['attendance'] as Map<String, dynamic>?;
    
    return PersonAttendance(
      id: data['id']?.toString(),
      attendanceId: data['attendance_id'],
      personId: data['person_id'],
      status: _parseStatus(data['status']),
      notes: data['notes'],
      date: attendanceData?['date'],
      title: attendanceData?['typeInfo'],
    );
  }

  // ATTENDANCE_SIGNOUT: history + date-change helpers (Ionic parity)

  /// Song history rows of one Termin (song, conductor person_id / otherConductor).
  Future<List<Map<String, dynamic>>> getHistoryForAttendance(int attendanceId) async {
    try {
      final response = await supabase
          .from('history')
          .select('id, songId, person_id, otherConductor, date')
          .eq('attendance_id', attendanceId)
          .eq('tenantId', currentTenantId)
          .order('id', ascending: true);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e, stack) {
      handleError(e, stack, 'getHistoryForAttendance');
      rethrow;
    }
  }

  /// LOGIC_ATT: Ionic addSongsToHistory – inserts song history rows of a
  /// Termin. `tenantId` is always forced to the current tenant.
  Future<void> addHistoryEntries(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    try {
      await supabase
          .from('history')
          .insert([for (final r in rows) {...r, 'tenantId': currentTenantId}]);
    } catch (e, stack) {
      handleError(e, stack, 'addHistoryEntries');
      rethrow;
    }
  }

  /// LOGIC_ATT: Ionic updateHistoryEntry (e.g. conductor change).
  Future<void> updateHistoryEntry(int id, Map<String, dynamic> updates) async {
    ensureNotDemo('updateHistoryEntry'); // DEMO_GUARD
    try {
      await supabase
          .from('history')
          .update(updates)
          .eq('id', id)
          .eq('tenantId', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'updateHistoryEntry');
      rethrow;
    }
  }

  /// LOGIC_ATT: Ionic removeHistoryEntry.
  Future<void> deleteHistoryEntry(int id) async {
    ensureNotDemo('deleteHistoryEntry'); // DEMO_GUARD
    try {
      await supabase
          .from('history')
          .delete()
          .eq('id', id)
          .eq('tenantId', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'deleteHistoryEntry');
      rethrow;
    }
  }

  /// Moves the song history of a Termin to its new date.
  Future<void> updateHistoryDatesForAttendance(int attendanceId, String date) async {
    ensureNotDemo('updateHistoryDatesForAttendance'); // DEMO_GUARD
    try {
      await supabase
          .from('history')
          .update({'date': date})
          .eq('attendance_id', attendanceId)
          .eq('tenantId', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'updateHistoryDatesForAttendance');
      rethrow;
    }
  }

  /// Sets every person of a Termin back to [status] and clears their notes
  /// ("Status zurücksetzen" when moving a Termin).
  ///
  /// person_attendances has no tenantId column: the owning attendance is
  /// verified against the current tenant first, then rows are filtered by
  /// that attendance_id.
  Future<void> resetPersonAttendancesForAttendance(
    int attendanceId,
    AttendanceStatus status,
  ) async {
    try {
      final owner = await supabase
          .from('attendance')
          .select('id')
          .eq('id', attendanceId)
          .eq('tenantId', currentTenantId)
          .maybeSingle();
      if (owner == null) {
        throw RepositoryException(
          message: 'Attendance not found or belongs to different tenant',
          operation: 'resetPersonAttendancesForAttendance',
        );
      }
      await supabase
          .from('person_attendances')
          .update({
            'status': status.value,
            'notes': '',
            'changed_at': DateTime.now().toUtc().toIso8601String(),
            'changed_by': supabase.auth.currentUser?.id,
          })
          .eq('attendance_id', attendanceId);
    } catch (e, stack) {
      handleError(e, stack, 'resetPersonAttendancesForAttendance');
      rethrow;
    }
  }

  // ATT_DETAIL: ad-hoc reminder, description attachment

  /// Throws when [attendanceId] does not belong to the current tenant.
  Future<void> _assertAttendanceInTenant(int attendanceId, String operation) async {
    final check = await supabase
        .from('attendance')
        .select('id')
        .eq('id', attendanceId)
        .eq('tenantId', currentTenantId)
        .maybeSingle();
    if (check == null) {
      throw RepositoryException(
        message: 'Attendance not found or belongs to different tenant',
        operation: operation,
      );
    }
  }

  /// Sends an ad-hoc reminder (push + e-mail) through the
  /// `send-ad-hoc-reminder` Edge Function (Ionic sendAdHocReminder).
  /// [playerAppId] targets one person, [playerAppIds] a subset
  /// ("nur Personen ohne Rückmeldung"); both null = everyone in the Termin.
  Future<void> sendAdHocReminder({
    required int attendanceId,
    String? title,
    String? message,
    String? playerAppId,
    List<String>? playerAppIds,
  }) async {
    try {
      await _assertAttendanceInTenant(attendanceId, 'sendAdHocReminder');
      await supabase.functions.invoke('send-ad-hoc-reminder', body: {
        'attendanceId': attendanceId,
        'tenantId': currentTenantId,
        if (title != null && title.isNotEmpty) 'title': title,
        if (message != null && message.isNotEmpty) 'message': message,
        if (playerAppId != null && playerAppId.isNotEmpty) 'playerAppId': playerAppId,
        if (playerAppIds != null) 'playerAppIds': playerAppIds,
      });
    } catch (e, stack) {
      handleError(e, stack, 'sendAdHocReminder');
      rethrow;
    }
  }

  /// Storage path of the description attachment (Ionic onAttachmentSelect).
  static String attachmentPath(int attendanceId, String fileName) {
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return '$attendanceId/attachment/$safeName';
  }

  /// Uploads the single attachment of a Termin to the public `attendances`
  /// bucket and stores url + name on the attendance row.
  Future<({String url, String name})> uploadAttachment(
    int attendanceId,
    Uint8List bytes,
    String fileName, {
    String? previousFileName,
  }) async {
    ensureNotDemo('uploadAttachment'); // DEMO_GUARD
    try {
      await _assertAttendanceInTenant(attendanceId, 'uploadAttachment');
      // Only one attachment per Termin: drop a previous file with another
      // name so it does not stay orphaned in storage.
      if (previousFileName != null &&
          previousFileName.isNotEmpty &&
          previousFileName != fileName) {
        try {
          await supabase.storage
              .from('attendances')
              .remove([attachmentPath(attendanceId, previousFileName)]);
        } catch (_) {
          // Old file may already be gone.
        }
      }
      final path = attachmentPath(attendanceId, fileName);
      await supabase.storage
          .from('attendances')
          .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));
      final url = supabase.storage.from('attendances').getPublicUrl(path);
      await supabase
          .from('attendance')
          .update({'attachment_url': url, 'attachment_name': fileName})
          .eq('id', attendanceId)
          .eq('tenantId', currentTenantId);
      return (url: url, name: fileName);
    } catch (e, stack) {
      handleError(e, stack, 'uploadAttachment');
      rethrow;
    }
  }

  // DB_REVIEW_REST (H4): Termin-Foto like Ionic image.service
  // updateAttendanceImage: bucket `attendances`, key `<attendanceId>`, upsert.
  static String attendanceImagePath(int attendanceId) => '$attendanceId';

  /// Uploads the Termin photo and stores its public URL in `attendance.img`.
  Future<String> uploadAttendanceImage(int attendanceId, Uint8List bytes) async {
    ensureNotDemo('uploadAttendanceImage'); // DEMO_GUARD
    try {
      await _assertAttendanceInTenant(attendanceId, 'uploadAttendanceImage');
      final path = attendanceImagePath(attendanceId);
      await supabase.storage.from('attendances').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      final url = supabase.storage.from('attendances').getPublicUrl(path);
      await supabase
          .from('attendance')
          .update({'img': url})
          .eq('id', attendanceId)
          .eq('tenantId', currentTenantId);
      return url;
    } catch (e, stack) {
      handleError(e, stack, 'uploadAttendanceImage');
      rethrow;
    }
  }

  /// Removes the attachment file and clears url + name on the attendance row.
  Future<void> removeAttachment(int attendanceId, String? fileName) async {
    ensureNotDemo('removeAttachment'); // DEMO_GUARD
    try {
      await _assertAttendanceInTenant(attendanceId, 'removeAttachment');
      if (fileName != null && fileName.isNotEmpty) {
        try {
          await supabase.storage
              .from('attendances')
              .remove([attachmentPath(attendanceId, fileName)]);
        } catch (_) {
          // File may already be gone – still clear the reference.
        }
      }
      await supabase
          .from('attendance')
          .update({'attachment_url': null, 'attachment_name': null})
          .eq('id', attendanceId)
          .eq('tenantId', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'removeAttachment');
      rethrow;
    }
  }
  // END ATT_DETAIL

  AttendanceStatus _parseStatus(dynamic status) {
    if (status == null) return AttendanceStatus.neutral;
    if (status is AttendanceStatus) return status;

    // Handle integer values (as stored in database)
    if (status is int) {
      return AttendanceStatus.fromValue(status);
    }

    // Handle string values (enum names or integer strings)
    final statusStr = status.toString();
    final intValue = int.tryParse(statusStr);
    if (intValue != null) {
      return AttendanceStatus.fromValue(intValue);
    }

    return AttendanceStatus.values.firstWhere(
      (s) => s.name.toLowerCase() == statusStr.toLowerCase(),
      orElse: () => AttendanceStatus.neutral,
    );
  }
}
