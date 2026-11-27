part of 'rd_person_edit_page.dart';

extension _RdPersonEditActions on _RdPersonEditPageState {
  // ---------------------------------------------------------------------
  // Actions (same calls as the person page of the normal app)
  // ---------------------------------------------------------------------

  Future<void> _resetLateCount(Person person) async {
    try {
      await ref.read(playerNotifierProvider.notifier).resetLateCount(person);
      _container.invalidate(personProvider(_personId));
      _container.invalidate(personAttendanceStatsProvider(_personId));
      if (mounted) ToastHelper.showSuccess(context, context.l10n.personLateCounterReset);
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.personResetFailed);
    }
  }

  Future<void> _changeRole(Person person) async {
    if (!ref.read(currentRoleProvider).isConductor) {
      ToastHelper.showError(context, context.l10n.personFlutterNoPermissionRoles);
      return;
    }
    // Bind the tenant repository before the first await (tenant switch).
    final repo = ref.read(userRegistrationRepositoryWithTenantProvider);
    // The role could not be read: no change on a guess (the checks for the
    // own and the last admin need the real one). Loaded again for next time.
    if (_roleUnknown) {
      ToastHelper.showError(context, context.l10n.redesignTodayLoadFailed);
      if (!_loadingRole) unawaited(_loadUserRole(person));
      return;
    }
    final current = _userRole ?? Role.player;
    // Mitglied, Verantwortlicher, Helfer; Stimmführer is the switch at the
    // person (a Zusatz): for them Mitglied and Helfer become the Stimmführer
    // roles. Another current role stays visible.
    final leader = person.isLeader && !_general;
    final roles = <Role>[Role.player, Role.responsible, Role.helper];
    final shown = rdBaseRole(current);
    if (!roles.contains(shown)) roles.add(shown);
    final picked = await showAppActionSheet<Role>(
      context,
      title: context.l10n.personRole,
      actions: [for (final r in roles) AppActionSheetAction(value: r, label: UserRegistrationRepository.roleText(r))],
    );
    if (picked == null || !mounted) return;
    final role = leader ? (rdLeaderRoleFor(picked) ?? picked) : picked;
    if (role == current) return;
    if (person.appId == null || !repo.hasTenantId) return;
    // Like the user management: the own admin role cannot be removed here
    // and the last admin cannot be downgraded.
    if (current == Role.admin && role != Role.admin) {
      if (person.appId == ref.read(currentAuthUserIdProvider)) {
        ToastHelper.showError(context, context.l10n.rdPeopleRoleOwnAdmin);
        return;
      }
      final List<TenantUser> users;
      try {
        // Read again: the cached list may be older than an admin change
        // made elsewhere.
        users = await ref.refresh(tenantUsersProvider.future);
      } catch (e) {
        if (mounted) ToastHelper.showError(context, context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(e)));
        return;
      }
      if (!mounted) return;
      if (users.where((u) => u.roleEnum == Role.admin).length <= 1) {
        ToastHelper.showError(context, context.l10n.settingsFlutterUserMgmtLastAdmin);
        return;
      }
    }
    try {
      await repo.updateTenantUserRole(person.appId!, role);
      _container.invalidate(tenantUsersProvider);
      if (!mounted) return;
      _update(() => _userRole = role);
      ToastHelper.showSuccess(context, context.l10n.personRoleUpdated);
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(e)));
    }
  }

  Future<void> _unlinkAccount(Person person) async {
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: context.l10n.personRemoveAccount,
      message: context.l10n.personRemoveAccountMessage,
      // Beta: the button names what happens, never "Ja".
      confirmText: context.l10n.commonRemove,
      cancelText: context.l10n.commonCancel,
    );
    if (!confirmed || !mounted) return;
    if (!ref.read(currentRoleProvider).isConductor) {
      ToastHelper.showError(context, context.l10n.personFlutterNoPermissionUnlink);
      return;
    }
    if (DemoGuard.blocked()) return; // DEMO_GUARD
    try {
      await ref.read(playerNotifierProvider.notifier).unlinkAccount(person);
      _container.invalidate(personProvider(_personId));
      _container.invalidate(currentSelfServicePlayerProvider);
      if (mounted) ToastHelper.showSuccess(context, context.l10n.personUserRemoved);
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.personUserRemoveFailed);
    }
  }


  Future<void> _createAccount(Person person) async {
    if (_creatingAccount) return;
    if (!ref.read(currentRoleProvider).isConductor) {
      ToastHelper.showError(context, context.l10n.personFlutterNoPermissionCreateAccount);
      return;
    }
    final email = person.email;
    if (email == null || email.isEmpty) {
      ToastHelper.showError(context, context.l10n.personFlutterNoEmail);
      return;
    }
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: context.l10n.personFlutterCreateAccountQuestion,
      message: context.l10n.personFlutterCreateAccountMessage(person.fullName, email),
      confirmText: context.l10n.personFlutterCreateAccount,
      cancelText: context.l10n.commonCancel,
    );
    if (!confirmed || !mounted) return;
    _creatingAccount = true;
    try {
      // AUTH: attendix-user Edge Function; Verantwortlicher for the main
      // group, otherwise Spieler (Ionic).
      await ref.read(accountCreationNotifierProvider.notifier).createAccount(person);
      _container.invalidate(personProvider(_personId));
      if (mounted) ToastHelper.showSuccess(context, context.l10n.personFlutterAccountCreatedMail);
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(
            context, context.l10n.personFlutterCreateAccountFailed('${person.firstName} ${person.lastName}', e));
      }
    } finally {
      _creatingAccount = false;
    }
  }

  /// Ionic assignMyAccount(): link the signed-in user to this person.
  Future<void> _assignMyAccount(Person person) async {
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (person.id == null || user == null) return;
    try {
      final tenantUser = await ref.read(currentTenantUserProvider.future);
      await ref
          .read(accountCreationNotifierProvider.notifier)
          .createAccount(person.copyWith(email: tenantUser?.email ?? user.email));
      _container.invalidate(personProvider(_personId));
      _container.invalidate(realtimePlayersProvider);
      _container.invalidate(currentTenantUserProvider);
      _container.invalidate(currentSelfServicePlayerProvider);
      if (mounted) ToastHelper.showSuccess(context, context.l10n.personUserAssigned);
    } catch (e) {
      if (mounted) ToastHelper.showError(context, friendlyErrorMessage(e));
    }
  }

  Future<void> _searchOtherInstance(Person person) async {
    try {
      final linked = await searchPersonInOtherInstance(
        context,
        ref,
        person,
        firstName: person.firstName,
        lastName: person.lastName,
        onNoMatch: () {
          if (mounted) ToastHelper.showError(context, context.l10n.redesignPersonFormNoMatchOther);
        },
      );
      if (!linked) return;
      _refresh();
      if (mounted) ToastHelper.showSuccess(context, context.l10n.personEmailUpdated);
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(e)));
    }
  }

  /// Hands over the person as stored: typed text and running writes first,
  /// then reloaded (current history, e.g. after an earlier copy).
  Future<void> _transfer({required bool copy}) async {
    _saveTyped();
    await _settle();
    if (!mounted) return;
    Person? stored;
    try {
      stored = await _repo?.getPlayerById(_personId);
    } catch (e, st) {
      ErrorReporter.report(e, st, where: 'rd_person_edit_page');
    }
    final person = stored ?? _person;
    if (person == null || !mounted) return;
    final done = await showPersonTransferSheet(context, person, copy: copy);
    if (!done || !mounted) return;
    _refresh();
    if (!copy) {
      _deleted = true; // the person left this group
      context.go(RedesignRoutes.members);
    }
  }

  Future<void> _delete(Person person) async {
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: context.l10n.attendanceRemovePerson,
      message: context.l10n.personRemovePersonMessage,
      // Beta: the button names what happens, never "Ja".
      confirmText: context.l10n.commonRemove,
      cancelText: context.l10n.commonCancel,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(playerNotifierProvider.notifier).deletePlayer(_personId, appId: person.appId);
      _deleted = true;
      if (!mounted) return;
      ToastHelper.showSuccess(context, context.l10n.personRemoved);
      context.go(RedesignRoutes.members);
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(e)));
    }
  }

  /// Ionic activate(): "Person reaktivieren" for archived persons.
  Future<void> _reactivate(Person person) async {
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: context.l10n.rdTextRestoreTitle(person.fullName),
      message: context.l10n.rdTextRestoreMessage,
      confirmText: context.l10n.redesignArchiveListRestore,
      cancelText: context.l10n.commonCancel,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(playerNotifierProvider.notifier).reactivatePlayer(person);
      _container.invalidate(realtimePlayersProvider);
      _container.invalidate(personProvider(_personId));
      if (!mounted) return;
      ToastHelper.showSuccess(context, context.l10n.rdTextRestoreDone(person.fullName));
      _done();
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(e)));
    }
  }

  Future<void> _onAvatarTap(Person person) async {
    final hasImage = person.img != null && person.img!.isNotEmpty && !person.img!.contains('.svg');
    if (!hasImage) return replacePersonPhoto(context, ref, person);
    final action = await showAppActionSheet<String>(
      context,
      actions: [
        AppActionSheetAction(value: 'replace', icon: Icons.photo_camera_outlined, label: context.l10n.personReplace),
        AppActionSheetAction(value: 'remove', icon: Icons.delete_outline, label: context.l10n.commonRemove, destructive: true),
      ],
    );
    if (!mounted) return;
    switch (action) {
      case 'replace':
        await replacePersonPhoto(context, ref, person);
      case 'remove':
        await removePersonPhoto(context, ref, person);
    }
  }

  void _showAccountHelp(Person person) {
    showAppDialog<void>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(ctx.l10n.personHelp),
        content: Text([if (person.appId == null) ctx.l10n.personAccountHelp, ctx.l10n.redesignPersonFormExistingUserHint].join('\n\n')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.l10n.commonClose))],
      ),
    );
  }

  /// Waits until every queued write finished (also the ones queued meanwhile).
  Future<void> _settle() async {
    while (true) {
      final queue = _queue;
      await queue;
      if (identical(queue, _queue)) return;
    }
  }

  /// "Fertig" and back: saves the typed text, waits for the e-mail (account
  /// question) and every queued write, then the page closes. Failures are
  /// shown as toasts while it is still open.
  Future<void> _done() async {
    if (_leaving) return;
    _leaving = true;
    final wasInvalid = _emailInvalid;
    FocusScope.of(context).unfocus();
    _saveTyped();
    await _saveEmail();
    await _settle();
    if (!mounted) return;
    // An invalid e-mail is shown once; "Fertig" again leaves without it.
    if (_emailInvalid && !wasInvalid) {
      _leaving = false;
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RedesignRoutes.person(_personId));
    }
  }
}
