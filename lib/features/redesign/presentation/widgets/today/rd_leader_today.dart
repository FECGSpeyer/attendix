import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/enums.dart';
import '../../../../../core/providers/attendance_type_providers.dart';
import '../../../../../core/providers/dashboard_providers.dart';
import '../../../../../core/providers/player_providers.dart';
import '../../../../../core/providers/realtime_providers.dart';
import '../../../../../core/providers/role_permission_providers.dart';
import '../../../../../core/providers/tenant_providers.dart';
import '../../../../../core/router/redesign_routes.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../core/utils/dashboard_utils.dart' show BirthdayEntry;
import '../../../../../core/utils/event_list_utils.dart';
import '../../../../../data/models/attendance/attendance.dart';
import '../../../../../data/models/person/person.dart';
import '../../../../../l10n/l10n.dart';
import '../../../data/providers/rd_events_providers.dart' show rdAttendanceDurationDays, rdSortStartOf, rdUnrecordedProvider;
import '../../../data/providers/rd_today_providers.dart';
import '../../../data/rd_event_details_logic.dart';
import '../../../data/rd_event_phase.dart' show rdEventSpan;
import '../manage/rd_manage_list.dart' show rdLoadedValue;
import '../rd_desktop.dart';
import '../rd_widgets.dart';
import 'rd_player_today.dart';
import 'rd_remind_open_sheet.dart';
import 'rd_today_common.dart';
import 'rd_duty_section.dart';

/// REDESIGN: "Heute" of Dirigent, Verantwortlich, Beobachter and Helfer
/// (canvas D1, R3): next Termin with its answers, what needs attention,
/// upcoming birthdays.
class RdLeaderToday extends ConsumerWidget {
  const RdLeaderToday({super.key, required this.role});

  final Role role;

  /// Upcoming Termine (not ended), soonest first, without the type filter
  /// of the Termin list.
  static List<Attendance> upcomingOf(List<Attendance> all,
      {DateTime? now, List<AttendanceType> types = const []}) {
    final current = now ?? DateTime.now();
    final upcoming = all
        .where((a) => !EventListUtils.hasEnded(a.date, rdAttendanceDurationDays(a, types), now: current))
        .toList();
    DateTime keyOf(Attendance a) => rdSortStartOf(a, types) ?? DateTime(9999);
    upcoming.sort((a, b) => keyOf(a).compareTo(keyOf(b)));
    return upcoming;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final listAsync = ref.watch(realtimeAttendanceListProvider);
    final isLead = role.isAdmin || role.isResponsible;

    final all = listAsync.valueOrNull;
    if (all == null) {
      if (listAsync.hasError) {
        return RdInfoCard(
          text: l10n.redesignTodayLoadFailed,
          icon: Icons.error_outline,
          action: RdOutlineButton(
            label: l10n.redesignCommonRetry,
            onPressed: () => ref.read(attendanceRefetchCounter.notifier).state++,
          ),
        );
      }
      return RdInfoCard(text: l10n.redesignTodayLoading, loading: true);
    }

    final types = ref.watch(attendanceTypesProvider).valueOrNull ?? const <AttendanceType>[];
    final upcoming = upcomingOf(all, types: types);
    final next = upcoming.firstOrNull;

    final nextCard = <Widget>[
      // UX V1: Beobachter cannot open Termine (Ionic); say so once
      // instead of rows that look tappable.
      if (role.isViewer) ...[
        RdInfoCard(text: l10n.redesignTodayViewerHint, icon: Icons.info_outline),
        const SizedBox(height: 16),
      ],
      if (next == null)
        RdInfoCard(
          text: l10n.redesignTodayNoUpcoming,
          icon: Icons.event_available_outlined,
          action: RdOutlineButton(
            label: l10n.redesignTodayAllEvents,
            onPressed: () => context.go(RedesignRoutes.events),
          ),
        )
      else
        _NextEventCard(attendance: next, canOpen: role.canAddAttendance, canRemind: isLead),
    ];
    final own = <Widget>[
      if (role.canSeeSelfServiceTab) ...[
        const SizedBox(height: 24),
        const RdOwnAnswerSection(),
        const RdDutySection(),
      ],
    ];
    // The week list was dropped from Heute (it mostly repeated the next
    // Termin, the Termine tab shows the rest); only upcoming birthdays stay.
    final birthday = isLead ? _birthdayLine(context, ref) : null;
    final birthdaySection = <Widget>[
      if (birthday != null) RdInfoCard(text: birthday, icon: Icons.cake_outlined),
    ];

    // Desktop: the next Termin on the left, what needs attention and
    // birthdays on the right (canvas "Beta: Desktop-UX").
    if (rdTodayColumns(context)) {
      return RdDesktopColumns(
        minWidth: 0,
        left: [...nextCard, ...own],
        right: [
          if (isLead) _AttentionSection(next: next, padding: const EdgeInsets.only(bottom: 24)),
          ...birthdaySection,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...nextCard,
        if (isLead) _AttentionSection(next: next),
        ...own,
        if (birthdaySection.isNotEmpty) ...[
          const SizedBox(height: 24),
          ...birthdaySection,
        ],
      ],
    );
  }

  /// "Geburtstag: Lea (morgen)" or "Geburtstage: Lea (morgen), Jonas (Sa 14.11.)" for
  /// the coming 7 days.
  String? _birthdayLine(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final birthdays = ref.watch(dashboardBirthdaysProvider).valueOrNull ?? const [];
    final soon = birthdays.where((b) => b.daysOffset >= 0 && b.daysOffset <= 7).toList()
      ..sort((a, b) => a.daysOffset.compareTo(b.daysOffset));
    if (soon.isEmpty) return null;
    // Always upcoming (0–7 days): "heute", "morgen" or "Do 12.11." so it
    // never reads like last week's Thursday.
    final locale = currentIntlLocale();
    String day(BirthdayEntry b) => switch (b.daysOffset) {
          0 => l10n.redesignPersonToday,
          1 => l10n.redesignPersonTomorrow,
          _ => '${DateFormat.E(locale).format(b.date).replaceAll('.', '')} '
              '${DateFormat.Md(locale).format(b.date)}',
        };
    if (soon.length == 1) return l10n.redesignTodayBirthday(soon.first.person.firstName, day(soon.first));
    return l10n.redesignTodayBirthdays(
      soon.map((b) => '${b.person.firstName} (${day(b)})').join(', '),
    );
  }

}

class _NextEventCard extends ConsumerWidget {
  const _NextEventCard({required this.attendance, required this.canOpen, this.canRemind = false});

