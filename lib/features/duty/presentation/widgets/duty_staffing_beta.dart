part of 'duty_staffing_section.dart';

/// REDESIGN: "Dienst" on the Beta Termin page. Same rows, rights and actions
/// as the classic card (Besetzung with −/+, occupants with status and
/// "Austragen", own request to confirm, "Person einteilen", present and
/// available persons with "Einteilen", persons who cannot), shown as Beta
/// grouped lists with pills.
extension _DutyStaffingBeta on _DutyStaffingSectionState {
  RdTone _fillTone(DutyFill fill) => switch (fill) {
    DutyFill.full => RdTone.present,
    DutyFill.requested || DutyFill.partial => RdTone.late,
    DutyFill.open => RdTone.absent,
  };

  Widget _buildBeta({
    required List<PersonAttendance> players,
    required List<PersonAttendance> occupants,
    required List<PersonAttendance> available,
    required List<PersonAttendance> presentUnassigned,
    required List<PersonAttendance> unavailable,
    required bool canManage,
    required bool canViewNotes,
    required int? myPersonId,
  }) {
    final p = context.rd;
    final l10n = context.l10n;

    Widget assignChip(PersonAttendance pa) => RdChoiceChip(
      label: l10n.attendanceAssign,
      selected: false,
      onTap: _busy ? null : () => _assign([pa.id!], players),
    );

    List<Widget> group(String label, List<Widget> rows) => [
      const SizedBox(height: 18),
      RdGroupLabel(label),
      RdGroupedList(children: rows),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdGroupLabel(l10n.redesignDutyTitle),
        RdGroupedList(
          children: [
            RdListRow(
              title: l10n.attendanceStaffing,
              subtitle: l10n.attendanceNeeded(_required),
              showChevron: false,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RdPill(
                    l10n.redesignDutyFill(occupants.length, _required),
                    tone: _fillTone(dutyFill(players, _required)),
                  ),
                  if (canManage) ...[
                    const SizedBox(width: 8),
                    Opacity(
                      opacity: _required <= 1 || _busy ? 0.4 : 1,
                      child: RdCircleButton(
                        icon: Icons.remove,
                        label: l10n.attendanceFewerPeopleNeeded,
                        onPressed: () {
                          if (_required > 1 && !_busy) _changeRequired(-1);
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    Opacity(
                      opacity: _busy ? 0.4 : 1,
                      child: RdCircleButton(
                        icon: Icons.add,
                        label: l10n.attendanceMorePeopleNeeded,
                        onPressed: () {
                          if (!_busy) _changeRequired(1);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            for (final pa in occupants) ...[
              RdListRow(
                leading: RdInitials(rdInitialsOf(pa.fullName), size: 36),
                title: pa.fullName,
                subtitle: pa.dutyState == DutyState.self ? l10n.attendanceSelfSignedUp : null,
                showChevron: false,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    pa.dutyState == DutyState.requested
                        ? RdPill(l10n.redesignDutyRequested, tone: RdTone.late)
                        : RdPill(l10n.redesignDutyConfirmed, tone: RdTone.present),
                    if (canManage)
                      IconButton(
                        icon: Icon(Icons.more_horiz, color: p.text2),
                        tooltip: l10n.redesignDutyMore(pa.fullName),
                        onPressed: () => _occupantActions(pa),
                      ),
                  ],
                ),
                onTap: canManage ? () => _occupantActions(pa) : null,
              ),
              if (pa.dutyState == DutyState.requested && myPersonId != null && pa.personId == myPersonId)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${l10n.signoutYouAreAssigned} · ${l10n.signoutPleaseConfirm}',
                        style: RdType.meta(p, size: 13),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: RdOutlineButton(
                              label: l10n.signoutCannot,
                              height: 40,
                              onPressed: () => declineDutyAction(context, ref, pa.id!, _attendanceId),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RdPrimaryButton(
                              label: l10n.commonConfirm,
                              height: 40,
                              onPressed: () => confirmDutyAction(context, ref, pa.id!, _attendanceId),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
            if (canManage)
              RdListRow(
                leading: Icon(Icons.person_add_alt_outlined, color: p.primary),
                title: l10n.attendanceAssignPerson,
                titleColor: p.primary,
                showChevron: false,
                onTap: _busy ? null : () => _openAssign(players, occupants.length),
              ),
          ],
        ),
        if (canManage && presentUnassigned.isNotEmpty)
          ...group(l10n.attendancePresentNotAssigned, [
            for (final pa in presentUnassigned)
              RdListRow(title: pa.fullName, showChevron: false, trailing: assignChip(pa)),
          ]),
        if (canManage && available.isNotEmpty)
          ...group(l10n.attendanceAvailable, [
            for (final pa in available) RdListRow(title: pa.fullName, showChevron: false, trailing: assignChip(pa)),
          ]),
        if (unavailable.isNotEmpty)
          ...group(l10n.redesignDutyCannot, [
            for (final pa in unavailable)
              RdListRow(
                title: pa.fullName,
                titleColor: p.text2,
                subtitle: dutyStaffingNote(
                  pa.notes,
                  canViewNotes: canViewNotes,
                  noteAddedLabel: l10n.attendanceNoteAdded,
                ),
                showChevron: false,
                trailing: RdPill(
                  (pa.dutyState ?? '').isNotEmpty ? l10n.redesignDutyDeclined : l10n.redesignDutySignedOut,
                ),
              ),
          ]),
      ],
    );
  }

  /// "⋯" of an occupant: "Austragen" (asks like the classic button).
  Future<void> _occupantActions(PersonAttendance pa) async {
    final l10n = context.l10n;
    final action = await showAppActionSheet<String>(
      context,
      title: pa.fullName,
      actions: [
        AppActionSheetAction(
          value: 'unassign',
          label: l10n.attendanceUnassign,
          icon: Icons.person_remove_outlined,
          destructive: true,
        ),
      ],
    );
    if (action == 'unassign' && mounted) await _unassign(pa);
  }
}
