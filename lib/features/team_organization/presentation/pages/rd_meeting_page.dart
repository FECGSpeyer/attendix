import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/plan_providers.dart';
import '../../../../core/providers/team_org_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/team_org/team_org.dart';
import '../../../../l10n/l10n.dart';
import '../../../redesign/presentation/widgets/rd_widgets.dart';
import '../../team_org_utils.dart';
import '../utils/route_return_reload.dart';
import '../widgets/agenda_picker_sheet.dart';
import '../widgets/rd_proposals.dart';
import '../widgets/tasks_tab.dart' show TeamOrgListSkeleton;

String rdMeetingRoute(int attendanceId) => '/settings/team-organization/meeting/$attendanceId';

/// Beta: one planned Besprechung. Everyone in its circle sees the agenda;
/// leadership also decides on suggestions and edits the agenda here.
class RdMeetingPage extends ConsumerStatefulWidget {
  const RdMeetingPage({super.key, required this.attendanceId});

  final int attendanceId;

  @override
  ConsumerState<RdMeetingPage> createState() => _RdMeetingPageState();
}

class _RdMeetingPageState extends ConsumerState<RdMeetingPage> with RouteReturnReload {
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) reloadTeamOrgTab(ref, 'topics', firstLoad: true);
    });
  }

  @override
  void onRouteReturn() => reloadTeamOrgTab(ref, 'topics');

  void _refreshPlans([ProviderContainer? container]) {
    final c = container ?? ProviderScope.containerOf(context, listen: false);
    c.invalidate(upcomingProtocolAttendancesProvider);
    c.invalidate(planAttendancesProvider);
    c.invalidate(orgPlansProvider);
  }

  /// One decision at a time: two writes to the same plan would overwrite
  /// each other.
  Future<void> _run(AgendaItem item, Future<void> Function() action) async {
    final id = item.id;
    if (id == null || _busy.isNotEmpty) return;
    setState(() => _busy.add(id));
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  /// "Aufnehmen": accepts the suggestion and puts it on this agenda.
  Future<void> _take(AgendaItem item, ProtocolAttendance att, ProtocolType? type) => _run(item, () async {
        // The page may close while this runs: bind everything first.
        final container = ProviderScope.containerOf(context, listen: false);
        final repo = ref.read(protocolRepositoryWithTenantProvider);
        final l10n = context.l10n;
        final ok = await acceptProposal(context, ref, item, toast: false);
        if (!ok) return;
        try {
          await addTopicsToAttendance(repo, att, type, [(item: item, duration: defaultTopicDuration(item, type))]);
          if (mounted) ToastHelper.showSuccess(context, l10n.rdTeamAcceptedToMeeting);
        } catch (_) {
          // Accepted, so it now waits under "Thema hinzufügen".
          if (mounted) ToastHelper.showWarning(context, l10n.rdTeamAcceptedNotPlanned);
        } finally {
          _refreshPlans(container);
        }
      });

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final isLeader = ref.watch(isTeamLeaderProvider);
    final canOpenEvent = ref.watch(effectiveRoleProvider).canAddAttendance;
    final upcomingAsync = ref.watch(upcomingProtocolAttendancesProvider);
    final types = ref.watch(protocolTypesProvider).valueOrNull ?? const <ProtocolType>[];
    final items = ref.watch(agendaItemsProvider).valueOrNull ?? const <AgendaItem>[];

    ProtocolAttendance? att;
    for (final a in upcomingAsync.valueOrNull ?? const <ProtocolAttendance>[]) {
      if (a.id == widget.attendanceId) att = a;
    }
    ProtocolType? type;
    for (final t in types) {
      if (t.id == att?.typeId) type = t;
    }

    Widget header(String title, String meta) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RdBackLink(label: l10n.rdTeamTitle, onTap: () => rdBack(context, '/settings/team-organization')),
            const SizedBox(height: 10),
            RdEyebrow(l10n.rdTeamMeetingPlanned),
            const SizedBox(height: 4),
            Text(title, style: RdType.title(p)),
            if (meta.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(meta, style: RdType.meta(p)),
            ],
            const SizedBox(height: 18),
          ],
        );

    if (att == null) {
      return RdPage(
        onRefresh: () => reloadTeamOrgTab(ref, 'topics'),
        children: [
          header(l10n.rdTeamTabMeetings, ''),
          if (upcomingAsync.isLoading && !upcomingAsync.hasValue)
            const TeamOrgListSkeleton()
          else if (upcomingAsync.hasError && !upcomingAsync.hasValue)
            RdCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.rdTeamLoadFailed, style: RdType.meta(p)),
                  const SizedBox(height: 10),
                  RdOutlineButton(
                    label: l10n.redesignCommonRetry,
                    onPressed: () => ref.invalidate(upcomingProtocolAttendancesProvider),
                  ),
                ],
              ),
            )
          else
            RdCard(child: Text(l10n.rdTeamMeetingGone, style: RdType.meta(p))),
        ],
      );
    }

    final meeting = att;
    final tops = planTops(meeting.fields);
    final numbers = topNumbers(meeting.fields);
    final byId = {for (final i in items) i.id: i};
    final pending = isLeader ? splitTopics(items).pending : const <AgendaItem>[];
    final time = [meeting.startTime, meeting.endTime].where((t) => t != null && t.isNotEmpty).join('–');
    final meta = [formatShortWeekdayDate(meeting.date), if (time.isNotEmpty) time].join(' · ');

    String topSubtitle(PlanField top) {
      final parts = [
        if (fieldConductor(top) != null) fieldConductor(top)!,
        if (fieldMinutes(top) > 0) l10n.teamOrgMinutes(fieldMinutes(top)),
      ];
      final description = byId[fieldAgendaItemId(top)]?.description?.trim() ?? '';
      final line = parts.join(' · ');
      if (description.isEmpty) return line;
      return line.isEmpty ? description : '$line\n$description';
    }

    return RdPage(
      onRefresh: () => reloadTeamOrgTab(ref, 'topics'),
      children: [
        header(attendanceTitle(meeting.typeInfo, type), meta),
        if (pending.isNotEmpty) ...[
          RdGroupLabel(l10n.rdTeamSuggestions),
          for (final item in pending)
            RdProposalCard(
              key: ValueKey('rd-proposal-${item.id}'),
              item: item,
              busy: _busy.isNotEmpty,
              primaryLabel: l10n.rdTeamAccept,
              onPrimary: () => _take(item, meeting, type),
              secondaryLabel: l10n.rdTeamLater,
              onSecondary: () => _run(item, () => acceptProposal(context, ref, item)),
              linkLabel: l10n.teamOrgReject,
              onLink: () => _run(item, () => rejectProposal(context, ref, item)),
            ),
          const SizedBox(height: 8),
        ],
        RdGroupLabel(
          tops.minutes > 0 ? '${l10n.rdTeamAgenda} · ${l10n.teamOrgMinutes(tops.minutes)}' : l10n.rdTeamAgenda,
        ),
        RdGroupedList(
          children: [
            for (final top in tops.tops)
              RdListRow(
                key: ValueKey('rd-top-${fieldId(top)}'),
                title: '${numbers[fieldId(top)] ?? ''} · ${fieldName(top)}',
                subtitle: topSubtitle(top).isEmpty ? null : topSubtitle(top),
                showChevron: byId.containsKey(fieldAgendaItemId(top)),
                onTap: byId.containsKey(fieldAgendaItemId(top))
                    ? () => context.push('/settings/agenda-items/${fieldAgendaItemId(top)}')
                    : null,
              ),
            if (tops.tops.isEmpty && !isLeader)
              RdListRow(title: l10n.teamOrgNoTopsYet, titleColor: p.text2, showChevron: false),
            if (isLeader)
              RdListRow(
                key: const ValueKey('rd-meeting-add-topic'),
                leading: const RdRowIcon(Icons.add),
                title: l10n.rdTeamAddTopic,
                titleColor: p.link,
                subtitle: l10n.rdTeamAddTopicHint,
                showChevron: false,
                onTap: () async {
                  await showAgendaPickerSheet(context, attendance: meeting, type: type);
                  if (mounted) _refreshPlans();
                },
              ),
          ],
        ),
        if (canOpenEvent) ...[
          const SizedBox(height: 18),
          RdGroupedList(
            children: [
              RdListRow(
                leading: const RdRowIcon(Icons.event_outlined),
                title: l10n.rdTeamOpenEvent,
                subtitle: l10n.rdTeamOpenEventHint,
                onTap: () => context.push(RedesignRoutes.betaTarget('/attendance/${meeting.id}')),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
