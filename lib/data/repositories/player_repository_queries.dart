part of 'player_repository.dart';

mixin _PlayerQueriesMixin on _PlayerRepositoryCore, _PlayerAttendanceSyncMixin, _PlayerLifecycleMixin {
  /// Update player's instrument
  Future<void> updatePlayerInstrument(
    Person player,
    int newInstrumentId,
    String? reason,
  ) async {
    ensureNotDemo('updatePlayerInstrument'); // DEMO_GUARD
    if (player.id == null) {
      throw RepositoryException(
        message: 'Player ID is required',
        operation: 'updatePlayerInstrument',
      );
    }

    try {
      // Add history entry
      final history = List<Map<String, dynamic>>.from(
        player.history.map((e) => e.toJson()),
      );
      history.add({
        'date': DateTime.now().toUtc().toIso8601String(),
        'text': reason ?? 'Instrument gewechselt',
        'type': PlayerHistoryType.instrumentChange.value,
      });

      await supabase
          .from('player')
          .update({
            'instrument': newInstrumentId,
            'history': history,
          })
          .eq('id', player.id!)
          .eq('tenantId', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'updatePlayerInstrument');
      rethrow;
    }
  }

  /// Search players by name
  Future<List<Person>> searchPlayers(String query) async {
    try {
      // SEC-003: Sanitize search input to prevent SQL wildcard injection
      final sanitizedQuery = sanitizeSearchQuery(query);
      final response = await supabase
          .from('player')
          .select('*')
          .eq('tenantId', currentTenantId)
          .isFilter('pending', false)
          .isFilter('left', null)
          .or('firstName.ilike.%$sanitizedQuery%,lastName.ilike.%$sanitizedQuery%')
          .order('lastName', ascending: true)
          .limit(20);

      return (response as List)
          .map((e) => Person.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'searchPlayers');
      rethrow;
    }
  }

  /// Get player count by instrument
  Future<Map<int, int>> getPlayerCountByInstrument() async {
    try {
      final response = await supabase
          .from('player')
          .select('instrument, paused')
          .eq('tenantId', currentTenantId)
          .isFilter('pending', false)
          .isFilter('left', null);

      // Ionic getPlayerCountByGroup: active people only (not left, not paused)
      final counts = <int, int>{};
      for (final row in response as List) {
        if (row['paused'] == true) continue;
        final instrument = row['instrument'] as int?;
        if (instrument != null) {
          counts[instrument] = (counts[instrument] ?? 0) + 1;
        }
      }
      return counts;
    } catch (e, stack) {
      handleError(e, stack, 'getPlayerCountByInstrument');
      rethrow;
    }
  }

  /// Get critical players
  Future<List<Person>> getCriticalPlayers() async {
    try {
      final response = await supabase
          .from('player')
          .select('*')
          .eq('tenantId', currentTenantId)
          .eq('isCritical', true)
          .isFilter('pending', false)
          .isFilter('left', null)
          .order('lastName', ascending: true);

      return (response as List)
          .map((e) => Person.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getCriticalPlayers');
      rethrow;
    }
  }

  /// Reset late count for a player (mark as resolved after conversation)
  Future<Person> resetLateCount(Person player) async {
    ensureNotDemo('resetLateCount'); // DEMO_GUARD
    if (player.id == null) {
      throw RepositoryException(
        message: 'Player ID is required for resetLateCount',
        operation: 'resetLateCount',
      );
    }

    try {
      // LOGIC_PEOPLE: Ionic person.page resetLateCount only sets lastSolve
      // (no history entry).
      final response = await supabase
          .from('player')
          .update({
            'lastSolve': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', player.id!)
          .eq('tenantId', currentTenantId)
          .select()
          .single();

      return Person.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'resetLateCount');
      rethrow;
    }
  }

  /// Resolve critical status for a player
  Future<Person> resolveCritical(Person player, String? notes) async {
    ensureNotDemo('resolveCritical'); // DEMO_GUARD
    if (player.id == null) {
      throw RepositoryException(
        message: 'Player ID is required for resolveCritical',
        operation: 'resolveCritical',
      );
    }

    try {
      // Add history entry
      final history = List<Map<String, dynamic>>.from(
        player.history.map((e) => e.toJson()),
      );
      history.add({
        'date': DateTime.now().toUtc().toIso8601String(),
        // LOGIC_PEOPLE: Ionic pushes `this.notes` as is (may be empty).
        'text': notes ?? '',
        'type': PlayerHistoryType.criticalPerson.value,
      });

      final response = await supabase
          .from('player')
          .update({
            'isCritical': false,
            'lastSolve': DateTime.now().toUtc().toIso8601String(),
            // Ionic keeps criticalReason untouched.
            'history': history,
          })
          .eq('id', player.id!)
          .eq('tenantId', currentTenantId)
          .select()
          .single();

      return Person.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'resolveCritical');
      rethrow;
    }
  }

  /// Link an existing account to a player
  Future<Person> linkAccount(Person player, String appId) async {
    ensureNotDemo('linkAccount'); // DEMO_GUARD
    if (player.id == null) {
      throw RepositoryException(
        message: 'Player ID is required for linkAccount',
        operation: 'linkAccount',
      );
    }

    try {
      final response = await supabase
          .from('player')
          .update({'appId': appId})
          .eq('id', player.id!)
          .eq('tenantId', currentTenantId)
          .select()
          .single();

      return Person.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'linkAccount');
      rethrow;
    }
  }

  /// Unlink account from a player
  Future<Person> unlinkAccount(Person player) async {
    ensureNotDemo('unlinkAccount'); // DEMO_GUARD
    if (player.id == null) {
      throw RepositoryException(
        message: 'Player ID is required for unlinkAccount',
        operation: 'unlinkAccount',
      );
    }

    // LOGIC_PEOPLE: Ionic person.page removeUserFromTenant →
    // db.removeUserFromTenant(appId, false, id) (keeps admins / accounts
    // linked to another active person) and then clears email AND appId.
    final appId = player.appId;
    if (appId != null && appId.isNotEmpty) {
      await removeUserFromTenant(appId, personId: player.id);
    }

    try {
      final response = await supabase
          .from('player')
          .update({'appId': null, 'email': null})
          .eq('id', player.id!)
          .eq('tenantId', currentTenantId)
          .select()
          .single();

      return Person.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'unlinkAccount');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------
  // Person detail page (moved from the page, #7 repository bundling)
  // ---------------------------------------------------------------------

  /// person_attendances of [personId] with the fields the attendance
  /// statistics need. Tenant filter via the inner-joined attendance
  /// (person_attendances has no tenantId column).
  Future<List<Map<String, dynamic>>> getPersonAttendanceStatsRows(int personId) async {
    try {
      final response = await fetchAllPages<Map<String, dynamic>>((from, to) async => await supabase
          .from('person_attendances')
          .select('status, notes, duty_state, '
              'attendance:attendance_id!inner(id, date, tenantId, archived, '
              'attType:type_id(include_in_average, duty_mode))')
          .eq('person_id', personId)
          .eq('attendance.tenantId', currentTenantId)
          .order('id', ascending: true)
          .range(from, to));
      // Ionic 4.17.24 getPersonAttendances: archived only for admins/responsible.
      final showArchived = canSeeArchivedAttendances(currentUserRole);
      return response
          .where((row) =>
              showArchived || !isArchivedRow(row['attendance'] as Map<String, dynamic>?))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getPersonAttendanceStatsRows');
      rethrow;
    }
  }

  /// person_attendances of [personId] with their Termin, for the history.
  /// [fromDate] (`yyyy-MM-dd`) keeps only Termine on or after that day.
  Future<List<Map<String, dynamic>>> getPersonAttendanceHistoryRows(int personId,
      {String? fromDate}) async {
    try {
      final response = await fetchAllPages<Map<String, dynamic>>((from, to) async {
        var query = supabase
            .from('person_attendances')
            .select('*, attendance:attendance_id!inner(id, date, type, typeInfo, type_id, tenantId, archived)')
            .eq('person_id', personId)
            .eq('attendance.tenantId', currentTenantId);
        if (fromDate != null) query = query.gte('attendance.date', fromDate);
        return await query.order('id', ascending: true).range(from, to);
      });
      final showArchived = canSeeArchivedAttendances(currentUserRole);
      return response
          .where((row) =>
              showArchived || !isArchivedRow(row['attendance'] as Map<String, dynamic>?))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getPersonAttendanceHistoryRows');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------
  // PEOPLE2: reorder, duplicate detection and merge (Ionic person/list page)
  // ---------------------------------------------------------------------

  /// Persist the manual order of players inside their group
  /// (Ionic list.page savePlayerOrder). [orders] maps player id → sort_order.
  Future<void> savePlayerOrder(Map<int, int> orders) async {
    ensureNotDemo('savePlayerOrder'); // DEMO_GUARD
    try {
      for (final entry in orders.entries) {
        await supabase
            .from('player')
            .update({'sort_order': entry.value})
            .eq('id', entry.key)
            .eq('tenantId', currentTenantId);
      }
    } catch (e, stack) {
      handleError(e, stack, 'savePlayerOrder');
      rethrow;
    }
  }

  /// Same-tenant, account-less, confirmed players with a similar name —
  /// candidates for merging a pending registration into
  /// (Ionic player.service getPossibleDuplicatesInTenant).
  Future<List<RankedMatch<Person>>> getPossibleDuplicatesInTenant(
    String firstName,
    String lastName, {
    required int excludeId,
  }) async {
    String clean(String v) {
      final c = v.replaceAll(RegExp(r'[,*%():\\]+'), '').trim();
      return c.length > 50 ? c.substring(0, 50) : c;
    }

    final safeFirst = clean(firstName);
    final safeLast = clean(lastName);
    if (safeFirst.isEmpty && safeLast.isEmpty) return [];
    final orParts = <String>[
      if (safeFirst.isNotEmpty) 'firstName.ilike.$safeFirst%',
      if (safeLast.isNotEmpty) 'lastName.ilike.$safeLast%',
    ];

    try {
      final response = await supabase
          .from('player')
          .select('*')
          .eq('tenantId', currentTenantId)
          .eq('pending', false)
          .isFilter('appId', null)
          .neq('id', excludeId)
          .or(orParts.join(','))
          .limit(500);

      final candidates = (response as List)
          .map((e) => Person.fromJson(e as Map<String, dynamic>))
          .toList();
      return rankCandidates<Person>(
        PersonLike(firstName: firstName, lastName: lastName),
        candidates,
        (p) => PersonLike(
          firstName: p.firstName,
          lastName: p.lastName,
          email: p.email,
          appId: p.appId,
          globalPersonId: p.globalPersonId,
          birthday: p.birthday,
        ),
        threshold: 0.65,
      );
    } catch (e, stack) {
      handleError(e, stack, 'getPossibleDuplicatesInTenant');
      rethrow;
    }
  }

  /// Merge a pending self-registration into an existing account-less person
  /// (Ionic db.service mergePendingPlayerIntoExisting): attendance and
  /// absence history move onto [target] (target wins on conflicts), the
  /// applicant's account is adopted and the pending row is deleted.
  Future<void> mergePendingPlayerIntoExisting(
    Person pending,
    Person target, {
    required String approverEmail,
  }) async {
    final pendingId = pending.id;
    final targetId = target.id;
    if (pendingId == null || targetId == null) {
      throw RepositoryException(
        message: 'Player IDs are required for merge',
        operation: 'mergePendingPlayerIntoExisting',
      );
    }

    try {
      // Both rows must belong to the current tenant (person_attendances has
      // no tenant column, so verify ownership before re-pointing rows).
      final owned = await supabase
          .from('player')
          .select('id')
          .inFilter('id', [pendingId, targetId])
          .eq('tenantId', currentTenantId);
      if ((owned as List).length != 2) {
        throw RepositoryException(
          message: l10nWithoutContext.coreFlutterRepoPersonsNotInTenant,
          operation: 'mergePendingPlayerIntoExisting',
        );
      }

      await _reassignPersonAttendances(pendingId, targetId);

      // player_absences uses snake_case tenant_id
      await supabase
          .from('player_absences')
          .update({'person_id': targetId})
          .eq('person_id', pendingId)
          .eq('tenant_id', currentTenantId);

      // SOL_FIX7: abort (keep the pending person) unless every row moved.
      await _ensureNothingLeftToTransfer(
          pendingId, 'mergePendingPlayerIntoExisting');

      final history = [
        ...target.history.map((e) => e.toJson()),
        {
          'date': DateTime.now().toUtc().toIso8601String(),
          'text': 'Zusammengeführt mit Registrierung von '
              '${pending.firstName} ${pending.lastName} '
              '(genehmigt von $approverEmail)',
          'type': PlayerHistoryType.approved.value,
        },
      ];

      await supabase
          .from('player')
          .update({
            'appId': pending.appId,
            'email': target.email ?? pending.email,
            'self_register': true,
            'history': history,
            'pending': false,
          })
          .eq('id', targetId)
          .eq('tenantId', currentTenantId);

      // Ionic mergePendingPlayerIntoExisting: updateTenantUser({role:
      // PLAYER}) and the approval mail with PLAYER, whatever the group (like
      // approvePlayer; a main-group person gets no RESPONSIBLE rights here).
      const role = Role.player;

      if (pending.appId != null) {
        await supabase
            .from('tenantUsers')
            .update({'role': role.value})
            .eq('userId', pending.appId!)
            .eq('tenantId', currentTenantId);
      }

      // Best-effort: notification + attendance backfill must not block cleanup
      final email = target.email ?? pending.email;
      if (email != null && email.isNotEmpty) {
        try {
          await supabase.functions.invoke('attendix-user', body: {
            'action': 'approve',
            'email': email,
            'name': target.firstName,
            'role': UserRegistrationRepository.roleText(role),
            'roleId': role.value,
            'tenantId': currentTenantId,
          });
        } catch (e, st) {
          ErrorReporter.report(e, st, where: 'player_repository');
        }
      }
      // A paused person is not added to upcoming attendances.
      if (!target.paused) {
        try {
          await addToUpcomingAttendances(target);
        } catch (e, st) {
          ErrorReporter.report(e, st, where: 'player_repository');
        }
      }

      await supabase
          .from('player')
          .delete()
          .eq('id', pendingId)
          .eq('tenantId', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'mergePendingPlayerIntoExisting');
      rethrow;
    }
  }

  /// SOL_FIX7: the source person of a merge may only be deleted when every
  /// attendance and absence row was transferred; anything left would be
  /// lost with it (or block the delete). Throws to abort the merge.
  Future<void> _ensureNothingLeftToTransfer(int fromId, String operation) async {
    final leftAttendances = await supabase
        .from('person_attendances')
        .select('id')
        .eq('person_id', fromId)
        .limit(1);
    // player_absences uses snake_case tenant_id
    final leftAbsences = await supabase
        .from('player_absences')
        .select('id')
        .eq('person_id', fromId)
        .eq('tenant_id', currentTenantId)
        .limit(1);
    if ((leftAttendances as List).isNotEmpty || (leftAbsences as List).isNotEmpty) {
      throw RepositoryException(
        message: l10nWithoutContext.svcTransferPersonAttendancesFailed,
        operation: operation,
      );
    }
  }
}
