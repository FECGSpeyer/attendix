import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/player_absence_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/providers/role_permission_providers.dart';
import '../../../../core/providers/self_service_providers.dart';
import '../../../../core/providers/signout_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/event_list_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../l10n/l10n.dart';
import '../../../self_service/presentation/pages/signout_page.dart'
    show signoutEventActions;
import '../../../self_service/presentation/widgets/self_service_event_actions.dart';
import '../../data/providers/rd_events_providers.dart';
import '../../data/providers/rd_today_providers.dart';
import '../widgets/event/rd_absence_sheet.dart';
import '../widgets/event/rd_signout_sheet.dart';
import '../widgets/rd_split_view.dart';
import '../widgets/rd_widgets.dart';
import '../widgets/today/rd_today_common.dart';
import '../../data/rd_dates.dart';
import '../widgets/today/rd_duty_section.dart';

/// REDESIGN: tab "Termine" (canvas D2 for Dirigent/Helfer/Beobachter, S2
/// for Spieler). Kommend / Vergangen, filters, and for Spieler the answer
/// right in the list. Eltern keep the parents portal.
class RdEventsPage extends ConsumerStatefulWidget {
  const RdEventsPage({super.key});

  @override
  ConsumerState<RdEventsPage> createState() => _RdEventsPageState();
}

class _RdEventsPageState extends ConsumerState<RdEventsPage> {
  bool _past = false;
  String? _type;
  bool _searching = false;
  String _query = '';
  bool _onlyOpen = false;

