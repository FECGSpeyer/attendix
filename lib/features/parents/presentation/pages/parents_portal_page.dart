import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/event_list_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/repositories/sign_in_out_repository.dart';
import '../../../../shared/widgets/event_list/event_list_widgets.dart';
import '../../../../shared/widgets/event_list/excuse_reason_sheet.dart';
import '../../../self_service/presentation/widgets/plan_viewer_sheet.dart';
import '../../../self_service/presentation/widgets/upcoming_songs_sheet.dart';
import '../../data/providers/parents_providers.dart';
import '../../../messages/presentation/widgets/notification_bell.dart'; // MESSAGES

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
            label: 'Ablaufplan',
            icon: Icons.description_outlined,
            onTap: () => _showPlanViewer(g),
          ),
        if (g.description != null && g.description!.isNotEmpty)
          EventChip(
            label: 'Infos',
            icon: Icons.info_outline,
            onTap: () => showEventDescriptionSheet(context, g.description!),
          ),
        if (g.attachmentUrl != null && g.attachmentUrl!.isNotEmpty)
          EventChip(
            label: 'Anhang',
            icon: Icons.attach_file,
            onTap: () => openEventAttachment(g.attachmentUrl!),
          ),
      ];

  @override
  Widget build(BuildContext context) {
    final tenant = ref.watch(currentTenantProvider);
    final childrenAsync = ref.watch(parentChildrenProvider);
    final attendancesAsync = ref.watch(childrenAttendancesProvider);
    final current = ref.watch(currentParentAttendanceProvider);
    final upcomingAll = ref.watch(upcomingParentAttendancesProvider);
    final past = ref.watch(pastParentAttendancesProvider);
    ref.watch(attendanceTypesProvider);

    final upcoming = upcomingAll.where((g) => !g.isRunning).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(tenant?.longName.isNotEmpty == true ? tenant!.longName : 'Termine'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Legende',
            onPressed: () => showEventLegendSheet(context),
          ),
          const NotificationBell(), // MESSAGES
        ],
      ),
      body: childrenAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _ErrorView(
          error: error,
          onRetry: () => ref.invalidate(parentChildrenProvider),
        ),
        data: (children) {
          if (children.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.family_restroom, size: 64, color: AppColors.medium),
                    SizedBox(height: 12),
                    Text('Keine Kinder gefunden'),
                    SizedBox(height: 4),
                    Text(
                      'Es wurden keine Kinder mit Ihrem\nEltern-Account verknüpft.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.medium),
                    ),
                  ],
                ),
              ),
            );
          }

          return attendancesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => _ErrorView(
              error: error,
              onRetry: () => ref.invalidate(childrenAttendancesProvider),
            ),
            data: (attendances) {
              final pastPreview = _showAllPast
                  ? past
                  : past.take(EventListUtils.pastPreviewCount).toList();
              final groups = EventListUtils.groupByMonth(upcoming, (g) => g.date);
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(parentChildrenProvider);
                  ref.invalidate(childrenAttendancesProvider);
                  await ref.read(childrenAttendancesProvider.future);
                },
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 32),
                  children: [
                    _ChildrenOverviewCard(children: children),
                    if (current != null) ...[
                      const EventMonthHeader(label: 'Heute'),
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
                            child: const Text('Alle Kinder an- bzw. abmelden'),
                          ),
                        ),
                    ],
                    if (upcoming.isNotEmpty) ...[
                      EventSectionHeader(title: 'Anstehend', count: upcoming.length),
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
                                    child: const Text('Alle'),
                                  ),
                              ],
                            ),
                          ]),
                      ],
                    ],
                    if (past.isNotEmpty) ...[
                      EventSectionHeader(title: 'Vergangen', count: past.length),
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
                            label: _showAllPast ? 'Weniger anzeigen' : 'Alle ${past.length} anzeigen',
                            onTap: () => setState(() => _showAllPast = !_showAllPast),
                          ),
                      ]),
                    ],
                    if (attendances.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Keine Termine gefunden',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.medium),
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

  /// Action sheet for one child or all children of a Termin (Ionic openActionSheet).
  Future<void> _showActions(ParentAttendanceGroup group, {ChildPersonAttendance? child}) async {
    final ids = (child != null ? [child] : group.childAttendances)
        .map((c) => c.id)
        .whereType<String>()
        .toList();
    if (ids.isEmpty) {
      ToastHelper.showWarning(context, 'Keine gültigen Einträge gefunden');
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

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  child != null ? '${child.childFirstName} · ${_title(group)}' : _title(group),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(_meta(group, withDate: true)),
              ),
              const Divider(height: 1),
              if (showSignIn)
                ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: const Text('Anmelden'),
                  onTap: () => Navigator.pop(ctx, 'signin'),
                ),
              if (showSignOut)
                ListTile(
                  leading: const Icon(Icons.cancel_outlined),
                  title: const Text('Abmelden'),
                  onTap: () => Navigator.pop(ctx, 'signout'),
                ),
              if (showLate)
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: const Text('Verspätung eintragen'),
                  onTap: () => Navigator.pop(ctx, 'late'),
                ),
              if (group.sharePlan && group.plan != null)
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Ablaufplan anzeigen'),
                  onTap: () => Navigator.pop(ctx, 'plan'),
                ),
              if (group.description?.isNotEmpty ?? false)
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Beschreibung anzeigen'),
                  onTap: () => Navigator.pop(ctx, 'description'),
                ),
              if (group.attachmentUrl?.isNotEmpty ?? false)
                ListTile(
                  leading: const Icon(Icons.attach_file),
                  title: const Text('Anhang öffnen'),
                  onTap: () => Navigator.pop(ctx, 'attachment'),
                ),
              if (group.place?.isNotEmpty ?? false)
                ListTile(
                  leading: const Icon(Icons.navigation_outlined),
                  title: const Text('Navigation öffnen'),
                  onTap: () => Navigator.pop(ctx, 'navigation'),
                ),
              ListTile(
                leading: const Icon(Icons.close, color: AppColors.danger),
                title: const Text('Abbrechen', style: TextStyle(color: AppColors.danger)),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
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
      ToastHelper.showError(context, 'Anmeldung fehlgeschlagen. Bitte versuche es erneut.');
    } else {
      ToastHelper.showSuccess(context, 'Danke für die Anmeldung 🙂');
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
      ToastHelper.showError(context, 'Abmeldung fehlgeschlagen. Bitte versuche es erneut.');
    } else {
      ToastHelper.showSuccess(
        context,
        isLate
            ? 'Vielen Dank für die Info und Gottes Segen!'
            : 'Vielen Dank für die rechtzeitige Abmeldung und Gottes Segen!',
      );
    }
  }

  Future<void> _showPlanViewer(ParentAttendanceGroup group) async {
    if (!group.hasPlan) {
      ToastHelper.showWarning(context, 'Kein Ablaufplan verfügbar');
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
          Text('Fehler: $error', textAlign: TextAlign.center),
          TextButton(onPressed: onRetry, child: const Text('Erneut versuchen')),
        ],
      ),
    );
  }
}

/// "Shalom!" card with the children and their percentage.
class _ChildrenOverviewCard extends ConsumerWidget {
  const _ChildrenOverviewCard({required this.children});

  final List<Person> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Shalom!',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(children.length == 1
                ? 'Du verwaltest 1 Kind:'
                : 'Du verwaltest ${children.length} Kinder:'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final child in children)
                  Builder(builder: (context) {
                    final stats = child.id != null ? ref.watch(childStatsProvider(child.id!)) : null;
                    return Chip(
                      label: Text(child.firstName),
                      avatar: stats == null
                          ? null
                          : CircleAvatar(
                              backgroundColor: EventListUtils.percentageColor(stats.percentage),
                              child: FittedBox(
                                child: Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: Text('${stats.percentage}%',
                                      style: const TextStyle(color: Colors.white)),
                                ),
                              ),
                            ),
                    );
                  }),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => showUpcomingSongsSheet(context),
                child: const Text('Aktuelle Werke anzeigen'),
              ),
            ),
          ],
        ),
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
          subtitle: (c.notes?.isNotEmpty ?? false) ? Text('Notiz: ${c.notes}') : null,
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
