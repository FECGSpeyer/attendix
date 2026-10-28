import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/signout_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/event_list_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../data/repositories/sign_in_out_repository.dart';
import '../../../../shared/widgets/event_list/event_list_widgets.dart';
import '../../../../shared/widgets/event_list/excuse_reason_sheet.dart';
import '../../../self_service/presentation/widgets/plan_viewer_sheet.dart';
import '../../data/providers/parents_providers.dart';
import '../../../../core/services/tracking/tracking_event.dart';
import '../../../../core/services/tracking/tracking_service.dart';
import '../../../../l10n/l10n.dart';
import '../widgets/parents_header_widgets.dart'; // PROFILE_OFFLINE
import '../../../../core/providers/song_providers.dart'; // PROFILE_OFFLINE
import '../../../messages/presentation/widgets/notification_bell.dart'; // MESSAGES
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

/// Parents Portal Page (Ionic `selfService/parents`) in the card layout:
/// children with percentage, "Heute" card with one row per child, upcoming
/// Termine with a chip per child and past Termine.
class ParentsPortalPage extends ConsumerStatefulWidget {
  const ParentsPortalPage({super.key});

  @override
  ConsumerState<ParentsPortalPage> createState() => _ParentsPortalPageState();
}

class _ParentsPortalPageState extends ConsumerState<ParentsPortalPage> {
  bool _showAllPast = false;

  AttendanceType? _typeOf(String? typeId) {
    final types = ref.read(attendanceTypesProvider).valueOrNull ?? const [];
    return types.where((t) => t.id == typeId).firstOrNull;
  }

  String _readableDate(ParentAttendanceGroup g) {
    final type = _typeOf(g.typeId);
    return EventListUtils.readableDate(
      g.date,
      allDay: type?.allDay ?? false,
      durationDays: type?.durationDays,
    );
  }

  String _title(ParentAttendanceGroup g) {
    if (g.typeInfo != null && g.typeInfo!.isNotEmpty) return g.typeInfo!;
    final type = _typeOf(g.typeId);
    if (type != null && !type.hideName) return type.name;
    return _readableDate(g);
  }

  String _meta(ParentAttendanceGroup g, {bool withDate = false, bool withPlace = true}) {
    final type = _typeOf(g.typeId);
    final showDate = withDate ||
        EventListUtils.isMultiDay(g.durationDays) ||
        ((type?.allDay ?? false) && (type?.durationDays ?? 1) > 1);
    final date = _readableDate(g);
    return EventListUtils.meta([
      showDate && date != _title(g) ? date : '',
      EventListUtils.timeRange(g.startTime ?? type?.startTime, g.endTime ?? type?.endTime),
      withPlace ? g.place : '',
    ]);
  }

  bool _highlight(ParentAttendanceGroup g) =>
      _typeOf(g.typeId)?.highlight ?? g.legacyType == 'vortrag';

  String _initials(ChildPersonAttendance c) {
    final name = c.childFirstName.isNotEmpty ? c.childFirstName : c.childName;
    return name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();
  }

  List<Widget> _chips(ParentAttendanceGroup g) => [
        if (g.hasPlan)
          EventChip(
            label: context.l10n.signoutRunSheet,
            icon: Icons.description_outlined,
            onTap: () => _showPlanViewer(g),
          ),
        if (g.description != null && g.description!.isNotEmpty)
          EventChip(
            label: context.l10n.signoutInfos,
            icon: Icons.info_outline,
            onTap: () => showEventDescriptionSheet(context, g.description!),
          ),
        if (g.attachmentUrl != null && g.attachmentUrl!.isNotEmpty)
          EventChip(
            label: context.l10n.selfServiceAttachment,
            icon: Icons.attach_file,
            onTap: () => openEventAttachment(g.attachmentUrl!),
          ),
      ];