  /// Thumb of Kommend / Vergangen while swiping the list.
  /// Notifier so only the segmented control rebuilds while swiping, not
  /// the whole page with every row.
  final _swipePos = ValueNotifier<double?>(null);
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    _swipePos.dispose();
    super.dispose();
  }

  bool _matches(String title, String? place) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return title.toLowerCase().contains(q) || (place ?? '').toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final role = ref.watch(effectiveRoleProvider);
    final leader = role.canSeeAttendanceTab;
    final canCreate = leader && ref.watch(canCreateAttendanceProvider);
    final player = leader ? null : ref.watch(currentSelfServicePlayerProvider).valueOrNull;
    final canReportAbsence = player != null && ref.watch(canSelfReportAbsenceProvider);

    return RdPage(
      onRefresh: () async {
        if (leader) {
          ref.read(attendanceRefetchCounter.notifier).state++;
        } else {
          ref.invalidate(signoutDataProvider);
          await ref.read(rdSignoutDataProvider.future).catchError((_) => const SignoutData());
        }
      },
      floatingActionButton: canCreate
          ? FloatingActionButton(
              tooltip: l10n.redesignEventsNew,
              backgroundColor: p.primary,
              foregroundColor: p.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              onPressed: () => context.push(RedesignRoutes.newEvent),
              child: const Icon(Icons.add, size: 28),
            )
          : null,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(l10n.redesignTabEvents, style: RdType.largeTitle(p)),
              ),
            ),
            if (canReportAbsence) ...[
              RdPillButton(
                icon: Icons.event_busy_outlined,
                label: l10n.redesignEventsAbsent,
                onPressed: () => showRdAbsenceSheet(
                  context,
                  ref,
                  player,
                  canSelfPause: ref.read(canSelfPauseProvider),
                ),
              ),
              const SizedBox(width: 8),
            ],
            RdCircleButton(
              icon: _searching ? Icons.close : Icons.search,
              label: _searching ? l10n.redesignEventsSearchClose : l10n.redesignEventsSearch,
              onPressed: () => setState(() {
                _searching = !_searching;
                if (!_searching) {
                  _search.clear();
                  _query = '';
                }
              }),
            ),
          ],
        ),
        if (_searching) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            autofocus: true,
            onChanged: (v) => setState(() => _query = v),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l10n.redesignEventsSearchHint,
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: p.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(p.buttonRadius),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        if (leader) _leaderBody(context) else _playerBody(context),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Dirigent, Helfer, Beobachter
  // ---------------------------------------------------------------------------

  Widget _leaderBody(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(realtimeAttendanceListProvider);
    final all = async.valueOrNull;
    if (all == null) {
      return async.hasError
          ? RdInfoCard(
              text: l10n.redesignTodayLoadFailed,
              icon: Icons.error_outline,
              action: RdOutlineButton(
                label: l10n.redesignCommonRetry,
                onPressed: () => ref.read(attendanceRefetchCounter.notifier).state++,
              ),
            )
          : RdInfoCard(text: l10n.redesignTodayLoading, loading: true);
    }
    final types = (ref.watch(attendanceTypesProvider).valueOrNull ?? const <AttendanceType>[])
        .where((t) => t.visible)
        .toList();
    final typeById = {for (final t in types) t.id: t};
    final past = rdPast(all);
    final average = rdAveragePercentage(past);
    final source = _past ? past : rdUpcoming(all);
    final list = source.where((a) {
      if (_type != null && a.typeId != _type) return false;
      final info = rdEventInfo(a, typeById[a.typeId]);
      return _matches(info.title, a.place);
    }).toList();
    final sections = rdGroupEvents(list, (a) => a.date, past: _past);
    final counts = _past ? const <int, RdStatusCounts>{} : (ref.watch(rdUpcomingCountsProvider).valueOrNull ?? const {});
    final canOpen = ref.watch(effectiveRoleProvider).canAddAttendance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _segments(
          context,
          pastLabel: average == null
              ? l10n.redesignEventsPast
              : l10n.redesignEventsPastAverage(average.round()),
        ),
        _swipe(Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (types.length > 1) ...[
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    RdChoiceChip(
                      label: l10n.redesignCommonAll,
                      selected: _type == null,
                      onTap: () => setState(() => _type = null),
                    ),
                    for (final t in types) ...[
                      const SizedBox(width: 8),
                      RdChoiceChip(
                        label: t.name,
                        selected: _type == t.id,
                        onTap: () => setState(() => _type = _type == t.id ? null : t.id),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            if (sections.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: RdInfoCard(
                  text: all.isEmpty
                      ? l10n.redesignEventsEmpty
                      : _query.isNotEmpty || _type != null
                          ? l10n.redesignEventsNoMatch
                          : (_past ? l10n.redesignEventsNoPast : l10n.redesignTodayNoUpcoming),
                  icon: Icons.event_available_outlined,
                  // Canvas "Leere Termine": straight to the first Termin.
                  action: all.isEmpty && ref.watch(canCreateAttendanceProvider)
                      ? RdPrimaryButton(
                          label: l10n.redesignEventsCreateFirst,
                          icon: Icons.add,
                          onPressed: () => context.push(RedesignRoutes.newEvent),
                        )
                      : null,
                ),
              ),
            for (final section in sections) ...[
              _SectionLabel(section: section, past: _past),
              for (final a in section.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _LeaderEventCard(
                    attendance: a,
                    type: typeById[a.typeId],
                    counts: a.id == null ? null : counts[a.id],
                    past: _past,
                    selected: a.id != null && RdSplitScope.of(context)?.selectedId == a.id,
                    onTap: a.id != null && canOpen
                        ? () => RdSplitScope.open(context, RedesignRoutes.event(a.id!))
                        : null,
                  ),
                ),
            ],
          ],
        )),
      ],
    );
  }

  void _setPast(bool past) => setState(() {
        _past = past;
        _onlyOpen = false;
      });

  Widget _segments(BuildContext context, {required String pastLabel}) {
    final l10n = context.l10n;
    return ValueListenableBuilder<double?>(
      valueListenable: _swipePos,
      builder: (context, pos, _) => RdSegmented<bool>(
        values: const [false, true],
        selected: _past,
        position: pos,
        labelOf: (past) => past ? pastLabel : l10n.redesignEventsUpcoming,
        onChanged: _setPast,
      ),
    );
  }

  /// Swipe between Kommend and Vergangen (the segments stay the main way).
  Widget _swipe(Widget child) => RdSwipeSwitch<bool>(
        values: const [false, true],
        selected: _past,
        onChanged: _setPast,
        onDrag: (pos) => _swipePos.value = pos,
        child: child,
      );

  // ---------------------------------------------------------------------------
  // Spieler, Stimmführer
  // ---------------------------------------------------------------------------

  /// Opens the Termin a notification asked for (`pendingAttendanceId`)
  /// once the own Termine are loaded: the own Termin page, or the sheet
  /// "Meine Termine" opens (another group, a duty to take over). It looks in
  /// the unfiltered own Termine, since the list here leaves out duties
  /// without an own assignment; a Termin that is not there says so.
  void _openPending(SignoutData data, SelfServiceEventActions actions) {
    final pendingId = ref.read(pendingAttendanceIdProvider);
    if (pendingId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ref.read(pendingAttendanceIdProvider) != pendingId) return;
      ref.read(pendingAttendanceIdProvider.notifier).state = null;
      final all = ref.read(signoutDataProvider).valueOrNull ?? data;
      final att = [...all.allUpcoming, ...all.past].where((a) => a.attendanceId == pendingId).firstOrNull;
      if (att == null) {
        ToastHelper.showInfo(context, context.l10n.redesignEventNotFound);
        return;
      }
      final own = actions.isOwn(att);
      // The own Termin page reads the filtered list, so only those open it.
      final listed = [...data.allUpcoming, ...data.past].any((a) => a.id == att.id);
      if (att.id != null && own && listed) {
        context.push(RedesignRoutes.ownEvent(att.id!));
      } else {
        actions.presentActions(context, att);
      }
    });
  }

  Widget _playerBody(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(rdSignoutDataProvider);
    final data = async.valueOrNull;
    if (data == null) {
      return async.hasError
          ? RdInfoCard(
              text: l10n.redesignTodayLoadFailed,
              icon: Icons.error_outline,
              action: RdOutlineButton(
                label: l10n.redesignCommonRetry,
                onPressed: () => ref.invalidate(signoutDataProvider),
              ),
            )
          : RdInfoCard(text: l10n.redesignTodayLoading, loading: true);
    }
    final tenant = ref.watch(currentTenantProvider);
    final player = ref.watch(currentSelfServicePlayerProvider).valueOrNull;
    final actions = signoutEventActions(context, ref, tenant: tenant, player: player);
    // A notification, push or "open attendance" link asked for a Termin
    // (like "Meine Termine" does); also when it arrives while open.
    ref.watch(pendingAttendanceIdProvider);
    _openPending(data, actions);

    bool waiting(CrossTenantPersonAttendance att) {
      final qa = actions.quickActions(att);
      return qa != null && att.status == AttendanceStatus.neutral && qa.canSignin;
    }

    final openCount = data.allUpcoming.where(waiting).length;
    final source = _past ? data.past : data.allUpcoming;
    final list = source
        .where((a) => !_onlyOpen || waiting(a))
        .where((a) => _matches(a.eventTitle, a.place))
        .toList();
    final sections = rdGroupEvents(list, (a) => a.date, past: _past);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _segments(context, pastLabel: l10n.redesignEventsPastOwn(data.percentage)),
        _swipe(Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // "Bitte bestätigen" and "Offene Dienste": unassigned duties are
            // taken over there, not answered in this list.
            if (!_past) const RdDutySection(),
            if (!_past && openCount > 0) ...[
              const SizedBox(height: 12),
              _WaitingBanner(
                count: openCount,
                active: _onlyOpen,
                onTap: () => setState(() => _onlyOpen = !_onlyOpen),
              ),
            ],
            const SizedBox(height: 8),
            if (sections.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: RdInfoCard(
                  text: _query.isNotEmpty
                      ? l10n.redesignEventsNoMatch
                      : (_past ? l10n.redesignEventsNoPast : l10n.redesignTodayNoUpcoming),
                  icon: Icons.event_available_outlined,
                ),
              ),
            for (final section in sections) ...[
              _SectionLabel(section: section, past: _past),
              for (final att in section.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PlayerEventCard(
                    key: ValueKey('rd-own-${att.id ?? att.attendanceId}'),
                    att: att,
                    actions: actions,
                    showAnswer: !_past && waiting(att),
                  ),
                ),
            ],
          ],
        )),
      ],
    );
  }
}

