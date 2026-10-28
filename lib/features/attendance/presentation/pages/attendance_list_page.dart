import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/attendance_providers.dart';
import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/providers/role_permission_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/utils/haptic_helper.dart';
import '../../../../core/utils/event_list_utils.dart';
import '../../../../data/models/attendance/attendance.dart';
import 'attendance_create_page.dart'; // UX_ATT
import '../../../../data/models/plan/plan.dart'; // ATT_DETAIL
import '../../../planning/presentation/pages/plan_viewer_page.dart'; // ATT_DETAIL
import '../../../../shared/widgets/loading/loading.dart';
import '../../../../shared/widgets/common/empty_state.dart';
import '../../../messages/presentation/widgets/notification_bell.dart'; // MESSAGES
import '../../../../shared/widgets/event_list/event_list_widgets.dart';
import '../../../../core/providers/duty_providers.dart';
import '../../../duty/presentation/pages/duty_distribute_page.dart';
import '../../../duty/presentation/widgets/duty_actions.dart';
import '../../../duty/presentation/widgets/my_duty_requests_section.dart';
import '../../../../shared/widgets/tenant/tenant_switcher_title.dart'; // SETTINGS2
import '../widgets/ios_condense_header.dart'; // UX_ATT
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK
import '../../../../shared/widgets/layout/ios_tab_bar.dart'; // IOS_SHELL
import '../../../../shared/widgets/layout/ionic_ios.dart'
    show IonTranslucentBarBackground, ionTranslucentTopPadding; // PARITY_R5


/// Attendance list page
class AttendanceListPage extends ConsumerStatefulWidget {
  const AttendanceListPage({super.key});

  @override
  ConsumerState<AttendanceListPage> createState() => _AttendanceListPageState();
}

class _AttendanceListPageState extends ConsumerState<AttendanceListPage> {
  bool _showAllPast = false;
  // UX_ATT: iOS large title (Ionic ion-header collapse="condense")
  final _condense = CondenseHeaderController();

  @override
  void dispose() {
    _condense.dispose();
    super.dispose();
  }

  /// Navigate to detail page, refresh list data when returning
  Future<void> _navigateToDetail(int attendanceId) async {
    // LOGIC_SELF: Ionic openAttendance returns for anyone who is not a
    // conductor (ADMIN/RESPONSIBLE) or helper (HELPER/VOICE_LEADER_HELPER).
    if (!ref.read(effectiveRoleProvider).canAddAttendance) return;
    await context.push('/attendance/$attendanceId');
    if (mounted) {
      ref.invalidate(realtimeAttendanceListProvider);
    }
  }

