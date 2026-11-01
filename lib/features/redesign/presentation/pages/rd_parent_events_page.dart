import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/signout_providers.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/event_list_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../data/repositories/sign_in_out_repository.dart' show CrossTenantPersonAttendance;
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/event_list/event_list_widgets.dart' show openEventAttachment, openEventNavigation;
import '../../../../shared/widgets/event_list/excuse_reason_sheet.dart' show showEventDescriptionSheet;
import '../../../parents/data/providers/parents_providers.dart';
import '../../../parents/presentation/widgets/parents_header_widgets.dart' show showCurrentSongsSheet;
import '../../../self_service/presentation/widgets/plan_viewer_sheet.dart';
import '../../data/providers/rd_events_providers.dart';
import '../widgets/rd_widgets.dart';
import '../widgets/today/rd_parent_today.dart' show RdChildAnswerRow;
import '../widgets/today/rd_today_common.dart';

/// REDESIGN: tab "Termine" of Eltern (the old parents portal `/parents` in
/// the new design): the children with their rate, Kommend / Vergangen, and
/// every coming Termin as a card with one answer row per child (same writes
/// as "Heute" and the old page). A notification opens its Termin as a sheet.
class RdParentEventsPage extends ConsumerStatefulWidget {
  const RdParentEventsPage({super.key});

  @override
  ConsumerState<RdParentEventsPage> createState() => _RdParentEventsPageState();
}

class _RdParentEventsPageState extends ConsumerState<RdParentEventsPage> {
  bool _past = false;
  final _swipePos = ValueNotifier<double?>(null);

  @override
  void dispose() {
    _swipePos.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(currentSongsProvider);
    ref.invalidate(parentChildrenProvider);
    ref.invalidate(childrenAttendancesProvider);
    try {
      await ref.read(childrenAttendancesProvider.future);
    } catch (_) {
      // The page shows the error with "retry".
    }
  }

