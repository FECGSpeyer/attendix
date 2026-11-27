part of 'attendance_repository.dart';

mixin _AttendanceRecordsMixin on _AttendanceRepositoryCore {
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
          .select('*, attendance:attendance_id!inner(id, date, type, typeInfo, songs, type_id, start_time, end_time, deadline, tenantId, archived)')
          .eq('person_id', personId)
          .eq('attendance.tenantId', currentTenantId)
          .gt('attendance.date', sinceDate.toIso8601String());

      final showArchived = canSeeArchivedAttendances(currentUserRole);
      return (response as List)
          .where((row) => row['attendance'] != null)
          .where((row) => showArchived || !isArchivedRow(row['attendance'] as Map<String, dynamic>?))
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
  /// `attendance` row (id, date, type, typeInfo). Only Termine from
  /// yesterday on are loaded (a margin for the time zone; Ionic loads the
  /// season and keeps the dates after today), page by page past the
  /// PostgREST row limit. The caller does the exact "upcoming" check and
  /// maps into a domain model — the nested attendance fields (like
  /// typeInfo) are not part of the PersonAttendance model, so this method
  /// exposes the raw shape.
  ///
  /// Multi-tenant safety: the join uses `attendance!inner` with
  /// `attendance.tenantId = currentTenantId`, so cross-tenant rows cannot
  /// leak even though `person_attendances` has no `tenantId` column.
  Future<List<Map<String, dynamic>>> getUpcomingAbsencesForPersons(
    List<int> personIds, {
    DateTime? now,
  }) async {
    if (personIds.isEmpty) return [];
    final n = now ?? DateTime.now();
    final from = DateTime(n.year, n.month, n.day - 1).toIso8601String().substring(0, 10);
    try {
      final response = await fetchAllPages<dynamic>((rangeFrom, rangeTo) async => await supabase
          .from('person_attendances')
          // PARITY_R10: type name/hide_name for the Ionic absence title
          // (Utils.getTypeTitle: typeInfo, else the type name unless hidden).
          .select('*, attendance:attendance_id!inner(id, date, type, typeInfo, tenantId, attType:type_id(name, hide_name))')
          .inFilter('person_id', personIds)
          .inFilter('status', [2, 4, 5])
          .eq('attendance.tenantId', currentTenantId)
          .gte('attendance.date', from)
          .order('id', ascending: true) // stable paging
          .range(rangeFrom, rangeTo) as List);

      return response
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
              type_id, plan, extra_plans, share_plan, duration_days, place,
              description, attachment_url, attachment_name, archived
            )
          ''')
          .inFilter('person_id', personIds)
          .eq('attendance.tenantId', currentTenantId)
          .order('attendance(date)', ascending: false);
      // Ionic 4.17.24: archived Termine only for admins/responsible.
      final showArchived = canSeeArchivedAttendances(currentUserRole);
      return (response as List)
          .where((row) => row['attendance'] != null)
          .where((row) => showArchived || !isArchivedRow(row['attendance'] as Map<String, dynamic>?))
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
  ///
  /// [isSessionCurrent] / [actingUserId] come from the write session captured
  /// when the user acted. They are handed to every [updatePersonAttendance],
  /// which checks the session right before each write, so an account or
  /// tenant switch during the computation stops the remaining writes.
  Future<void> updateShiftAssignmentsForAttendance(
    int attendanceId, {
    bool Function()? isSessionCurrent,
    String? actingUserId,
  }) async {
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
              status: parseAttendanceStatus(r['status']),
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
        await updatePersonAttendance(
          u.id,
          {'status': u.status.value, 'notes': u.notes},
          isSessionCurrent: isSessionCurrent,
          actingUserId: actingUserId,
        );
      }
    } on OfflineSessionChangedException {
      // Session changed mid-run: stop, keep the typed error for the caller.
      rethrow;
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

  /// Whether [personId] already has a row in the Termin [attendanceId] of
  /// the current tenant (inner join on attendance.tenantId).
  Future<bool> hasPersonAttendance(int attendanceId, int personId) async {
    try {
      final rows = await supabase
          .from('person_attendances')
          .select('id, attendance:attendance_id!inner(tenantId)')
          .eq('attendance_id', attendanceId)
          .eq('person_id', personId)
          .eq('attendance.tenantId', currentTenantId)
          .limit(1);
      return (rows as List).isNotEmpty;
    } catch (e, stack) {
      handleError(e, stack, 'hasPersonAttendance');
      rethrow;
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
  ///
  /// SOL_FIX11: offline queue replays pass [isSessionCurrent] and
  /// [actingUserId]. The session is checked again AFTER the async
  /// validation, immediately before the mutation (no await in between); if
  /// it changed (sign-out / account switch during validation) nothing is
  /// written and [OfflineSessionChangedException] is thrown so the queue
  /// keeps the entry. `changed_by` / duty `assigned_by` then use
  /// [actingUserId] (the author of the queued write), never a re-read user.
  ///
  /// [onlyIfStatus]: the row is written only while it still has this status
  /// (checked in the same UPDATE); otherwise nothing is written and
  /// [PersonAttendanceStatusChangedException] is thrown.
  Future<PersonAttendance> updatePersonAttendance(
    String id,
    Map<String, dynamic> updates, {
    bool Function()? isSessionCurrent,
    String? actingUserId,
    AttendanceStatus? onlyIfStatus,
  }) async {
    try {
      // Validate that personAttendance belongs to current tenant
      // DUTY: also load duty_state + the type's duty_mode for syncDutyWithStatus
      final validation = await supabase
          .from('person_attendances')
          .select('id, duty_state, attendance:attendance_id(tenantId, type_id, attType:type_id(duty_mode))')
          .eq('id', id)
          .maybeSingle();

      // SOL_FIX11: session guard right after the async validation and
      // before any mutation (no await until the update below).
      if (isSessionCurrent != null && !isSessionCurrent()) {
        throw const OfflineSessionChangedException();
      }
      final changedBy = actingUserId ?? supabase.auth.currentUser?.id;

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
        updates.addAll(dutySyncFieldsForStatus(
          isDutyTermin: true,
          currentDutyState: validation['duty_state'] as String?,
          newStatus: newStatus,
          userId: changedBy,
        ));
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
      updates['changed_by'] = changedBy;

      final response = onlyIfStatus == null
          ? await supabase
              .from('person_attendances')
              .update(updates)
              .eq('id', id)
              .select()
              .maybeSingle()
          : await supabase
              .from('person_attendances')
              .update(updates)
              .eq('id', id)
              .eq('status', onlyIfStatus.value)
              .select()
              .maybeSingle();

      if (response == null && onlyIfStatus != null) {
        throw const PersonAttendanceStatusChangedException();
      }
      // RT-008: Handle case where personAttendance was not found
      if (response == null) {
        throw RepositoryException(
          message: 'PersonAttendance not found',
          operation: 'updatePersonAttendance',
        );
      }

      return PersonAttendance.fromJson(response);
    } on OfflineSessionChangedException {
      rethrow; // SOL_FIX11: not an error – the queue keeps the write.
    } on PersonAttendanceStatusChangedException {
      rethrow; // expected: the row changed meanwhile.
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

  // Helper to parse attendance with optional person attendances
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
      // Chunked ids (URL size) and paged rows (PostgREST max-rows).
      final rows = await fetchInChunks<dynamic, int>(
        attendanceIds,
        (chunk) => fetchAllPages<dynamic>((from, to) async => await supabase
            .from('person_attendances')
            .select('id, attendance_id, person_id, status, notes, duty_state, '
                'attendance:attendance_id!inner(tenantId)')
            .inFilter('attendance_id', chunk)
            .eq('attendance.tenantId', currentTenantId)
            .order('id', ascending: true) // stable paging
            .range(from, to) as List),
      );
      return [
        for (final e in rows)
          PersonAttendance.fromJson(Map<String, dynamic>.from(e as Map)..remove('attendance')),
      ];
    } catch (e, stack) {
      handleError(e, stack, 'getPersonAttendancesForAttendances');
      rethrow;
    }
  }

  PersonAttendance _parsePersonAttendanceWithAttendance(Map<String, dynamic> data) {
    final attendanceData = data['attendance'] as Map<String, dynamic>?;
    
    return PersonAttendance(
      id: data['id']?.toString(),
      attendanceId: data['attendance_id'],
      personId: data['person_id'],
      status: parseAttendanceStatus(data['status']),
      notes: data['notes'],
      date: attendanceData?['date'],
      title: attendanceData?['typeInfo'],
    );
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
}