  final Attendance attendance;

  /// Dirigent and Verantwortlich: "6 offen" opens the reminder (UX D2).
  final bool canRemind;

  /// Beobachter only see the list, not the Termin (route guard).
  final bool canOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final type = ref.watch(rdAttendanceTypeProvider(attendance.typeId));
    final info = rdEventInfo(attendance, type);
    final id = attendance.id;
    final counts = id == null ? null : ref.watch(rdAttendanceCountsProvider(id)).valueOrNull;
    // The link counts exactly whom the remind sheet asks (duty Termine skip
    // stand-ins, a Helfer only the own group), not every open answer.
    final toRemind = canRemind && id != null && (counts?.open ?? 0) > 0
        ? ref.watch(rdOpenPersonsProvider(id)).valueOrNull?.length ?? 0
        : 0;
    final hasTime = (attendance.startTime ?? type?.startTime)?.isNotEmpty ?? false;
    final countdown = rdCountdown(l10n, info.start, hasTime: hasTime);
    final meta = [info.timeRange, info.place].where((s) => s.isNotEmpty).join(' · ');

    return RdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: RdEyebrow(
                  '${l10n.redesignTodayNextEvent} · '
                  '${info.start == null ? '' : rdRelativeDay(l10n, info.start!)}',
                ),
              ),
              if (countdown != null) RdPill(countdown, tone: RdTone.primary),
            ],
          ),
          const SizedBox(height: 8),
          Semantics(
            header: true,
            child: Text(info.title, style: RdType.cardTitle(p)),
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(meta, style: RdType.meta(p, size: 15)),
          ],
          const SizedBox(height: 16),
          if (counts != null) ...[
            RdStatusBar(
              total: counts.total,
              segments: [
                RdBarSegment(counts.present, p.present),
                RdBarSegment(counts.lateAnnounced, p.late),
                RdBarSegment(counts.excused, p.excused),
                RdBarSegment(counts.absent, p.absent),
              ],
              semanticLabel: _countsLine(l10n, counts),
            ),
            const SizedBox(height: 8),
            if (id != null && toRemind > 0)
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('${_countsLine(l10n, counts, withOpen: false)} · ', style: RdType.meta(p, size: 13)),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => showRdRemindOpenSheet(
                      context,
                      attendanceId: id,
                      title: info.title,
                      when: rdRemindWhen(info.start, hasTime: hasTime),
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 32),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.redesignRemindOpenLink(toRemind),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: p.link,
                              decoration: TextDecoration.underline,
                              decorationColor: p.link,
                            ),
                          ),
                          Icon(Icons.chevron_right, size: 16, color: p.link),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            else
              Text(_countsLine(l10n, counts), style: RdType.meta(p, size: 13)),
            const SizedBox(height: 16),
          ],
          if (id != null && canOpen)
            SizedBox(
              width: double.infinity,
              child: RdPrimaryButton(
                label: l10n.redesignTodayRecord,
                icon: Icons.checklist_rounded,
                onPressed: () => context.push(RedesignRoutes.event(id, record: true)),
              ),
            ),
        ],
      ),
    );
  }

  static String _countsLine(AppLocalizations l10n, RdStatusCounts c, {bool withOpen = true}) => [
        l10n.redesignTodayCountYes(c.present),
        if (c.excused > 0) l10n.redesignTodayCountExcused(c.excused),
        if (c.lateAnnounced > 0) l10n.redesignTodayCountLater(c.lateAnnounced),
        if (c.absent > 0) l10n.redesignTodayCountAbsent(c.absent),
        if (withOpen) l10n.redesignTodayCountOpen(c.open),
      ].join(' · ');
}

