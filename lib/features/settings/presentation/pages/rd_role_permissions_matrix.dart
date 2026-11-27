part of 'rd_role_permissions_page.dart';

/// Role permission rows, role detail views, and account lists for
/// [RdRolePermissionsPage].
extension _RdRolePermissionsMatrix on _RdRolePermissionsPageState {
  Widget _switch(String title, String helper, bool value, ValueChanged<bool>? onChanged) {
    final p = context.rd;
    return RdListRow(
      title: title,
      subtitle: helper,
      showChevron: false,
      trailing: Switch.adaptive(value: value, activeTrackColor: p.primary, onChanged: onChanged),
      onTap: onChanged == null ? null : () => onChanged(!value),
    );
  }

  /// A switch of [base] that also sets its Stimmführer role ([rdLeaderVariant]).
  /// Shows the base role's value; when the Stimmführer still differ, the hint
  /// says so and the next change aligns them.
  Widget _merged(
    Role base,
    String title,
    String hint,
    bool Function(TenantRolePermission p) get,
    TenantRolePermission Function(TenantRolePermission p, bool v) set,
  ) {
    final leader = rdLeaderVariant(base);
    final value = get(_permissions[base]!);
    final other = leader == null ? null : _permissions[leader];
    final differs = other != null && get(other) != value;
    return _switch(
      title,
      differs ? '$hint\n${context.l10n.rdSettingsPermLeaderDiffers}' : hint,
      value,
      (v) => _setPermissions({
        base: (p) => set(p, v),
        if (other != null) leader!: (p) => set(p, v),
      }),
    );
  }

  /// A right the role always has ([never]: one it never gets): a row
  /// without a switch, so the page also says what cannot be set.
  Widget _fixed(String title, {String? hint, bool never = false}) {
    final p = context.rd;
    return RdListRow(
      leading: Icon(never ? Icons.lock_outline : Icons.check, size: 20, color: never ? p.text2 : p.present),
      title: title,
      subtitle: hint,
      showChevron: false,
    );
  }

  List<Widget> _group(String label, List<Widget> rows, {String? note}) => [
    RdGroupLabel(label),
    RdGroupedList(children: rows),
    if (note != null) RdListNote(note),
    const SizedBox(height: 22),
  ];

  /// "Personen": the accounts with this role, each opens its person.
  /// Nothing while the accounts load (the switches do not wait for them).
  /// [personsOnly]: accounts without a person in the group are counted, not
  /// named (their e-mail is for those who manage the accounts).
  List<Widget> _people({String? note, bool baseRole = false, bool personsOnly = false}) {
    final l10n = context.l10n;
    final accounts = ref.watch(rdRoleAccountsProvider);
    if (accounts == null) return [if (note != null) RdListNote(note)];
    final players = playersOfCurrentTenant(ref.watch(playersProvider), ref.watch(currentTenantIdProvider));
    final groups = {for (final g in ref.watch(groupsProvider).valueOrNull ?? const []) g.id: g.name};
    final all = rdRolePeople(rdRoleAccounts(accounts, widget.view), players);
    final people = personsOnly ? [for (final r in all) if (r.person != null) r] : all;
    final hidden = all.length - people.length;
    String? subtitle(RdRolePerson r) {
      final parts = [
        if (groups[r.person?.instrument] case final String name when name.isNotEmpty) name,
        // Stimmführer: the role they are a Zusatz of.
        if (baseRole) UserRegistrationRepository.roleText(rdBaseRole(r.account.roleEnum)),
      ];
      return parts.isEmpty ? null : parts.join(' · ');
    }

    return [
      RdGroupLabel(l10n.rdRolesPeople),
      if (people.isEmpty)
        RdInfoCard(
          text: hidden > 0 ? l10n.rdRolesOtherAccounts(hidden) : l10n.rdRolesNoPeople,
          icon: Icons.person_outline,
        )
      else
        RdGroupedList(
          children: [
            for (final r in people)
              RdListRow(
                leading: RdInitials(r.person?.initials ?? '', size: 36),
                title: r.name,
                subtitle: subtitle(r),
                showChevron: r.person?.id != null,
                onTap: r.person?.id == null ? null : () => context.push(RedesignRoutes.person(r.person!.id!)),
              ),
          ],
        ),
      if (people.isNotEmpty && hidden > 0) RdListNote(l10n.rdRolesOtherAccounts(hidden)),
      if (note != null) RdListNote(note),
    ];
  }