  // UX_ATT: Ionic att-list remove(): alert with header only,
  // "Abbrechen" / "Fortfahren".
  Future<void> _confirmDelete(BuildContext context, Attendance attendance) async {
    HapticHelper.medium();
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(context.l10n.attListRemoveConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.attListContinue),
          ),
        ],
      ),
    );
    if ((confirmed ?? false) && context.mounted) {
      await ref.read(attendanceNotifierProvider.notifier).deleteAttendance(attendance.id!);
      ref.invalidate(realtimeAttendanceListProvider);
    }
  }

  // ATT_DETAIL: Ablaufplan on the list (Ionic hasPlan / openPlanViewer)
  /// Beobachter never see the Ablaufplan.
  bool _hasPlan(Attendance att) {
    if (ref.read(effectiveRoleProvider).isViewer) return false;
    final fields = att.plan?['fields'];
    return fields is List && fields.isNotEmpty;
  }

  /// Opens the Ablaufplan read-only; a Termin running today starts in live mode.
  Future<void> _openPlanViewer(Attendance att) async {
    Plan? plan;
    try {
      plan = Plan.fromJson(att.plan!);
    } catch (_) {
      return;
    }
    await showPlanViewer(
      context,
      attendance: PlanAttendance(
        id: att.id,
        date: att.date,
        durationDays: att.durationDays,
        plan: plan,
        typeId: att.typeId,
        typeInfo: att.typeInfo,
        startTime: att.startTime,
        sharePlan: att.sharePlan,
      ),
      plan: plan,
      title: (plan.title?.trim().isNotEmpty ?? false)
          ? plan.title!.trim()
          : (att.typeInfo?.isNotEmpty ?? false)
              ? att.typeInfo!
              : context.l10n.signoutRunSheet,
      defaultLive: EventListUtils.isRunning(att.date, att.durationDays),
    );
  }

  /// Termintyp filter popover (Ionic att-list "options" popover).
  Widget _buildTypeFilterButton(List<AttendanceType> types) {
    final filter = ref.watch(attendanceListTypeFilterProvider);
    final active = filter != null;
    return PopupMenuButton<String>(
      tooltip: context.l10n.teamOrgFilter,
      icon: Icon(Icons.tune, color: active ? AppColors.primary : null),
      onSelected: (value) => ref.read(attendanceListTypeFilterProvider.notifier).state =
          value == '__all__' ? null : value,
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: '__all__',
          child: Row(
            children: [
              const SizedBox(width: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.l10n.attListShowAll,
                  style: TextStyle(color: !active ? AppColors.primary : null),
                ),
              ),
              if (!active) const Icon(Icons.check, color: AppColors.primary, size: 20),
            ],
          ),
        ),
        for (final type in types)
          if (type.id != null)
            PopupMenuItem<String>(
              value: type.id!,
              child: Row(
                children: [
                  Icon(Icons.circle, size: 20, color: ColorUtils.parseNamedColor(type.color)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      type.name,
                      style: TextStyle(color: filter == type.id ? AppColors.primary : null),
                    ),
                  ),
                  if (filter == type.id)
                    const Icon(Icons.check, color: AppColors.primary, size: 20),
                ],
              ),
            ),
      ],
    );
  }

  /// "{n} % · {n} anwesend · {n} entschuldigt · {n} abwesend" bubbles of the
  /// today card; duty Termine show "{text} besetzt" plus the names
  /// (Ionic ev-today__stats).
  List<EventTodayStat> _todayStats(Attendance att, DutyTermin? duty) {
    if (duty != null) {
      return [
        EventTodayStat(context.l10n.attListDutyFilled(dutyBadge(duty).text), strong: true),
        EventTodayStat(dutyNames(duty)),
      ];
    }
    final counts = ref.watch(attendanceStatusCountsProvider(att.id!)).valueOrNull;
    if (counts == null) return const [];
    return [
      EventTodayStat('${(att.percentage ?? 0).round()} %', strong: true),
      EventTodayStat(context.l10n.attListCountPresent(counts.present)),
      if (counts.excused > 0) EventTodayStat(context.l10n.attListCountExcused(counts.excused)),
      if (counts.absent > 0) EventTodayStat(context.l10n.attListCountAbsent(counts.absent)),
    ];
  }
  // END ATT_DETAIL

  // UX_ATT: create flow opens as sheet over the list (Ionic addAttModal).
  Future<void> _openCreate() async {
    final created = await showAttendanceCreateSheet(context);
    if (created && mounted) ref.invalidate(realtimeAttendanceListProvider);
  }

  /// UX_ATT: Ionic noDataContainer: plain 80 px icon, label, small button.
  Widget _buildEmpty(bool largeTitle) {
    final canCreate = ref.watch(canCreateAttendanceProvider);
    return _condense.listen(
      child: ListView(
        children: [
          if (largeTitle) IosLargeTitle(context.l10n.attListEvents),
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.6,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_box_outlined,
                    size: 80,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  const SizedBox(height: 8),
                  Text(context.l10n.attListNoEventsYet, style: const TextStyle(fontSize: 16)),
                  if (canCreate) ...[
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _openCreate,
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: Text(context.l10n.attListAddEvent),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// UX_ATT: round "+" FAB bottom right (Ionic ion-fab). On iOS the Ionic
  /// iOS 26 theme draws it as a 61 px white glass button with a dark icon.
  Widget _buildFab(BuildContext context) => IonFabButton(
        onPressed: _openCreate,
        tooltip: context.l10n.attListAddEvent,
        icon: Icons.add,
      );

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final attendanceAsync = ref.watch(realtimeAttendanceListProvider);
    // Use effectiveRoleProvider to support debug role override
    final role = ref.watch(effectiveRoleProvider);
    // UX_ATT: Ionic shows the large "Termine" title (iOS) only with one tenant;
    // with several tenants the toolbar holds the tenant switcher instead.
    final singleTenant = (ref.watch(userTenantsProvider).valueOrNull?.length ?? 0) <= 1;
    final largeTitle = isIosLook(context) && singleTenant;

    final ios = isIosLook(context);
    return Scaffold(
      // PARITY_R5: Ionic `ion-content fullscreen` under the translucent header
      extendBodyBehindAppBar: ios,
      appBar: AppBar(
        // PARITY_R5: ion-header translucent – page colour at 20 % over a
        // backdrop blur once the large title is condensed (always with the
        // tenant switcher, which has no large title).
        backgroundColor: ios ? Colors.transparent : null,
        shape: ios ? const Border() : null,
        flexibleSpace: ValueListenableBuilder<bool>(
          valueListenable: _condense.collapsed,
          builder: (context, collapsed, _) =>
              IonTranslucentBarBackground(visible: collapsed || !largeTitle),
        ),
        // UX_AUTH: Ionic keeps the tenant switcher left (ion-buttons slot=start).
        centerTitle: TenantSwitcherTitle.centerTitle(ref),
        // SETTINGS2: Ionic att-list header tenant switcher
        title: _condense.toolbarTitle(
          enabled: largeTitle,
          title: TenantSwitcherTitle(
            fallbackTitle: context.l10n.attListEvents,
            singleTenantTitle: context.l10n.attListEvents,
          ),
        ),
        // UX_ATT: Ionic order: Filter, Dienste verteilen, Glocke
        // IOS_SHELL: iOS → one glass capsule (ion-buttons slot="end")
        actions: [
          ToolbarButtonGroup(children: [
          // ATT_DETAIL: Termintyp filter
          _buildTypeFilterButton(ref.watch(attendanceTypesProvider).valueOrNull ?? const []),
          // DUTY: "Dienste verteilen" for leaders when the tenant uses the Dienstplan
          // LOGIC_SELF: Ionic isConductor = ADMIN || RESPONSIBLE (no viewer)
          if ((role.isAdmin || role.isResponsible) && ref.watch(hasDutyTypesProvider))
            IconButton(
              icon: const Icon(Icons.shuffle),
              tooltip: context.l10n.attListDistributeDuties,
              onPressed: () async {
                final saved = await openDutyDistributePage(context);
                if (saved && mounted) ref.invalidate(realtimeAttendanceListProvider);
              },
            ),
          const NotificationBell(), // MESSAGES
          ]),
        ],
      ),
      // IOS_ATT_PAGES: Ionic iOS page is white, rows sit directly on it
      backgroundColor: eventPageBackground(context),
      body: attendanceAsync.when(
        skipLoadingOnReload: true,
        // UX_ATT: Ionic skeleton: one-line items
        loading: () => ListView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            if (largeTitle) IosLargeTitle(context.l10n.attListEvents),
            const ListSkeleton(
              itemCount: 12,
              showAvatar: false,
              showSubtitle: false,
              showDividers: true,
            ),
          ],
        ),
        error: (error, stack) => EmptyStateWidget(
          icon: Icons.error_outline,
          title: context.l10n.attendanceFlutterLoadError,
          subtitle: context.l10n.attendanceFlutterListLoadFailed,
          actionLabel: context.l10n.messagesRetry,
          onAction: () => ref.invalidate(realtimeAttendanceListProvider),
        ),
        data: (attendances) {
          // ATT_DETAIL: an active type filter without matches still shows the list
          if (attendances.isEmpty && ref.watch(attendanceListTypeFilterProvider) == null) {
            return _buildEmpty(largeTitle);
          }

          // Get highlighted type IDs from AttendanceTypes (like Ionic)
          final attendanceTypes = ref.watch(attendanceTypesProvider).valueOrNull ?? [];
          final highlightedTypeIds = attendanceTypes
              .where((t) => t.highlight)
              .map((t) => t.id)
              .whereType<String>()
              .toSet();

          // Use memoized categorized attendances (no more date parsing in build)
          final categorized = ref.watch(categorizedAttendancesProvider);
          final averagePercent = ref.watch(averageAttendancePercentProvider);
          // DUTY: Besetzung of duty Termine by attendance id
          final dutyTermine = ref.watch(dutyTermineByIdProvider).valueOrNull ?? const <int, DutyTermin>{};

          final current = categorized.current;
          final upcomingGroups = EventListUtils.groupByMonth(categorized.upcoming, (a) => a.date);
          final past = categorized.past;
          final pastPreview = _showAllPast
              ? past
              : past.take(EventListUtils.pastPreviewCount).toList();
          final typesById = {for (final t in attendanceTypes) t.id: t};

          // UX_ATT: Ionic getReadableDate / getEventTitle / getEventMeta
          String readableDate(Attendance att) {
            final type = typesById[att.typeId];
            return EventListUtils.readableDate(
              att.date,
              allDay: type?.allDay ?? false,
              durationDays: att.durationDays ?? type?.durationDays,
            );
          }

          String title(Attendance att) {
            if (att.typeInfo?.isNotEmpty ?? false) return att.typeInfo!;
            final type = typesById[att.typeId];
            if (type != null && !type.hideName) return type.name;
            return readableDate(att);
          }

          // Ionic getEventMeta: date (multi-day / today card), time, place.
          // Duty names are a separate line (Ionic second <p>).
          String meta(Attendance att, {bool withDate = false, bool withPlace = true}) {
            final type = typesById[att.typeId];
            final multiDay = (att.durationDays ?? 1) > 1 ||
                ((type?.allDay ?? false) && (type?.durationDays ?? 1) > 1);
            final date = readableDate(att);
            return EventListUtils.meta([
              if ((withDate || multiDay) && date != title(att)) date,
              if (!(type?.allDay ?? false))
                EventListUtils.timeRange(
                  att.startTime ?? type?.startTime,
                  att.endTime ?? type?.endTime,
                ),
              if (withPlace) att.place,
            ]);
          }

          // UX_ATT: "{present} von {total} anwesend" of past rows
          // Hidden until the counts are loaded (no "0 von 0" flash).
          final listCounts =
              ref.watch(attendanceListStatusCountsProvider).valueOrNull;
          String? countText(Attendance att) {
            final counts = listCounts?[att.id];
            if (counts == null) return null;
            final total = counts.total;
            final present = ((att.percentage ?? 0) / 100 * total).round();
            return context.l10n.attListPresentOf(present, total);
          }

          EventPill percentPill(Attendance att) {
            // DUTY: Besetzung instead of % for duty Termine
            final duty = dutyTermine[att.id];
            if (duty != null) {
              final badge = dutyBadge(duty);
              return EventPill(label: badge.text, color: badge.color);
            }
            final perc = (att.percentage ?? 0).round();
            return EventPill(label: '$perc%', color: EventListUtils.percentageColor(perc));
          }

          // UX_ATT: Ionic: delete on the current card for Dirigent + Helfer,
          // on list rows only for the Dirigent; icon-only trash option that
          // also fires on a full swipe (ion-item-option expandable / ionSwipe).
          Widget slidable(Attendance att, Widget child, {bool helperToo = false}) {
            final allowed = helperToo ? role.canAddAttendance : role.isConductor;
            if (!allowed) return child;
            return Slidable(
              key: ValueKey('att-${att.id}'),
              endActionPane: ActionPane(
                motion: const ScrollMotion(),
                extentRatio: 0.25,
                dismissible: DismissiblePane(
                  closeOnCancel: true,
                  confirmDismiss: () async {
                    await _confirmDelete(context, att);
                    return false;
                  },
                  onDismissed: () {},
                ),
                children: [
                  SlidableAction(
                    onPressed: (_) => _confirmDelete(context, att),
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    icon: Icons.delete_outline,
                  ),
                ],
              ),
              child: child,
            );
          }

          final currentDuty = current == null ? null : dutyTermine[current.id];
          final averageRounded = averagePercent?.round() ?? 0;

          return Builder(builder: (body) => RefreshIndicator.adaptive(
            edgeOffset: ionTranslucentTopPadding(body, ios),
            onRefresh: () async {
              // FN-008: invalidate to trigger fresh fetch from realtime provider
              ref.invalidate(realtimeAttendanceListProvider);
            },
            child: _condense.listen(
              child: ListView(
                // Room for the FAB below the last card (Ionic marginBottom)
                padding: EdgeInsets.only(
                    top: ionTranslucentTopPadding(body, ios), // PARITY_R5
                    bottom: scrollEndPadding(context, base: 16, fabRoom: 80)),
                children: [
                  if (largeTitle) IosLargeTitle(context.l10n.attListEvents),
                  // DUTY: own duties waiting for confirmation
                  const MyDutyRequestsSection(),
                  // "Heute" / "Nächster Termin" – filled card (Ionic ev-today--filled),
                  // only for Dirigent + Helfer like Ionic.
                  if (current != null && role.canAddAttendance) ...[
                    EventMonthHeader(
                      label: EventListUtils.isRunning(current.date, current.durationDays)
                          ? context.l10n.teamOrgTodayCap
                          : context.l10n.teamOrgNextEvent,
                    ),
                    slidable(
                      current,
                      helperToo: true,
                      EventTodayFilledCard(
                        date: current.date,
                        title: title(current),
                        meta: meta(current, withDate: true, withPlace: false),
                        place: current.place,
                        onTap: () => _navigateToDetail(current.id!),
                        // ATT_DETAIL: status counters / duty Besetzung
                        stats: current.id == null ? const [] : _todayStats(current, currentDuty),
                        ctas: [
                          EventTodayCta(
                            icon: Icons.check_box_outlined,
                            label: _hasPlan(current)
                                ? context.l10n.signoutAttendance
                                : context.l10n.attendanceFlutterRecordAttendance,
                            onTap: () => _navigateToDetail(current.id!),
                          ),
                          // ATT_DETAIL: Ablaufplan
                          if (_hasPlan(current))
                            EventTodayCta(
                              icon: Icons.description_outlined,
                              label: context.l10n.signoutRunSheet,
                              secondary: true,
                              onTap: () => _openPlanViewer(current),
                            ),
                        ],
                      ),
                    ),
                  ],

                  if (categorized.upcoming.isNotEmpty) ...[
                    EventSectionHeader(title: context.l10n.signoutUpcoming, count: categorized.upcoming.length),
                    for (final group in upcomingGroups) ...[
                      EventMonthHeader(label: group.label),
                      EventListCard(plain: true, children: [
                        for (final att in group.items)
                          slidable(
                            att,
                            EventRow(
                              date: att.date,
                              title: title(att),
                              // DUTY: headset icon before duty Termine
                              titleLeading: dutyTermine[att.id] != null
                                  ? const Icon(Icons.headset_mic_outlined, size: 16, color: AppColors.primary)
                                  : null,
                              subtitle: meta(att),
                              extra: [
                                if (dutyTermine[att.id] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      dutyNames(dutyTermine[att.id]!),
                                      style: const TextStyle(color: AppColors.medium, fontSize: 14),
                                    ),
                                  ),
                              ],
                              highlight: highlightedTypeIds.contains(att.typeId),
                              onTap: () => _navigateToDetail(att.id!),
                              trailing: [
                                // ATT_DETAIL: "Ablaufplan anzeigen"
                                if (_hasPlan(att))
                                  IconButton(
                                    tooltip: context.l10n.signoutShowRunSheet,
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.description_outlined, color: AppColors.primary),
                                    onPressed: () => _openPlanViewer(att),
                                  ),
                                percentPill(att),
                              ],
                            ),
                          ),
                      ]),
                    ],
                  ],

                  if (past.isNotEmpty) ...[
                    EventSectionHeader(title: context.l10n.signoutPast, count: past.length),
                    EventListCard(plain: true, children: [
                      // UX_ATT: Ionic ev-summary "Durchschnitt" + pill inside the list
                      EventSummaryRow(
                        label: context.l10n.attListAverage,
                        pill: EventPill(
                          label: '$averageRounded%',
                          color: EventListUtils.percentageColor(averageRounded),
                        ),
                      ),
                      for (final att in pastPreview)
                        slidable(
                          att,
                          EventRow(
                            date: att.date,
                            title: title(att),
                            subtitle: [readableDate(att), countText(att)]
                                .whereType<String>()
                                .join(' · '),
                            past: true,
                            highlight: highlightedTypeIds.contains(att.typeId),
                            onTap: () => _navigateToDetail(att.id!),
                            trailing: [percentPill(att)],
                          ),
                        ),
                      if (past.length > EventListUtils.pastPreviewCount)
                        EventMoreLink(
                          label: _showAllPast ? context.l10n.attendanceFlutterShowLess : context.l10n.attendanceFlutterShowAllCount(past.length),
                          onTap: () => setState(() => _showAllPast = !_showAllPast),
                        ),
                    ]),
                  ],
                ],
              ),
            ),
          ));
        },
      ),
      // FAB only for roles that can add attendances (not VIEWER).
      // SETTINGS_EXT: Helfer abhängig von Rollenberechtigung attendance_create
      // IOS_SHELL: iOS → ion-fab in the tab bar row
      floatingActionButton: ref.watch(canCreateAttendanceProvider)
          ? TabBarFab(child: _buildFab(context))
          : null,
    );
  }
}