/// "DIESE WOCHE" / "NOVEMBER".
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.section, required this.past});

  final RdEventSection<Object?> section;
  final bool past;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final month = section.month;
    final text = section.thisWeek
        ? (past ? l10n.redesignEventsLastWeek : l10n.redesignTodayThisWeek)
        : DateFormat(month!.year == now.year ? 'MMMM' : 'MMMM y', currentIntlLocale())
            .format(month);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: RdGroupLabel(text),
    );
  }
}

/// Date box of a Termin card; multi-day Termine show the range.
class _DateBox extends StatelessWidget {
  const _DateBox({required this.date, this.durationDays, this.highlight = false});

  final String? date;
  final int? durationDays;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final start = EventListUtils.parse(date);
    final locale = currentIntlLocale();
    String wd(DateTime d) => DateFormat.E(locale).format(d).replaceAll('.', '').toUpperCase();
    var top = start == null ? '' : wd(start);
    var bottom = start == null ? '–' : '${start.day}';
    final days = durationDays ?? 1;
    if (start != null && days > 1) {
      final end = rdAddDays(start, days - 1);
      top = '${wd(start)}–${wd(end)}';
      bottom = '${start.day}–${end.day}';
    }
    final fg = highlight ? p.softText : p.text;
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: highlight ? p.soft : p.track,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            top,
            maxLines: 1,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: highlight ? fg : p.text2),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              bottom,
              style: TextStyle(fontSize: days > 1 ? 16 : 20, fontWeight: FontWeight.w700, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

bool _isToday(String? date, int? durationDays) =>
    EventListUtils.isRunning(date, durationDays);

class _LeaderEventCard extends StatelessWidget {
  const _LeaderEventCard({
    required this.attendance,
    required this.type,
    required this.counts,
    required this.past,
    required this.onTap,
    this.selected = false,
  });

  final Attendance attendance;
  final AttendanceType? type;
  final RdStatusCounts? counts;
  final bool past;
  final VoidCallback? onTap;

  /// Open on the right of the split view.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final info = rdEventInfo(attendance, type);
    final today = !past && _isToday(attendance.date, attendance.durationDays);
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DateBox(date: attendance.date, durationDays: attendance.durationDays, highlight: today),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        info.title,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.text),
                      ),
                    ),
                    if (type != null && type!.name.isNotEmpty && type!.name != info.title) ...[
                      const SizedBox(width: 8),
                      RdPill(type!.name, tone: type!.highlight ? RdTone.excused : RdTone.primary),
                    ],
                  ],
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(meta, style: RdType.meta(p, size: 13)),
                ],
                if (!past && c != null && c.total > 0) ...[
                  const SizedBox(height: 8),
                  RdStatusBar(
                    total: c.total,
                    segments: [
                      RdBarSegment(c.present, p.present),
                      RdBarSegment(c.lateAnnounced, p.late),
                      RdBarSegment(c.excused, p.excused),
                      RdBarSegment(c.absent, p.absent),
                    ],
                    semanticLabel: _countsLine(l10n, c),
                  ),
                  const SizedBox(height: 6),
                  Text(_countsLine(l10n, c), style: RdType.meta(p, size: 12)),
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
        ],
      ),
    );
  }

  static String _countsLine(AppLocalizations l10n, RdStatusCounts c) => [
        l10n.redesignTodayCountYes(c.present),
        if (c.excused > 0) l10n.redesignTodayCountExcused(c.excused),
        if (c.lateAnnounced > 0) l10n.redesignTodayCountLater(c.lateAnnounced),
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
    final qa = actions.quickActions(att);
    final today = !att.isPast && att.isRunning;
    final deadline = att.deadline != null && att.deadline!.isNotEmpty && !att.isPast
        ? EventListUtils.deadlineText(att.deadline)
        : '';
    final meta = [att.eventMeta(), if (widget.showAnswer) deadline]
        .where((s) => s.isNotEmpty)
        .join(' · ');
    final busy = _busy || ref.watch(signoutNotifierProvider).isLoading;

    return RdCard(
      padding: const EdgeInsets.all(14),
      onTap: () => att.id != null && own
          ? context.push(RedesignRoutes.ownEvent(att.id!))
          : actions.presentActions(context, att),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _DateBox(date: att.date, durationDays: att.effectiveDurationDays, highlight: today),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      att.eventTitle,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.text),
                    ),
                    if (meta.isNotEmpty)
                      Text(meta, style: RdType.meta(p, size: 13)),
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
                    onPressed: busy
                        ? null
                        : () => _run(() => actions.handleSigninWithFields(context, att)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RdOutlineButton(
                    label: l10n.redesignEventsNo,
                    height: 44,
                    onPressed: busy || !qa.allowExcuse || qa.blocked
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
