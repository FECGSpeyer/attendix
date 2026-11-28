part of 'event_page.dart';

/// "✓ 7 weitere anwesend · Zeigen" at the end of a voice.
class _MoreRow extends StatelessWidget {
  const _MoreRow({super.key, required this.text, required this.action, required this.onTap});

  /// null once the voice is open (only "Weniger").
  final String? text;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              if (text != null) ...[
                Icon(Icons.check_rounded, size: 18, color: p.present),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text!,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.present),
                  ),
                ),
              ] else
                const Spacer(),
              Text(action, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.link)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Überblick (concept "Termin-Bereich neu", Schritt 2): the card at the top
/// follows the phase of the Termin (Jetzt-Karte):
/// * vorher: Rückmeldungen, who signed out and why, "Offene erinnern";
/// * heute: the same with "Heute 19:30 · in 40 Min.", "Anwesenheit
///   eintragen", Pultmodus and Ablauf;
/// * läuft: Anwesenheit, "Anwesenheit eintragen", "Jetzt im Ablauf";
/// * danach: "35 von 38 · 92 %" and the Abschluss.
/// Below: Programm (opens the Reiter), Vorbereitung, "Für Mitglieder",
/// "Nur Leitung", Dienst and Protokoll.
/// "Vorbereitung" in the Überblick: always for the Leitung before the
/// Termin (empty with "+ Aufgabe"); afterwards only while tasks are open.
bool _showPrep(Attendance attendance, {required bool over, required bool canMutate, required bool canView}) {
  if (!canView) return false;
  final items = attendance.checklist ?? const <ChecklistItem>[];
  if (items.isNotEmpty) return !(over && items.every((c) => c.completed));
  return canMutate && !over && !attendance.archived;
}

class _Overview extends ConsumerWidget {
  const _Overview({
    required this.attendance,
    required this.type,
    required this.members,
    required this.personAttendanceIds,
    required this.span,
    required this.phase,
    this.sideBySide = false,
    required this.onRecord,
    required this.onPult,
    required this.onOpenMember,
  });

  final Attendance attendance;
  final AttendanceType? type;
  final List<RdMember> members;
  final Map<int, String?> personAttendanceIds;
  final ({DateTime start, DateTime end, bool hasTime})? span;
  final RdEventPhase phase;

  /// The Anwesenheit is next to it (desktop): no "Anwesenheit eintragen".
  final bool sideBySide;
  /// To the Anwesenheit, with the filter of a tapped count.
  final ValueChanged<RdRecordFilter> onRecord;
  final VoidCallback onPult;
  final ValueChanged<RdMember> onOpenMember;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final role = ref.watch(effectiveRoleProvider);
    final canViewNotes = ref.watch(canViewAttendanceNotesProvider);
    final canMutate = canMutateAttendanceDetail(role);
    final counts = RdStatusCounts.fromStatuses(members.map((m) => m.status));
    final ended = EventListUtils.hasEnded(attendance.date, _effectiveDays(attendance, type));
    final info = rdEventInfo(attendance, type);
    final start = info.start;
    final over = phase == RdEventPhase.after || (phase == RdEventPhase.archived && ended);
    final started = over || phase == RdEventPhase.running || (start != null && !DateTime.now().isBefore(start));
    final now = phase == RdEventPhase.today || phase == RdEventPhase.running;
    final gaps = started ? const <RdRegisterGap>[] : rdRegisterGaps(members);
    final notes = (attendance.notes ?? '').trim();
    final id = attendance.id;
    final hasPlan = attendanceHasPlan(attendance) && role != Role.viewer;
    // Until the list is there (or when it failed) the open answers count:
    // the sheet then says what went wrong.
    final toRemind = canMutate && !ended && counts.open > 0 && id != null
        ? ref.watch(rdOpenPersonsProvider(id)).valueOrNull?.length ?? counts.open
        : 0;

