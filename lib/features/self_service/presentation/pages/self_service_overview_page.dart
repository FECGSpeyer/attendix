import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/self_service_providers.dart';
import '../../../../core/providers/role_permission_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../../core/utils/event_list_utils.dart';
import '../../../../shared/widgets/event_list/event_list_widgets.dart';
import '../widgets/plan_viewer_sheet.dart';
import '../widgets/self_service_event_actions.dart';
import '../../../messages/presentation/widgets/notification_bell.dart'; // MESSAGES

/// "Übersicht" – all Termine of the user across all tenants
/// (Ionic `selfService/overview`) in the card layout.
class SelfServiceOverviewPage extends ConsumerStatefulWidget {
  const SelfServiceOverviewPage({super.key});

  @override
  ConsumerState<SelfServiceOverviewPage> createState() =>
      _SelfServiceOverviewPageState();
}

class _SelfServiceOverviewPageState
    extends ConsumerState<SelfServiceOverviewPage> {
  String _groupingMode = 'chronological'; // or 'byTenant'
  bool _showAllPast = false;

  SelfServiceEventActions _actions() {
    final tenant = ref.read(currentTenantProvider);
    final notifier = ref.read(signInOutNotifierProvider.notifier);
    final canAccessFiles = ref.read(canAccessFilesProvider);
    final currentTenantId = tenant?.id;

    Future<bool> done() async => !ref.read(signInOutNotifierProvider).hasError;

    return SelfServiceEventActions(
      absenceReasons: EventListUtils.absenceReasonsOf(tenant?.absenceReasons),
      lateReasons: EventListUtils.lateReasonsOf(tenant?.lateReasons),
      supportsRegistrationFields: false,
      signIn: (att, note) async {
        await notifier.signIn(att.id!, SignInType.fromStatus(att.status), notes: note);
        return done();
      },
      signOut: (att, reason, isLate) async {
        await notifier.signOut([att.id!], reason, isLateComing: isLate);
        return done();
      },
      updateNote: (att, note) async {
        await notifier.updateNote(att.id!, note);
        return done();
      },
      openPlan: (att) => showPlanViewerSheet(context, attendance: att),
      // Files of other tenants are only reachable after switching the tenant.
      canAccessFiles: (att) => canAccessFiles && att.tenantId == currentTenantId,
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(allPersonAttendancesAcrossTenantsProvider);
    await ref.read(allPersonAttendancesAcrossTenantsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final attendancesAsync = ref.watch(allPersonAttendancesAcrossTenantsProvider);
    final stats = ref.watch(attendanceStatsProvider);
    final upcomingAll = ref.watch(upcomingAttendancesAcrossTenantsProvider);
    final past = ref.watch(pastAttendancesAcrossTenantsProvider);
    ref.watch(canAccessFilesProvider);
    final actions = _actions();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alle Termine'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Legende',
            onPressed: () => showEventLegendSheet(context),
          ),
          const NotificationBell(), // MESSAGES
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'chronological', label: Text('Chronologisch')),
                  ButtonSegment(value: 'byTenant', label: Text('Nach Instanz')),
                ],
                selected: {_groupingMode},
                onSelectionChanged: (value) =>
                    setState(() => _groupingMode = value.first),
              ),
            ),
          ),
        ),
      ),
      body: attendancesAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Termine werden geladen...'),
            ],
          ),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
              const SizedBox(height: 8),
              Text('Fehler: $error', textAlign: TextAlign.center),
              TextButton(onPressed: _refresh, child: const Text('Erneut versuchen')),
            ],
          ),
        ),
        data: (attendances) {
          final current = upcomingAll.isNotEmpty ? upcomingAll.first : null;
          final upcoming = upcomingAll.length > 1 ? upcomingAll.sublist(1) : const <CrossTenantPersonAttendance>[];
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                if (past.isNotEmpty)
                  EventSummary(percentage: stats.percentage, lateCount: stats.lateCount),
                if (_groupingMode == 'chronological')
                  ..._buildChronological(current, upcoming, past, actions)
                else
                  ..._buildByTenant(attendances, actions),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _tenantLine(CrossTenantPersonAttendance att) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: ColorUtils.parseNamedColor(att.tenantColor),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              att.tenantName,
              style: const TextStyle(color: AppColors.medium, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(CrossTenantPersonAttendance att, SelfServiceEventActions actions, {required bool showTenant}) {
    final past = att.isPast;
    final meta = att.eventMeta(withDate: past, withPlace: false);
    return EventRow(
      date: att.date,
      title: att.eventTitle,
      subtitle: meta,
      past: past,
      highlight: att.highlight,
      // Past rows open nothing
      onTap: past ? null : () => actions.presentActions(context, att),
      extra: [
        if (showTenant) _tenantLine(att),
        if (!past) EventChips(chips: actions.chips(context, att, withPlan: false)),
      ],
      trailing: [
        if (past && actions.hasFilesFolder(att))
          IconButton(
            icon: const Icon(Icons.folder_open_outlined),
            tooltip: 'Dateiablage öffnen',
            onPressed: () => openFilesFolderRoute(context, att.filesFolder!),
          ),
        EventPill.status(att.status, past: past),
      ],
    );
  }

  List<Widget> _buildChronological(
    CrossTenantPersonAttendance? current,
    List<CrossTenantPersonAttendance> upcoming,
    List<CrossTenantPersonAttendance> past,
    SelfServiceEventActions actions,
  ) {
    final groups = EventListUtils.groupByMonth(upcoming, (a) => a.date);
    final pastPreview = _showAllPast
        ? past
        : past.take(EventListUtils.pastPreviewCount).toList();
    return [
      if (current != null) ...[
        EventMonthHeader(label: current.isRunning ? 'Heute' : 'Nächster Termin'),
        EventTodayCard(
          date: current.date,
          title: current.eventTitle,
          meta: current.eventMeta(withDate: true, withPlace: false),
          extraHeader: [_tenantLine(current)],
          status: EventPill.status(current.status),
          place: current.place,
          chips: actions.chips(context, current, withPlan: false),
          actions: actions.quickActionButtons(context, current),
          onMore: () => actions.presentActions(context, current, hideQuickActions: true),
        ),
      ],
      EventSectionHeader(title: 'Anstehend', count: upcoming.length),
      for (final group in groups) ...[
        EventMonthHeader(label: group.label),
        EventListCard(children: [
          for (final att in group.items) _row(att, actions, showTenant: true),
        ]),
      ],
      if (upcoming.isEmpty)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text('Keine anstehenden Termine',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.medium)),
        ),
      if (past.isNotEmpty) ...[
        EventSectionHeader(title: 'Vergangen', count: past.length),
        EventListCard(children: [
          for (final att in pastPreview) _row(att, actions, showTenant: true),
          if (past.length > EventListUtils.pastPreviewCount)
            EventMoreLink(
              label: _showAllPast ? 'Weniger anzeigen' : 'Alle ${past.length} anzeigen',
              onTap: () => setState(() => _showAllPast = !_showAllPast),
            ),
        ]),
      ],
    ];
  }

  List<Widget> _buildByTenant(
    List<CrossTenantPersonAttendance> attendances,
    SelfServiceEventActions actions,
  ) {
    final grouped = <int, List<CrossTenantPersonAttendance>>{};
    for (final att in attendances) {
      grouped.putIfAbsent(att.tenantId, () => []).add(att);
    }
    if (grouped.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.all(24),
          child: Text('Keine Termine gefunden',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.medium)),
        ),
      ];
    }
    int byDate(CrossTenantPersonAttendance a, CrossTenantPersonAttendance b) =>
        (EventListUtils.parse(a.date) ?? DateTime(1970))
            .compareTo(EventListUtils.parse(b.date) ?? DateTime(1970));

    final widgets = <Widget>[];
    for (final list in grouped.values) {
      // Upcoming first (ascending), then past (descending)
      final up = list.where((a) => !a.isPast).toList()..sort(byDate);
      final down = list.where((a) => a.isPast).toList()..sort((a, b) => byDate(b, a));
      final sorted = [...up, ...down];
      final first = sorted.first;
      widgets.add(EventSectionHeader(
        title: first.tenantName,
        count: sorted.length,
        leading: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: ColorUtils.parseNamedColor(first.tenantColor),
            shape: BoxShape.circle,
          ),
        ),
      ));
      widgets.add(EventListCard(children: [
        for (final att in sorted) _row(att, actions, showTenant: false),
      ]));
    }
    return widgets;
  }
}
