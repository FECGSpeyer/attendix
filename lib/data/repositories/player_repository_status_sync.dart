part of 'player_repository.dart';

/// Shift status synchronization and type filter helpers for [PlayerRepository].
mixin _PlayerStatusSyncMixin on _PlayerRepositoryCore {
  /// Shift plan of [tenantId] (default: current tenant) by id (null when
  /// unset / missing / belonging to another tenant).
  Future<ShiftPlan?> _loadShiftPlan(String? shiftId, {int? tenantId}) async {
    if (shiftId == null || shiftId.isEmpty) return null;
    final row = await supabase
        .from('shifts')
        .select('*')
        .eq('id', shiftId)
        .eq('tenant_id', tenantId ?? currentTenantId)
        .maybeSingle();
    return row == null ? null : ShiftPlan.fromJson(row);
  }

  /// Initial person_attendances status/notes for [player] in [att]: the
  /// type's default status, or — for non all-day types and a person with a
  /// shift plan — the shift-based status (Utils.getStatusByShift, e.g.
  /// "Entschuldigt" + 'Schichtbedingt').
  ///
  /// SOL_FIX1: shared by addToUpcomingAttendances and
  /// addPlayerToAttendancesByDate (approve / addPlayer / handover backfill).
  ({int status, String notes}) _initialStatus(
    Person player,
    _TypeFilter type,
    Map att,
    ShiftPlan? shift,
  ) {
    if (shift == null || type.allDay) {
      return (status: type.defaultStatus, notes: '');
    }
    final result = peopleStatusByShift(
      shift: shift,
      attDate: att['date']?.toString() ?? '',
      attendanceStart: att['start_time']?.toString() ?? type.startTime ?? '',
      attendanceEnd: att['end_time']?.toString() ?? type.endTime ?? '',
      defaultStatus: AttendanceStatus.fromValue(type.defaultStatus),
      shiftStart: player.shiftStart,
      shiftName: player.shiftName,
    );
    return (status: result.status.value, notes: result.note);
  }

  /// LOGIC_PEOPLE: Ionic db.updateShiftAssignmentsForPerson — after a shift
  /// change, reset the person's future shift-excused entries to the type
  /// default and re-apply the (new) shift plan.
  Future<void> updateShiftAssignmentsForPerson(Person person) async {
    final personId = person.id;
    if (personId == null) return;
    try {
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      // SOL_FIX36: only (about) future Termine, filtered on the server and
      // fully paged in a stable order; `isPast` below decides exactly.
      final since =
          todayStart.subtract(const Duration(days: 1)).toUtc().toIso8601String();
      final rows = await fetchAllPages<Map<String, dynamic>>((from, to) async {
        final page = await supabase
            .from('person_attendances')
            .select(
              'id, status, notes, duty_state, attendance:attendance_id!inner(id, date, type_id, start_time, end_time, tenantId, attType:type_id(duty_mode))',
            )
            .eq('person_id', personId)
            .eq('attendance.tenantId', currentTenantId)
            .gte('attendance.date', since)
            .order('id', ascending: true)
            .range(from, to);
        return (page as List).cast<Map<String, dynamic>>();
      });
      final types = await _loadTypeFilters();
      final shift = await _loadShiftPlan(person.shiftId);

      bool isPast(Map att) {
        final d = DateTime.tryParse(att['date']?.toString() ?? '');
        if (d == null) return true;
        return DateTime(d.year, d.month, d.day).isBefore(todayStart);
      }

      final entries = rows
          .map((r) => Map<String, dynamic>.from(r))
          .where((r) => r['attendance'] is Map && !isPast(r['attendance'] as Map))
          .toList();

      // Phase 1: reset future shift-excused entries to the type default.
      for (final r in entries) {
        final att = r['attendance'] as Map;
        if (!isWorkExcusedNote(r['notes'] as String?) ||
            r['status'] != AttendanceStatus.excused.value) {
          continue;
        }
        final type = types.where((t) => t.id == att['type_id']).firstOrNull;
        if (type == null) continue;
        await _updateShiftEntry(r, personId, type.defaultStatus, '');
      }

      // Phase 2: apply the new shift.
      if (shift == null) return;
      for (final r in entries) {
        final att = r['attendance'] as Map;
        final type = types.where((t) => t.id == att['type_id']).firstOrNull;
        if (type == null) continue;
        ({AttendanceStatus status, String note}) result;
        try {
          result = peopleStatusByShift(
            shift: shift,
            attDate: att['date']?.toString() ?? '',
            attendanceStart:
                att['start_time']?.toString() ?? type.startTime ?? '',
            attendanceEnd: att['end_time']?.toString() ?? type.endTime ?? '',
            defaultStatus: AttendanceStatus.fromValue(type.defaultStatus),
            shiftStart: person.shiftStart,
            shiftName: person.shiftName,
          );
        } catch (_) {
          continue; // shift_name not in the new plan — skip like Ionic
        }
        if (result.status == AttendanceStatus.excused &&
            r['status'] == type.defaultStatus) {
          await _updateShiftEntry(
            r,
            personId,
            result.status.value,
            result.note,
          );
        }
      }
    } catch (e, stack) {
      handleError(e, stack, 'updateShiftAssignmentsForPerson');
      rethrow;
    }
  }

  /// db-f424eb31: a status change of [updateShiftAssignmentsForPerson] goes
  /// through Ionic db.updatePersonAttendance: changed_at/changed_by and the
  /// duty sync (syncDutyWithStatus) are written with it. [row] is updated in
  /// place for the following phase.
  Future<void> _updateShiftEntry(
    Map<String, dynamic> row,
    int personId,
    int status,
    String notes,
  ) async {
    final userId = supabase.auth.currentUser?.id;
    final att = row['attendance'];
    final isDuty = att is Map &&
        att['attType'] is Map &&
        (att['attType'] as Map)['duty_mode'] == true;
    final updates = <String, dynamic>{
      'status': status,
      'notes': notes,
      ...dutySyncFieldsForStatus(
        isDutyTermin: isDuty,
        currentDutyState: row['duty_state'] as String?,
        newStatus: AttendanceStatus.fromValue(status),
        userId: userId,
      ),
      'changed_at': DateTime.now().toUtc().toIso8601String(),
      'changed_by': userId,
    };
    await supabase
        .from('person_attendances')
        .update(updates)
        .eq('id', row['id'])
        .eq('person_id', personId);
    row['status'] = status;
    row['notes'] = notes;
    if (updates.containsKey('duty_state')) {
      row['duty_state'] = updates['duty_state'];
    }
  }

  /// Attendance types of the current tenant with parsed filter data.
  Future<List<_TypeFilter>> _loadTypeFilters({int? tenantId}) async {
    final types = await supabase
        .from('attendance_types')
        .select(
          'id, relevant_groups, relevant_persons, default_status, additional_fields_filter, all_day, start_time, end_time',
        )
        .eq('tenant_id', tenantId ?? currentTenantId);
    return (types as List).map((t) {
      final raw = t['default_status'];
      final status = raw is int
          ? raw
          : AttendanceStatus.values
              .firstWhere(
                (s) => s.name == raw,
                orElse: () => AttendanceStatus.neutral,
              )
              .value;
      final groups = t['relevant_groups'];
      final filter = t['additional_fields_filter'];
      return _TypeFilter(
        id: t['id'],
        relevantGroups:
            groups is List ? groups.whereType<int>().toList() : const [],
        relevantPersons: typeCirclePersonsFromJson(t['relevant_persons']),
        defaultStatus: status,
        filterKey: filter is Map ? filter['key']?.toString() : null,
        filterOption: filter is Map ? filter['option'] : null,
        allDay: t['all_day'] == true,
        startTime: t['start_time'] as String?,
        endTime: t['end_time'] as String?,
      );
    }).toList();
  }

  /// Default values of the tenant's extra fields (for filter matching).
  Future<Map<String, dynamic>> _loadExtraFieldDefaults({int? tenantId}) async {
    final row = await supabase
        .from('tenants')
        .select('additional_fields')
        .eq('id', tenantId ?? currentTenantId)
        .maybeSingle();
    final fields = row?['additional_fields'];
    return {
      if (fields is List)
        for (final f in fields.whereType<Map>())
          f['id'].toString(): f['defaultValue'],
    };
  }

  /// Field definitions and values the type filters see, like Termin
  /// creation (Ionic getPersonExtraFields + hydrated shared values).
  Future<({Map<String, dynamic> defaults, Person player, Set<String> orgKeys})>
      _loadFilterFields(
    Person player, {
    int? tenantId,
  }) async {
    final tenant = tenantId ?? currentTenantId;
    final defaults = await _loadExtraFieldDefaults(tenantId: tenant);
    final link = await supabase
        .from('tenant_group_tenants')
        .select('tenant_group')
        .eq('tenant_id', tenant)
        .maybeSingle();
    final orgId = (link?['tenant_group'] as num?)?.toInt();
    if (orgId == null) {
      return (defaults: defaults, player: player, orgKeys: const <String>{});
    }
    // tenant_groups has no tenantId column: scoped via the organisation id.
    final org = await supabase
        .from('tenant_groups')
        .select('additional_fields')
        .eq('id', orgId)
        .maybeSingle();
    final orgDefaults =
        organisationFieldDefaults(org?['additional_fields'] as List?);
    if (orgDefaults.isEmpty) {
      return (defaults: defaults, player: player, orgKeys: const <String>{});
    }
    final key = organisationPersonKeyOfRow({
      'global_person_id': player.globalPersonId,
      'appId': player.appId,
    });
    final shared = key == null
        ? const <String, dynamic>{}
        : (await fetchSharedFieldValuesForPeople(supabase, orgId, [key]))[key] ??
            const <String, dynamic>{};
    final values = {
      ...?player.additionalFields,
      for (final e in shared.entries)
        if (orgDefaults.containsKey(e.key)) e.key: e.value,
    };
    return (
      defaults: {...defaults, ...orgDefaults},
      player: player.copyWith(additionalFields: values),
      orgKeys: orgDefaults.keys.toSet(),
    );
  }

  bool _matchesType(
    Person player,
    _TypeFilter type,
    Map<String, dynamic> defaults, {
    bool checkPaused = true,
  }) {
    if (checkPaused && player.paused) return false;
    if (!typeCircleCovers(
      type.relevantGroups,
      type.relevantPersons,
      groupId: player.instrument,
      personId: player.id,
    )) {
      return false;
    }
    final key = type.filterKey;
    if (key != null && type.filterOption != null && defaults.containsKey(key)) {
      final value = player.additionalFields?[key] ?? defaults[key];
      if (value != type.filterOption) return false;
    }
    return true;
  }

  /// Attendance ids (as strings) the player already has rows for, restricted
  /// to the current tenant via the attendance join.
  ///
  /// SOL_FIX4: paginated (a long-standing member easily has more than 1000
  /// rows; a truncated set re-inserted duplicates), stable order by id.
  Future<Set<String>> _existingAttendanceIds(
    int playerId, {
    int? tenantId,
  }) async {
    final rows = await fetchAllPages<Map<String, dynamic>>((from, to) async {
      final page = await supabase
          .from('person_attendances')
          .select('id, attendance_id, attendance:attendance_id!inner(tenantId)')
          .eq('person_id', playerId)
          .eq('attendance.tenantId', tenantId ?? currentTenantId)
          .order('id', ascending: true)
          .range(from, to);
      return (page as List).cast<Map<String, dynamic>>();
    });
    return rows
        .map((r) => r['attendance_id']?.toString())
        .whereType<String>()
        .toSet();
  }
}

/// Filter data of an attendance type (relevant groups + extra field filter).
class _TypeFilter {
  const _TypeFilter({
    required this.id,
    required this.relevantGroups,
    this.relevantPersons = const [],
    required this.defaultStatus,
    this.filterKey,
    this.filterOption,
    this.allDay = false,
    this.startTime,
    this.endTime,
  });

  final dynamic id;
  final List<int> relevantGroups;

  /// Single persons of the circle (Besprechungen), next to the groups.
  final List<int> relevantPersons;
  bool get hasCircle => !typeCircleIsEveryone(relevantGroups, relevantPersons);
  final int defaultStatus;
  final String? filterKey;
  final dynamic filterOption;
  final bool allDay;
  final String? startTime;
  final String? endTime;
}
