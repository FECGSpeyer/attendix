part of 'player_repository.dart';

mixin _PlayerAttendanceSyncMixin
    on _PlayerRepositoryCore, _PlayerStatusSyncMixin {
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

      final query = supabase
          .from('attendance')
          .select('id')
          .eq('tenantId', currentTenantId);
      final upcomingAttendances = fromStart == null
          ? await query.gte(
              'date',
              DateTime.now().toIso8601String().substring(0, 10),
            )
          : inclusive
              ? await query.gte('date', fromStart)
              : await query.gt('date', fromStart);

      final attendanceIds = (upcomingAttendances as List)
          .map((a) => a['id'])
          .toList();

      if (attendanceIds.isEmpty) return;

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
        if (!helperCoversDate(
          player.additionalFields,
          att['date']?.toString(),
        )) {
          continue;
        }
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

  /// Ionic db.addPlayerToAttendancesByDate: add the person to every
  /// attendance after their join date (or today when unknown) that matches
  /// the type's group / extra field filters.
  ///
  /// [tenantId] targets another tenant (Ionic handover: backfill in the
  /// target instance); defaults to the current tenant.
  Future<void> addPlayerToAttendancesByDate(
    Person player, {
    int? tenantId,
  }) async {
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
        if (!helperCoversDate(
          player.additionalFields,
          att['date']?.toString(),
        )) {
          continue;
        }
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
          helperUntilOf(oldAdditionalFields) !=
              helperUntilOf(player.additionalFields);
      final types = (await _loadTypeFilters())
          .where((t) =>
              helperChanged ||
              t.hasCircle ||
              (t.filterKey != null && t.filterOption != null))
          .toList();
      if (types.isEmpty) return;

      final fields = await _loadFilterFields(player);
      final defaults = fields.defaults;
      player = fields.player;
      final groupChanged = oldInstrument != player.instrument;
      final changedFields = _changedFilterFields(
        types,
        defaults,
        player,
        oldAdditionalFields,
        fields.orgKeys,
      );
      if (!groupChanged && changedFields.isEmpty && !helperChanged) return;

      final today = DateTime.now().toIso8601String().substring(0, 10);
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

  Set<String> _changedFilterFields(
    List<_TypeFilter> types,
    Map<String, dynamic> defaults,
    Person player,
    Map<String, dynamic>? oldAdditionalFields,
    Set<String> orgKeys,
  ) {
    final changedFields = <String>{};
    for (final t in types) {
      final key = t.filterKey;
      if (key == null || !defaults.containsKey(key)) continue;
      final newValue = player.additionalFields?[key] ?? defaults[key];
      final oldValue = orgKeys.contains(key) &&
              !(oldAdditionalFields?.containsKey(key) ?? false)
          ? newValue
          : oldAdditionalFields?[key] ?? defaults[key];
      if (oldValue != newValue) changedFields.add(key);
    }
    return changedFields;
  }

  /// Move person_attendances from [fromId] to [toId]; rows that would
  /// conflict (same attendance) are deleted, the target's row wins.
  /// Callers must verify both ids belong to the current tenant
  /// (person_attendances has no tenant column).
  ///
  /// SOL_FIX7: both sides are loaded completely (paged, stable order by id)
  /// and the id lists are written in chunks.
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
    int personId,
    String columns,
  ) {
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