/// "Braucht deine Aufmerksamkeit" (Dirigent, Verantwortlich): new
/// registrations, critical members, sign-outs for the next Termin.
class _AttentionSection extends ConsumerWidget {
  const _AttentionSection({required this.next, this.padding = const EdgeInsets.only(top: 24)});

  /// Space around the section (below it when it opens a desktop column).
  final EdgeInsets padding;

  final Attendance? next;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final pending = ref.watch(pendingPlayersProvider).valueOrNull?.length ?? 0;
    // Same set as the Problemfälle filter of Mitglieder: active only. Only
    // loaded people of this group: no names from before a group switch.
    final tenantId = ref.watch(currentTenantProvider)?.id;
    final criticalPeople =
        rdLoadedValue(ref.watch(criticalPlayersProvider))?.where((x) => !x.paused && x.tenantId == tenantId).toList() ??
        const <Person>[];
    final critical = criticalPeople.length;
    final nextId = next?.id;
    final unrecorded = ref.watch(rdUnrecordedProvider).valueOrNull ?? const <int>[];
    final excused = nextId == null
        ? 0
        : ref.watch(rdAttendanceCountsProvider(nextId)).valueOrNull?.excused ?? 0;
    // Vorbereitung tasks due within a day or overdue (Termine still ahead).
    final types = ref.watch(attendanceTypesProvider).valueOrNull ?? const <AttendanceType>[];
    final prep = ref.watch(canViewAttendanceChecklistProvider)
        ? rdDuePrepTasks(
            (ref.watch(realtimeAttendanceListProvider).valueOrNull ?? const <Attendance>[]).where(
              (a) => a.id != null && !a.archived && !_eventOver(a, types),
            ),
          )
        : const <({Attendance attendance, ChecklistItem item})>[];
    final prepOverdue = prep.any((t) => rdChecklistDue(t.item) == RdDue.overdue);

