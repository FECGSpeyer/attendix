part of 'player_repository.dart';

const String _handoverPrefix = 'Übergabe an "';
const String _handoverDeclined = '" wurde abgelehnt: ';
const String _handoverKeeps = 'bleibt auch hier aktiv';
const String _handoverMoves = 'wechselt ganz';
final RegExp _handoverAsked =
    RegExp('^${RegExp.escape(_handoverPrefix)}(.*)" angefragt \\(($_handoverKeeps|$_handoverMoves)\\)\\.\$');
final RegExp _handoverDone = RegExp(r'^Person wurde zu "(.*)" (?:kopiert|übertragen)\.$');


mixin _PlayerHandoverMixin on _PlayerRepositoryCore, _PlayerAttendanceSyncMixin {
  // ============= HANDOVER METHODS =============

  /// Check if a player already exists in the target tenant.
  ///
  /// LOGIC_PEOPLE: Ionic db.personExistsInTenant — e-mail (ilike, trimmed),
  /// then first + last name (ilike) as fallback.
  Future<bool> playerExistsInTenant(Person player, int targetTenantId) async {
    try {
      final email = normalizeEmailForMatch(player.email);
      if (email != null) {
        final byEmail = await supabase
            .from('player')
            .select('id')
            .eq('tenantId', targetTenantId)
            .ilike('email', escapeLikePattern(email))
            .limit(1);
        if ((byEmail as List).isNotEmpty) return true;
      }

      final firstName = player.firstName.trim();
      final lastName = player.lastName.trim();
      if (firstName.isEmpty && lastName.isEmpty) return false;

      final byName = await supabase
          .from('player')
          .select('id')
          .eq('tenantId', targetTenantId)
          .ilike('firstName', escapeLikePattern(firstName))
          .ilike('lastName', escapeLikePattern(lastName))
          .limit(1);
      return (byName as List).isNotEmpty;
    } catch (e, stack) {
      handleError(e, stack, 'playerExistsInTenant');
      rethrow;
    }
  }

  /// Groups of a handover target tenant (cross-tenant read by design, the
  /// query is scoped to the explicit target tenantId). Ionic db.getGroups
  /// order: category, sort_order (nulls last), name – the first group is
  /// the default mapping.
  Future<List<Group>> getTargetTenantGroups(int targetTenantId) async {
    try {
      final response = await supabase
          .from('instruments')
          .select('*')
          .eq('tenantId', targetTenantId)
          .order('category', ascending: true)
          .order('sort_order', ascending: true, nullsFirst: false)
          .order('name', ascending: true);
      return (response as List)
          .map((e) => Group.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getTargetTenantGroups');
      rethrow;
    }
  }

  /// Handover a single player to another tenant
  ///
  /// [player] - The player to transfer
  /// [targetTenantId] - The target tenant ID
  /// [targetGroupId] - The mapped group/instrument ID in the target tenant
  /// [targetTenantName] - Name of target tenant for history entry
  /// [sourceTenantName] - Name of source tenant for history entry
  /// [stayInInstance] - If true, copies player (COPIED_FROM/TO), otherwise transfers (TRANSFERRED_FROM/TO)
  /// [responsibleForMainGroup] - false for the person page (Ionic: always
  ///   PLAYER); the handover page keeps RESPONSIBLE for the main group.
  /// [asRequest] - the caller is no lead of the target group: the person
  ///   only waits in the target's Freigaben (see `handover_request.dart`);
  ///   account, mail, attendances and the source's `left` follow when a
  ///   lead there approves ([completeHandoverAtSource]).
  ///
  /// LOGIC_PEOPLE: Ionic db.handoverPerson — the target person is created
  /// FIRST (account linked/registered in the target instance with
  /// RESPONSIBLE for the target main group, else PLAYER; an existing row of
  /// the same account is reactivated; attendances since today are
  /// backfilled). Only then is the source updated (history; on transfer
  /// `left`), so a failed insert never archives the source. The source keeps
  /// its appId like in Ionic.
  ///
  /// Returns [HandoverResult.success], [HandoverResult.duplicate] or
  /// [HandoverResult.error].
  Future<HandoverResult> handoverPlayer({
    required Person player,
    required int targetTenantId,
    required int? targetGroupId,
    required String targetTenantName,
    required String sourceTenantName,
    required bool stayInInstance,
    bool responsibleForMainGroup = true,
    bool asRequest = false,
  }) async {
    ensureNotDemo('handoverPlayer'); // DEMO_GUARD
    if (player.id == null) {
      throw RepositoryException(
        message: 'Player ID is required for handover',
        operation: 'handoverPlayer',
      );
    }

    try {
      // Check for duplicates
      final exists = await playerExistsInTenant(player, targetTenantId);
      if (exists) {
        return HandoverResult.duplicate;
      }

      final now = DateTime.now();
      final nowIso = now.toUtc().toIso8601String();
      final todayUtc =
          DateTime.utc(now.year, now.month, now.day).toIso8601String();

      // 1. Create the person in the target tenant (Ionic addPlayer).
      final targetHistory = <Map<String, dynamic>>[
        {
          'date': nowIso,
          'text':
              'Person wurde von der Instanz "$sourceTenantName" übertragen.',
          'type': (stayInInstance
                  ? PlayerHistoryType.copiedFrom
                  : PlayerHistoryType.transferredFrom)
              .value,
        },
      ];

      if (asRequest) {
        // The account already has a (maybe archived) person there: the
        // target's leads reactivate that one instead of a second row.
        final account = player.appId ?? '';
        if (account.isNotEmpty) {
          final sameAccount = await supabase
              .from('player')
              .select('id')
              .eq('appId', account)
              .eq('tenantId', targetTenantId)
              .limit(1);
          if ((sameAccount as List).isNotEmpty) return HandoverResult.duplicate;
        }
        await _requestHandover(
          player: player,
          targetTenantId: targetTenantId,
          targetGroupId: targetGroupId,
          targetTenantName: targetTenantName,
          sourceTenantName: sourceTenantName,
          stayInInstance: stayInInstance,
          targetHistory: targetHistory,
          nowIso: nowIso,
          todayUtc: todayUtc,
        );
        return HandoverResult.requested;
      }

      String? appId = player.appId;
      final email = player.email?.trim() ?? '';
      if (email.isNotEmpty) {
        final targetMainGroup = responsibleForMainGroup
            ? await _mainGroupId(tenantId: targetTenantId)
            : null;
        final role = responsibleForMainGroup &&
                targetGroupId != null &&
                targetGroupId == targetMainGroup
            ? Role.responsible
            : Role.player;
        appId = await _registration().registerUser(
          email: email,
          name: player.firstName,
          role: role,
          tenantId: targetTenantId,
        );
      }

      final img = (player.img ?? '').isNotEmpty &&
              !(player.img!.startsWith('data:'))
          ? player.img
          : kDefaultPersonImage;

      final newPlayerData = <String, dynamic>{
        'tenantId': targetTenantId,
        'firstName': player.firstName,
        'lastName': player.lastName,
        'instrument': targetGroupId,
        'img': img,
        'joined': todayUtc,
        'email': player.email,
        'appId': appId,
        'hasTeacher': player.hasTeacher,
        'teacher': player.teacher,
        'playsSince': player.playsSince,
        'correctBirthday': player.correctBirthday,
        'birthday': player.birthday,
        'isLeader': false,
        'isCritical': false,
        'notes': player.notes,
        'history': targetHistory,
        'pending': false,
        'self_register': false,
      };

      Map<String, dynamic>? existingRow;
      if (appId != null && appId.isNotEmpty) {
        existingRow = await supabase
            .from('player')
            .select('id')
            .eq('appId', appId)
            .eq('tenantId', targetTenantId)
            .limit(1)
            .maybeSingle();
      }

      final Map<String, dynamic> created;
      if (existingRow != null && existingRow['id'] != null) {
        // Ionic: reactivate the previous row of this account.
        created = await supabase
            .from('player')
            .update({...newPlayerData, 'left': null})
            .eq('id', existingRow['id'])
            .eq('tenantId', targetTenantId)
            .select()
            .single();
      } else {
        // DB_FIX: Ionic copy/transfer → addPlayer sets the id (Utils.getId)
        newPlayerData['id'] = generateIonicId();
        created = await supabase
            .from('player')
            .insert(newPlayerData)
            .select()
            .single();
      }

      final createdPerson = Person.fromJson(created);
      await addPlayerToAttendancesByDate(createdPerson,
          tenantId: targetTenantId);

      // Ionic 4.19.3: the new row gets its own copy of the profile picture.
      if (createdPerson.id != null) {
        try {
          await copyProfileImage(player.img, createdPerson.id!,
              targetTenantId: targetTenantId);
        } catch (e) {
          debugPrint('handoverPlayer: copying profile image failed: $e');
        }
      }

      // 2. Update the source (history; transfer also sets `left`).
      final sourceHistory = List<Map<String, dynamic>>.from(
        player.history.map((e) => e.toJson()),
      );
      sourceHistory.add({
        'date': nowIso,
        'text': stayInInstance
            ? 'Person wurde zu "$targetTenantName" kopiert.'
            : 'Person wurde zu "$targetTenantName" übertragen.',
        'type': (stayInInstance
                ? PlayerHistoryType.copiedTo
                : PlayerHistoryType.transferredTo)
            .value,
      });

      await supabase
          .from('player')
          .update({
            'history': sourceHistory,
            if (!stayInInstance) 'left': nowIso,
          })
          .eq('id', player.id!)
          .eq('tenantId', currentTenantId);

      return HandoverResult.success;
    } catch (e) {
      if (e is DemoModeException) rethrow;
      debugPrint('handoverPlayer failed: $e');
      return HandoverResult.error;
    }
  }

  /// Handover as a request: the waiting row in the target group (pending,
  /// without account; `self_register` so the target's leads get the usual
  /// "wartet auf Freigabe" notification) and a note in the source history.
  /// Cross-tenant by design, scoped to the explicit [targetTenantId].
  Future<void> _requestHandover({
    required Person player,
    required int targetTenantId,
    required int? targetGroupId,
    required String targetTenantName,
    required String sourceTenantName,
    required bool stayInInstance,
    required List<Map<String, dynamic>> targetHistory,
    required String nowIso,
    required String todayUtc,
  }) async {
    final request = HandoverRequest(
      fromTenantId: currentTenantId,
      fromTenantName: sourceTenantName,
      fromPersonId: player.id!,
      keep: stayInInstance,
      by: _actorEmail(),
    );
    final img = (player.img ?? '').isNotEmpty && !(player.img!.startsWith('data:'))
        ? player.img
        : kDefaultPersonImage;

    // The note in the own person's history comes FIRST: the answer of the
    // target group only acts on a source person that carries it.
    final oldHistory = List<Map<String, dynamic>>.from(player.history.map((e) => e.toJson()));
    await supabase
        .from('player')
        .update({
          'history': [
            ...oldHistory,
            {
              'date': nowIso,
              'text': PlayerRepository.handoverAskedNote(targetTenantName, keep: stayInInstance),
              'type': PlayerHistoryType.other.value,
            },
          ],
        })
        .eq('id', player.id!)
        .eq('tenantId', currentTenantId);

    try {
      await _insertHandoverRequest(
        request: request,
        player: player,
        targetTenantId: targetTenantId,
        targetGroupId: targetGroupId,
        img: img,
        todayUtc: todayUtc,
        targetHistory: targetHistory,
      );
    } catch (_) {
      // Nothing waits there: the note goes again (best effort).
      try {
        await supabase
            .from('player')
            .update({'history': oldHistory})
            .eq('id', player.id!)
            .eq('tenantId', currentTenantId);
      } catch (e) {
        debugPrint('requestHandover: taking the note back failed: $e');
      }
      rethrow;
    }
  }

  Future<void> _insertHandoverRequest({
    required HandoverRequest request,
    required Person player,
    required int targetTenantId,
    required int? targetGroupId,
    required String? img,
    required String todayUtc,
    required List<Map<String, dynamic>> targetHistory,
  }) async {
    await supabase.from('player').insert({
      'id': generateIonicId(),
      'tenantId': targetTenantId,
      'firstName': player.firstName,
      'lastName': player.lastName,
      'instrument': targetGroupId,
      'img': img,
      'joined': todayUtc,
      'email': player.email,
      'appId': null,
      'hasTeacher': player.hasTeacher,
      'teacher': player.teacher,
      'playsSince': player.playsSince,
      'correctBirthday': player.correctBirthday,
      'birthday': player.birthday,
      'isLeader': false,
      'isCritical': false,
      'notes': player.notes,
      'history': targetHistory,
      'pending': true,
      'self_register': true,
      'additional_fields': {kHandoverRequestKey: request.toJson()},
    });
  }

  /// A handover request was approved in the current (target) group: the
  /// source group gets its history entry and, when the person moves
  /// completely, `left`. Cross-tenant by design, scoped to the source
  /// tenant and person of [request]; whether the person stays there is what
  /// the asking group wrote into its own note, not what the marker says.
  Future<void> completeHandoverAtSource(
    HandoverRequest request, {
    required String targetTenantName,
  }) async {
    ensureNotDemo('completeHandoverAtSource'); // DEMO_GUARD
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      await _answerAtSource(
        request,
        targetTenantName,
        (keep) => (
          entry: {
            'date': nowIso,
            'text': keep
                ? 'Person wurde zu "$targetTenantName" kopiert.'
                : 'Person wurde zu "$targetTenantName" übertragen.',
            'type': (keep ? PlayerHistoryType.copiedTo : PlayerHistoryType.transferredTo).value,
          },
          left: keep ? null : nowIso,
        ),
      );
    } catch (e, stack) {
      handleError(e, stack, 'completeHandoverAtSource');
      rethrow;
    }
  }

  /// A handover request was declined in the current (target) group: the
  /// source group reads why in the person's history.
  Future<void> noteDeclinedHandoverAtSource(
    HandoverRequest request, {
    required String targetTenantName,
    required String reason,
  }) async {
    ensureNotDemo('noteDeclinedHandoverAtSource'); // DEMO_GUARD
    try {
      await _answerAtSource(
        request,
        targetTenantName,
        (_) => (
          entry: {
            'date': DateTime.now().toUtc().toIso8601String(),
            'text': '$_handoverPrefix$targetTenantName$_handoverDeclined$reason',
            'type': PlayerHistoryType.other.value,
          },
          left: null,
        ),
      );
    } catch (e, stack) {
      handleError(e, stack, 'noteDeclinedHandoverAtSource');
      rethrow;
    }
  }

  /// Account of the source person of a handover [request], for a person
  /// without e-mail (nothing to register with). Null when the source is not
  /// a person that was asked for.
  Future<String?> handoverSourceAccount(
    HandoverRequest request, {
    required String targetTenantName,
  }) async {
    try {
      final row = await _openHandoverSource(request, targetTenantName);
      final appId = row?['appId'];
      return appId is String && appId.isNotEmpty ? appId : null;
    } catch (e, stack) {
      handleError(e, stack, 'handoverSourceAccount');
      rethrow;
    }
  }

  /// The source person of [request] with its open note, or null. Never the
  /// own group: a request always comes from another one.
  Future<Map<String, dynamic>?> _openHandoverSource(HandoverRequest request, String targetTenantName) async {
    // The one row of the asking group that the request names (the database
    // allows it only to leads within the same organisation).
    final sourceTenantId = request.fromTenantId;
    if (sourceTenantId == currentTenantId) return null;
    final row = await supabase
        .from('player')
        .select('appId, history, left')
        .eq('id', request.fromPersonId)
        .eq('tenantId', sourceTenantId)
        .maybeSingle();
    if (row == null || PlayerRepository.openHandoverKeep(row, targetTenantName) == null) return null;
    return row;
  }

  Future<void> _answerAtSource(
    HandoverRequest request,
    String targetTenantName,
    ({Map<String, dynamic> entry, String? left}) Function(bool keep) answer,
  ) async {
    final row = await _openHandoverSource(request, targetTenantName);
    if (row == null) return;
    final sourceTenantId = request.fromTenantId;
    final result = answer(PlayerRepository.openHandoverKeep(row, targetTenantName)!);
    final history = [...(row['history'] as List), result.entry];
    await supabase
        .from('player')
        .update({
          'history': history,
          // Already archived there: the earlier date stays.
          if (result.left != null && row['left'] == null) 'left': result.left,
        })
        .eq('id', request.fromPersonId)
        .eq('tenantId', sourceTenantId);
  }

  /// Removes the waiting row of a declined handover request (nothing else
  /// hangs on it yet: no account, no attendances).
  Future<void> deleteHandoverRequest(Person person) async {
    ensureNotDemo('deleteHandoverRequest'); // DEMO_GUARD
    if (person.id == null) {
      throw RepositoryException(message: 'Player ID is required', operation: 'deleteHandoverRequest');
    }
    try {
      final deleted = await supabase
          .from('player')
          .delete()
          .eq('id', person.id!)
          .eq('tenantId', currentTenantId)
          .eq('pending', true)
          .select('id');
      // Not allowed or already gone: the asking group must not read
      // "abgelehnt" while the person still waits here.
      if ((deleted as List).isEmpty) {
        throw RepositoryException(
          message: 'Die Anfrage konnte nicht entfernt werden.',
          operation: 'deleteHandoverRequest',
        );
      }
    } catch (e, stack) {
      handleError(e, stack, 'deleteHandoverRequest');
      rethrow;
    }
  }

  /// Handover multiple players to another tenant
  ///
  /// Returns a map with counts:
  /// {'success': n, 'requested': n, 'duplicate': n, 'error': n}
  Future<Map<String, int>> handoverPlayers({
    required List<Person> players,
    required int targetTenantId,
    required Map<int, int?> groupMapping,
    required String targetTenantName,
    required String sourceTenantName,
    required bool stayInInstance,
    bool asRequest = false,
    void Function(int current, int total, String playerName)? onProgress,
  }) async {
    ensureNotDemo('handoverPlayers'); // DEMO_GUARD
    final results = {'success': 0, 'requested': 0, 'duplicate': 0, 'error': 0};

    for (var i = 0; i < players.length; i++) {
      final player = players[i];
      onProgress?.call(i + 1, players.length, player.fullName);

      final targetGroupId = player.instrument != null
          ? groupMapping[player.instrument]
          : null;

      final result = await handoverPlayer(
        player: player,
        targetTenantId: targetTenantId,
        targetGroupId: targetGroupId,
        targetTenantName: targetTenantName,
        sourceTenantName: sourceTenantName,
        stayInInstance: stayInInstance,
        asRequest: asRequest,
      );

      switch (result) {
        case HandoverResult.success:
          results['success'] = results['success']! + 1;
        case HandoverResult.requested:
          results['requested'] = results['requested']! + 1;
        case HandoverResult.duplicate:
          results['duplicate'] = results['duplicate']! + 1;
        case HandoverResult.error:
          results['error'] = results['error']! + 1;
      }
    }

    return results;
  }
}
