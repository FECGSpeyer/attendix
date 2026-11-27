part of 'sign_in_out_repository.dart';

mixin _SignInOutQueriesMixin on _SignInOutRepositoryCore {
  /// Own Termine of a person in the current tenant ("Meine Termine").
  ///
  /// With [all] = false only Termine since [since] are loaded (season start).
  Future<List<CrossTenantPersonAttendance>> getPersonAttendances(
    int personId, {
    String? since,
    String tenantName = '',
  }) async {
    try {
      // SEC: person_attendances has no tenantId column – the inner join on
      // attendance is filtered by tenantId so only Termine of this tenant
      // are returned.
      // SOL_FIX37: paged in a stable order, so a long history never pushes
      // rows (upcoming Termine, quota) past the PostgREST row limit.
      final response = await fetchAllPages<Map<String, dynamic>>((from, to) async {
        var query = supabase
            .from('person_attendances')
            .select(
                '*, attendance:attendance_id!inner($kSignoutAttendanceColumns, '
                'attType:type_id($kSignoutAttendanceTypeColumns))')
            .eq('person_id', personId)
            .eq('attendance.tenantId', currentTenantId);
        if (since != null) {
          query = query.gt('attendance.date', since);
        }
        final page = await query.order('id', ascending: true).range(from, to);
        return (page as List).cast<Map<String, dynamic>>();
      });

      // Ionic 4.17.24: archived Termine only for admins/responsible – also
      // not in the own list and average.
      final showArchived = canSeeArchivedAttendances(currentUserRole);
      return response
          .where((json) => json['attendance'] != null)
          .where((json) =>
              showArchived || !isArchivedRow(json['attendance'] as Map<String, dynamic>?))
          .map((json) => _fromRows(
                json['attendance'] as Map<String, dynamic>,
                json,
                tenantId: currentTenantId,
                tenantName: tenantName,
                // Ionic getPersonAttendances: attType without hide_name
                honorHideName: false,
              ))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getPersonAttendances');
      rethrow;
    }
  }

  /// All running/upcoming Termine of the tenant plus the own status
  /// (tenant setting "Alle Termine für Mitglieder sichtbar").
  Future<List<CrossTenantPersonAttendance>> getAllUpcomingAttendancesForSignout(
    int playerId, {
    String tenantName = '',
  }) async {
    try {
      // Look back a bit so multi-day Termine that started earlier and are
      // still running stay included.
      final since = DateTime.now()
          .subtract(const Duration(days: 31))
          .toUtc()
          .toIso8601String();
      final atts = await supabase
          .from('attendance')
          .select('$kSignoutAttendanceColumns, '
              'attType:type_id($kSignoutAttendanceTypeColumns)')
          .eq('tenantId', currentTenantId)
          .gt('date', since)
          .order('date', ascending: true);

      final running = (atts as List)
          .cast<Map<String, dynamic>>()
          .where((a) => !EventListUtils.hasEnded(
                a['date']?.toString(),
                _toInt(a['duration_days']),
              ))
          .toList();
      if (running.isEmpty) return [];

      // SEC: filtered by own person_id and attendance ids of this tenant.
      final pas = await supabase
          .from('person_attendances')
          .select('id, attendance_id, status, notes, registration_answers, duty_state')
          .eq('person_id', playerId)
          .inFilter('attendance_id', running.map((a) => a['id']).toList());
      final paMap = <int, Map<String, dynamic>>{
        for (final pa in (pas as List).cast<Map<String, dynamic>>())
          _toInt(pa['attendance_id']) ?? -1: pa,
      };

      return running.map((att) {
        final pa = paMap[_toInt(att['id'])];
        return _fromRows(
          att,
          pa ?? {'person_id': playerId},
          tenantId: currentTenantId,
          tenantName: tenantName,
          isMember: pa != null,
          // Ionic getAllUpcomingAttendancesForSignout: attType without hide_name
          honorHideName: false,
        );
      }).toList();
    } catch (e, stack) {
      handleError(e, stack, 'getAllUpcomingAttendancesForSignout');
      rethrow;
    }
  }

  CrossTenantPersonAttendance _fromRows(
    Map<String, dynamic> att,
    Map<String, dynamic> pa, {
    required int tenantId,
    required String tenantName,
    String tenantColor = '#3880FF',
    bool isMember = true,
    bool honorHideName = true,
  }) {
    final type = _parseType(att['attType']);
    return CrossTenantPersonAttendance(
      id: pa['id']?.toString(),
      personId: _toInt(pa['person_id']),
      attendanceId: _toInt(att['id']),
      status: isMember ? parseAttendanceStatus(pa['status']) : AttendanceStatus.neutral,
      notes: pa['notes'] as String?,
      date: att['date'] as String?,
      typeInfo: att['typeInfo'] as String?,
      startTime: att['start_time'] as String?,
      endTime: att['end_time'] as String?,
      deadline: att['deadline'] as String?,
      tenantId: tenantId,
      tenantName: tenantName,
      tenantColor: tenantColor,
      plan: att['plan'] as Map<String, dynamic>?,
      extraPlans: att['extra_plans'] is List
          ? [
              for (final p in att['extra_plans'] as List)
                if (p is Map) Map<String, dynamic>.from(p),
            ]
          : null,
      sharePlan: att['share_plan'] == true,
      typeId: att['type_id']?.toString(),
      includeInAverage: type?.includeInAverage ?? true,
      durationDays: _toInt(att['duration_days']),
      place: att['place'] as String?,
      filesFolder: att['files_folder'] as String?,
      description: att['description'] as String?,
      attachmentUrl: att['attachment_url'] as String?,
      attachmentName: att['attachment_name'] as String?,
      songs: (att['songs'] is List)
          ? (att['songs'] as List).map((e) => _toInt(e) ?? 0).toList()
          : const [],
      attendanceType: type,
      isMember: isMember,
      dutyState: pa['duty_state'] as String?,
      registrationAnswers: pa['registration_answers'] is Map
          ? Map<String, dynamic>.from(pa['registration_answers'] as Map)
          : null,
      legacyType: att['type'] as String?,
      honorHideName: honorHideName,
    );
  }


  /// Own Termine of the current user in all tenants he belongs to
  /// ("Übersicht", Ionic `loadAllPersonAttendancesAcrossTenants`).
  ///
  /// IOS_ATT_PAGES: same scope as Ionic –
  /// * tenants = the user's `tenantUsers` memberships (not every `player`
  ///   row linked to the account),
  /// * one person per tenant: the active linked row (SOL_FIX14 – Ionic's
  ///   `.single()` skipped tenants with several rows; no row → skipped),
  /// * only Termine after the tenant's `seasonStart` (default 2023-01-01),
  /// * tenant label `longName || shortName`, colour by membership order,
  /// * sorted by date ascending.
  Future<List<CrossTenantPersonAttendance>> getAllPersonAttendancesAcrossTenants() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return [];

      // SEC: cross-tenant by design – only the user's own memberships.
      final memberships = await supabase
          .from('tenantUsers')
          .select('tenantId, role')
          .eq('userId', userId);
      final tenantIds = <int>[];
      // Ionic 4.17.24: archived Termine per membership role.
      final roles = <int, Role>{};
      for (final m in memberships as List) {
        final id = _toInt(m['tenantId']);
        if (id != null && !tenantIds.contains(id)) tenantIds.add(id);
        final role = _toInt(m['role']);
        if (id != null && role != null) roles[id] = Role.fromValue(role);
      }
      if (tenantIds.isEmpty) return [];

      final tenants = await supabase
          .from('tenants')
          .select('id, shortName, longName, seasonStart')
          .inFilter('id', tenantIds);
      final tenantRows = <int, Map<String, dynamic>>{
        for (final t in (tenants as List).cast<Map<String, dynamic>>())
          if (_toInt(t['id']) != null) _toInt(t['id'])!: t,
      };

      final perTenant = await Future.wait([
        for (final tenantId in tenantIds)
          _ownAttendancesOfTenant(
            userId: userId,
            tenantId: tenantId,
            tenant: tenantRows[tenantId],
            tenantColor: _getTenantColor(tenantId, tenantIds),
            showArchived: canSeeArchivedAttendances(roles[tenantId]),
          ),
      ]);

      return SignInOutRepository.sortCrossTenantByDate(perTenant.expand((l) => l).toList());
    } catch (e, stack) {
      handleError(e, stack, 'getAllPersonAttendancesAcrossTenants');
      rethrow;
    }
  }

  /// Ionic `getPersonIdForTenant` + `getPersonAttendancesForTenant`.
  Future<List<CrossTenantPersonAttendance>> _ownAttendancesOfTenant({
    required String userId,
    required int tenantId,
    required Map<String, dynamic>? tenant,
    required String tenantColor,
    bool showArchived = false,
  }) async {
    // SEC: the person of the user in this tenant (tenantId + appId).
    // SOL_FIX14: load every linked row incl. pending / left and pick the
    // active one (same choice as CrossTenantService.getPersonIdForTenant).
    // Ionic's `.single()` fails when the account has several rows in the
    // tenant (e.g. an archived and a new active one) and the tenant's
    // Termine vanished from the Übersicht.
    final persons = await supabase
        .from('player')
        .select('id, pending, left')
        .eq('tenantId', tenantId)
        .eq('appId', userId);
    final personId = CrossTenantService.pickPersonIdForTenant(
        (persons as List).cast<Map<String, dynamic>>());
    if (personId == null) return const [];

    // SEC: person_attendances has no tenantId – the inner join on attendance
    // is filtered by the membership's tenantId.
    final rows = await supabase
        .from('person_attendances')
        .select(
            '*, attendance:attendance_id!inner($kOverviewAttendanceColumns, '
            'attType:type_id($kSignoutAttendanceTypeColumns))')
        .eq('person_id', personId)
        .eq('attendance.tenantId', tenantId)
        .gt('attendance.date', SignInOutRepository.overviewSeasonStart(tenant?['seasonStart']));

    final tenantName = SignInOutRepository.tenantDisplayName(
      tenant?['longName'] as String?,
      tenant?['shortName'] as String?,
    );
    return (rows as List)
        .where((json) => json['attendance'] != null)
        .where((json) => _toInt(json['attendance']['tenantId']) == tenantId)
        .where((json) =>
            showArchived || !isArchivedRow(json['attendance'] as Map<String, dynamic>?))
        // IOS_FORMS2: like Ionic, duty Termine are listed (and count for the
        // average) even when the person was not assigned.
        .map((json) => _fromRows(
              json['attendance'] as Map<String, dynamic>,
              json as Map<String, dynamic>,
              tenantId: tenantId,
              tenantName: tenantName,
              tenantColor: tenantColor,
            ))
        .toList();
  }
}

int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}
