part of 'player_repository.dart';

mixin _PlayerLifecycleMixin on _PlayerRepositoryCore, _PlayerAttendanceSyncMixin {
  /// LOGIC_PEOPLE: Ionic db.addPlayer(player, register, role).
  ///
  /// With [register] and an e-mail the account is registered/linked right
  /// away (registerUser with [role]). When the account already has a player
  /// row in this tenant (e.g. a returning member who left), that row is
  /// reactivated (`left = null`, fields overwritten) instead of inserting a
  /// duplicate. Non-pending persons are added to every Termin since their
  /// join date.
  ///
  /// ASTRA_PHOTO: [imageBytes] is a picture chosen while creating (Ionic keeps
  /// it as a data URL). Like Ionic it is uploaded right after a fresh insert,
  /// before the Termine are filled; a failed upload is only logged and never
  /// loses the created person. A reactivated row gets no upload (Ionic returns
  /// before the upload in that branch).
  Future<Person> addPlayer(
    Person player, {
    required bool register,
    required Role role,
    Uint8List? imageBytes,
  }) async {
    ensureNotDemo('addPlayer'); // DEMO_GUARD
    var person = player;
    final email = player.email?.trim() ?? '';
    if (register && email.isNotEmpty) {
      final appId = await _registration().registerUser(
        email: email,
        name: player.firstName,
        role: role,
      );
      person = person.copyWith(appId: appId);
    }

    Person result;
    final appId = person.appId;
    Map<String, dynamic>? existing;
    if (appId != null && appId.isNotEmpty) {
      existing = await supabase
          .from('player')
          .select('id')
          .eq('appId', appId)
          .eq('tenantId', currentTenantId)
          .limit(1)
          .maybeSingle();
    }

    if (existing != null && existing['id'] != null) {
      try {
        // Ionic reactivates with pickPersonFields (no img): the row keeps
        // its own picture, an adopted one of a cross-tenant match (shared
        // file profiles/<other id>) is not written.
        final data = _personInsertData(person)
          ..remove('id')
          ..remove('img')
          ..['left'] = null;
        final updated = await supabase
            .from('player')
            .update(data)
            .eq('id', existing['id'])
            .eq('tenantId', currentTenantId)
            .select()
            .single();
        result = Person.fromJson(updated);
      } catch (e, stack) {
        handleError(e, stack, 'addPlayer');
        rethrow;
      }
    } else {
      result = await createPlayer(person);
      final resultId = result.id;
      if (imageBytes != null && resultId != null) {
        try {
          final url = await updateImage(resultId, imageBytes);
          result = result.copyWith(img: url);
        } catch (e, stack) {
          // Ionic addPlayer: console.error('Error uploading image', …) only.
          debugPrint('addPlayer: image upload failed: $e\n$stack');
        }
      }
    }

    if (!person.pending) {
      try {
        await addPlayerToAttendancesByDate(result);
      } catch (e) {
        // The person is saved; only the Termine are missing. Callers that
        // retry (import) must not save it a second time.
        throw PersonNotAddedToAttendancesException(result, e);
      }
    }
    return result;
  }


  /// Archive a player (soft delete)
  Future<void> archivePlayer(Person player, String leftDate, String? reason) async {
    ensureNotDemo('archivePlayer'); // DEMO_GUARD
    if (player.id == null) {
      throw RepositoryException(
        message: 'Player ID is required for archive',
        operation: 'archivePlayer',
      );
    }

    try {
      // LOGIC_PEOPLE: Ionic db.archivePlayer — revoke the account's access
      // (tenantUsers, guarded for admins / other linked persons) and clear
      // appId.
      // SOL_FIX1: tied solely to appId (Ionic additionally requires an
      // e-mail, which left the account link + access of persons without
      // e-mail in place after archiving).
      var clearAppId = false;
      final appId = player.appId;
      if (appId != null && appId.isNotEmpty) {
        await removeUserFromTenant(appId, personId: player.id);
        clearAppId = true;
      }

      // Add history entry
      final history = List<Map<String, dynamic>>.from(
        player.history.map((e) => e.toJson()),
      );
      history.add({
        'date': DateTime.now().toUtc().toIso8601String(),
        'text': (reason == null || reason.isEmpty)
            ? 'Kein Grund angegeben'
            : reason,
        'type': PlayerHistoryType.archived.value,
      });

      await supabase
          .from('player')
          .update({
            'left': leftDate,
            'history': history,
            if (clearAppId) 'appId': null,
          })
          .eq('id', player.id!)
          .eq('tenantId', currentTenantId);

      // Ionic removePlayerFromUpcomingAttendances(id, left) →
      // getAttendancesByDate(left): drop the person from every Termin after
      // the local start of the leave day (date > startOf('day'), exclusive).
      await removeFromUpcomingAttendances(
        player.id!,
        from: leftDate,
        inclusive: false,
      );
    } catch (e, stack) {
      handleError(e, stack, 'archivePlayer');
      rethrow;
    }
  }

  /// LOGIC_PEOPLE: Ionic db.removeUserFromTenant — removes the account's
  /// access (tenantUsers row) from the current tenant.
  ///
  /// Without [deleteAdmin] nothing happens when the account is ADMIN here,
  /// and with [personId] access is kept while the same account is still
  /// linked to another active person of this tenant.
  Future<void> removeUserFromTenant(
    String appId, {
    int? personId,
    bool deleteAdmin = false,
  }) async {
    ensureNotDemo('removeUserFromTenant'); // DEMO_GUARD
    try {
      if (deleteAdmin) {
        await supabase
            .from('tenantUsers')
            .delete()
            .eq('tenantId', currentTenantId)
            .eq('role', Role.admin.value)
            .eq('userId', appId);
        return;
      }

      final admin = await supabase
          .from('tenantUsers')
          .select('userId')
          .eq('tenantId', currentTenantId)
          .eq('role', Role.admin.value)
          .eq('userId', appId)
          .limit(1);
      if ((admin as List).isNotEmpty) return;

      if (personId != null) {
        final others = await supabase
            .from('player')
            .select('id')
            .eq('tenantId', currentTenantId)
            .eq('appId', appId)
            .isFilter('left', null)
            .neq('id', personId)
            .limit(1);
        if ((others as List).isNotEmpty) return;
      }

      await supabase
          .from('tenantUsers')
          .delete()
          .eq('tenantId', currentTenantId)
          .eq('userId', appId);
    } catch (e) {
      // Ionic: throw new Error(translate('db.removeFromTenantFailed'))
      throw AccountFlowException(l10nWithoutContext.dbRemoveFromTenantFailed);
    }
  }

  /// Reactivate an archived player
  Future<void> reactivatePlayer(Person player) async {
    ensureNotDemo('reactivatePlayer'); // DEMO_GUARD
    if (player.id == null) {
      throw RepositoryException(
        message: 'Player ID is required for reactivate',
        operation: 'reactivatePlayer',
      );
    }

    // LOGIC_PEOPLE: Ionic db.activatePlayer — (re)create the account when an
    // e-mail is set, history 'Person wieder aktiviert', left = null, then add
    // the person to upcoming Termine (with shift / extra-field filters).
    //
    // SOL_FIX25: a person that kept its account link (e.g. transferred to
    // another tenant: archived here with `appId`) reuses that link when the
    // account still has access to this tenant; registering again would find
    // this very person as a duplicate and abort before `left` is reset.
    var person = player;
    if ((player.email ?? '').trim().isNotEmpty) {
      final linked = await _existingAccountLink(player);
      if (linked == null) {
        final appId = await _registration().createPlayerAccount(
          player,
          mainGroupId: await _mainGroupId(),
        );
        person = person.copyWith(appId: appId);
      }
    }

    try {
      // Add history entry
      final history = List<Map<String, dynamic>>.from(
        player.history.map((e) => e.toJson()),
      );
      history.add({
        'date': DateTime.now().toUtc().toIso8601String(),
        'text': 'Person wieder aktiviert',
        'type': PlayerHistoryType.returned.value,
      });

      await supabase
          .from('player')
          .update({
            'left': null,
            'history': history,
          })
          .eq('id', player.id!)
          .eq('tenantId', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'reactivatePlayer');
      rethrow;
    }

    await addToUpcomingAttendances(person);
  }

  /// SOL_FIX25: [player]'s `appId` when that account still has access to
  /// this tenant (`tenantUsers` row), otherwise null.
  Future<String?> _existingAccountLink(Person player) async {
    final appId = player.appId;
    if (appId == null || appId.isEmpty) return null;
    try {
      final rows = await supabase
          .from('tenantUsers')
          .select('userId')
          .eq('tenantId', currentTenantId)
          .eq('userId', appId)
          .limit(1);
      return (rows as List).isNotEmpty ? appId : null;
    } catch (e, stack) {
      handleError(e, stack, '_existingAccountLink');
      rethrow;
    }
  }

  /// Delete a player permanently.
  ///
  /// LOGIC_PEOPLE: Ionic db.removePlayer — afterwards the account's access
  /// to this tenant is removed (guarded like [removeUserFromTenant]).
  Future<void> deletePlayer(int playerId, {String? appId}) async {
    ensureNotDemo('deletePlayer'); // DEMO_GUARD
    try {
      await supabase
          .from('player')
          .delete()
          .eq('id', playerId)
          .eq('tenantId', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'deletePlayer');
      rethrow;
    }
    if (appId != null && appId.isNotEmpty) {
      await removeUserFromTenant(appId, personId: playerId);
    }
  }

  /// Pause a player.
  ///
  /// [pauseFrom] (YYYY-MM-DD, optional, Ionic "Pausiert ab"): when set, the
  /// player is removed from every attendance on/after that date — including
  /// past ones — instead of only from upcoming attendances.
  /// Returns the updated history (reused for pausing in other tenants).
  Future<List<Map<String, dynamic>>> pausePlayer(
    Person player,
    String? pausedUntil,
    String reason, {
    String? pauseFrom,
  }) async {
    ensureNotDemo('pausePlayer'); // DEMO_GUARD
    if (player.id == null) {
      throw RepositoryException(
        message: 'Player ID is required for pause',
        operation: 'pausePlayer',
      );
    }

    try {
      // Add history entry
      final history = List<Map<String, dynamic>>.from(
        player.history.map((e) => e.toJson()),
      );
      history.add({
        'date': DateTime.now().toUtc().toIso8601String(),
        'text': reason,
        'type': PlayerHistoryType.paused.value,
      });

      await supabase
          .from('player')
          .update({
            'paused': true,
            'paused_until': pausedUntil,
            'history': history,
          })
          .eq('id', player.id!)
          .eq('tenantId', currentTenantId);

      // Remove from upcoming attendances (or from all since pauseFrom)
      await removeFromUpcomingAttendances(player.id!, from: pauseFrom);
      return history;
    } catch (e, stack) {
      handleError(e, stack, 'pausePlayer');
      rethrow;
    }
  }

  /// Unpause a player
  Future<void> unpausePlayer(Person player, {String historyText = 'Pause beendet'}) async {
    ensureNotDemo('unpausePlayer'); // DEMO_GUARD
    if (player.id == null) {
      throw RepositoryException(
        message: 'Player ID is required for unpause',
        operation: 'unpausePlayer',
      );
    }

    try {
      // Ionic 4.19.13: add to upcoming attendances BEFORE clearing paused,
      // so a failed backfill keeps the person paused instead of missing from
      // upcoming Termine.
      await addToUpcomingAttendances(player);

      // Add history entry
      final history = List<Map<String, dynamic>>.from(
        player.history.map((e) => e.toJson()),
      );
      history.add({
        'date': DateTime.now().toUtc().toIso8601String(),
        'text': historyText,
        'type': PlayerHistoryType.unpaused.value,
      });

      await supabase
          .from('player')
          .update({
            'paused': false,
            'paused_until': null,
            'history': history,
          })
          .eq('id', player.id!)
          .eq('tenantId', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'unpausePlayer');
      rethrow;
    }
  }


  /// Aushilfen whose last day ("dabei bis") has passed are archived with
  /// that day as leave date (no cron: runs when the member list opens, like
  /// [checkAndUnpausePlayers]). Returns how many were archived.
  Future<int> archiveExpiredHelpers() async {
    if (!hasTenantId) return 0;
    var archived = 0;
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final rows = await supabase
          .from('player')
          .select('*')
          .eq('tenantId', currentTenantId)
          .isFilter('left', null)
          .not('additional_fields->>$helperUntilKey', 'is', null)
          .lt('additional_fields->>$helperUntilKey', today);
      for (final row in rows as List) {
        ensureNotDemo('archiveExpiredHelpers'); // DEMO_GUARD
        final player = Person.fromJson(row as Map<String, dynamic>);
        final until = helperUntil(player);
        if (player.id == null || until == null || until.compareTo(today) >= 0) continue;
        // Left the day after the last day: archivePlayer keeps every Termin
        // up to the end of the last day and drops the later ones.
        final lastDay = DateTime.parse(until);
        final leftDay = helperDay(DateTime(lastDay.year, lastDay.month, lastDay.day + 1));
        await archivePlayer(player, leftDay, 'Aushilfe beendet (dabei bis erreicht)');
        archived++;
      }
    } catch (e, stack) {
      if (e is DemoModeException) rethrow;
      // Background check: the next opening tries again.
      ErrorReporter.report(e, stack, where: 'PlayerRepository.archiveExpiredHelpers');
    }
    return archived;
  }

  /// Check for players whose pause period has ended and unpause them
  Future<void> checkAndUnpausePlayers() async {
    // Skip if tenant is not set yet
    if (!hasTenantId) return;

    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);

      // Get players where paused_until has passed
      final pausedPlayers = await supabase
          .from('player')
          .select('*')
          .eq('tenantId', currentTenantId)
          .eq('paused', true)
          .not('paused_until', 'is', null)
          .lte('paused_until', today);

      for (final playerData in pausedPlayers as List) {
        // Ionic unpauses via updatePlayer → checkDemoRestriction(): demo
        // toast, nothing written (the DemoModeException reaches the caller).
        ensureNotDemo('checkAndUnpausePlayers'); // DEMO_GUARD
        final player = Person.fromJson(playerData as Map<String, dynamic>);

        try {
          // Ionic 4.19.13: add to upcoming attendances BEFORE clearing paused,
          // so a failure keeps the player paused and retries on the next open.
          await addToUpcomingAttendances(player);

          // Add history entry
          final history = List<Map<String, dynamic>>.from(
            player.history.map((e) => e.toJson()),
          );
          history.add({
            'date': DateTime.now().toUtc().toIso8601String(),
            'text': 'Automatisch reaktiviert (Pausendatum erreicht)',
            'type': PlayerHistoryType.unpaused.value,
          });

          // Update player
          await supabase
              .from('player')
              .update({
                'paused': false,
                'paused_until': null,
                'history': history,
              })
              .eq('id', player.id!)
              .eq('tenantId', currentTenantId);
        } catch (e, stack) {
          if (e is DemoModeException) rethrow;
          if (kDebugMode) {
            debugPrint(
              '[PlayerRepository] Error in checkAndUnpausePlayers for player ${player.id}: $e',
            );
          }
          ErrorReporter.report(
            e,
            stack,
            where: 'PlayerRepository.checkAndUnpausePlayers',
          );
        }
      }
    } catch (e, stack) {
      // Only the demo error reaches the caller (demo toast).
      if (e is DemoModeException) rethrow;
      // Don't rethrow anything else - this runs in the background.
      if (kDebugMode) {
        debugPrint('[PlayerRepository] Error in checkAndUnpausePlayers: $e');
      }
      ErrorReporter.report(
        e,
        stack,
        where: 'PlayerRepository.checkAndUnpausePlayers',
      );
    }
  }

  /// Approve a pending player. [extra]: further columns written in the
  /// same update (parent registration: `parent_id`, marker removed).
  /// [onApproved] runs right after the person left Freigaben, before the
  /// attendances are filled (a failure there must not skip it).
  Future<void> approvePlayer(
    Person player, {
    Map<String, dynamic> extra = const {},
    Future<void> Function()? onApproved,
  }) async {
    ensureNotDemo('approvePlayer'); // DEMO_GUARD
    if (player.id == null) {
      throw RepositoryException(
        message: 'Player ID is required',
        operation: 'approvePlayer',
      );
    }

    try {
      final history = List<Map<String, dynamic>>.from(
        player.history.map((e) => e.toJson()),
      );
      history.add({
        'date': DateTime.now().toUtc().toIso8601String(),
        // LOGIC_PEOPLE: Ionic history text incl. the approver.
        'text': 'Person genehmigt von ${_actorEmail()}',
        'type': PlayerHistoryType.approved.value,
      });

      await supabase
          .from('player')
          .update({
            ...extra,
            'pending': false,
            'history': history,
          })
          .eq('id', player.id!)
          .eq('tenantId', currentTenantId);

      await onApproved?.call();

      // LOGIC_PEOPLE: Ionic approvePlayer → addPlayerToAttendancesByDate
      // (every Termin since the join date, with group / extra-field filters).
      await addPlayerToAttendancesByDate(player);
    } catch (e, stack) {
      handleError(e, stack, 'approvePlayer');
      rethrow;
    }
  }

  /// Parent registration: whether another child of the account [parentAppId]
  /// still waits in Freigaben of the current tenant.
  Future<bool> hasPendingChildOf(String parentAppId, {int? exceptId}) async {
    try {
      var query = supabase
          .from('player')
          .select('id')
          .eq('tenantId', currentTenantId)
          .eq('pending', true)
          .isFilter('left', null)
          .eq('additional_fields->$kParentRegistrationKey->>appId', parentAppId);
      if (exceptId != null) query = query.neq('id', exceptId);
      final rows = await query.limit(1);
      return (rows as List).isNotEmpty;
    } catch (e, stack) {
      handleError(e, stack, 'hasPendingChildOf');
      rethrow;
    }
  }

  /// Decline a pending player - archives them with a reason
  Future<void> declinePlayer(Person player, String reason) async {
    ensureNotDemo('declinePlayer'); // DEMO_GUARD
    if (player.id == null) {
      throw RepositoryException(
        message: 'Player ID is required',
        operation: 'declinePlayer',
      );
    }

    try {
      final history = List<Map<String, dynamic>>.from(
        player.history.map((e) => e.toJson()),
      );
      history.add({
        'date': DateTime.now().toUtc().toIso8601String(),
        // LOGIC_PEOPLE: Ionic history text incl. decliner and reason.
        'text': 'Person abgelehnt von ${_actorEmail()}: $reason',
        'type': PlayerHistoryType.declined.value,
      });

      await supabase
          .from('player')
          .update({
            'pending': false,
            'left': DateTime.now().toUtc().toIso8601String(),
            'history': history,
          })
          .eq('id', player.id!)
          .eq('tenantId', currentTenantId);

      // Ionic removeUserFromTenant(appId, false, id): keeps admins and
      // accounts still linked to another active person.
      if (player.appId != null && player.appId!.isNotEmpty) {
        await removeUserFromTenant(player.appId!, personId: player.id);
      }
    } catch (e, stack) {
      handleError(e, stack, 'declinePlayer');
      rethrow;
    }
  }
}