  /// A notification or push asked for a Termin (`pendingAttendanceId`): open
  /// it as a sheet once the Termine are loaded (old page: action sheet).
  /// While the Termine (re)load or after a failed reload the id stays: the
  /// page shows the load error with "retry" and comes back here once the
  /// Termine are loaded.
  void _openPending() {
    final pendingId = ref.read(pendingAttendanceIdProvider);
    if (pendingId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ref.read(pendingAttendanceIdProvider) != pendingId) return;
      final kids = ref.read(parentChildrenProvider);
      final atts = ref.read(childrenAttendancesProvider);
      if (kids.isLoading || atts.isLoading || kids.hasError || atts.hasError) return;
      ref.read(pendingAttendanceIdProvider.notifier).state = null;
      final all = ref.read(parentAttendanceGroupsProvider);
      if (all.any((g) => g.attendanceId == pendingId)) {
        showRdParentEventSheet(context, pendingId);
      } else {
        ToastHelper.showInfo(context, context.l10n.redesignEventNotFound);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final childrenAsync = ref.watch(parentChildrenProvider);
    final attendancesAsync = ref.watch(childrenAttendancesProvider);
    ref.watch(pendingAttendanceIdProvider);

    final children = <Widget>[
      Semantics(header: true, child: Text(l10n.redesignTabEvents, style: RdType.largeTitle(p))),
      const SizedBox(height: 12),
    ];

    final kids = childrenAsync.valueOrNull;
    // A failed reload shows the error with "retry" instead of the previous
    // Termine, so answers never go to a stale list.
    final error = childrenAsync.hasError || attendancesAsync.hasError;
    if (kids == null || !attendancesAsync.hasValue || error) {
      children.add(
        error
            ? RdInfoCard(
              text: l10n.redesignTodayLoadFailed,
              icon: Icons.cloud_off_outlined,
              action: RdOutlineButton(
                label: l10n.redesignCommonRetry,
                onPressed: () {
                  ref.invalidate(parentChildrenProvider);
                  ref.invalidate(childrenAttendancesProvider);
                },
              ),
            )
            : RdInfoCard(text: l10n.redesignTodayLoading, loading: true),
      );
      return RdPage(onRefresh: _refresh, children: children);
    }
    if (kids.isEmpty) {
      children.add(RdInfoCard(text: l10n.redesignTodayNoChildren, icon: Icons.info_outline));
      return RdPage(onRefresh: _refresh, children: children);
    }

    final upcoming = ref.watch(upcomingParentAttendancesProvider);
    final past = ref.watch(pastParentAttendancesProvider);
    _openPending();

    final songs = ref.watch(currentSongsProvider).valueOrNull ?? const [];
    children.add(
      Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final kid in kids)
            Builder(
              builder: (context) {
                final pct = kid.id == null ? null : ref.watch(childStatsProvider(kid.id!)).percentage;
                final hasStats = kid.id != null && ref.watch(childStatsProvider(kid.id!)).totalCount > 0;
                return RdPill(
                  hasStats ? l10n.redesignParentsChildRate(kid.firstName, pct!) : kid.firstName,
                  tone: !hasStats ? null : (pct! >= 75 ? RdTone.present : (pct >= 50 ? RdTone.late : RdTone.absent)),
                );
              },
            ),
          if (songs.isNotEmpty)
            RdTextLink(label: l10n.selfServiceShowCurrentSongs, onTap: () => showCurrentSongsSheet(context, songs)),
        ],
      ),
    );
    children.add(const SizedBox(height: 14));
    children.add(
      ValueListenableBuilder<double?>(
        valueListenable: _swipePos,
        builder:
            (context, pos, _) => RdSegmented<bool>(
              values: const [false, true],
              selected: _past,
              position: pos,
              labelOf: (past) => past ? l10n.redesignEventsPast : l10n.redesignEventsUpcoming,
              onChanged: (v) => setState(() => _past = v),
            ),
      ),
    );

    final source = _past ? past : upcoming;
    final sections = rdGroupEvents(source, (g) => g.date, past: _past);
    final body = <Widget>[const SizedBox(height: 8)];
    if (sections.isEmpty) {
      body.add(
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: RdInfoCard(
            text: _past ? l10n.redesignEventsNoPast : l10n.redesignTodayNoUpcoming,
            icon: Icons.event_available_outlined,
          ),
        ),
      );
    }
    for (final section in sections) {
      body.add(_SectionLabel(section: section, past: _past));
      if (_past) {
        body.add(
          RdGroupedList(
            children: [
              for (final g in section.items) _PastRow(key: ValueKey('rd-parent-past-${g.attendanceId}'), group: g),
            ],
          ),
        );
      } else {
        for (final g in section.items) {
          body.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RdParentEventCard(key: ValueKey('rd-parent-${g.attendanceId}'), group: g),
            ),
          );
        }
      }
    }
    children.add(
      RdSwipeSwitch<bool>(
        values: const [false, true],
        selected: _past,
        onChanged: (v) => setState(() => _past = v),
        onDrag: (pos) => _swipePos.value = pos,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: body),
      ),
    );

    return RdPage(onRefresh: _refresh, children: children);
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
    final text =
        section.thisWeek
            ? (past ? l10n.redesignEventsLastWeek : l10n.redesignTodayThisWeek)
            : DateFormat(month!.year == now.year ? 'MMMM' : 'MMMM y', currentIntlLocale()).format(month);
    return Padding(padding: const EdgeInsets.only(top: 14), child: RdGroupLabel(text));
  }
}

/// Type of [g] (for times, the "late" option and highlighted Termine).
AttendanceType? _typeOf(WidgetRef ref, ParentAttendanceGroup g) {
  final types = ref.watch(attendanceTypesProvider).valueOrNull ?? const <AttendanceType>[];
  return types.where((t) => t.id == g.typeId).firstOrNull;
}

/// Title like the old page: info text, else the type name, else the date.
String _titleOf(AttendanceType? type, ParentAttendanceGroup g) {
  if (g.typeInfo != null && g.typeInfo!.isNotEmpty) return g.typeInfo!;
  if (type != null && !type.hideName) return type.name;
  return EventListUtils.readableDate(g.date, allDay: type?.allDay ?? false, durationDays: type?.durationDays);
}

/// Opens the Termin [attendanceId] of the parents as a sheet.
Future<void> showRdParentEventSheet(BuildContext context, int attendanceId) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.rd.bg,
    builder:
        (_) => Consumer(
          builder: (context, ref, _) {
            final group =
                ref.watch(parentAttendanceGroupsProvider).where((g) => g.attendanceId == attendanceId).firstOrNull;
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child:
                    group == null
                        ? RdInfoCard(text: context.l10n.redesignEventNotFound, icon: Icons.event_busy_outlined)
                        : RdParentEventCard(group: group),
              ),
            );
          },
        ),
  );
}

/// A coming Termin of the parents: date, title, time and place, Ablaufplan /
/// Infos / Anhang / Navigation, and one answer row per child.
class RdParentEventCard extends ConsumerWidget {
  const RdParentEventCard({super.key, required this.group});

  final ParentAttendanceGroup group;

