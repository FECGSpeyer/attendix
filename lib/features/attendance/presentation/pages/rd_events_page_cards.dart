part of 'rd_events_page.dart';

/// Section header, event cards, and waiting-answer banner for [RdEventsPage].
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.section, required this.past});

  final RdEventSection<Object?> section;
  final bool past;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final month = section.month;
    final text =
        section.thisWeek
            ? (past ? l10n.redesignEventsLastWeek : l10n.redesignTodayThisWeek)
            : section.nextWeek
            ? l10n.rdTextNextWeek
            : DateFormat(month!.year == now.year ? 'MMMM' : 'MMMM y', currentIntlLocale()).format(month);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: RdGroupLabel(text),
    );
  }
}

bool _isToday(String? date, int? durationDays) => EventListUtils.isRunning(date, durationDays);

class _LeaderEventCard extends StatelessWidget {
  const _LeaderEventCard({
    required this.attendance,
    required this.type,
    required this.counts,
    required this.past,
    required this.onTap,
    this.own,
    this.orgName,
    this.selected = false,
  });

  final Attendance attendance;
  final AttendanceType? type;
  final RdStatusCounts? counts;

  /// The Helfer's own answer for this Termin (chip opens the answer sheet).
  final CrossTenantPersonAttendance? own;
  final bool past;
  final String? orgName;
  final VoidCallback? onTap;

  /// Open on the right of the split view.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final info = rdEventInfo(attendance, type);
    final days = rdEffectiveDurationDays(
      attendance.durationDays,
      typeAllDay: type?.allDay ?? false,
      typeDurationDays: type?.durationDays,
    );
    final today = !past && _isToday(attendance.date, days);
    final day = info.start == null || past ? '' : _dayWord(l10n, info.start!);
    final meta = [
      [day, info.timeRange].where((s) => s.isNotEmpty).join(' '),
      info.place,
    ].where((s) => s.isNotEmpty).join(' · ');
    final c = counts;
    final percentage = attendance.percentage;

    return RdCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      border: selected ? Border.all(color: p.primary, width: 2) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          RdEventDateBox(date: attendance.date, durationDays: days, highlight: today),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        info.title,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.text),
                      ),
                    ),
                    if (type != null && type!.name.isNotEmpty && type!.name != info.title) ...[
                      const SizedBox(width: 8),
                      // A long type name ellipsizes instead of overflowing the card.
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: RdPill(type!.name, tone: type!.highlight ? RdTone.excused : RdTone.primary),
                      ),
                    ],
                  ],
                ),
                if (meta.isNotEmpty || attendance.isOrgPlan) ...[
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (meta.isNotEmpty) Text(meta, style: RdType.meta(p, size: 13)),
                      if (attendance.isOrgPlan)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 160),
                          child: RdOrgPill(
                            orgName != null && orgName!.isNotEmpty ? orgName! : l10n.rdOrgBadge,
                            compact: true,
                          ),
                        ),
                    ],
                  ),
                ],
                if (!past && c != null && c.total > 0) ...[
                  const SizedBox(height: 8),
                  // Compact number-and-word pairs below the event details.
                  RdStatusCounters(
                    inline: true,
                    counters: rdAnswerCounters(context, c),
                    semanticLabel: _countsLine(l10n, c),
                  ),
                ],
                if (past && percentage != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    l10n.redesignEventsPercentPresent(percentage.round()),
                    style: RdType.meta(p, size: 12).copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
          if (own != null) ...[
            const SizedBox(width: 10),
            RdOwnStatusChip(attendance: own!, onTap: () => showRdOwnAnswerSheet(context, own!.id!)),
          ],
        ],
      ),
    );
  }

  static String _countsLine(AppLocalizations l10n, RdStatusCounts c) => [
    l10n.redesignTodayCountYes(c.present),
    if (c.excused > 0) l10n.redesignTodayCountExcused(c.excused),
    if (c.lateAnnounced > 0) l10n.redesignTodayCountLater(c.lateAnnounced),
    if (c.absent > 0) l10n.redesignTodayCountAbsent(c.absent),
    if (c.open > 0) l10n.redesignTodayCountOpen(c.open),
  ].join(' · ');
}

/// "Heute" / "Morgen" in the meta line, nothing for later days (the date
/// box shows them).
String _dayWord(AppLocalizations l10n, DateTime start) {
  final now = DateTime.now();
  final diff = rdDaysBetween(now, start);
  if (diff <= 0) return l10n.redesignTodayDayToday;
  if (diff == 1) return l10n.redesignTodayDayTomorrow;
  return '';
}

/// Own Termin; open ones show "Dabei" / "Abmelden" right in the card.
class _PlayerEventCard extends ConsumerStatefulWidget {
  const _PlayerEventCard({
    super.key,
    required this.att,
    required this.actions,
    required this.showAnswer,
  });

  final CrossTenantPersonAttendance att;
  final SelfServiceEventActions actions;
  final bool showAnswer;

  @override
  ConsumerState<_PlayerEventCard> createState() => _PlayerEventCardState();
}

class _PlayerEventCardState extends ConsumerState<_PlayerEventCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final att = widget.att;
    final actions = widget.actions;
    final own = actions.isOwn(att);
    final qa = actions.quickActions(att, anyLate: true);
    final today = !att.isPast && att.isRunning;
    final deadline =
        att.deadline != null && att.deadline!.isNotEmpty && !att.isPast
            ? EventListUtils.deadlineText(att.deadline)
            : '';
    final meta = [att.eventMeta(), if (widget.showAnswer) deadline].where((s) => s.isNotEmpty).join(' · ');
    final busy = _busy || ref.watch(signoutNotifierProvider).isLoading;

    return RdCard(
      padding: const EdgeInsets.all(14),
      onTap:
          () =>
              att.id != null && own
                  ? context.push(RedesignRoutes.ownEvent(att.id!))
                  : actions.presentActions(context, att),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              RdEventDateBox(date: att.date, durationDays: att.effectiveDurationDays, highlight: today),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      att.eventTitle,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.text),
                    ),
                    if (meta.isNotEmpty) Text(meta, style: RdType.meta(p, size: 13)),
                    // Ionic: hint of the instance below Termine without the person.
                    if (!own)
                      Text(
                        rdNotMemberInfo(ref.watch(currentTenantProvider)),
                        style: RdType.meta(p, size: 13).copyWith(fontStyle: FontStyle.italic),
                      ),
                  ],
                ),
              ),
              if (own && !widget.showAnswer) ...[
                const SizedBox(width: 8),
                rdOwnStatusPill(l10n, att.status),
              ],
            ],
          ),
          if (widget.showAnswer && qa != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: RdOutlineButton(
                    label: l10n.redesignEventsYes,
                    icon: Icons.check,
                    color: p.present,
                    height: 44,
                    onPressed: busy ? null : () => _run(() => actions.handleSigninWithFields(context, att)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RdOutlineButton(
                    label: l10n.redesignEventsNo,
                    height: 44,
                    onPressed:
                        busy || !qa.allowExcuse || qa.blocked
                            ? null
                            : () => _run(() => showRdSignoutSheet(context, att: att, actions: actions)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// "2 Termine warten auf deine Antwort" (tap: show only those).
class _WaitingBanner extends StatelessWidget {
  const _WaitingBanner({required this.count, required this.active, required this.onTap});

  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    return Semantics(
      button: true,
      selected: active,
      child: Material(
        color: p.lateSoft,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      active ? l10n.redesignEventsShowAll : l10n.redesignEventsWaiting(count),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.late),
                    ),
                  ),
                  Icon(active ? Icons.close : Icons.chevron_right, size: 18, color: p.late),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