    final rows = <Widget>[
      if (pending > 0)
        RdListRow(
          leading: RdRowIcon(Icons.person_add_alt_1_outlined, color: p.primary, background: p.soft),
          title: l10n.redesignTodayPending(pending),
          subtitle: l10n.redesignTodayPendingHint,
          trailing: RdCountBadge(pending),
          onTap: () => context.push(RedesignRoutes.approvalsFrom('heute')),
        ),
      if (critical > 0)
        RdListRow(
          leading: RdRowIcon(Icons.warning_amber_rounded, color: p.absent, background: p.absentSoft),
          title: l10n.redesignTodayCritical(critical),
          subtitle: _criticalNames(l10n, criticalPeople),
          trailing: RdCountBadge(critical, tone: RdTone.absent),
          // The Problemfälle as a pushed list: back returns to "Heute".
          onTap: () => context.push(RedesignRoutes.criticalMembers(from: 'heute')),
        ),
      if (unrecorded.isNotEmpty)
        RdListRow(
          leading: RdRowIcon(Icons.edit_note_rounded, color: p.late, background: p.lateSoft),
          title: l10n.redesignTodayUnrecorded(unrecorded.length),
          subtitle: _unrecordedLine(ref, unrecorded),
          trailing: RdCountBadge(unrecorded.length, tone: RdTone.late),
          // Newest first: the one most likely still to be recorded.
          onTap: () => context.push(RedesignRoutes.event(unrecorded.last, record: true)),
        ),
      if (prep.isNotEmpty)
        RdListRow(
          key: const Key('rd-today-prep'),
          leading: RdRowIcon(
            Icons.task_alt_rounded,
            color: prepOverdue ? p.absent : p.late,
            background: prepOverdue ? p.absentSoft : p.lateSoft,
          ),
          title: l10n.redesignTodayPrepDue(prep.length),
          subtitle: _prepLine(ref, prep.first),
          trailing: RdCountBadge(prep.length, tone: prepOverdue ? RdTone.absent : RdTone.late),
          // The most urgent one: its Termin shows the Vorbereitung in the Überblick.
          onTap: () => context.push(RedesignRoutes.event(prep.first.attendance.id!)),
        ),
      if (excused > 0 && nextId != null)
        RdListRow(
          leading: RdRowIcon(Icons.event_busy_outlined, color: p.excused, background: p.excusedSoft),
          title: l10n.redesignTodaySignouts(excused),
          subtitle: l10n.redesignTodaySignoutsHint,
          trailing: RdCountBadge(excused, tone: RdTone.excused),
          onTap: () => context.push(RedesignRoutes.event(nextId)),
        ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RdSectionHeader(l10n.redesignTodayAttention),
          RdGroupedList(children: rows),
        ],
      ),
    );
  }
}

/// Whether the Termin [a] is over, with its end time (or its type's).
bool _eventOver(Attendance a, List<AttendanceType> types, {DateTime? now}) {
  final type = types.where((t) => t.id == a.typeId).firstOrNull;
  final span = rdEventSpan(
    day: EventListUtils.parse(a.date),
    startTime: a.startTime ?? type?.startTime,
    endTime: a.endTime ?? type?.endTime,
    durationDays: rdAttendanceDurationDays(a, types),
  );
  if (span == null) return EventListUtils.hasEnded(a.date, rdAttendanceDurationDays(a, types), now: now);
  return !(now ?? DateTime.now()).isBefore(span.end);
}

/// "Raum aufschließen · Probe 17.11." for the most urgent Vorbereitung task.
String _prepLine(WidgetRef ref, ({Attendance attendance, ChecklistItem item}) task) {
  final a = task.attendance;
  return [
    task.item.text,
    [
      rdEventInfo(a, ref.watch(rdAttendanceTypeProvider(a.typeId))).title,
      if (EventListUtils.parse(a.date) case final d?) '${d.day}.${d.month}.',
    ].join(' '),
  ].join(' · ');
}

/// "Probe 29.10., Probe 22.10." for the not yet recorded Termine (newest
/// first, at most three).
String _unrecordedLine(WidgetRef ref, List<int> ids) {
  final all = ref.watch(realtimeAttendanceListProvider).valueOrNull ?? const <Attendance>[];
  final byId = {for (final a in all) a.id: a};
  return [
    for (final id in ids.reversed.take(3))
      if (byId[id] case final a?)
        [
          rdEventInfo(a, ref.watch(rdAttendanceTypeProvider(a.typeId))).title,
          if (EventListUtils.parse(a.date) case final d?) '${d.day}.${d.month}.',
        ].join(' '),
  ].join(', ');
}

/// "Anna Becker, Jonas Klein und 2 weitere" (the Problemfälle on Heute).
String _criticalNames(AppLocalizations l10n, List<Person> people) {
  const shown = 2;
  final names = [for (final x in people.take(shown)) '${x.firstName} ${x.lastName}'.trim()].join(', ');
  return people.length > shown ? l10n.rdCriticalNames(names, people.length - shown) : names;
}