    // Before the start: answers; from the start on: who is there.
    final here = members.where((m) => m.status == AttendanceStatus.present).length;
    final late = members.where((m) => m.status == AttendanceStatus.late || m.status == AttendanceStatus.lateExcused).length;
    // Each number opens the Anwesenheit filtered to it (no arrows: the
    // card stays calm, the "›" at "eingeladen" shows it can be tapped).
    RdCounter counter(int value, String label, Color color, RdRecordFilter filter, {bool always = false}) => RdCounter(
          value,
          label,
          color,
          always: always,
          tapKey: Key('rd-event-count-${filter.name}'),
          onTap: () => onRecord(filter),
        );
    final answers = started
        ? [
            counter(here, l10n.redesignCountersHere, p.present, RdRecordFilter.present, always: true),
            counter(late, l10n.redesignCountersLate, p.late, RdRecordFilter.late),
            counter(counts.excused, l10n.redesignCountersExcused, p.excused, RdRecordFilter.excused),
            counter(counts.absent, l10n.redesignCountersAbsent, p.absent, RdRecordFilter.absent),
            counter(counts.open, l10n.redesignCountersNoAnswer, p.text, RdRecordFilter.open),
          ]
        : [
            counter(counts.present, l10n.redesignCountersYes, p.present, RdRecordFilter.yes, always: true),
            counter(counts.excused, l10n.redesignCountersExcused, p.excused, RdRecordFilter.excused),
            counter(counts.lateAnnounced, l10n.redesignCountersLater, p.late, RdRecordFilter.later),
            counter(counts.absent, l10n.redesignCountersAbsent, p.absent, RdRecordFilter.absent),
            counter(counts.open, l10n.redesignCountersNoAnswer, p.text, RdRecordFilter.open),
          ];
    final total = counts.total;
    final percent = total == 0 ? 0 : ((here + late) * 100 / total).round();
    final String title;
    final String side;
    if (!started) {
      title = l10n.redesignEventAnswers;
      side = l10n.redesignEventInvited(total);
    } else if (!over) {
      title = l10n.redesignEventTabRecord;
      side = l10n.redesignEventAttendancePersons(total);
    } else {
      title = l10n.redesignEventTabRecord;
      side = l10n.redesignEventPresentOf(here + late, total, percent);
    }
    // "Heute 19:30 · in 40 Min."
    final pill = phase == RdEventPhase.today ? rdPhasePill(l10n, phase, span: span) : null;
    final countdown = phase == RdEventPhase.today ? rdCountdown(l10n, start, hasTime: span?.hasTime ?? false) : null;
    final settled = over && counts.open == 0 && counts.absent == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (pill != null) ...[
                Text(
                  [pill.label, if (countdown != null) countdown].join(' · ').toUpperCase(),
                  key: const Key('rd-event-now-eyebrow'),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: p.late),
                ),
                const SizedBox(height: 6),
              ],
              // The whole list sits in the Anwesenheit.
              LayoutBuilder(
                builder: (context, constraints) {
                  final tight = constraints.maxWidth < 280 || MediaQuery.textScalerOf(context).scale(16) > 20;
                  return InkWell(
                    key: const Key('rd-event-answers-open'),
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => onRecord(RdRecordFilter.all),
                    child: tight
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(title, style: RdType.section(p))),
                                  Icon(Icons.chevron_right, size: 18, color: p.text2),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(side, style: RdType.meta(p, size: 13)),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(child: Text(title, style: RdType.section(p))),
                              Text(side, style: RdType.meta(p, size: 13)),
                              Icon(Icons.chevron_right, size: 18, color: p.text2),
                            ],
                          ),
                  );
                },
              ),
              const SizedBox(height: 8),
              // Numbers instead of the bar; a 0 is left out.
              RdStatusCounters(
                counters: answers,
                semanticLabel: [for (final c in answers) if (c.visible) '${c.value} ${c.label}'].join(', '),
              ),
              for (final gap in gaps) ...[
                const SizedBox(height: 12),
                _GapNote(gap: gap),
              ],
              // From the Termin day on: record, Pultmodus, Ablauf.
              if (now) ...[
                const SizedBox(height: 16),
                if (!sideBySide) ...[
                  RdPrimaryButton(
                    label: l10n.redesignEventRecord,
                    icon: Icons.checklist_rounded,
                    onPressed: () => onRecord(RdRecordFilter.all),
                  ),
                  const SizedBox(height: 10),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    RdPillButton(
                      key: const Key('rd-event-now-pult'),
                      icon: Icons.grid_view_rounded,
                      label: l10n.redesignPultOpen,
                      onPressed: onPult,
                    ),
                    if (hasPlan)
                      RdPillButton(
                        key: const Key('rd-event-now-plan'),
                        icon: Icons.view_timeline_outlined,
                        label: phase == RdEventPhase.running ? l10n.redesignEventPlanLive : l10n.redesignEventPlanSection,
                        onPressed: () => openAttendancePlanViewer(context, attendance),
                      ),
                  ],
                ),
              ],
              if (phase == RdEventPhase.running && hasPlan) ...[
                const SizedBox(height: 14),
                if (rdPlanOf(attendance) case final plan?) RdPlanNow(day: EventListUtils.parse(attendance.date), plan: plan),
              ],
              // Only Termin-Arten with "offen" (Zusage) have someone to remind.
              // The count is whom the sheet reminds (duty Termine skip
              // stand-ins, a Helfer only the own group).
              if (canMutate && !ended && toRemind > 0 && id != null) ...[
                SizedBox(height: now ? 10 : 16),
                RdOutlineButton(
                  key: const Key('rd-event-remind-open'),
                  label: '${l10n.redesignEventRemindOpen} ($toRemind)',
                  icon: Icons.notifications_none,
                  height: 44,
                  onPressed: () => showRdRemindOpenSheet(
                    context,
                    attendanceId: id,
                    title: info.title,
                    when: rdRemindWhen(start, hasTime: (attendance.startTime ?? type?.startTime)?.isNotEmpty ?? false),
                  ),
                ),
              ],
              if (!over)
                RdSignoutList(
                  members: members,
                  title: info.title,
                  showNote: canViewNotes,
                  started: started,
                  onOpen: onOpenMember,
                ),
              if (settled) ...[
                const SizedBox(height: 14),
                Row(
                  key: const Key('rd-event-settled'),
                  children: [
                    Icon(Icons.check_circle_outline, size: 18, color: p.present),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        [
                          l10n.redesignEventAllSettled,
                          if (!attendance.archived &&
                              canArchiveAttendance(
                                date: attendance.date,
                                durationDays: _effectiveDays(attendance, type),
                                archived: attendance.archived,
                                role: role,
                              ))
                            l10n.redesignEventArchiveHint,
                        ].join(' · '),
                        style: RdType.meta(p, size: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        // After the Termin: Unentschuldigte anschreiben, automatische Nachricht.
        if (over)
          RdEventClosingSection(
            attendance: attendance,
            type: type,
            members: members,
            personAttendanceIds: personAttendanceIds,
          ),
        // "Vorbereitung": always there for the Leitung before the Termin
        // (empty with "+ Aufgabe"); afterwards only while tasks are open.
        if (_showPrep(attendance, over: over, canMutate: canMutate, canView: ref.watch(canViewAttendanceChecklistProvider))) ...[
          const SizedBox(height: 24),
          RdEventChecklistSection(attendance: attendance, type: type, canEdit: canMutate),
        ],
        // "Werke": what is rehearsed or performed (below the Vorbereitung).
        if (rdShowsProgram(ref, type) && id != null) RdEventProgramSection(attendance: attendance, type: type, ended: over),
        RdEventInfoSection(attendance: attendance, title: l10n.redesignEventForMembers, ended: over),
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 24),
          RdGroupLabel(l10n.redesignEventLeadersOnly),
          RdCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.attendanceNotes, style: RdType.meta(p, size: 13)),
                const SizedBox(height: 4),
                Text(notes, style: RdType.body(p)),
              ],
            ),
          ),
        ],
        // Dienstplan "Besetzung" and Protokoll as on the Termin page.
        if (type != null && type!.dutyMode && id != null) ...[
          const SizedBox(height: 24),
          DutyStaffingSection(attendance: attendance, attendanceType: type!),
        ],
        if (id != null && (ref.watch(protocolTypeByIdProvider(attendance.typeId))?.enableProtocol ?? false)) ...[
          const SizedBox(height: 24),
          AttendanceProtocolSection(attendanceId: id, typeId: attendance.typeId),
        ],
      ],
    );
  }
}

