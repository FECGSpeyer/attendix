part of 'assistant_page.dart';

class _ReplyView extends ConsumerWidget {
  const _ReplyView({
    required this.reply,
    required this.index,
    required this.busy,
    required this.style,
    required this.seesOthers,
  });

  final AssistantReply reply;

  /// Position in the chat (for "Speichern" / "Rückgängig").
  final int index;
  final bool busy;
  final _ChatStyle style;
  final bool seesOthers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = TextStyle(color: style.text);
    final muted = TextStyle(color: style.muted, fontSize: 13);
    final title = TextStyle(color: style.text, fontWeight: FontWeight.w700, fontSize: 16);

    Widget link(String label, String location) => Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        style: TextButton.styleFrom(foregroundColor: style.accent, padding: EdgeInsets.zero),
        onPressed: () => context.push(location),
        icon: const Icon(Icons.open_in_new, size: 16),
        label: Text(label),
      ),
    );

    String eventLocation(int id) => RedesignRoutes.betaTarget('/attendance/$id');

    switch (reply) {
      case NoticeReply(:final notice, :final subject, :final count):
        final s = subject ?? '';
        return Text(switch (notice) {
          AssistantNotice.notUnderstood => l10n.assistantNoticeNotUnderstood,
          AssistantNotice.changeLater => l10n.assistantNoticeChangeLater,
          AssistantNotice.noRights => l10n.assistantNoticeNoRights,
          AssistantNotice.noOwnPerson => l10n.assistantNoticeNoOwnPerson,
          AssistantNotice.disabled => l10n.assistantNoticeDisabled,
          AssistantNotice.limit => l10n.assistantNoticeLimit,
          AssistantNotice.tooLong => l10n.assistantNoticeTooLong(assistantMaxTextLength),
          AssistantNotice.failed => l10n.assistantNoticeFailed,
          AssistantNotice.personNotFound => l10n.assistantNoticePersonNotFound(s),
          AssistantNotice.groupNotFound => l10n.assistantNoticeGroupNotFound(s),
          AssistantNotice.noEvent => l10n.assistantNoticeNoEvent,
          AssistantNotice.noData => l10n.assistantNoticeNoData,
          AssistantNotice.songNotFound => l10n.assistantNoticeSongNotFound(s),
          AssistantNotice.noHelp => l10n.assistantNoticeNoHelp,
          AssistantNotice.noBirthdays => l10n.assistantNoticeNoBirthdays,
          AssistantNotice.selfStatusNotAllowed => l10n.assistantNoticeSelfStatusNotAllowed,
          AssistantNotice.nothingToChange => l10n.assistantNoticeNothingToChange,
          AssistantNotice.tooManyChanges => l10n.assistantNoticeTooManyChanges(count ?? 0, assistantMaxChanges),
          AssistantNotice.absenceOutOfRange => l10n.assistantNoticeAbsenceOutOfRange,
          AssistantNotice.noAbsenceRights => l10n.assistantNoticeNoAbsenceRights,
          AssistantNotice.noType => l10n.assistantNoticeNoType,
          AssistantNotice.dateOutOfRange => l10n.assistantNoticeDateOutOfRange,
          AssistantNotice.eventLocked => l10n.assistantNoticeEventLocked,
          AssistantNotice.eventsExist => l10n.assistantNoticeEventsExist,
          AssistantNotice.noSongsForType => l10n.assistantNoticeNoSongsForType,
          AssistantNotice.songsNotFound => l10n.assistantNoticeSongsNotFound(s),
          AssistantNotice.excuseNeedsReason => l10n.assistantNoticeExcuseNeedsReason,
          AssistantNotice.noTasks => l10n.assistantNoticeNoTasks,
          AssistantNotice.noSongsYet => l10n.assistantNoticeNoSongsYet,
          AssistantNotice.taskDueOutOfRange => l10n.assistantNoticeTaskDueOutOfRange,
          AssistantNotice.noDuty => l10n.assistantNoticeNoDuty,
          AssistantNotice.dutyNotSelf => l10n.assistantNoticeDutyNotSelf,
          AssistantNotice.dutyNotMember => l10n.assistantNoticeDutyNotMember,
          AssistantNotice.dutyAlready => l10n.assistantNoticeDutyAlready,
          AssistantNotice.dutyFull => l10n.assistantNoticeDutyFull,
          AssistantNotice.noRecipients => l10n.assistantNoticeNoRecipients,
        }, style: text);

      case ChoiceReply(:final query, :final options, :final kind):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              kind == ChoiceKind.type ? l10n.assistantChoiceWhichType : l10n.assistantChoiceWhich(query),
              style: text,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final o in options)
                  ActionChip(
                    label: Text(o.label),
                    onPressed: () => ref.read(assistantChatNotifierProvider.notifier).choose(o.label, o.command),
                  ),
              ],
            ),
          ],
        );

      case RateReply r:
        final percent = r.rate.percent ?? 0;
        final color = percent >= 75 ? style.good : (percent >= 50 ? Colors.orange.shade700 : style.bad);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              r.isMe
                  ? l10n.assistantRateMe
                  : r.subjectName == null
                  ? l10n.assistantRateAll
                  : l10n.assistantRateOf(r.subjectName!),
              style: title,
            ),
            Text(l10n.assistantRateRange(_day(r.range.from), _day(r.range.to)), style: muted),
            if (r.typeName != null) Text(l10n.assistantRateOnlyType(r.typeName!), style: muted),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('$percent %', style: TextStyle(color: color, fontSize: 30, fontWeight: FontWeight.w800)),
                const SizedBox(width: 14),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: percent / 100,
                      minHeight: 10,
                      color: color,
                      backgroundColor: style.line,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(l10n.assistantRateDetail(r.rate.attended, r.rate.total), style: muted),
            if (r.lowest.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(l10n.assistantRateLowest, style: text.copyWith(fontWeight: FontWeight.w600)),
              for (final p in r.lowest)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [Expanded(child: Text(p.name, style: text)), Text('${p.percent} %', style: muted)],
                  ),
                ),
            ],
            if (r.personId != null && !r.isMe && seesOthers)
              link(
                l10n.assistantRateOpenPerson,
                RedesignRoutes.person(r.personId!),
              ),
          ],
        );

      case EventReply e:
        Widget cell(String s, {Color? color, bool bold = false}) => SizedBox(
          width: 58,
          child: Text(
            s,
            textAlign: TextAlign.end,
            style: TextStyle(color: color ?? style.text, fontWeight: bold ? FontWeight.w600 : null),
          ),
        );
        Widget head(IconData icon, String label, Color color) => SizedBox(
          width: 58,
          child: Align(
            alignment: Alignment.centerRight,
            child: Tooltip(message: label, child: Semantics(label: label, child: Icon(icon, size: 18, color: color))),
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(e.title, style: title),
            Text(
              e.startTime == null
                  ? _weekdayDate(e.date)
                  : '${_weekdayDate(e.date)} · ${l10n.assistantEventTime(_time(e.startTime!))}',
              style: muted,
            ),
            const SizedBox(height: 10),
            // Column heads as icons (any language fits), named for screen
            // readers and on long press.
            Row(
              children: [
                const Expanded(child: SizedBox()),
                head(Icons.check_circle, l10n.assistantEventPresent, style.good),
                head(Icons.cancel, l10n.assistantEventAbsent, style.bad),
                head(Icons.help, l10n.assistantEventOpen, style.muted),
              ],
            ),
            for (final g in e.groups)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(g.name, style: text, overflow: TextOverflow.ellipsis)),
                    cell('${g.present}'),
                    cell('${g.absent}'),
                    cell('${g.open}'),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            if (e.open.isEmpty)
              Text(l10n.assistantEventAllAnswered, style: muted)
            else ...[
              Text(l10n.assistantEventOpenNames, style: text.copyWith(fontWeight: FontWeight.w600)),
              Text(e.open.join(', '), style: muted),
            ],
            if (e.absent.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(l10n.assistantEventAbsentNames, style: text.copyWith(fontWeight: FontWeight.w600)),
              Text(e.absent.join(', '), style: muted),
            ],
            link(l10n.assistantEventOpenEvent, eventLocation(e.attendanceId)),
          ],
        );

      case NextEventReply n:
        final times = [
          if (n.startTime != null) _time(n.startTime!),
          if (n.endTime != null) _time(n.endTime!),
        ].join(' – ');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              n.tenantName == null ? l10n.assistantNextTitle : '${l10n.assistantNextTitle} · ${n.tenantName}',
              style: muted,
            ),
            Text(n.title, style: title),
            const SizedBox(height: 4),
            Text(_weekdayDate(n.date), style: text),
            if (times.isNotEmpty) Text(l10n.assistantEventTime(times), style: text),
            if ((n.place ?? '').isNotEmpty)
              Row(
                children: [
                  Icon(Icons.place_outlined, size: 16, color: style.muted),
                  const SizedBox(width: 4),
                  Flexible(child: Text(n.place!, style: muted)),
                ],
              ),
            if (n.tenantName == null)
              link(l10n.assistantEventOpenEvent, eventLocation(n.attendanceId)),
          ],
        );

      case BirthdaysReply b:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.assistantBirthdaysTitle, style: title),
            Text(l10n.assistantRateRange(_day(b.range.from), _day(b.range.to)), style: muted),
            const SizedBox(height: 8),
            for (final p in b.people)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Text('🎂 ', style: text),
                    Expanded(child: Text(p.name, style: text)),
                    Text(
                      '${DateFormat(dateFmt(DateFmtKind.dayMonth)).format(p.date)} · ${l10n.assistantBirthdaysAge(p.age)}',
                      style: muted,
                    ),
                  ],
                ),
              ),
          ],
        );

      case SongReply s:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.number == null ? s.name : '${s.number}. ${s.name}', style: title),
            const SizedBox(height: 4),
            Text(
              s.lastSung == null ? l10n.assistantSongNever : l10n.assistantSongLastSung(_weekdayDate(s.lastSung!)),
              style: text,
            ),
            link(l10n.assistantSongOpen, RedesignRoutes.work(s.songId)),
          ],
        );

      case StatusPreviewReply(:final plan, state: final st):
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

      case AbsencePreviewReply(:final plan, state: final st):
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

      case CreatePreviewReply(:final plan, state: final st):
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

      case MovePreviewReply(:final plan, state: final st):
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

      case SongsPreviewReply(:final plan, state: final st):
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

      case TasksReply(:final tasks):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.assistantTasksTitle, style: title),
            const SizedBox(height: 4),
            for (final t in tasks)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: InkWell(
                  onTap: () => context.push('/settings/tasks/${t.id}'),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        t.priority == 'high' ? Icons.priority_high : Icons.radio_button_unchecked,
                        size: 18,
                        color: t.priority == 'high' ? style.bad : style.muted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.title, style: text.copyWith(fontWeight: FontWeight.w600)),
                            if (t.dueDate != null || t.inProgress)
                              Text(
                                [
                                  if (t.dueDate != null && DateTime.tryParse(t.dueDate!) != null)
                                    l10n.assistantTasksDue(_day(DateTime.parse(t.dueDate!))),
                                  if (t.inProgress) l10n.assistantTasksInProgress,
                                ].join(' · '),
                                style: muted,
                              ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 18, color: style.muted),
                    ],
                  ),
                ),
              ),
          ],
        );

      case EventSongsReply r:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.assistantEventSongsTitle, style: muted),
            Text(r.title, style: title),
            Text(_weekdayDate(r.date), style: muted),
            const SizedBox(height: 8),
            for (final s in r.songs)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.music_note, size: 16, color: style.accent),
                    const SizedBox(width: 6),
                    Expanded(child: Text(s, style: text)),
                  ],
                ),
              ),
            if (r.linkToEvent && seesOthers) link(l10n.assistantEventOpenEvent, eventLocation(r.attendanceId)),
          ],
        );

      case TaskPreviewReply(:final plan, state: final st):
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

      case DutyPreviewReply(:final plan, state: final st):
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

      case PersonDraftReply p:
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

      case MessageDraftReply m:
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

      case ActionDoneReply d:
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

      case HelpReply h:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.assistantHelpTitle, style: title),
            for (final a in h.articles) link(a.title, '/settings/help/article/${a.id}'),
          ],
        );
    }
  }
}
