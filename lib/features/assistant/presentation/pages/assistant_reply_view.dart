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
        return _buildStatusPreview(context, plan, st);

      case AbsencePreviewReply(:final plan, state: final st):
        return _buildAbsencePreview(context, plan, st);

      case CreatePreviewReply(:final plan, state: final st):
        return _buildCreatePreview(context, plan, st);

      case MovePreviewReply(:final plan, state: final st):
        return _buildMovePreview(context, plan, st);

      case SongsPreviewReply(:final plan, state: final st):
        return _buildSongsPreview(context, plan, st);

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
        return _buildTaskPreview(context, plan, st);

      case DutyPreviewReply(:final plan, state: final st):
        return _buildDutyPreview(context, plan, st);

      case PersonDraftReply p:
        return _buildPersonDraft(context, p);

      case MessageDraftReply m:
        return _buildMessageDraft(context, m);

      case ActionDoneReply d:
        return _buildActionDone(context, ref, d, link, eventLocation);

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
