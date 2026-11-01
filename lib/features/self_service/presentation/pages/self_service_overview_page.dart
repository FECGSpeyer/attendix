import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/self_service_providers.dart';
import '../../../../core/providers/role_permission_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../../core/utils/event_list_utils.dart';
import '../../../../shared/widgets/event_list/event_list_widgets.dart';
import '../../../../shared/widgets/layout/ionic_ios.dart';
import '../widgets/plan_viewer_sheet.dart';
import '../widgets/self_service_event_actions.dart';
import '../../../../l10n/l10n.dart';
import '../../../messages/presentation/widgets/notification_bell.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../shared/widgets/adaptive/ion_toolbar_segment.dart';
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart';

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
    // ASTRA_FILES: role + files_shared of the other instances come from the
    // already loaded tenantUsers/tenants rows (no extra query).
    final userTenants = ref.read(userTenantsProvider).valueOrNull ?? const <Tenant>[];

    Future<bool> done() async => !ref.read(signInOutNotifierProvider).hasError;

    return SelfServiceEventActions(
      absenceReasons: EventListUtils.absenceReasonsOf(tenant?.absenceReasons),
      lateReasons: EventListUtils.lateReasonsOf(tenant?.lateReasons),
      supportsRegistrationFields: false,
      overviewMode: true,
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
      // ASTRA_FILES: Ionic hasFilesFolder → canAccessFiles(att.tenantId), the
      // permission in the Termin's own instance; opening switches to it.
      canAccessFiles: (att) => canAccessFilesInTenant(
        tenantId: att.tenantId,
        currentTenantId: currentTenantId,
        currentTenantAccess: canAccessFiles,
        userTenants: userTenants,
      ),
      currentTenantId: currentTenantId,
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
    ref.watch(userTenantsProvider);
    final actions = _actions();

    // UX_SONGS_SELF: Ionic condensed large title + segment toolbar.
    return CondenseHeader(
      builder: (context, condensed) => Scaffold(
      appBar: AppBar(
        // IOS_R4: Ionic collapse="condense" – no hairline under the segment
        // toolbar (and the page colour behind it) until the large title has
        // scrolled away.
        // PARITY_R5: iOS translucent header (blur once condensed).
        backgroundColor: isIosLook(context)
            ? Colors.transparent
            : condenseBarColor(context, condensed,
                pageBackground: eventPageBackground(context)),
        shape: isIosLook(context)
            ? const Border()
            : condenseBarShape(context, condensed),
        flexibleSpace: IonTranslucentBarBackground(visible: condensed),
        title: CondenseTitle(
          condensed: condensed,
          child: Text(context.l10n.selfServiceAllEvents),
        ),
        // IOS_SHELL: iOS → one glass capsule (ion-buttons slot="end")
        actions: [
          ToolbarButtonGroup(children: [
            IconButton(
              // IOS_THEME2: ionicon information-outline (plain "i")
              icon: const IonInformationIcon(),
              tooltip: context.l10n.signoutLegend,
              onPressed: () => showEventLegendSheet(context),
            ),
            const NotificationBell(),
          ]),
        ],
        // IOS_ATT_PAGES: second ion-toolbar with the segment – iOS: neutral
        // segmented control centred in the toolbar; Material: full width.
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(IonToolbarSegment.toolbarHeight(context)),
          child: IonToolbarSegment<String>(
            items: [
              IonSegmentItem(value: 'chronological', label: Text(context.l10n.selfServiceChronological)),
              IonSegmentItem(value: 'byTenant', label: Text(context.l10n.selfServiceByInstance)),
            ],
            value: _groupingMode,
            onChanged: (value) => setState(() => _groupingMode = value),
            // ATT_SPACING: overview.page.scss `ion-segment { padding: 8px }`
            trackPadding: 8,
          ),
        ),
      ),
      // PARITY_R5: Ionic `ion-content fullscreen` under the translucent header
      extendBodyBehindAppBar: isIosLook(context),
      // IOS_ATT_PAGES: Ionic iOS page is white, rows sit directly on it
      backgroundColor: eventPageBackground(context),
      body: attendancesAsync.when(
        // Ionic: ion-card with spinner and text at the top
        loading: () => ListView(
          children: [
            IonLargeTitle(context.l10n.selfServiceAllEvents),
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppSpinner(),
                    const SizedBox(height: 8),
                    Text(context.l10n.selfServiceLoadingEvents, textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ],
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
              const SizedBox(height: 8),
              Text(context.l10n.signoutFlutterError(friendlyErrorMessage(error)), textAlign: TextAlign.center),
              TextButton(onPressed: _refresh, child: IonButtonLabel(context.l10n.messagesRetry)),
            ],
          ),
        ),
        data: (attendances) {
          final current = upcomingAll.isNotEmpty ? upcomingAll.first : null;
          final upcoming = upcomingAll.length > 1 ? upcomingAll.sublist(1) : const <CrossTenantPersonAttendance>[];
          return Builder(builder: (body) => RefreshIndicator.adaptive(
            onRefresh: _refresh,
            edgeOffset: ionTranslucentTopPadding(body, isIosLook(context)),
            child: ListView(
              padding: EdgeInsets.only(
                  top: ionTranslucentTopPadding(body, isIosLook(context)),
                  bottom: scrollEndPadding(context, base: 32)),
              children: [
                IonLargeTitle(context.l10n.selfServiceAllEvents),
                // Ionic `.ev-summary.overview-summary`: card, margin 8 16 0
                // (iOS: card background = white page → plain)
                if (past.isNotEmpty)
                  // PWA_PARITY: plain block in both modes (no md card shadow).
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: EventSummary(percentage: stats.percentage, lateCount: stats.lateCount),
                  ),
                if (_groupingMode == 'chronological')
                  ..._buildChronological(current, upcoming, past, actions)
                else
                  ..._buildByTenant(attendances, actions),
              ],
            ),
          ));
        },
      ),
      ),
    );
  }

  /// Ionic `p.ev-empty`: margin 12 20, `--ion-color-medium`, the inherited
  /// 1rem (ATT_SPACING: 17pt #636469 on iOS, not 14pt light grey).
  Widget _empty(String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Text(
          text,
          style: TextStyle(
            color: EvMetrics.medium(context),
            fontSize: useIosLook(context) ? EvMetrics.rem(context, 1) : null,
            height: EvMetrics.lineHeight(context),
          ),
        ),
      );

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
              // ATT_SPACING: `<p class="tenant-line">` – an ion-label p
              // (.875rem, line-height normal), not a 12pt caption.
              style: TextStyle(
                color: useIosLook(context)
                    ? IonIos.labelP(Theme.of(context).brightness)
                    : AppColors.medium,
                fontSize: EvMetrics.rem(context, 0.875),
                height: EvMetrics.lineHeight(context),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(CrossTenantPersonAttendance att, SelfServiceEventActions actions, {required bool showTenant}) {
    // Ionic attHasPassed = attendanceHasEnded(att)
    final past = overviewHasEnded(att);
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
            tooltip: context.l10n.signoutOpenFiles,
            onPressed: () => actions.openFilesFolder(context, att),
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
        EventMonthHeader(label: current.isRunning ? context.l10n.teamOrgTodayCap : context.l10n.teamOrgNextEvent),
        EventTodayCard(
          bordered: true,
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
      EventSectionHeader(title: context.l10n.signoutUpcoming, count: upcoming.length),
      for (final group in groups) ...[
        EventMonthHeader(label: group.label),
        EventListCard(plain: true, children: [
          for (final att in group.items) _row(att, actions, showTenant: true),
        ]),
      ],
      // Ionic `.ev-empty`: margin 12 20, medium
      if (upcoming.isEmpty) _empty(context.l10n.selfServiceNoUpcoming),
      if (past.isNotEmpty) ...[
        EventSectionHeader(title: context.l10n.signoutPast, count: past.length),
        EventListCard(plain: true, children: [
          for (final att in pastPreview) _row(att, actions, showTenant: true),
          if (past.length > EventListUtils.pastPreviewCount)
            EventMoreLink(
              label: _showAllPast
                  ? context.l10n.signoutFlutterShowLess
                  : context.l10n.signoutFlutterShowAll(past.length),
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
    // Ionic groupByTenant
    final groups = groupOverviewByTenant(attendances);
    if (groups.isEmpty) {
      return [_empty(context.l10n.selfServiceNoEvents)];
    }

    final widgets = <Widget>[];
    for (final sorted in groups) {
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
      widgets.add(EventListCard(plain: true, children: [
        for (final att in sorted) _row(att, actions, showTenant: false),
      ]));
    }
    return widgets;
  }
}