/// "Trompete: 0 von 2 da. Max Huber, Jan Ott haben abgesagt."
class _GapNote extends StatelessWidget {
  const _GapNote({required this.gap});

  final RdRegisterGap gap;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: p.absentSoft, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: p.absent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: l10n.redesignEventRegisterEmpty(gap.group, gap.members.length),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: ' '),
                  TextSpan(
                    text: l10n.redesignEventRegisterNames(
                      gap.members.length,
                      gap.members.map((m) => m.name).join(', '),
                    ),
                  ),
                ],
              ),
              style: TextStyle(fontSize: 14, color: p.text),
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder of the answers card while the Termin loads: the title, the
/// counts the list already had and a fixed height, so the page does not
/// jump when the data arrives.
class _LoadingAnswers extends StatelessWidget {
  const _LoadingAnswers({required this.counts});

  final RdStatusCounts? counts;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final c = counts;
    return RdCard(
      key: const Key('rd-event-loading'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 92),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: Text(l10n.redesignEventAnswers, style: RdType.section(p))),
                if (c != null) Text(l10n.redesignEventInvited(c.total), style: RdType.meta(p, size: 13)),
              ],
            ),
            if (c != null) ...[
              const SizedBox(height: 8),
              RdStatusCounters(
                counters: rdAnswerCounters(context, c, openLabel: l10n.redesignCountersNoAnswer),
                semanticLabel: l10n.redesignTodayLoading,
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: p.text2),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.redesignTodayLoading,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RdType.meta(p, size: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