  Future<void> _showPlan(BuildContext context) async {
    final first = group.childAttendances.firstOrNull;
    await showPlanViewerSheet(
      context,
      attendance: CrossTenantPersonAttendance(
        id: first?.id,
        date: group.date,
        typeInfo: group.typeInfo,
        startTime: group.startTime,
        endTime: group.endTime,
        plan: group.plan,
        sharePlan: group.sharePlan,
        tenantId: 0,
        tenantName: '',
        tenantColor: '#000000',
      ),
      extraPlans: group.extraPlans,
      durationDays: group.durationDays,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final type = _typeOf(ref, group);
    final title = _titleOf(type, group);
    final highlight = type?.highlight ?? group.legacyType == 'vortrag';
    final day = EventListUtils.parse(group.date);
    final locale = currentIntlLocale();
    // Multi-day Termine show their date range like the old page.
    final multiDay =
        EventListUtils.isMultiDay(group.durationDays) || ((type?.allDay ?? false) && (type?.durationDays ?? 1) > 1);
    final range =
        multiDay
            ? EventListUtils.readableDate(
              group.date,
              allDay: true,
              durationDays: group.durationDays ?? type?.durationDays,
            )
            : '';
    final meta = [
      if (range != title) range,
      EventListUtils.timeRange(group.startTime ?? type?.startTime, group.endTime ?? type?.endTime),
      group.place ?? '',
    ].where((s) => s.isNotEmpty).join(' · ');
    final deadline = group.deadlineText;
    final open = group.childAttendances.any((c) => c.status.isNeutral);

    final links = <Widget>[
      if (group.hasPlan) RdTextLink(label: l10n.signoutRunSheet, onTap: () => _showPlan(context)),
      if ((group.description ?? '').isNotEmpty)
        RdTextLink(label: l10n.signoutInfos, onTap: () => showEventDescriptionSheet(context, group.description!)),
      if ((group.attachmentUrl ?? '').isNotEmpty)
        RdTextLink(label: l10n.selfServiceAttachment, onTap: () => openEventAttachment(group.attachmentUrl!)),
      if ((group.place ?? '').isNotEmpty)
        RdTextLink(label: l10n.redesignParentsRoute, onTap: () => openEventNavigation(context, group.place!)),
    ];

    return RdCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      border: group.isRunning ? Border.all(color: p.primary, width: 1.5) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RdDateTile(
                weekday: day == null ? '' : DateFormat.E(locale).format(day).replaceAll('.', ''),
                day: day == null ? '–' : '${day.day}',
                highlight: highlight || group.isRunning,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(header: true, child: Text(title, style: RdType.section(p))),
                    if (meta.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(meta, style: RdType.meta(p, size: 14)),
                      ),
                    if (deadline != null && open)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(deadline, style: RdType.meta(p, size: 13).copyWith(color: p.late)),
                      ),
                  ],
                ),
              ),
              if (group.isRunning) RdPill(l10n.redesignParentsToday, tone: RdTone.primary),
            ],
          ),
          if (links.isNotEmpty)
            // Under the title (date tile 44 + gap 12), minus the link's own 8 px.
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 48),
              child: Wrap(spacing: 4, runSpacing: 0, children: links),
            ),
          const SizedBox(height: 4),
          Divider(height: 12, thickness: 1, color: p.line),
          for (final child in group.childAttendances)
            RdChildAnswerRow(key: ValueKey('rd-child-${child.id}'), group: group, child: child),
        ],
      ),
    );
  }
}

/// A past Termin: date, title and the status of each child.
class _PastRow extends ConsumerWidget {
  const _PastRow({super.key, required this.group});

  final ParentAttendanceGroup group;

  static RdTone? _tone(AttendanceStatus s) => switch (s) {
    AttendanceStatus.present => RdTone.present,
    AttendanceStatus.late || AttendanceStatus.lateExcused => RdTone.late,
    AttendanceStatus.excused => RdTone.excused,
    AttendanceStatus.absent => RdTone.absent,
    AttendanceStatus.neutral => null,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = _typeOf(ref, group);
    final day = EventListUtils.parse(group.date);
    final locale = currentIntlLocale();
    return RdListRow(
      leading: RdDateTile(
        weekday: day == null ? '' : DateFormat.E(locale).format(day).replaceAll('.', ''),
        day: day == null ? '–' : '${day.day}',
      ),
      title: _titleOf(type, group),
      showChevron: false,
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 180),
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          alignment: WrapAlignment.end,
          children: [
            for (final c in group.childAttendances)
              RdPill(
                group.childAttendances.length == 1
                    ? EventListUtils.statusLabel(c.status, past: true)
                    : '${c.childFirstName} · ${EventListUtils.statusLabel(c.status, past: true)}',
                tone: _tone(c.status),
              ),
          ],
        ),
      ),
    );
  }
}
