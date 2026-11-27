part of 'person_edit_page.dart';

extension _RdPersonEditForm on _RdPersonEditPageState {
  Widget _form(BuildContext context, Person person) {
    final p = context.rd;
    final l10n = context.l10n;
    final role = ref.watch(currentRoleProvider);
    final isAdmin = role.isAdmin || role.isResponsible;
    final tenant = ref.watch(currentTenantProvider);
    final main = ref.watch(mainGroupProvider).valueOrNull;
    final ownMember = ref.watch(currentSelfServicePlayerProvider);
    // Settled only: hasValue stays true while reloading / after an error.
    final ownMemberMissing =
        !ownMember.isLoading && !ownMember.hasError && ownMember.hasValue && ownMember.value == null;
    final isMainGroup = main?.id != null && main!.id == person.instrument;
    final textStyle = TextStyle(fontSize: 17, color: p.text);
    final userId = ref.watch(currentAuthUserIdProvider);
    final isSelf = person.appId != null && person.appId == userId;
    final hasEmail = (person.email ?? '').trim().isNotEmpty;

    Widget hint(String text, {Color? color}) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(text, style: RdType.meta(p, size: 13).copyWith(color: color)),
        );
    Widget field(String label, TextEditingController c, FocusNode f, Key key,
            {TextInputType? keyboard, bool readOnly = false, int maxLines = 1, TextCapitalization caps = TextCapitalization.none}) =>
        RdFieldRow(
          label: label,
          child: TextField(
            key: key,
            controller: c,
            focusNode: f,
            readOnly: readOnly,
            keyboardType: keyboard,
            minLines: 1,
            maxLines: maxLines,
            textCapitalization: caps,
            style: readOnly ? textStyle.copyWith(color: p.text2) : textStyle,
            decoration: rdInputDecoration(p, ''),
            onChanged: (_) => _update(() {}),
          ),
        );
    Widget row(String title, VoidCallback? onTap, {IconData? icon, Color? color, String? value, String? subtitle, Key? key}) =>
        RdListRow(
          key: key,
          title: title,
          subtitle: subtitle,
          value: value,
          titleColor: color,
          leading: icon == null ? null : Icon(icon, color: color ?? p.softText),
          showChevron: color == null,
          onTap: onTap,
        );

    final namesEmpty = _first.text.trim().isEmpty || _last.text.trim().isEmpty;
    final stats = ref.watch(personAttendanceStatsProvider(_personId)).valueOrNull;
    final lateCount = stats?['lateCount'] as int? ?? 0;
    final lateExcused = stats?['lateCountExcused'] as int? ?? 0;
    final showLate = stats != null && lateCount >= lateWarningThreshold(tenant?.criticalRules);
    final canManageAbsences = ref.watch(canManagePlannedAbsencesProvider);
    final absences = canManageAbsences ? ref.watch(playerAbsencesByPersonIdProvider(_personId)).valueOrNull ?? const [] : const [];
    final others = person.appId == null ? null : ref.watch(otherTenantsProvider(person.appId!)).valueOrNull;
    final criticalReason = person.isCritical ? rdCriticalContextOf(ref)?.reasonOf(person) : null;