  /// Helfer (also for Helfer who are Stimmführer). "Alle Register" sets
  /// both roles; whether Stimmführer-Helfer are limited to their own Stimme
  /// is a switch of the Stimmführer page. Notizen and Checkliste only apply
  /// to Helfer: Stimmführer-Helfer always see them (Ionic `role === HELPER`).
  List<Widget> _helperPage() {
    final l10n = context.l10n;
    final kind = ref.watch(rdGroupKindProvider);
    final helper = _permissions[Role.helper];
    final leader = _permissions[Role.voiceLeaderHelper];
    return [
      ..._group(l10n.rdRolesAlways, [_fixed(l10n.rdRolesFixedAttendance), _fixed(l10n.rdRolesFixedSignup)]),
      if (helper != null)
        ..._group(
          l10n.rdRolesAdjustable,
          [
            _switch(
              l10n.rdSettingsPermAllGroups(kind),
              leader != null && !helper.attendanceAllGroups && leader.attendanceAllGroups
                  ? '${l10n.rdSettingsPermAllGroupsHint(kind)}\n${l10n.rdSettingsPermLeaderDiffers}'
                  : l10n.rdSettingsPermAllGroupsHint(kind),
              helper.attendanceAllGroups,
              (v) => _setPermissions({
                Role.helper: (p) => p.copyWith(attendanceAllGroups: v),
                // Turned off: Stimmführer-Helfer neither; turned on: all Register.
                if (leader != null) Role.voiceLeaderHelper: (p) => p.copyWith(attendanceAllGroups: v),
              }),
            ),
            _merged(
              Role.helper,
              l10n.rdSettingsPermCreate,
              l10n.rdSettingsPermCreateHint,
              (p) => p.attendanceCreate,
              (p, v) => p.copyWith(attendanceCreate: v),
            ),
            _switch(
              l10n.rdSettingsPermNotes,
              l10n.rdSettingsPermNotesHint,
              helper.playerNotesView,
              (v) => _setPermissions({Role.helper: (p) => p.copyWith(playerNotesView: v)}),
            ),
            _switch(
              l10n.rdSettingsPermChecklist,
              l10n.rdSettingsPermChecklistHint,
              helper.checklistView,
              (v) => _setPermissions({Role.helper: (p) => p.copyWith(checklistView: v)}),
            ),
            _merged(
              Role.helper,
              l10n.rdSettingsPermAbsence,
              l10n.rdSettingsPermAbsenceHint,
              (p) => p.playerPlannedAbsence,
              (p, v) => p.copyWith(playerPlannedAbsence: v),
            ),
          ],
          note: l10n.rdSettingsPermHelperNote,
        ),
      ..._group(l10n.rdRolesNever, [_fixed(l10n.rdRolesNeverLead, hint: l10n.rdRolesNeverLeadHint, never: true)]),
      ..._people(note: l10n.rdRolesAssignNote),
    ];
  }

