part of 'player_repository.dart';

mixin _PlayerAttendanceSyncMixin on _PlayerRepositoryCore {
  /// Remove player from all upcoming (future) attendances.
  ///
  /// With [from] (YYYY-MM-DD or ISO timestamp) the player is removed from
  /// every attendance since the *local* start of that day, including past
  /// ones (Ionic removePlayerFromUpcomingAttendances with `from`): `date >=`
  /// the day start, or `date >` it with [inclusive] false (archive, Ionic
  /// getAttendancesByDate). The day is taken in local time so a UTC string
  /// of local midnight ("2026-11-09T23:00Z" for 10.11.) doesn't reach back
  /// into the previous day.
  Future<void> removeFromUpcomingAttendances(
    int playerId, {
    String? from,
    bool inclusive = true,
  }) async {
    try {
      final fromStart =
          from != null ? DateHelper.localDayStartUtcIso(from) : null;

      // Get attendance IDs (since the given date) for this tenant
      final query = supabase
          .from('attendance')
          .select('id')
          .eq('tenantId', currentTenantId);
      final upcomingAttendances = fromStart == null
          ? await query.gte(
              'date', DateTime.now().toIso8601String().substring(0, 10))
          : inclusive
              ? await query.gte('date', fromStart)
              : await query.gt('date', fromStart);

      final attendanceIds = (upcomingAttendances as List)
          .map((a) => a['id']) // Can be int or String (UUID)
          .toList();

      if (attendanceIds.isEmpty) return;

      // Delete person_attendances for these attendances
      await supabase
          .from('person_attendances')
          .delete()
          .eq('person_id', playerId)
          .inFilter('attendance_id', attendanceIds);
    } catch (e, stack) {
      handleError(e, stack, 'removeFromUpcomingAttendances');
      // Don't rethrow - this is a secondary operation
    }
  }

  /// Add player to all upcoming attendances.
  ///
  /// LOGIC_PEOPLE: Ionic db.addPlayerToUpcomingAttendances — respects the
  /// type's `relevant_groups` AND `additional_fields_filter`, and (for
  /// non all-day types) sets status/notes from the person's shift plan
  /// (Utils.getStatusByShift, e.g. "Entschuldigt" + 'Schichtbedingt').
  Future<void> addToUpcomingAttendances(Person player) async {
    final playerId = player.id;
    if (playerId == null) return;

    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);

      // Get upcoming attendances for this tenant
      // SOL_FIX4: paginated (PostgREST max-rows), stable order by id.
      final upcomingAttendances =
          await fetchAllPages<Map<String, dynamic>>((from, to) async {
        final page = await supabase
            .from('attendance')
            .select('id, type_id, date, start_time, end_time')
            .eq('tenantId', currentTenantId)
            .gte('date', today)
            .order('id', ascending: true)
            .range(from, to);
        return (page as List).cast<Map<String, dynamic>>();
      });

      if (upcomingAttendances.isEmpty) return;

      final types = await _loadTypeFilters();
      final fields = await _loadFilterFields(player);
      final defaults = fields.defaults;
      player = fields.player;
      final existing = await _existingAttendanceIds(playerId);
      final shift = await _loadShiftPlan(player.shiftId);

      final rows = <Map<String, dynamic>>[];
      for (final att in upcomingAttendances) {
        if (existing.contains(att['id']?.toString())) continue;
        // Aushilfen only until their last day ("dabei bis").
        if (!helperCoversDate(player.additionalFields, att['date']?.toString())) continue;
        final type = types.where((t) => t.id == att['type_id']).firstOrNull;
        if (type == null) continue;
        if (!_matchesType(player, type, defaults, checkPaused: false)) continue;

        final initial = _initialStatus(player, type, att, shift);
        rows.add({
          'attendance_id': att['id'],
          'person_id': playerId,
          'notes': initial.notes,
          'status': initial.status,
        });
      }
      if (rows.isNotEmpty) {
        await supabase.from('person_attendances').insert(rows);
      }
    } catch (e, stack) {
      handleError(e, stack, 'addToUpcomingAttendances');
      rethrow; // Rethrow to see error in UI
    }
  }

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
  /// addPlayerToAttendancesByDate (approve / addPlayer / handover backfill),
  /// so every backfill path applies the shift plan.
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
      // fully paged in a stable order – a long history must not push future
      // entries past the PostgREST row limit. One day of slack; `isPast`
      // below decides exactly.
      final since = todayStart.subtract(const Duration(days: 1)).toUtc().toIso8601String();
      final rows = await fetchAllPages<Map<String, dynamic>>((from, to) async {
        final page = await supabase
            .from('person_attendances')
            .select(
                'id, status, notes, duty_state, attendance:attendance_id!inner(id, date, type_id, start_time, end_time, tenantId, attType:type_id(duty_mode))')
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
          await _updateShiftEntry(r, personId, result.status.value, result.note);
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
    final isDuty = att is Map && att['attType'] is Map && (att['attType'] as Map)['duty_mode'] == true;
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
    if (updates.containsKey('duty_state')) row['duty_state'] = updates['duty_state'];
  }

  /// Attendance types of the current tenant with parsed filter data.
  Future<List<_TypeFilter>> _loadTypeFilters({int? tenantId}) async {
    final types = await supabase
        .from('attendance_types')
        .select(
            'id, relevant_groups, relevant_persons, default_status, additional_fields_filter, all_day, start_time, end_time')
        .eq('tenant_id', tenantId ?? currentTenantId);
    return (types as List).map((t) {
      final raw = t['default_status'];
      final status = raw is int
          ? raw
          : AttendanceStatus.values
              .firstWhere((s) => s.name == raw,
                  orElse: () => AttendanceStatus.neutral)
              .value;
      final groups = t['relevant_groups'];
      final filter = t['additional_fields_filter'];
      return _TypeFilter(
        id: t['id'],
        relevantGroups: groups is List ? groups.whereType<int>().toList() : const [],
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
  /// creation (Ionic getPersonExtraFields + hydrated shared values): the
  /// defaults of the tenant fields, overridden by the organisation's fields,
  /// and [player] with its shared organisation values over its own.
  Future<({Map<String, dynamic> defaults, Person player, Set<String> orgKeys})> _loadFilterFields(
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
    if (orgId == null) return (defaults: defaults, player: player, orgKeys: const <String>{});
    // tenant_groups has no tenantId column: scoped via the organisation id
    // of the tenant (tenant_group_tenants above).
    final org = await supabase
        .from('tenant_groups')
        .select('additional_fields')
        .eq('id', orgId)
        .maybeSingle();
    final orgDefaults = organisationFieldDefaults(org?['additional_fields'] as List?);
    if (orgDefaults.isEmpty) return (defaults: defaults, player: player, orgKeys: const <String>{});
    final key = organisationPersonKeyOfRow({
      'global_person_id': player.globalPersonId,
      'appId': player.appId,
    });
    final shared = key == null
        ? const <String, dynamic>{}
        : (await fetchSharedFieldValuesForPeople(supabase, orgId, [key]))[key] ?? const <String, dynamic>{};
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
    if (!typeCircleCovers(type.relevantGroups, type.relevantPersons,
        groupId: player.instrument, personId: player.id)) {
      return false;
    }
    final key = type.filterKey;
    if (key != null && type.filterOption != null && defaults.containsKey(key)) {
      final value = player.additionalFields?[key] ?? defaults[key];
      if (value != type.filterOption) return false;
    }
    return true;
  }

  /// Ionic db.addPlayerToAttendancesByDate: add the person to every
  /// attendance after their join date (or today when unknown) that matches
  /// the type's group / extra field filters.
  ///
  /// [tenantId] targets another tenant (Ionic handover: backfill in the
  /// target instance); defaults to the current tenant.
  Future<void> addPlayerToAttendancesByDate(Person player,
      {int? tenantId}) async {
    final playerId = player.id;
    if (playerId == null) return;
    final targetTenantId = tenantId ?? currentTenantId;
    try {
      final joined = player.joined != null && player.joined!.length >= 10
          ? player.joined!.substring(0, 10)
          : DateTime.now().toIso8601String().substring(0, 10);
      // SOL_FIX4: paginated — more than 1000 matching Termine (PostgREST
      // max-rows) were silently missed; stable order by id.
      final attendances =
          await fetchAllPages<Map<String, dynamic>>((from, to) async {
        final page = await supabase
            .from('attendance')
            .select('id, type_id, date, start_time, end_time')
            .eq('tenantId', targetTenantId)
            .gt('date', joined)
            .order('id', ascending: true)
            .range(from, to);
        return (page as List).cast<Map<String, dynamic>>();
      });
      if (attendances.isEmpty) return;

      final types = await _loadTypeFilters(tenantId: targetTenantId);
      final fields = await _loadFilterFields(player, tenantId: targetTenantId);
      final defaults = fields.defaults;
      player = fields.player;
      final existing =
          await _existingAttendanceIds(playerId, tenantId: targetTenantId);

      final rows = <Map<String, dynamic>>[];
      for (final att in attendances) {
        if (existing.contains(att['id']?.toString())) continue;
        // Aushilfen only until their last day ("dabei bis").
        if (!helperCoversDate(player.additionalFields, att['date']?.toString())) continue;
        final type = types.where((t) => t.id == att['type_id']).firstOrNull;
        if (type == null) continue;
        if (!_matchesType(player, type, defaults, checkPaused: false)) continue;
        // PARITY_A (D4): Ionic db.addPlayerToAttendancesByDate inserts the
        // type's default_status with empty notes (no shift plan here).
        rows.add({
          'attendance_id': att['id'],
          'person_id': playerId,
          'notes': '',
          'status': type.defaultStatus,
        });
      }
      if (rows.isNotEmpty) {
        await supabase.from('person_attendances').insert(rows);
      }
    } catch (e, stack) {
      handleError(e, stack, 'addPlayerToAttendancesByDate');
      rethrow;
    }
  }

  /// Ionic db.syncPlayerWithUpcomingAttendances: after a group or
  /// filter-relevant extra field change, add the person to upcoming
  /// attendances they now match and remove them from ones they no longer
  /// match. Only attendance types with a filter are touched.
  Future<void> syncPlayerWithUpcomingAttendances(
    Person player, {
    int? oldInstrument,
    Map<String, dynamic>? oldAdditionalFields,
  }) async {
    final playerId = player.id;
    if (playerId == null) return;
    try {
      // Aushilfe: a changed last day ("dabei bis") touches every type.
      final helperChanged = oldAdditionalFields != null &&
          oldAdditionalFields.containsKey(helperUntilKey) &&
          helperUntilOf(oldAdditionalFields) != helperUntilOf(player.additionalFields);
      final types = (await _loadTypeFilters())
          .where((t) =>
              helperChanged ||
              t.hasCircle ||
              (t.filterKey != null && t.filterOption != null))
          .toList();
      if (types.isEmpty) return;

      // Organisation fields too (Termin creation filters on them as well),
      // with the person's shared values as stored now (callers write first).
      final fields = await _loadFilterFields(player);
      final defaults = fields.defaults;
      player = fields.player;
      final groupChanged = oldInstrument != player.instrument;
      final changedFields = <String>{};
      for (final t in types) {
        final key = t.filterKey;
        if (key == null || !defaults.containsKey(key)) continue;
        final newValue = player.additionalFields?[key] ?? defaults[key];
        // An organisation value the caller did not pass is unknown, not the
        // default: counted as unchanged (no reconciling on a guess).
        final oldValue = fields.orgKeys.contains(key) && !(oldAdditionalFields?.containsKey(key) ?? false)
            ? newValue
            : oldAdditionalFields?[key] ?? defaults[key];
        if (oldValue != newValue) changedFields.add(key);
      }
      if (!groupChanged && changedFields.isEmpty && !helperChanged) return;

      final today = DateTime.now().toIso8601String().substring(0, 10);
      // SOL_FIX4: paginated, stable order by id.
      final upcoming =
          await fetchAllPages<Map<String, dynamic>>((from, to) async {
        final page = await supabase
            .from('attendance')
            .select('id, type_id, date')
            .eq('tenantId', currentTenantId)
            .gte('date', today)
            .order('id', ascending: true)
            .range(from, to);
        return (page as List).cast<Map<String, dynamic>>();
      });
      if (upcoming.isEmpty) return;

      final existing = await _existingAttendanceIds(playerId);
      final toAdd = <Map<String, dynamic>>[];
      final toRemove = <dynamic>[];
      for (final att in upcoming) {
        final type = types.where((t) => t.id == att['type_id']).firstOrNull;
        if (type == null) continue;
        final affectsGroup = groupChanged && type.hasCircle;
        final affectsField =
            type.filterKey != null && changedFields.contains(type.filterKey);
        if (!affectsGroup && !affectsField && !helperChanged) continue;

        final covered =
            helperCoversDate(player.additionalFields, att['date']?.toString());
        final isIn = existing.contains(att['id']?.toString());
        // Only the Aushilfe's last day changed for this type: rows within
        // the time stay as they are (also persons added by hand to a Termin
        // of another Register), only later ones go and missing matching
        // ones come.
        final should = affectsGroup || affectsField
            ? _matchesType(player, type, defaults) && covered
            : covered && (isIn || _matchesType(player, type, defaults));
        if (should && !isIn) {
          toAdd.add({
            'attendance_id': att['id'],
            'person_id': playerId,
            'notes': '',
            'status': type.defaultStatus,
          });
        } else if (!should && isIn) {
          toRemove.add(att['id']);
        }
      }
      if (toAdd.isNotEmpty) {
        await supabase.from('person_attendances').insert(toAdd);
      }
      if (toRemove.isNotEmpty) {
        await supabase
            .from('person_attendances')
            .delete()
            .eq('person_id', playerId)
            .inFilter('attendance_id', toRemove);
      }
    } catch (e, stack) {
      handleError(e, stack, 'syncPlayerWithUpcomingAttendances');
      rethrow;
    }
  }

  /// Attendance ids (as strings) the player already has rows for, restricted
  /// to the current tenant via the attendance join.
  ///
  /// SOL_FIX4: paginated (a long-standing member easily has more than 1000
  /// rows; a truncated set re-inserted duplicates), stable order by id.
  Future<Set<String>> _existingAttendanceIds(int playerId,
      {int? tenantId}) async {
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

  /// Move person_attendances from [fromId] to [toId]; rows that would
  /// conflict (same attendance) are deleted, the target's row wins.
  /// Callers must verify both ids belong to the current tenant
  /// (person_attendances has no tenant column).
  ///
  /// SOL_FIX7: both sides are loaded completely (paged, stable order by id;
  /// a long-standing member easily has more than PostgREST's 1000 rows) and
  /// the id lists are written in chunks. Same writes as Ionic
  /// reassignPersonAttendances otherwise (delete conflicts, re-point rest).
  Future<void> _reassignPersonAttendances(int fromId, int toId) async {
    final fromRows = await _personAttendanceRows(fromId, 'id, attendance_id');
    if (fromRows.isEmpty) return;

    final toRows = await _personAttendanceRows(toId, 'id, attendance_id');
    final toAttendanceIds =
        toRows.map((r) => r['attendance_id']?.toString()).toSet();

    final conflicting = <dynamic>[];
    final movable = <dynamic>[];
    for (final r in fromRows) {
      if (toAttendanceIds.contains(r['attendance_id']?.toString())) {
        conflicting.add(r['id']);
      } else {
        movable.add(r['id']);
      }
    }

    for (final chunk in _chunks(conflicting)) {
      await supabase
          .from('person_attendances')
          .delete()
          .inFilter('id', chunk)
          .eq('person_id', fromId);
    }
    for (final chunk in _chunks(movable)) {
      await supabase
          .from('person_attendances')
          .update({'person_id': toId})
          .inFilter('id', chunk)
          .eq('person_id', fromId);
    }
  }

  /// All person_attendances rows of [personId] (paged, ordered by id).
  Future<List<Map<String, dynamic>>> _personAttendanceRows(
      int personId, String columns) {
    return fetchAllPages<Map<String, dynamic>>((from, to) async {
      final page = await supabase
          .from('person_attendances')
          .select(columns)
          .eq('person_id', personId)
          .order('id', ascending: true)
          .range(from, to);
      return (page as List).cast<Map<String, dynamic>>();
    });
  }
}

/// SOL_FIX7: id lists for `in.(…)` filters are split so the request URL
/// stays short (a member can have thousands of rows).
Iterable<List<dynamic>> _chunks(List<dynamic> ids, [int size = 200]) sync* {
  for (var i = 0; i < ids.length; i += size) {
    yield ids.sublist(i, i + size > ids.length ? ids.length : i + size);
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