  @override
  Widget build(BuildContext context) {
    final childrenAsync = ref.watch(parentChildrenProvider);
    final attendancesAsync = ref.watch(childrenAttendancesProvider);
    final current = ref.watch(currentParentAttendanceProvider);
    final upcomingAll = ref.watch(upcomingParentAttendancesProvider);
    final past = ref.watch(pastParentAttendancesProvider);
    ref.watch(attendanceTypesProvider);
    // PUSH: rebuild when a push tap sets the pending Termin while this page
    // is open (Ionic effect on pendingAttendanceId).
    ref.watch(pendingAttendanceIdProvider);

    final upcoming = upcomingAll.where((g) => !g.isRunning).toList();

    return Scaffold(
      appBar: AppBar(
        title: const ParentsTenantTitle(), // PROFILE_OFFLINE: tenant switcher
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: context.l10n.signoutLegend,
            onPressed: () => showEventLegendSheet(context),
          ),
          const NotificationBell(), // MESSAGES
        ],
      ),
      body: childrenAsync.when(
        loading: () => const Center(child: AppSpinner()),
        error: (error, stack) => _ErrorView(
          error: error,
          onRetry: () => ref.invalidate(parentChildrenProvider),
        ),
        data: (children) {
          if (children.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.family_restroom, size: 64, color: AppColors.medium),
                    const SizedBox(height: 12),
                    Text(context.l10n.selfServiceFlutterNoKids),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.selfServiceFlutterNoKidsHint,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.medium),
                    ),
                  ],
                ),
              ),
            );
          }

          return attendancesAsync.when(
            loading: () => const Center(child: AppSpinner()),
            error: (error, stack) => _ErrorView(
              error: error,
              onRetry: () => ref.invalidate(childrenAttendancesProvider),
            ),
            data: (attendances) {
              _openPendingAttendance([
                if (current != null) current,
                ...upcomingAll,
                ...past,
              ]);
              final pastPreview = _showAllPast
                  ? past
                  : past.take(EventListUtils.pastPreviewCount).toList();
              final groups = EventListUtils.groupByMonth(upcoming, (g) => g.date);
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(currentSongsProvider); // PROFILE_OFFLINE
                  ref.invalidate(parentChildrenProvider);
                  ref.invalidate(childrenAttendancesProvider);
                  await ref.read(childrenAttendancesProvider.future);
                },
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 32),
                  children: [
                    ParentsWelcomeCard(kids: children), // PROFILE_OFFLINE
                    if (current != null) ...[
                      EventMonthHeader(label: context.l10n.teamOrgTodayCap),
                      EventTodayCard(
                        date: current.date,
                        title: _title(current),
                        meta: _meta(current, withDate: true, withPlace: false),
                        place: current.place,
                        chips: _chips(current),
                        extraHeader: const [],
                        actions: const [],
                      ),
                      _TodayChildren(
                        group: current,
                        initials: _initials,
                        onChildTap: (c) => _showActions(current, child: c),
                      ),
                      if (children.length != 1)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: OutlinedButton(
                            onPressed: () => _showActions(current),
                            child: Text(context.l10n.selfServiceAllKidsSignInOut),
                          ),
                        ),
                    ],
                    if (upcoming.isNotEmpty) ...[
                      EventSectionHeader(title: context.l10n.signoutUpcoming, count: upcoming.length),
                      for (final group in groups) ...[
                        EventMonthHeader(label: group.label),
                        for (final g in group.items)
                          EventListCard(children: [
                            EventRow(
                              date: g.date,
                              title: _title(g),
                              subtitle: _meta(g),
                              highlight: _highlight(g),
                              extra: [
                                EventChips(chips: _chips(g)),
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      for (final c in g.childAttendances)
                                        _KidChip(
                                          initials: _initials(c),
                                          label:
                                              '${c.childFirstName} · ${EventListUtils.statusLabel(c.status)}',
                                          status: c.status,
                                          onTap: () => _showActions(g, child: c),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                              trailing: [
                                if (children.length != 1)
                                  TextButton(
                                    onPressed: () => _showActions(g),
                                    child: Text(context.l10n.commonAll),
                                  ),
                              ],
                            ),
                          ]),
                      ],
                    ],
                    if (past.isNotEmpty) ...[
                      EventSectionHeader(title: context.l10n.signoutPast, count: past.length),
                      EventListCard(children: [
                        for (final g in pastPreview)
                          EventRow(
                            date: g.date,
                            title: _title(g),
                            past: true,
                            highlight: _highlight(g),
                            extra: [
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    for (final c in g.childAttendances)
                                      EventPill(
                                        label:
                                            '${c.childFirstName} · ${EventListUtils.statusLabel(c.status, past: true)}',
                                        color: EventListUtils.statusColor(c.status),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        if (past.length > EventListUtils.pastPreviewCount)
                          EventMoreLink(
                            label: _showAllPast
                                ? context.l10n.signoutFlutterShowLess
                                : context.l10n.signoutFlutterShowAll(past.length),
                            onTap: () => setState(() => _showAllPast = !_showAllPast),
                          ),
                      ]),
                    ],
                    if (attendances.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          context.l10n.selfServiceNoEvents,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.medium),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// LOGIC_SELF: opens the Termin of a deep link / bell tap once the data is
  /// loaded (Ionic ParentsPage pendingAttendanceId → openAttendanceById,
  /// action sheet for all kids).
  void _openPendingAttendance(List<ParentAttendanceGroup> groups) {
    final pendingId = ref.read(pendingAttendanceIdProvider);
    if (pendingId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ref.read(pendingAttendanceIdProvider) != pendingId) return;
      ref.read(pendingAttendanceIdProvider.notifier).state = null;
      final group = groups.where((g) => g.attendanceId == pendingId).firstOrNull;
      if (group != null) _showActions(group);
    });
  }

  /// Action sheet for one child or all children of a Termin (Ionic openActionSheet).
  Future<void> _showActions(ParentAttendanceGroup group, {ChildPersonAttendance? child}) async {
    final ids = (child != null ? [child] : group.childAttendances)
        .map((c) => c.id)
        .whereType<String>()
        .toList();
    if (ids.isEmpty) {
      ToastHelper.showWarning(context, context.l10n.selfServiceFlutterNoValidEntries);
      return;
    }

    final type = _typeOf(group.typeId);
    final lateAllowed = type?.availableStatuses == null ||
        type!.availableStatuses!.contains(AttendanceStatus.late);

    var showSignIn = true;
    var showSignOut = true;
    var showLate = lateAllowed;
    if (child != null) {
      if (child.status == AttendanceStatus.present) {
        showSignIn = false;
      } else if (child.status == AttendanceStatus.absent) {
        showSignOut = false;
      } else if (child.status == AttendanceStatus.late) {
        showLate = false;
      }
    }

    final action = await showAppActionSheet<String>(
      context,
      title: child != null ? '${child.childFirstName} · ${_title(group)}' : _title(group),
      message: _meta(group, withDate: true),
      cancelDestructive: true,
      actions: [
        if (showSignIn) AppActionSheetAction(value: 'signin', icon: Icons.check_circle_outline, label: context.l10n.signoutSignIn),
        if (showSignOut) AppActionSheetAction(value: 'signout', icon: Icons.cancel_outlined, label: context.l10n.signoutSignOut),
        if (showLate) AppActionSheetAction(value: 'late', icon: Icons.schedule, label: context.l10n.signoutEnterLate),
        if (group.sharePlan && group.plan != null) AppActionSheetAction(value: 'plan', icon: Icons.description_outlined, label: context.l10n.signoutShowRunSheet),
        if (group.description?.isNotEmpty ?? false) AppActionSheetAction(value: 'description', icon: Icons.info_outline, label: context.l10n.signoutShowDescription),
        if (group.attachmentUrl?.isNotEmpty ?? false) AppActionSheetAction(value: 'attachment', icon: Icons.attach_file, label: context.l10n.signoutOpenAttachment),
        if (group.place?.isNotEmpty ?? false) AppActionSheetAction(value: 'navigation', icon: Icons.navigation_outlined, label: context.l10n.signoutOpenNavigation),
      ],
    );
    if (action == null || !mounted) return;

    switch (action) {
      case 'signin':
        await _signIn(group, ids, child);
      case 'signout':
        await _signOut(group, ids, isLate: false);
      case 'late':
        await _signOut(group, ids, isLate: true);
      case 'plan':
        await _showPlanViewer(group);
      case 'description':
        await showEventDescriptionSheet(context, group.description!);
      case 'attachment':
        await openEventAttachment(group.attachmentUrl!);
      case 'navigation':
        await openEventNavigation(context, group.place!);
    }
  }

  Future<void> _signIn(ParentAttendanceGroup group, List<String> ids, ChildPersonAttendance? child) async {
    final notifier = ref.read(parentSignInOutNotifierProvider.notifier);
    for (final id in ids) {
      final c = group.childAttendances.firstWhere((c) => c.id == id, orElse: () => child ?? group.childAttendances.first);
      await notifier.signIn(id, SignInType.fromStatus(c.status));
    }
    if (!mounted) return;
    if (ref.read(parentSignInOutNotifierProvider).hasError) {
      ToastHelper.showError(context, context.l10n.signoutFlutterSigninFailed);
    } else {
      ref.read(trackingServiceProvider).track(TrackingEvent.parentSignIn, properties: {'count': ids.length});
      ToastHelper.showSuccess(context, context.l10n.selfServiceThanksForSignIn);
    }
  }

  Future<void> _signOut(ParentAttendanceGroup group, List<String> ids, {required bool isLate}) async {
    final tenant = ref.read(currentTenantProvider);
    final reason = await showExcuseReasonSheet(
      context,
      isLate: isLate,
      isToday: EventListUtils.isRunning(group.date, 1),
      absenceReasons: EventListUtils.absenceReasonsOf(tenant?.absenceReasons),
      lateReasons: EventListUtils.lateReasonsOf(tenant?.lateReasons),
    );
    if (reason == null || !mounted) return;
    await ref
        .read(parentSignInOutNotifierProvider.notifier)
        .signOut(ids, reason, isLateComing: isLate);
    if (!mounted) return;
    if (ref.read(parentSignInOutNotifierProvider).hasError) {
      ToastHelper.showError(context, context.l10n.signoutFlutterSignoutFailed);
    } else {
      ref.read(trackingServiceProvider).track(TrackingEvent.parentSignOut, properties: {'count': ids.length, 'isLate': isLate});
      ToastHelper.showSuccess(
        context,
        isLate
            ? context.l10n.selfServiceParentsThanksLate
            : context.l10n.selfServiceParentsThanksSignout,
      );
    }
  }

  Future<void> _showPlanViewer(ParentAttendanceGroup group) async {
    if (!group.hasPlan) {
      ToastHelper.showWarning(context, context.l10n.planningNoPlanAvailable);
      return;
    }
    final first = group.childAttendances.firstOrNull;
    final crossTenant = CrossTenantPersonAttendance(
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
    );
    await showPlanViewerSheet(context, attendance: crossTenant);
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
          const SizedBox(height: 8),
          Text(context.l10n.signoutFlutterError(friendlyErrorMessage(error)), textAlign: TextAlign.center),
          TextButton(onPressed: onRetry, child: Text(context.l10n.messagesRetry)),
        ],
      ),
    );
  }
}