    return RdFormBody(
      children: [
        RdCard(
          padding: EdgeInsets.zero,
          color: person.isCritical ? p.absentSoft : null,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: RdPersonAvatar(name: _name(person), imageUrl: person.img, onTap: () => _onAvatarTap(person)),
              ),
              Expanded(
                child: Column(
                  children: [
                    field(l10n.peopleFirstName, _first, _firstFocus, const Key('rd-person-first'), caps: TextCapitalization.words),
                    Divider(height: 1, thickness: 1, color: p.line),
                    field(l10n.peopleLastName, _last, _lastFocus, const Key('rd-person-last'), caps: TextCapitalization.words),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (namesEmpty) hint(l10n.personEnterNames, color: p.absent),
        const SizedBox(height: 20),
        RdGroupLabel(l10n.rdWordsGroup(ref.watch(rdGroupKindProvider))),
        RdPersonGroupChips(
          selected: person.instrument,
          onSelected: _setGroup,
          onManage: _canEdit ? () => context.push(RedesignRoutes.groups) : null,
        ),
        const SizedBox(height: 20),
        RdGroupLabel(l10n.redesignPersonFormContact),
        RdGroupedList(
          children: [
            field(l10n.peopleEmail, _email, _emailFocus, const Key('rd-person-email'),
                keyboard: TextInputType.emailAddress, readOnly: person.appId != null),
            field(l10n.peoplePhone, _phone, _phoneFocus, const Key('rd-person-phone'), keyboard: TextInputType.phone),
          ],
        ),
        if (_emailInvalid) hint(l10n.personInvalidEmail, color: p.absent),
        if (person.appId == null) hint(l10n.redesignPersonFormEmailHint),
        // Ionic: "Notizen" for Admins and Verantwortliche.
        if (isAdmin) ...[
          const SizedBox(height: 20),
          RdGroupLabel(l10n.redesignPersonNotes),
          RdGroupedList(children: [
            field(l10n.peopleNotes, _notes, _notesFocus, const Key('rd-person-notes'),
                maxLines: 6, caps: TextCapitalization.sentences),
          ]),
        ],
        const SizedBox(height: 20),
        RdGroupedList(
          children: [
            RdListRow(
              key: const Key('rd-person-more'),
              title: l10n.redesignPersonFormMore,
              subtitle: l10n.redesignPersonFormMoreHint,
              showChevron: false,
              trailing: Icon(_showMore ? Icons.expand_less : Icons.expand_more, color: p.text2),
              onTap: () => _update(() => _showMore = !_showMore),
            ),
          ],
        ),
        if (_showMore) ...[
          const SizedBox(height: 12),
          RdPersonMoreFields(
            person: person,
            isMainGroup: isMainGroup,
            additionalValues: _additional,
            birthdayHighlight: !person.correctBirthday,
            onColumns: _onColumns,
            onExtra: _onExtra,
          ),
        ],
        hint(l10n.redesignPersonFormLiveHint),

        // Problemfall (Ionic: !readOnly && isCritical): the same
        // "Gespräch eintragen" as on the person page and in the list of the
        // Problemfälle, written in this page's queue.
        if (person.isCritical) ...[
          const SizedBox(height: 20),
          RdGroupLabel(l10n.peopleProblemCase),
          RdGroupedList(children: [
            // Why (the rule that hits); none while it cannot be worked out.
            if (criticalReason != null) RdCriticalReasonRow(criticalReason),
            RdListRow(
              key: const Key('rd-person-edit-talk'),
              leading: Icon(Icons.check, color: p.link),
              title: l10n.rdCriticalTalk,
              titleColor: p.link,
              showChevron: false,
              onTap:
                  _editable
                      ? () => rdRecordTalk(
                        context,
                        ref,
                        person,
                        reason: criticalReason,
                        // Like _store: nothing once the person left the group
                        // or may no longer be edited (while the sheet was open).
                        run: (write) => _enqueue(() async {
                          if (_deleted || !_editable) return;
                          await write();
                        }),
                      )
                      : null,
            ),
          ]),
        ],

        // Verspätungen (Ionic late-warning-card)
        if (showLate) ...[
          const SizedBox(height: 20),
          RdCard(
            color: p.lateSoft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.personLateWarningTitle, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.text)),
                const SizedBox(height: 6),
                Text.rich(htmlStrongToSpan(l10n.personLateWarning(lateCount)), style: TextStyle(color: p.text)),
                if (lateExcused > 0) ...[
                  const SizedBox(height: 6),
                  Text(l10n.personLateExcusedExtra(lateExcused), style: RdType.meta(p, size: 13)),
                ],
                const SizedBox(height: 12),
                RdOutlineButton(label: l10n.personResetTalked, onPressed: () => _resetLateCount(person)),
              ],
            ),
          ),
        ],

        // Account (Ionic: !readOnly && !approveMode; pending persons only
        // get the approval card)
        ...[
          const SizedBox(height: 20),
          RdGroupLabel(l10n.personAccount),
          RdGroupedList(children: [
            if (person.appId != null) ...[
              RdListRow(title: l10n.personAccount, value: l10n.personFlutterLinked, showChevron: false),
              RdListRow(
                key: const Key('rd-person-role'),
                title: l10n.personRole,
                value: _loadingRole ? '…' : rdRoleLabel(_userRole ?? Role.player, isLeader: person.isLeader),
                // Main group: the role follows the group (Ionic).
                onTap: isMainGroup || _loadingRole ? null : () => _changeRole(person),
              ),
              row(l10n.personFlutterUnlinkAccount, () => _unlinkAccount(person), icon: Icons.link_off, color: p.absent),
            ] else ...[
              if (hasEmail) row(l10n.personFlutterCreateAccount, () => _createAccount(person), icon: Icons.person_add_alt_outlined),
              if (hasEmail)
                row(l10n.redesignPersonFormSearchOtherGroup, () => _searchOtherInstance(person), icon: Icons.person_search),
            ],
            row(l10n.personHelp, () => _showAccountHelp(person), icon: Icons.help_outline),
          ]),
          if (person.appId == null && !hasEmail) hint(l10n.personFlutterEmailRequiredForAccount),
        ],

        // Abwesenheiten (Ionic person.page absences, Dienstplan)
        if (canManageAbsences) ...[
          const SizedBox(height: 20),
          RdGroupLabel(absences.isEmpty ? l10n.personAbsences : l10n.personAbsencesCount(absences.length)),
          RdGroupedList(children: [
            for (final a in absences)
              RdListRow(
                title: '${_fmt(a.fromDate)} – ${_fmt(a.untilDate)}',
                subtitle: a.reason,
                trailing: Icon(Icons.delete_outline, color: p.absent),
                showChevron: false,
                onTap: () => deletePlannedAbsenceFlow(context, ref, a),
              ),
            row(
              l10n.personAddAbsence,
              () => addPlannedAbsenceFlow(
                context,
                ref,
                personId: _personId,
                showLongAbsenceHint: true,
                forOther: true,
                firstName: person.firstName,
              ),
              icon: Icons.add_circle_outline,
            ),
            if (ref.watch(hasDutyTypesProvider))
              row(
                l10n.signoutRegularlyUnavailable,
                () => openUnavailabilityPage(context, personId: _personId, personName: person.fullName, forOther: true),
                icon: Icons.event_busy_outlined,
              ),
          ]),
        ],

        // Weitere Aktionen (Ionic openMoreMenu)
        const SizedBox(height: 20),
        RdGroupLabel(l10n.personActions),
        RdGroupedList(children: [
          row(l10n.redesignPersonHistory, () => context.push(RedesignRoutes.personHistory(_personId)), icon: Icons.history),
          // Only while the signed-in user has no member of their own in this
          // group (hidden while loading): one login, one member.
          if (person.appId == null && ownMemberMissing)
            row(l10n.personAssignMyUser, () => _assignMyAccount(person), icon: Icons.person_pin_outlined),
          if (_canTransfer) ...[
            row(l10n.redesignPersonFormTransferOther, () => _transfer(copy: false), icon: Icons.drive_file_move_outline),
            row(l10n.redesignPersonFormCopyOther, () => _transfer(copy: true), icon: Icons.copy_outlined),
          ],
        ]),

        // Andere Gruppen (only with an account)
        if (others != null && others.isNotEmpty) ...[
          const SizedBox(height: 20),
          RdGroupLabel(l10n.redesignPersonFormOtherGroups),
          RdGroupedList(children: [
            for (final t in others)
              RdListRow(
                title: t['tenantName'] as String,
                subtitle: t['role'] as String,
                value: t['percentage'] == null ? l10n.personNotAvailable : '${t['percentage']} %',
                showChevron: false,
              ),
          ]),
        ],

        if (!isSelf) ...[
          const SizedBox(height: 32),
          RdGroupedList(children: [
            row(l10n.attendanceRemovePerson, () => _delete(person),
                icon: Icons.delete_outline, color: p.absent, key: const Key('rd-person-delete')),
          ]),
        ],
      ],
    );
  }

  String _fmt(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }
}