  /// Stimmführer: a Zusatz of Mitglied or Helfer (the switch at the
  /// person). Their own switch: Stimmführer-Helfer only record their own
  /// Stimme, offered while Helfer record all of them.
  List<Widget> _leaderPage() {
    final l10n = context.l10n;
    final kind = ref.watch(rdGroupKindProvider);
    final helper = _permissions[Role.helper];
    final leader = _permissions[Role.voiceLeaderHelper];
    return [
      ..._group(l10n.rdRolesAlways, [
        _fixed(l10n.rdRolesFixedOwnRole, hint: l10n.rdRolesFixedOwnRoleHint),
        _fixed(l10n.rdRolesFixedMyVoice, hint: l10n.rdRolesFixedMyVoiceHint(kind)),
      ]),
      if (helper != null && leader != null)
        if (helper.attendanceAllGroups)
          ..._group(l10n.rdRolesAdjustable, [
            _switch(
              l10n.rdSettingsPermLeaderOwnOnly,
              l10n.rdSettingsPermLeaderOwnOnlyHint,
              !leader.attendanceAllGroups,
              (v) => _setPermissions({Role.voiceLeaderHelper: (p) => p.copyWith(attendanceAllGroups: !v)}),
            ),
          ])
        else ...[
          RdInfoCard(text: l10n.rdRolesLeaderOwnAlready(kind), icon: Icons.info_outline),
          const SizedBox(height: 22),
        ],
      ..._people(note: l10n.rdRolesLeaderNote, baseRole: true),
    ];
  }

  /// Mitglied (also for Mitglieder who are Stimmführer): what members see
  /// (group settings) and may. Selbst pausieren is read from the Mitglied
  /// role for everyone with an own profile ([canSelfPauseProvider]), so it
  /// only sets that role.
  List<Widget> _memberPage() {
    final l10n = context.l10n;
    final player = _permissions[Role.player];
    final general = ref.watch(rdGroupKindProvider) == 'general';
    return [
      ..._group(l10n.rdRolesAlways, [
        _fixed(l10n.rdRolesFixedSignup),
        if (!general) _fixed(l10n.rdRolesFixedWorks),
      ]),
      RdTenantSettingsBlock(sections: const [RdTenantSettings.visibility], label: l10n.rdRolesSees),
      const SizedBox(height: 22),
      if (player != null)
        ..._group(
          l10n.rdRolesAdjustable,
          [
            _switch(
              l10n.rdSettingsPermPause,
              l10n.rdSettingsPermPauseHint,
              player.playerSelfPause,
              (v) => _setPermissions({Role.player: (p) => p.copyWith(playerSelfPause: v)}),
            ),
            _merged(
              Role.player,
              l10n.rdSettingsPermAbsence,
              l10n.rdSettingsPermAbsenceHint,
              (p) => p.playerPlannedAbsence,
              (p, v) => p.copyWith(playerPlannedAbsence: v),
            ),
          ],
          note: l10n.rdSettingsPermMemberNote,
        ),
      ..._group(l10n.rdRolesNever, [
        _fixed(l10n.rdRolesNeverAttendance, hint: l10n.rdRolesNeverAttendanceHint, never: true),
        _fixed(l10n.rdRolesNeverLead, hint: l10n.rdRolesNeverLeadHint, never: true),
      ]),
    ];
  }

  /// Verantwortliche and (for those who may not manage Admins) Admins:
  /// nothing to set, the page says what the role is and who has it.
  List<Widget> _leadPage() {
    final l10n = context.l10n;
    final general = ref.watch(rdGroupKindProvider) == 'general';
    if (widget.view == RdRoleView.admin) {
      return [
        ..._group(l10n.rdRolesAlways, [_fixed(l10n.rdRolesFixedAll, hint: l10n.rdRolesFixedAllHint)]),
        // Who reads this page does not manage the Admins.
        ..._people(personsOnly: true),
      ];
    }
    return [
      ..._group(l10n.rdRolesAlways, [
        _fixed(l10n.rdRolesFixedManage),
        if (!general) _fixed(l10n.rdRolesFixedManageWorks),
        _fixed(l10n.rdRolesFixedSettings),
      ]),
      ..._group(l10n.rdRolesNever, [_fixed(l10n.rdRolesNeverAdmins, hint: l10n.rdRolesNeverAdminsHint, never: true)]),
      ..._people(note: l10n.rdRolesAssignNote),
    ];
  }

