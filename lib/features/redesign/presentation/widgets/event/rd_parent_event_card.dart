import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/providers/attendance_type_providers.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../core/utils/event_list_utils.dart';
import '../../../../../data/models/attendance/attendance.dart';
import '../../../../../data/repositories/sign_in_out_repository.dart' show CrossTenantPersonAttendance;
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/widgets/event_list/event_list_widgets.dart' show openEventAttachment, openEventNavigation;
import '../../../../../shared/widgets/event_list/excuse_reason_sheet.dart' show showEventDescriptionSheet;
import '../../../../parents/data/providers/parents_providers.dart';
import '../../../../self_service/presentation/widgets/plan_viewer_sheet.dart';
import '../../../../self_service/presentation/widgets/self_service_event_actions.dart' show SelfServiceActionType;
import '../../../data/rd_dates.dart';
import '../rd_widgets.dart';
import '../today/rd_parent_today.dart' show RdAllChildrenAnswer, RdChildAnswerRow, rdChildrenLine, rdOpenChildren;
import '../today/rd_today_common.dart';

/// REDESIGN: Termine of Eltern in the look of the Spieler Termine (same
/// card, date box, answer buttons). The card answers open children right
/// in the list; a tap opens the Termin as a sheet with Ablaufplan, Infos,
/// Anhang, Route and every child.

AttendanceType? _typeOf(WidgetRef ref, ParentAttendanceGroup g) {
  final types = ref.watch(attendanceTypesProvider).valueOrNull ?? const <AttendanceType>[];
  return types.where((t) => t.id == g.typeId).firstOrNull;
}

/// Title like the old parents page: info text, else the type name, else the date.
String rdParentTitle(AttendanceType? type, ParentAttendanceGroup g) {
  if (g.typeInfo != null && g.typeInfo!.isNotEmpty) return g.typeInfo!;
  if (type != null && !type.hideName) return type.name;
  return EventListUtils.readableDate(g.date, allDay: type?.allDay ?? false, durationDays: type?.durationDays);
}

/// "Fr, 7.11. - So, 9.11. · 17:00–18:30 · Kirche": multi-day Termine show
/// their date range like the old page.
String rdParentMeta(AttendanceType? type, ParentAttendanceGroup g, {bool place = true}) {
  final title = rdParentTitle(type, g);
  final multiDay = EventListUtils.isMultiDay(g.durationDays) || ((type?.allDay ?? false) && (type?.durationDays ?? 1) > 1);
  final range = multiDay
      ? EventListUtils.readableDate(g.date, allDay: true, durationDays: g.durationDays ?? type?.durationDays)
      : '';
  return [
    if (range != title) range,
    EventListUtils.timeRange(g.startTime ?? type?.startTime, g.endTime ?? type?.endTime),
    if (place) g.place ?? '',
  ].where((s) => s.isNotEmpty).join(' · ');
}

/// Days of a Termin for the date box (group, else its type).
int? _days(AttendanceType? type, ParentAttendanceGroup g) =>
    g.durationDays ?? ((type?.allDay ?? false) ? type?.durationDays : null);

/// One Termin of the parents' list, like `_PlayerEventCard`.
class RdParentEventCard extends ConsumerWidget {
  const RdParentEventCard({super.key, required this.group, this.past = false});

  final ParentAttendanceGroup group;
  final bool past;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final type = _typeOf(ref, group);
    final open = !past && rdOpenChildren(group) > 0;
    final deadline = open ? (group.deadlineText ?? '') : '';
    final meta = [rdParentMeta(type, group), deadline].where((s) => s.isNotEmpty).join(' · ');
    final single = group.childAttendances.length == 1 ? group.childAttendances.first : null;
    final today = !past && group.isRunning;