/// One row per child below the "Heute" card.
class _TodayChildren extends StatelessWidget {
  const _TodayChildren({
    required this.group,
    required this.initials,
    required this.onChildTap,
  });

  final ParentAttendanceGroup group;
  final String Function(ChildPersonAttendance) initials;
  final void Function(ChildPersonAttendance) onChildTap;

  @override
  Widget build(BuildContext context) {
    return EventListCard(children: [
      for (final c in group.childAttendances)
        ListTile(
          onTap: () => onChildTap(c),
          leading: CircleAvatar(
            backgroundColor: EventListUtils.statusColor(c.status).withValues(alpha: 0.2),
            child: Text(initials(c),
                style: TextStyle(color: EventListUtils.statusColor(c.status), fontSize: 13)),
          ),
          title: Text(c.childFirstName),
          subtitle: (c.notes?.isNotEmpty ?? false) ? Text(context.l10n.signoutNoteChip(c.notes!)) : null,
          trailing: EventPill.status(c.status),
        ),
    ]);
  }
}

/// Tappable chip "Name · Status" of a child.
class _KidChip extends StatelessWidget {
  const _KidChip({
    required this.initials,
    required this.label,
    required this.status,
    required this.onTap,
  });

  final String initials;
  final String label;
  final AttendanceStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = EventListUtils.statusColor(status);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 11,
              backgroundColor: color,
              child: Text(initials, style: const TextStyle(fontSize: 9, color: Colors.white)),
            ),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, color: color == AppColors.warning ? AppColors.warningDark : color)),
          ],
        ),
      ),
    );
  }
}
