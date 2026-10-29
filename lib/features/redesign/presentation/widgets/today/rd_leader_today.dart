import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/enums.dart';
import '../../../../../core/providers/dashboard_providers.dart';
import '../../../../../core/providers/player_providers.dart';
import '../../../../../core/providers/realtime_providers.dart';
import '../../../../../core/router/redesign_routes.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../core/utils/event_list_utils.dart';
import '../../../../../data/models/attendance/attendance.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../settings/presentation/pages/pending_players_page.dart'
    show showPendingPersonsSheet;
import '../../../data/providers/rd_today_providers.dart';
import '../rd_widgets.dart';
import 'rd_player_today.dart';
import 'rd_today_common.dart';

/// REDESIGN: "Heute" of Dirigent, Verantwortlich, Beobachter and Helfer
/// (canvas D1, R3): next Termin with its answers, what needs attention,
/// this week.
class RdLeaderToday extends ConsumerWidget {
  const RdLeaderToday({super.key, required this.role});

  final Role role;

  /// Upcoming Termine (not ended), soonest first, without the type filter
  /// of the Termin list.
  static List<Attendance> upcomingOf(List<Attendance> all, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final upcoming = all
        .where((a) => !EventListUtils.hasEnded(a.date, a.durationDays, now: current))
        .toList();
    DateTime keyOf(Attendance a) =>
        rdStartOf(a.date, a.startTime) ?? DateTime(9999);
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

    final upcoming = upcomingOf(all);
    final next = upcoming.firstOrNull;
    final week = rdThisWeek(upcoming.skip(1).toList());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
          _NextEventCard(attendance: next, canOpen: role.canAddAttendance),
        if (isLead) _AttentionSection(next: next),
        if (role.canSeeSelfServiceTab) ...[
          const SizedBox(height: 24),
          const RdOwnAnswerSection(),
        ],
        const SizedBox(height: 24),
        RdSectionHeader(
          l10n.redesignTodayThisWeek,
          trailing: isLead ? _birthdayLine(context, ref) : null,
          action: RdLinkButton(
            label: l10n.redesignCommonAll,
            onPressed: () => context.go(RedesignRoutes.events),
          ),
        ),
        if (week.isEmpty)
          RdInfoCard(text: l10n.redesignTodayWeekEmpty)
        else
          RdGroupedList(
            children: [
              for (final a in week) _WeekRow(attendance: a, canOpen: role.canAddAttendance),
            ],
          ),
      ],
    );
  }

  /// "Geburtstag: Lea (Sa)" for the coming days.
  String? _birthdayLine(BuildContext context, WidgetRef ref) {
    final birthdays = ref.watch(dashboardBirthdaysProvider).valueOrNull ?? const [];
    final soon = birthdays.where((b) => b.daysOffset >= 0 && b.daysOffset <= 7).toList()
      ..sort((a, b) => a.daysOffset.compareTo(b.daysOffset));
    if (soon.isEmpty) return null;
    final first = soon.first;
    final day = first.daysOffset == 0
        ? context.l10n.redesignTodayDayToday
        : DateFormat.E(currentIntlLocale()).format(first.date).replaceAll('.', '');
    final name = first.person.firstName;
    return soon.length == 1
        ? context.l10n.redesignTodayBirthday(name, day)
        : context.l10n.redesignTodayBirthdayMore(name, day, soon.length - 1);
  }
}

class _NextEventCard extends ConsumerWidget {
  const _NextEventCard({required this.attendance, required this.canOpen});

  final Attendance attendance;

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

  static String _countsLine(AppLocalizations l10n, RdStatusCounts c) => [
        l10n.redesignTodayCountYes(c.present),
        if (c.excused > 0) l10n.redesignTodayCountExcused(c.excused),
        if (c.lateAnnounced > 0) l10n.redesignTodayCountLater(c.lateAnnounced),
        if (c.absent > 0) l10n.redesignTodayCountAbsent(c.absent),
        l10n.redesignTodayCountOpen(c.open),
      ].join(' · ');
}

/// "Braucht deine Aufmerksamkeit" (Dirigent, Verantwortlich): new
/// registrations, critical members, sign-outs for the next Termin.
class _AttentionSection extends ConsumerWidget {
  const _AttentionSection({required this.next});

  final Attendance? next;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final pending = ref.watch(pendingPlayersProvider).valueOrNull?.length ?? 0;
    final critical = ref.watch(criticalPlayersProvider).valueOrNull?.length ?? 0;
    final nextId = next?.id;
    final excused = nextId == null
        ? 0
        : ref.watch(rdAttendanceCountsProvider(nextId)).valueOrNull?.excused ?? 0;

    final rows = <Widget>[
      if (pending > 0)
        RdListRow(
          leading: RdRowIcon(Icons.person_add_alt_1_outlined, color: p.primary, background: p.soft),
          title: l10n.redesignTodayPending(pending),
          subtitle: l10n.redesignTodayPendingHint,
          trailing: RdCountBadge(pending),
          onTap: () => showPendingPersonsSheet(context),
        ),
      if (critical > 0)
        RdListRow(
          leading: RdRowIcon(Icons.warning_amber_rounded, color: p.absent, background: p.absentSoft),
          title: l10n.redesignTodayCritical(critical),
          subtitle: l10n.redesignTodayCriticalHint,
          trailing: RdCountBadge(critical, tone: RdTone.absent),
          onTap: () => context.go('/people'),
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
      padding: const EdgeInsets.only(top: 24),
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

class _WeekRow extends ConsumerWidget {
  const _WeekRow({required this.attendance, required this.canOpen});

  final Attendance attendance;
  final bool canOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = ref.watch(rdAttendanceTypeProvider(attendance.typeId));
    final info = rdEventInfo(attendance, type);
    final id = attendance.id;
    return RdEventRow(
      date: attendance.date,
      title: info.title,
      meta: [info.timeRange, info.place].where((s) => s.isNotEmpty).join(' · '),
      onTap: id != null && canOpen
          ? () => context.push(RedesignRoutes.event(id))
          : () => context.go(RedesignRoutes.events),
    );
  }
}
