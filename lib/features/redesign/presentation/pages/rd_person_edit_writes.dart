part of 'rd_person_edit_page.dart';

extension _RdPersonEditWrites on _RdPersonEditPageState {
  // ---------------------------------------------------------------------
  // Writing
  // ---------------------------------------------------------------------

  /// Queues [task]; the returned future completes when it finished.
  Future<void> _enqueue(Future<void> Function() task) {
    _running++;
    final run = _queue.then((_) => task()).catchError((Object e, StackTrace st) {
      ErrorReporter.report(e, st, where: 'rd_person_edit_page');
      if (mounted) ToastHelper.showError(context, context.l10n.personUpdateFailedWith(friendlyErrorMessage(e)));
    }).whenComplete(() {
      _running--;
      // Back may close the page directly again.
      if (_running == 0 && mounted && !_disposing) _update(() {});
    });
    return _queue = run;
  }

  void _refresh() {
    _container
      ..invalidate(personProvider(_personId))
      ..invalidate(realtimePlayersProvider);
  }

  void _markSaved() {
    if (!mounted) return;
    _savedTimer?.cancel();
    _update(() => _saved = true);
    _savedTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) _update(() => _saved = false);
    });
  }

  /// Writes [columns] (id + tenantId); reports a failure while the page is open.
  Future<bool> _store(Map<String, dynamic> columns) async {
    final repo = _repo;
    if (_deleted || !_editable || repo == null || !repo.hasTenantId) return false;
    try {
      await repo.updatePlayerFields(_personId, columns);
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.personUpdateFailedWith(friendlyErrorMessage(e)));
      return false;
    }
    _refresh();
    _markSaved();
    try {
      _container.read(trackingServiceProvider).track(TrackingEvent.playerUpdated);
    } catch (_) {}
    return true;
  }

  /// Writes [columns] with the [entry] built from the stored person added to
  /// the stored history (like the person page with the freshly loaded
  /// person): entries deleted in "Verlauf" stay deleted, entries added
  /// elsewhere (copy to another group) stay. When the person cannot be
  /// loaded nothing is written (an old history would bring deleted entries
  /// back): a toast, and [revert] sets the shown value back.
  Future<bool> _storeWithHistory(
    Map<String, dynamic> columns,
    Map<String, dynamic> Function(Person stored) entry, {
    required VoidCallback revert,
  }) async {
    final repo = _repo;
    if (_deleted || !_editable || repo == null || !repo.hasTenantId) return false;
    Person? stored;
    Object? error;
    try {
      stored = await repo.getPlayerById(_personId);
    } catch (e, st) {
      error = e;
      ErrorReporter.report(e, st, where: 'rd_person_edit_page');
    }
    if (stored == null) {
      revert();
      if (mounted) {
        ToastHelper.showError(
          context,
          error == null ? context.l10n.redesignPersonNotFound : context.l10n.personUpdateFailedWith(friendlyErrorMessage(error)),
        );
      }
      return false;
    }
    final history = [
      for (final h in stored.history) h.toJson(),
      entry(stored),
    ];
    return _store({...columns, 'history': history});
  }

  void _apply(Map<String, dynamic> columns) {
    final p = _person;
    if (p == null) return;
    if (_disposing || !mounted) {
      _person = applyPersonColumns(p, columns);
      return;
    }
    _update(() => _person = applyPersonColumns(p, columns));
  }

  /// Changes of the "Weitere Angaben" fields.
  void _onColumns(Map<String, dynamic> columns, {bool typing = false}) {
    final before = _person;
    if (before == null || !_editable) return;
    if (typing) {
      _apply(columns);
      _typedColumns.addAll(columns);
      _restartTyping();
      return;
    }
    if (columns.containsKey('isLeader')) {
      _setLeader(columns['isLeader'] as bool);
      return;
    }
    _apply(columns);
    final after = _person!;
    _enqueue(() async {
      if (!await _store(columns)) return;
      // LOGIC_PEOPLE: Ionic updateShiftAssignmentsForPerson when the shift
      // plan, shift or start changed.
      if (shiftAssignmentChanged(
        oldShiftId: before.shiftId,
        oldShiftName: before.shiftName,
        oldShiftStart: before.shiftStart,
        newShiftId: after.shiftId,
        newShiftName: after.shiftName,
        newShiftStart: DateTime.tryParse(after.shiftStart ?? ''),
      )) {
        await _repo!.updateShiftAssignmentsForPerson(after);
      }
    });
  }

  void _onExtra(String id, dynamic value, {bool typing = false}) {
    if (!_editable) return;
    _update(() => _additional[id] = value);
    _pendingExtra[id] = value;
    _touchedExtra.add(id);
    if (typing) {
      _restartTyping();
    } else {
      _writeExtra();
    }
  }

  void _restartTyping() {
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(milliseconds: 800), _flushTyped);
  }

  void _flushTyped() {
    _typingTimer?.cancel();
    if (_typedColumns.isNotEmpty) {
      final columns = Map<String, dynamic>.from(_typedColumns);
      _typedColumns.clear();
      _enqueue(() => _store(columns));
    }
    if (_pendingExtra.isNotEmpty) _writeExtra();
  }

  /// Zusatzfelder: organisation fields to tenant_group_person_fields, the
  /// rest to additional_fields, then Ionic
  /// syncPlayerWithUpcomingAttendancesByAdditionalFields.
  ///
  /// Only the fields changed here are put onto the stored values when the
  /// write runs (after the organisation values are loaded): values shown
  /// before they were loaded never overwrite stored organisation values.
  void _writeExtra() {
    final person = _person;
    final shared = _shared;
    final profileRepo = _profileRepo;
    if (_pendingExtra.isEmpty || person == null || shared == null || !_editable) return;
    final changes = Map<String, dynamic>.from(_pendingExtra);
    _pendingExtra.clear();
    // Written again with the next change or "Fertig" (newer values win).
    void keepForRetry() {
      for (final e in changes.entries) {
        _pendingExtra.putIfAbsent(e.key, () => e.value);
      }
    }

    _enqueue(() async {
      final fields = await shared;
      if (fields == null || profileRepo == null) {
        keepForRetry();
        if (mounted) ToastHelper.showError(context, context.l10n.svcLoadSharedFieldsFailed);
        return;
      }
      final old = _storedAdditional;
      final next = {...old, ...changes};
      if (mapEquals(next, old)) return;
      final Map<String, dynamic> local;
      try {
        local = await saveSharedPersonFields(
          profileRepo,
          values: next,
          orgFieldIds: fields.fieldIds,
          orgId: fields.orgId,
          personKey: organisationPersonKey(person),
        );
      } catch (e) {
        keepForRetry();
        if (mounted) ToastHelper.showError(context, context.l10n.personUpdateFailedWith(friendlyErrorMessage(e)));
        return;
      }
      if (!await _store({'additional_fields': local})) {
        keepForRetry();
        return;
      }
      _storedAdditional = next;
      try {
        await _repo!.syncPlayerWithUpcomingAttendances(
          (_person ?? person).copyWith(additionalFields: next),
          oldInstrument: (_person ?? person).instrument,
          // Every changed field with its old value, also one never stored
          // (null = its default): an organisation field missing here would
          // count as unchanged.
          oldAdditionalFields: {...old, for (final k in changes.keys) k: old[k]},
        );
      } catch (e, st) {
        ErrorReporter.report(e, st, where: 'rd_person_edit_page');
      }
    });
  }

  /// Names, phone and notes: written when the text differs from the stored
  /// one ([_confirmed]) and from the one already queued. Names are never
  /// emptied. Ionic: the previous note goes to the history.
  void _saveText(String column, String text) {
    final value = text.trim();
    final confirmed = _confirmed[column];
    if (!_editable || confirmed == null) return;
    if ((column == 'firstName' || column == 'lastName') && value.isEmpty) return;
    if (value == (_requested[column] ?? confirmed)) return;
    final stored = value.isEmpty ? null : value;
    _apply({column: stored});
    _requested[column] = value;
    _enqueue(() async {
      final bool ok;
      if (column == 'notes') {
        ok = await _storeWithHistory(
          {'notes': stored},
          (s) => personNotesChangeEntry(s.notes),
          revert: () {
            if (_requested['notes'] != value) return; // a newer note is queued
            final back = _confirmed['notes'] ?? '';
            _apply({'notes': back.isEmpty ? null : back});
            if (!_disposing && _notes.text.trim() == value) _notes.text = back;
          },
        );
      } else {
        ok = await _store({column: stored});
      }
      if (ok) _confirmed[column] = value;
      if (_requested[column] == value) _requested.remove(column);
    });
  }

  String _name(Person p) => '${p.firstName} ${p.lastName}'.trim();

  /// Ionic continueUpdatingPlayer role sync after a group or Stimmführer
  /// change (main group ⇄ Verantwortlicher, Stimmführer roles).
  Future<void> _syncRoles({
    required Person before,
    required Person after,
    required bool assignVoiceLeaderRole,
  }) async {
    final appId = before.appId;
    final tenantId = _repo?.currentTenantId;
    if (appId == null || tenantId == null) return;
    try {
      await syncPersonRoles(
        _container.read(authServiceProvider),
        appId: appId,
        tenantId: tenantId,
        mainGroupId: await _mainGroupId,
        oldGroupId: before.instrument,
        newGroupId: after.instrument,
        wasLeader: before.isLeader,
        isLeader: after.isLeader,
        isGeneral: _general,
        assignVoiceLeaderRole: assignVoiceLeaderRole,
      );
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.personFlutterRoleUpdateFailed(friendlyErrorMessage(e)));
    }
    if (mounted) await _loadUserRole(after);
  }

  /// Ionic onInstrumentChange: a moved person is no longer Stimmführer; the
  /// group change goes to the history.
  Future<void> _setGroup(int groupId) async {
    final before = _person;
    if (before == null || !_editable || before.instrument == groupId) return;
    _apply({'instrument': groupId, 'isLeader': false});
    final after = _person!;
    final groups = await _container.read(groupsMapProvider.future).catchError((Object _) => <int, String>{});
    _enqueue(() async {
      final ok = await _storeWithHistory(
        {'instrument': groupId, 'isLeader': false},
        (stored) => personGroupChangeEntry(groups, stored.instrument, groupId),
        // Back to the group shown before (unless another one was chosen).
        revert: () {
          if (_person?.instrument == groupId) _apply({'instrument': before.instrument, 'isLeader': before.isLeader});
        },
      );
      if (!ok) return;
      await _syncRoles(before: before, after: after, assignVoiceLeaderRole: false);
    });
  }

  /// Stimmführer is a Zusatz of the role (Beta): switching it on for a
  /// Mitglied or Helfer with an account gives the matching Stimmführer role
  /// right away (Ionic asked first). Other roles (Verantwortlicher, Admin)
  /// stay as they are; switching off takes the Stimmführer role back.
  Future<void> _setLeader(bool value) async {
    final before = _person;
    if (before == null || !_editable || before.isLeader == value) return;
    final change = ++_leaderChanges;
    _apply({'isLeader': value});
    final after = _person!;
    _enqueue(() async {
      final appId = before.appId;
      var assign = false;
      if (value && appId != null && !_general) {
        // The stored role, read before anything is written (not the shown
        // one, which may still load or be a fallback). Unreadable: nothing
        // is saved and the switch goes back.
        final Role? role;
        try {
          final repo = _registrations;
          if (repo == null || !repo.hasTenantId) throw StateError('no group');
          role = await repo.getTenantUserRole(appId);
        } catch (e) {
          // Only while no newer switch change follows (that one decides).
          if (_leaderChanges == change) _apply({'isLeader': before.isLeader});
          if (mounted) ToastHelper.showError(context, context.l10n.personFlutterRoleUpdateFailed(friendlyErrorMessage(e)));
          return;
        }
        assign = rdLeaderRoleFor(role) != null;
      }
      if (!await _store({'isLeader': value})) return;
      await _syncRoles(before: before, after: after, assignVoiceLeaderRole: assign);
    });
  }

  /// The typed e-mail differs from the stored one (only without an account).
  bool get _emailChanged {
    final p = _person;
    return p != null && p.appId == null && _email.text.trim() != (p.email ?? '').trim();
  }

  /// E-mail (only without an account): checked, matched against other
  /// groups, and – like the person page – registered right away. A second
  /// focus loss while it runs waits for the running save (one question, one
  /// account).
  Future<void> _saveEmail() {
    if (_disposing) return Future.value();
    return _emailSave ??= _runEmailSave().whenComplete(() {
      _emailSave = null;
      if (mounted && !_disposing) _update(() {});
    });
  }

  Future<void> _runEmailSave() async {
    try {
      await _writeEmail();
    } catch (e, st) {
      ErrorReporter.report(e, st, where: 'rd_person_edit_page');
    }
  }

  Future<void> _writeEmail() async {
    final person = _person;
    if (!_editable || person == null || person.appId != null || !mounted) return;
    var value = _email.text.trim();
    if (value == (person.email ?? '').trim()) {
      if (_emailInvalid) _update(() => _emailInvalid = false);
      return;
    }
    if (value.isNotEmpty && !isValidPersonEmail(value)) {
      _update(() => _emailInvalid = true);
      return;
    }
    _update(() => _emailInvalid = false);
    if (value.isEmpty) {
      _apply({'email': null});
      await _enqueue(() => _store({'email': null}));
      return;
    }
    // Bound to the person's group when the page was filled ([_fill]): the
    // account after "Ja" is created there even after a group switch.
    final registrations = _registrations;
    final draft = await _lookupEmail(value);
    if (!mounted) return;
    if (draft != null) value = draft.person.email?.trim() ?? value;
    if (value.isEmpty || value == (_person!.email ?? '').trim()) return;
    // Ionic: "Abbrechen" saves nothing – neither the e-mail nor the data of
    // the matched person.
    if (!await confirmCreateAccountForNewEmail(context)) {
      if (mounted) _update(() => _email.text = _person?.email ?? '');
      return;
    }
    if (mounted) _email.text = value;
    if (draft != null) await _takeDraft(draft);
    // Awaited: the e-mail save ([_emailSave]) runs until the account exists
    // and the page knows it, so a second focus loss neither asks again nor
    // queues a second account.
    await _enqueue(() async {
      final String appId;
      try {
        if (registrations == null || !registrations.hasTenantId) {
          throw AccountFlowException(l10nWithoutContext.coreFlutterNoInstanceSelected);
        }
        // Like AccountCreationNotifier.createAccount, with the bound repository.
        final mainGroupId = await registrations.getMainGroupId().catchError((Object _) => null);
        appId = await registrations.createPlayerAccount(_person!.copyWith(email: value), mainGroupId: mainGroupId);
      } catch (e) {
        if (mounted) ToastHelper.showError(context, context.l10n.personUpdateFailedWith(friendlyErrorMessage(e)));
        return;
      }
      _setAppId(appId);
      _container
        ..invalidate(playersProvider)
        ..invalidate(playerByIdProvider(_personId));
      if (await _store({'email': value})) _apply({'email': value});
    });
  }

  /// The account created here, before the reload shows it.
  void _setAppId(String appId) {
    final p = _person;
    if (p == null) return;
    _container.invalidate(currentSelfServicePlayerProvider);
    if (_disposing || !mounted) {
      _person = p.copyWith(appId: appId);
      return;
    }
    _update(() => _person = p.copyWith(appId: appId));
    if (_editingStarted) _loadUserRole(_person!);
  }

  /// Ionic onEmailBlur: the e-mail belongs to a person of another group
  /// → that person's data, taken over only after "Ja" ([_takeDraft]).
  Future<({Person person, int? groupId})?> _lookupEmail(String email) async {
    final repo = ref.read(crossTenantPersonRepositoryWithTenantProvider);
    if (emailsMatch(email, _person?.email)) return null;
    List<CrossTenantPersonCandidate> matches;
    try {
      final linkedIds = await ref.read(linkedTenantIdsProvider.future);
      matches = await repo.getPossiblePersonsByEmail(email, linkedTenantIds: linkedIds);
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.dbLoadPeopleFailed);
      return null;
    }
    matches = matches.where((m) => m.person.id != _personId).toList();
    if (matches.isEmpty || !mounted) return null;
    final chosen = await showEmailTakenDialog(
      context,
      matches,
      usedBy: context.l10n.redesignPersonFormEmailUsedBy,
      usedMany: context.l10n.redesignPersonFormEmailUsedMany,
    );
    if (chosen == null || !mounted) return null;
    final groups = ref.read(groupsProvider).valueOrNull ?? const [];
    final group = groups.where((g) => g.name == chosen.groupName).firstOrNull;
    return (person: chosen.person, groupId: group?.id);
  }

  /// Writes the data of the matched person (names, birthday, Nebenfach,
  /// Stimmlage, group).
  Future<void> _takeDraft(({Person person, int? groupId}) draft) async {
    final m = draft.person;
    if (mounted) {
      _first.text = m.firstName;
      _last.text = m.lastName;
    }
    _saveText('firstName', m.firstName);
    _saveText('lastName', m.lastName);
    _onColumns({
      if (m.correctBirthday && m.birthday != null) ...{'birthday': m.birthday, 'correctBirthday': true},
      'otherExercise': m.otherExercise,
      'range': m.range,
    });
    if (draft.groupId != null) await _setGroup(draft.groupId!);
    if (mounted) ToastHelper.showSuccess(context, context.l10n.personDataTaken);
  }
}