    return RdCard(
      padding: const EdgeInsets.all(14),
      onTap: () => showRdParentEventSheet(context, group.attendanceId),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              RdEventDateBox(date: group.date, durationDays: _days(type, group), highlight: today),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rdParentTitle(type, group),
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.text),
                    ),
                    if (meta.isNotEmpty) Text(meta, style: RdType.meta(p, size: 13)),
                    // Several children, all answered: "Mia ✓ · Ben ✕".
                    if (!open && single == null) Text(rdChildrenLine(l10n, group), style: RdType.meta(p, size: 13)),
                  ],
                ),
              ),
              if (!open && single != null) ...[
                const SizedBox(width: 8),
                rdOwnStatusPill(l10n, single.status),
              ],
            ],
          ),
          // Open children answer right here, like a Spieler's open Termin.
          if (open) ...[
            const SizedBox(height: 8),
            for (final child in group.childAttendances)
              RdChildAnswerRow(key: ValueKey('rd-child-${child.id}'), group: group, child: child),
          ],
        ],
      ),
    );
  }
}

/// Opens the Termin [attendanceId] of the parents as a sheet: details and
/// every child (answers can be changed until the Termin is over).
Future<void> showRdParentEventSheet(BuildContext context, int attendanceId) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.rd.bg,
    builder: (_) => Consumer(
      builder: (context, ref, _) {
        final group = ref.watch(parentAttendanceGroupsProvider).where((g) => g.attendanceId == attendanceId).firstOrNull;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: group == null
                ? RdInfoCard(text: context.l10n.redesignEventNotFound, icon: Icons.event_busy_outlined)
                : _ParentEventDetail(group: group),
          ),
        );
      },
    ),
  );
}

class _ParentEventDetail extends ConsumerWidget {
  const _ParentEventDetail({required this.group});

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
    final past = group.isPast;
    final deadline = !past && rdOpenChildren(group) > 0 ? group.deadlineText : null;
    // Like the Termin page of Spieler: "Dienstag, 4. November · 17:00 – 18:30".
    final start = EventListUtils.parse(group.date);
    final locale = currentIntlLocale();
    final days = _days(type, group) ?? 1;
    final date = start == null
        ? ''
        : days > 1
            ? '${DateFormat.MMMMEEEEd(locale).format(start)} – '
                '${DateFormat.MMMMEEEEd(locale).format(rdAddDays(start, days - 1))}'
            : DateFormat.MMMMEEEEd(locale).format(start);
    final time = EventListUtils.timeRange(group.startTime ?? type?.startTime, group.endTime ?? type?.endTime);
    final meta = [date, time].where((s) => s.isNotEmpty).join(' · ');

    RdListRow info(SelfServiceActionType t, VoidCallback onTap, {String? subtitle}) => RdListRow(
          leading: RdRowIcon(t.icon),
          title: t.label(l10n),
          subtitle: subtitle,
          onTap: onTap,
        );
    final infos = [
      if (group.hasPlan) info(SelfServiceActionType.showPlan, () => _showPlan(context)),
      if ((group.description ?? '').isNotEmpty)
        info(SelfServiceActionType.showDescription, () => showEventDescriptionSheet(context, group.description!)),
      if ((group.attachmentUrl ?? '').isNotEmpty)
        info(SelfServiceActionType.openAttachment, () => openEventAttachment(group.attachmentUrl!)),
      if ((group.place ?? '').isNotEmpty)
        info(SelfServiceActionType.openNavigation, () => openEventNavigation(context, group.place!),
            subtitle: group.place),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(header: true, child: Text(rdParentTitle(type, group), style: RdType.title(p))),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(meta, style: RdType.meta(p, size: 15)),
        ],
        if (deadline != null) Text(deadline, style: RdType.meta(p, size: 13).copyWith(color: p.late)),
        const SizedBox(height: 18),
        RdCard(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final child in group.childAttendances)
                RdChildAnswerRow(
                  key: ValueKey('rd-sheet-child-${child.id}'),
                  group: group,
                  child: child,
                  readOnly: past,
                ),
              // "Alle Kinder" like the old portal (one answer for every child).
              if (!past && group.childAttendances.length > 1) ...[
                Divider(height: 12, color: p.line),
                RdAllChildrenAnswer(group: group),
              ],
            ],
          ),
        ),
        if (infos.isNotEmpty) ...[
          const SizedBox(height: 24),
          RdGroupLabel(l10n.redesignOwnInfos),
          RdGroupedList(children: infos),
        ],
      ],
    );
  }
}