  /// Opens a page of the list: next to the Verwaltung on wide screens,
  /// pushed otherwise.
  void _open(String location) {
    if (_inSplit) {
      rdManageSplitOpen(context, location);
    } else {
      context.push(location);
    }
  }

  Widget _roleRow(IconData icon, String title, String hint, {int? count, String? value, required String location}) =>
      RdListRow(
        leading: RdRowIcon(icon),
        title: title,
        subtitle: hint,
        value: value ?? (count == null ? null : '$count'),
        onTap: () => _open(location),
      );

  /// The list of roles with the number of accounts, then what applies to
  /// everyone in the group.
  List<Widget> _listPage({required bool isAdmin}) {
    final l10n = context.l10n;
    final accounts = ref.watch(rdRoleAccountsProvider);
    int? count(RdRoleView view) => accounts == null ? null : rdRoleAccounts(accounts, view).length;
    final access = ref.watch(rdManageAccessProvider);
    final leaders = count(RdRoleView.leader);
    return [
      ..._group(l10n.rdRolesLeads, [
        _roleRow(
          Icons.verified_user_outlined,
          l10n.commonRolesAdmin,
          l10n.rdAdminAdminsHint,
          count: count(RdRoleView.admin),
          // Managing Admins is for Admins (not in the demo); others read.
          location:
              rdManageVisible(RdManageEntry.admins, access)
                  ? RedesignRoutes.admins
                  : RedesignRoutes.role(RdRoleView.admin.key),
        ),
        _roleRow(
          Icons.manage_accounts_outlined,
          l10n.rdRolesResponsible,
          l10n.rdRolesResponsibleHint,
          count: count(RdRoleView.responsible),
          location: RedesignRoutes.role(RdRoleView.responsible.key),
        ),
      ]),
      ..._group(l10n.rdRolesMembersHelpers, [
        _roleRow(
          Icons.fact_check_outlined,
          l10n.commonRolesHelper,
          l10n.rdRolesHelperHint,
          count: count(RdRoleView.helper),
          location: RedesignRoutes.role(RdRoleView.helper.key),
        ),
        // Groups of type "Allgemein" have no Stimmführer, unless some are
        // left from before.
        if (!access.isGeneral || (leaders ?? 0) > 0)
          _roleRow(
            Icons.record_voice_over_outlined,
            l10n.rolesVoiceLeader,
            l10n.rdRolesLeaderHint,
            count: leaders,
            location: RedesignRoutes.role(RdRoleView.leader.key),
          ),
        _roleRow(
          Icons.person_outline,
          l10n.commonRolesMember,
          l10n.rdRolesMemberHint,
          count: count(RdRoleView.member),
          location: RedesignRoutes.role(RdRoleView.member.key),
        ),
      ]),
      ..._group(l10n.rdRolesOthers, [
        _roleRow(
          Icons.favorite_border,
          l10n.rolesParents,
          l10n.rdAdminParentsHint,
          count: rdLoadedValue(ref.watch(parentsProvider))?.length,
          value: access.parentsEnabled ? null : l10n.rdRolesOff,
          location: RedesignRoutes.parents,
        ),
        _roleRow(
          Icons.visibility_outlined,
          l10n.commonRolesViewer,
          l10n.rdAdminViewersHint,
          count: rdLoadedValue(ref.watch(viewersProvider))?.length,
          location: RedesignRoutes.viewers,
        ),
      ]),
      RdTenantSettingsBlock(sections: const [RdTenantSettings.assistant], label: l10n.rdRolesForAll),
      const SizedBox(height: 12),
      RdGroupedList(
        children: [
          _switch(
            l10n.rdSettingsFilesForAll,
            l10n.rdSettingsFilesForAllHint,
            _filesShared,
            isAdmin ? _setFilesShared : null,
          ),
        ],
      ),
    ];
  }
}
