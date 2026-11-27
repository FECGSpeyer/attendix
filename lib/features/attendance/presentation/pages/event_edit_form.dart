part of 'event_edit_page.dart';

/// Form sections for [RdEventEditPage].
extension _RdEventEditForm on _RdEventEditPageState {
  Widget _form(BuildContext context, Attendance att, AttendanceType? type) {
    final p = context.rd;
    final l10n = context.l10n;
    final role = ref.watch(effectiveRoleProvider);

    return RdFormBody(
      children: [
        _buildBasicsSection(context, att, type),
        const SizedBox(height: 20),
        _buildMembersSection(context, att, type),
        const SizedBox(height: 20),
        _buildLeadersSection(context),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 20),
          child: Text(l10n.redesignEventEditHint, style: RdType.meta(p, size: 13)),
        ),
        if (role.isAdmin || role.isResponsible) ...[
          const SizedBox(height: 8),
          RdGroupedList(
            children: [
              RdListRow(
                key: const Key('rd-event-delete'),
                title: l10n.redesignEventDelete,
                titleColor: p.absent,
                leading: Icon(Icons.delete_outline, color: p.absent),
                showChevron: false,
                onTap: _delete,
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildBasicsSection(BuildContext context, Attendance att, AttendanceType? type) {
    final p = context.rd;
    final l10n = context.l10n;
    final locale = currentIntlLocale();
    final date = DateTime.tryParse(att.date)?.toLocal();
    final allDay = type?.allDay ?? false;
    // The loaded type must be this Termin's current one (not the previous
    // value while it reloads after an Art change).
    final typeReady = att.typeId == null || type?.id == att.typeId;
    final days =
        rdEffectiveDurationDays(
          att.durationDays,
          typeAllDay: type?.allDay ?? false,
          typeDurationDays: type?.durationDays,
        ) ??
        1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdGroupLabel(l10n.redesignEventEditBasics),
        RdGroupedList(
          children: [
            RdFieldRow(
              label: l10n.redesignCreateTitleLabel,
              child: TextField(
                key: const Key('rd-edit-title'),
                controller: _title,
                focusNode: _titleFocus,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                style: TextStyle(fontSize: 17, color: p.text),
                decoration: rdInputDecoration(p, type?.name ?? ''),
                onSubmitted: (_) => _titleFocus.unfocus(),
              ),
            ),
            RdListRow(
              key: const Key('rd-edit-type'),
              title: l10n.redesignCreateType,
              showChevron: false,
              trailing: type == null ? null : RdPill(type.name, tone: type.highlight ? RdTone.excused : RdTone.primary),
              onTap: () => _pickType(att, type),
            ),
            RdListRow(
              key: const Key('rd-edit-date'),
              title: l10n.redesignCreateDate,
              showChevron: false,
              trailing: RdValueBox(date == null ? '–' : DateFormat.yMMMEd(locale).format(date)),
              onTap: () => promptAttendanceDateChange(context, ref, _id, directPicker: true),
            ),
            if (allDay)
              RdListRow(
                title: l10n.redesignCreateDuration,
                showChevron: false,
                trailing: RdValueBox(l10n.redesignCreateDays(days)),
              )
            else
              RdListRow(
                title: l10n.redesignCreateTime,
                showChevron: false,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RdValueBox(
                      att.startTime ?? type?.startTime ?? '–',
                      semantics: l10n.redesignCreateStart,
                      // The Termin's type gives the times shown and checked.
                      onTap: typeReady ? () => _pickTime(att, type, start: true) : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text('–', style: TextStyle(color: p.text2)),
                    ),
                    RdValueBox(
                      att.endTime ?? type?.endTime ?? '–',
                      semantics: l10n.redesignCreateEnd,
                      error: rdEndBeforeStart(att.startTime ?? type?.startTime, att.endTime ?? type?.endTime),
                      onTap: typeReady ? () => _pickTime(att, type, start: false) : null,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildMembersSection(BuildContext context, Attendance att, AttendanceType? type) {
    final p = context.rd;
    final l10n = context.l10n;
    final history = ref.watch(realtimeAttendanceListProvider).valueOrNull ?? const <Attendance>[];
    final places = rdRecentPlaces(history).where((s) => s != _place.text.trim()).toList();
    final deadline = EventListUtils.deadlineLocal(att.deadline);
    final deadlineLocked = isDeadlineReadonly(att);
    final description = rdPlainText(att.description);
    final attachment = (att.attachmentName ?? '').trim();
    final folder = (att.filesFolder ?? '').trim();
    final canFiles = ref.watch(canAccessFilesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdGroupLabel(l10n.redesignEventForMembers),
        RdGroupedList(
          children: [
            if (type != null || (att.place ?? '').isNotEmpty)
              RdFieldRow(
                label: l10n.redesignCreatePlace,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      key: const Key('rd-edit-place'),
                      controller: _place,
                      focusNode: _placeFocus,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      style: TextStyle(fontSize: 17, color: p.text),
                      decoration: rdInputDecoration(p, l10n.redesignCreatePlaceHint),
                      onChanged: (_) => _update(() {}),
                      onSubmitted: (_) => _placeFocus.unfocus(),
                    ),
                    if (places.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final place in places)
                              RdPlaceChip(
                                place,
                                onTap: () {
                                  _update(() => _place.text = place);
                                  _savePlace();
                                },
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            RdListRow(
              key: const Key('rd-edit-deadline'),
              title: l10n.redesignCreateDeadline,
              subtitle: deadlineLocked ? l10n.redesignEventEditDeadlineLocked : null,
              value: deadline == null ? l10n.redesignCreateDeadlineNone : rdDeadlineLabel(deadline),
              onTap: deadlineLocked ? null : () => _pickDeadline(att, type),
            ),
            RdListRow(
              title: l10n.redesignEventDescription,
              subtitle: [if (description.isNotEmpty) description, if (attachment.isNotEmpty) attachment].join(' · '),
              onTap: () => showDescriptionAttachmentSheet(context, attendance: att),
            ),
            if (canFiles)
              RdListRow(
                title: l10n.attendanceFilesFolder,
                value: folder.isEmpty ? l10n.redesignEventEditFolderNone : folder,
                onTap: () => _pickFolder(att),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildLeadersSection(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdGroupLabel(l10n.redesignEventLeadersOnly),
        RdGroupedList(
          children: [
            RdFieldRow(
              label: l10n.attendanceNotes,
              child: TextField(
                key: const Key('rd-edit-notes'),
                controller: _notes,
                focusNode: _notesFocus,
                minLines: 2,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(fontSize: 17, color: p.text),
                decoration: rdInputDecoration(p, ''),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
