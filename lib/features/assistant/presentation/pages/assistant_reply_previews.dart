part of 'assistant_page.dart';

/// Action preview, draft, and done-confirmation cards for [_ReplyView].
extension _ReplyViewPreviews on _ReplyView {
  Widget _buildStatusPreview(BuildContext context, StatusPlan plan, ActionState st) {
    final l10n = context.l10n;
    final text = TextStyle(color: style.text);
    final muted = TextStyle(color: style.muted, fontSize: 13);
    final title = TextStyle(color: style.text, fontWeight: FontWeight.w700, fontSize: 16);
    const shown = 8;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          plan.parents
              ? l10n.assistantChangeTitleChildren
              : plan.self
              ? l10n.assistantChangeTitleSelf
              : l10n.assistantChangeTitleOthers,
          style: title,
        ),
        const SizedBox(height: 4),
        _StatusChip(status: plan.status, style: style),
        if (plan.reason != null) ...[
          const SizedBox(height: 4),
          Text(l10n.assistantChangeReason(plan.reason!), style: muted),
        ],
        const SizedBox(height: 8),
        for (final c in plan.changes.take(shown))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    plan.self
                        ? (plan.spansGroups && c.tenantName != null ? '${c.tenantName} · ${c.title}' : c.title)
                        : '${c.personName} · ${c.title}',
                    style: text,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                const SizedBox(width: 8),
                Text(_day(c.date), style: muted),
              ],
            ),
          ),
        if (plan.changes.length > shown)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(l10n.assistantChangeMore(plan.changes.length - shown), style: muted),
          ),
        if (plan.skippedLocked > 0) ...[
          const SizedBox(height: 6),
          Text(l10n.assistantChangeSkippedLocked(plan.skippedLocked), style: muted),
        ],
        if (plan.skippedWindow > 0) ...[
          const SizedBox(height: 6),
          Text(l10n.assistantChangeSkippedWindow(plan.skippedWindow), style: muted),
        ],
        if ((plan.self || plan.parents) && plan.status != AttendanceStatus.present) ...[
          const SizedBox(height: 6),
          Text(l10n.assistantChangeNotifyHint, style: muted),
        ],
        const SizedBox(height: 10),
        _ActionButtons(index: index, state: st, busy: busy, count: plan.changes.length, style: style),
      ],
    );
  }

  Widget _buildAbsencePreview(BuildContext context, AbsencePlan plan, ActionState st) {
    final l10n = context.l10n;
    final text = TextStyle(color: style.text);
    final muted = TextStyle(color: style.muted, fontSize: 13);
    final title = TextStyle(color: style.text, fontWeight: FontWeight.w700, fontSize: 16);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.assistantAbsenceTitle, style: title),
        Text(plan.isMe ? l10n.assistantAbsenceForMe : l10n.assistantAbsenceForPerson(plan.personName), style: text),
        Text(l10n.assistantRateRange(_day(plan.from), _day(plan.to)), style: text),
        Text(l10n.assistantChangeReason(plan.reason), style: muted),
        const SizedBox(height: 6),
        Text(l10n.assistantAbsenceAffected(plan.affected), style: muted),
        if (plan.isMe && plan.affected > 0) Text(l10n.assistantChangeNotifyHint, style: muted),
        const SizedBox(height: 10),
        _ActionButtons(index: index, state: st, busy: busy, count: 1, style: style),
      ],
    );
  }

  Widget _buildCreatePreview(BuildContext context, CreatePlan plan, ActionState st) {
    final l10n = context.l10n;
    final text = TextStyle(color: style.text);
    final muted = TextStyle(color: style.muted, fontSize: 13);
    final title = TextStyle(color: style.text, fontWeight: FontWeight.w700, fontSize: 16);
    const shown = 8;
    final times = [
      if ((plan.startTime ?? plan.type.startTime) != null) _time(plan.startTime ?? plan.type.startTime!),
      if ((plan.endTime ?? plan.type.endTime) != null) _time(plan.endTime ?? plan.type.endTime!),
    ].join(' – ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.assistantCreateTitle(plan.days.length), style: title),
        Text(
          plan.title == null ? plan.type.name : '${plan.type.name} · ${plan.title}',
          style: text.copyWith(fontWeight: FontWeight.w600),
        ),
        if (times.isNotEmpty) Text(l10n.assistantEventTime(times), style: muted),
        if (plan.place != null) Text(l10n.assistantCreatePlace(plan.place!), style: muted),
        const SizedBox(height: 6),
        for (final d in plan.days.take(shown))
          Padding(padding: const EdgeInsets.only(top: 3), child: Text(_weekdayDate(d), style: text)),
        if (plan.days.length > shown)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(l10n.assistantChangeMore(plan.days.length - shown), style: muted),
          ),
        if (plan.skippedExisting.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(l10n.assistantCreateSkippedExisting(plan.skippedExisting.length), style: muted),
        ],
        if (plan.skippedWindow > 0) ...[
          const SizedBox(height: 6),
          Text(l10n.assistantCreateSkippedWindow(plan.skippedWindow), style: muted),
        ],
        const SizedBox(height: 10),
        _ActionButtons(index: index, state: st, busy: busy, count: plan.days.length, style: style),
      ],
    );
  }

  Widget _buildMovePreview(BuildContext context, MovePlan plan, ActionState st) {
    final l10n = context.l10n;
    final text = TextStyle(color: style.text);
    final muted = TextStyle(color: style.muted, fontSize: 13);
    final title = TextStyle(color: style.text, fontWeight: FontWeight.w700, fontSize: 16);
    String when(DateTime day, String? start, String? end) {
      final t = [if (start != null) start, if (end != null) end].join(' – ');
      return t.isEmpty ? _weekdayDate(day) : '${_weekdayDate(day)} · ${l10n.assistantEventTime(t)}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.assistantMoveTitle, style: title),
        Text(plan.title, style: text.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(l10n.assistantMoveFrom(when(plan.oldDay, plan.oldStart, plan.oldEnd)), style: muted),
        Text(
          l10n.assistantMoveTo(when(plan.newDay, plan.newStart, plan.newEnd)),
          style: text.copyWith(fontWeight: FontWeight.w600),
        ),
        if (plan.movesDay) ...[const SizedBox(height: 6), Text(l10n.assistantMoveHint, style: muted)],
        const SizedBox(height: 10),
        _ActionButtons(index: index, state: st, busy: busy, count: 1, style: style),
      ],
    );
  }

  Widget _buildSongsPreview(BuildContext context, SongsPlan plan, ActionState st) {
    final l10n = context.l10n;
    final text = TextStyle(color: style.text);
    final muted = TextStyle(color: style.muted, fontSize: 13);
    final title = TextStyle(color: style.text, fontWeight: FontWeight.w700, fontSize: 16);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.assistantSongsTitle, style: title),
        Text('${plan.title} · ${_day(plan.date)}', style: muted),
        const SizedBox(height: 6),
        if (plan.added.isNotEmpty) Text(l10n.assistantSongsAdded(plan.added.join(', ')), style: text),
        if (plan.removed.isNotEmpty) Text(l10n.assistantSongsRemoved(plan.removed.join(', ')), style: text),
        if (plan.notFound.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(l10n.assistantSongsNotFound(plan.notFound.join(', ')), style: muted),
        ],
        const SizedBox(height: 10),
        _ActionButtons(index: index, state: st, busy: busy, count: 1, style: style),
      ],
    );
  }

  Widget _buildTaskPreview(BuildContext context, TaskPlan plan, ActionState st) {
    final l10n = context.l10n;
    final text = TextStyle(color: style.text);
    final muted = TextStyle(color: style.muted, fontSize: 13);
    final title = TextStyle(color: style.text, fontWeight: FontWeight.w700, fontSize: 16);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.assistantTaskTitle, style: title),
        Text(plan.title, style: text.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          plan.personName == null
              ? l10n.assistantTaskNobody
              : plan.isMe
              ? l10n.assistantTaskForMe
              : l10n.assistantTaskFor(plan.personName!),
          style: text,
        ),
        if (plan.dueDate != null && DateTime.tryParse(plan.dueDate!) != null)
          Text(l10n.assistantTaskDue(_weekdayDate(DateTime.parse(plan.dueDate!))), style: text),
        Text(l10n.assistantTaskPriority(_priority(l10n, plan.priority)), style: muted),
        if (plan.personName != null && !plan.isMe) ...[
          const SizedBox(height: 6),
          Text(l10n.assistantTaskNotifyHint(plan.personName!), style: muted),
        ],
        const SizedBox(height: 10),
        _ActionButtons(index: index, state: st, busy: busy, count: 1, style: style),
      ],
    );
  }

  Widget _buildDutyPreview(BuildContext context, DutyPlan plan, ActionState st) {
    final l10n = context.l10n;
    final text = TextStyle(color: style.text);
    final muted = TextStyle(color: style.muted, fontSize: 13);
    final title = TextStyle(color: style.text, fontWeight: FontWeight.w700, fontSize: 16);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.assistantDutyTitle, style: title),
        Text(plan.title, style: text.copyWith(fontWeight: FontWeight.w600)),
        Text(
          plan.startTime == null
              ? _weekdayDate(plan.date)
              : '${_weekdayDate(plan.date)} · ${l10n.assistantEventTime(_time(plan.startTime!))}',
          style: muted,
        ),
        const SizedBox(height: 4),
        Text(l10n.assistantDutyPlaces(plan.occupied, plan.required), style: muted),
        const SizedBox(height: 6),
        Text(l10n.assistantDutyHint, style: muted),
        const SizedBox(height: 10),
        _ActionButtons(index: index, state: st, busy: busy, count: 1, style: style),
      ],
    );
  }

  Widget _buildPersonDraft(BuildContext context, PersonDraftReply p) {
    final l10n = context.l10n;
    final text = TextStyle(color: style.text);
    final muted = TextStyle(color: style.muted, fontSize: 13);
    final title = TextStyle(color: style.text, fontWeight: FontWeight.w700, fontSize: 16);
    final name = [p.firstName, if (p.lastName != null) p.lastName!].join(' ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.assistantPersonTitle, style: title),
        Text(name, style: text.copyWith(fontWeight: FontWeight.w600)),
        if (p.groupName != null) Text(l10n.assistantPersonGroup(p.groupName!), style: text),
        if (p.birthday != null) Text(l10n.assistantPersonBirthday(_day(p.birthday!)), style: text),
        if (p.missingGroup != null) ...[
          const SizedBox(height: 4),
          Text(l10n.assistantPersonMissingGroup(p.missingGroup!), style: muted),
        ],
        const SizedBox(height: 6),
        Text(l10n.assistantPersonHint, style: muted),
        const SizedBox(height: 10),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: style.accent, foregroundColor: style.onAccent),
          onPressed:
              () => context.push(
                RedesignRoutes.personNew,
                extra: PersonCreatePrefill(
                  firstName: p.firstName,
                  lastName: p.lastName,
                  groupId: p.groupId,
                  birthday: p.birthday,
                ),
              ),
          icon: const Icon(Icons.edit_note, size: 18),
          label: Text(l10n.assistantPersonOpen),
        ),
      ],
    );
  }

  Widget _buildMessageDraft(BuildContext context, MessageDraftReply m) {
    final l10n = context.l10n;
    final text = TextStyle(color: style.text);
    final muted = TextStyle(color: style.muted, fontSize: 13);
    final title = TextStyle(color: style.text, fontWeight: FontWeight.w700, fontSize: 16);
    final draftTitle = _draftTitle(l10n, m);
    final draftBody = _draftBody(l10n, m);
    final to = m.groupName ?? l10n.assistantMessageToAll;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.assistantMessageTitle, style: title),
        Text(l10n.assistantMessageTo(m.playerIds.length, to), style: text),
        if (m.onlyOpen) Text(l10n.assistantMessageOnlyOpen, style: muted),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(border: Border.all(color: style.line), borderRadius: BorderRadius.circular(10)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(draftTitle, style: text.copyWith(fontWeight: FontWeight.w600)),
              if (draftBody.isNotEmpty) ...[const SizedBox(height: 4), Text(draftBody, style: text)],
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(l10n.assistantMessageHint, style: muted),
        const SizedBox(height: 10),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: style.accent, foregroundColor: style.onAccent),
          onPressed:
              () => openMessageCompose(
                context,
                preset: MessageComposePreset(
                  playerIds: m.playerIds,
                  recipientsLabel: l10n.assistantMessageTo(m.playerIds.length, to),
                  title: draftTitle,
                  content: textToDoc(draftBody),
                ),
              ),
          icon: const Icon(Icons.edit_note, size: 18),
          label: Text(l10n.assistantMessageOpen),
        ),
      ],
    );
  }

  Widget _buildActionDone(
    BuildContext context,
    WidgetRef ref,
    ActionDoneReply d,
    Widget Function(String label, String location) link,
    String Function(int id) eventLocation,
  ) {
    final l10n = context.l10n;
    final text = TextStyle(color: style.text);
    final muted = TextStyle(color: style.muted, fontSize: 13);
    final notifier = ref.read(assistantChatNotifierProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              d.undo == UndoState.undone ? Icons.undo : Icons.check_circle,
              size: 20,
              color: d.undo == UndoState.undone ? style.muted : style.good,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                d.absencePlan != null
                    ? '${l10n.assistantAbsenceDone} ${l10n.assistantChangeDone(d.count)}'
                    : d.createPlan != null
                    ? l10n.assistantCreateDone(d.count)
                    : d.movePlan != null
                    ? l10n.assistantMoveDone
                    : d.songsPlan != null
                    ? l10n.assistantSongsDone
                    : d.taskPlan != null
                    ? l10n.assistantTaskDone
                    : d.dutyPlan != null
                    ? l10n.assistantDutyDone
                    : l10n.assistantChangeDone(d.count),
                style: text.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        if (d.createPlan != null && d.undo == UndoState.available) ...[
          const SizedBox(height: 4),
          Text(l10n.assistantCreateUndoHint, style: muted),
        ],
        const SizedBox(height: 6),
        if (d.taskPlan?.personName != null && d.undo != UndoState.undone)
          switch (d.notify) {
            NotifyState.none => const SizedBox.shrink(),
            NotifyState.available => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: style.accent, foregroundColor: style.onAccent),
                onPressed: busy || d.undo != UndoState.available ? null : () => notifier.notifyTask(index),
                icon: const Icon(Icons.notifications_active_outlined, size: 18),
                label: Text(l10n.assistantTaskNotify(d.taskPlan!.personName!)),
              ),
            ),
            NotifyState.working => Text(l10n.assistantChangeSaving, style: muted),
            NotifyState.sent => Text(l10n.assistantTaskNotified(d.taskPlan!.personName!), style: muted),
            NotifyState.failed => Text(l10n.assistantTaskNotifyFailed, style: TextStyle(color: style.bad)),
          },
        switch (d.undo) {
          UndoState.available => Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: style.accent),
              onPressed: busy || d.notify == NotifyState.working ? null : () => notifier.undo(index),
              icon: const Icon(Icons.undo, size: 18),
              label: Text(l10n.assistantChangeUndo),
            ),
          ),
          UndoState.working => Text(l10n.assistantChangeSaving, style: muted),
          UndoState.undone => Text(l10n.assistantChangeUndone, style: muted),
          UndoState.failed => Text(l10n.assistantChangeUndoFailed, style: TextStyle(color: style.bad)),
        },
        if (d.statusPlan != null && d.statusPlan!.changes.isNotEmpty && !d.statusPlan!.self && seesOthers)
          link(l10n.assistantEventOpenEvent, eventLocation(d.statusPlan!.changes.first.attendanceId)),
        if (d.undo != UndoState.undone && seesOthers)
          if (d.movePlan != null)
            link(l10n.assistantEventOpenEvent, eventLocation(d.movePlan!.attendanceId))
          else if (d.songsPlan != null)
            link(l10n.assistantEventOpenEvent, eventLocation(d.songsPlan!.attendanceId))
          else if (d.createdIds.length == 1)
            link(l10n.assistantEventOpenEvent, eventLocation(d.createdIds.first)),
        if (d.taskId != null && d.undo != UndoState.undone)
          link(l10n.assistantTaskOpen, '/settings/tasks/${d.taskId}'),
      ],
    );
  }
}
