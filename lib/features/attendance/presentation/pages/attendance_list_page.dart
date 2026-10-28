import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/attendance_providers.dart';
import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/providers/role_permission_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/color_utils.dart';
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


/// Attendance list page
class AttendanceListPage extends ConsumerStatefulWidget {
  const AttendanceListPage({super.key});

  @override
  ConsumerState<AttendanceListPage> createState() => _AttendanceListPageState();
}

class _AttendanceListPageState extends ConsumerState<AttendanceListPage> {
  bool _showAllPast = false;

  /// Navigate to detail page, refresh list data when returning
  Future<void> _navigateToDetail(int attendanceId) async {
    await context.push('/attendance/$attendanceId');
    if (mounted) {
      ref.invalidate(realtimeAttendanceListProvider);
    }
  }

  // UX_ATT: Ionic att-list remove(): alert with header only,
  // "Abbrechen" / "Fortfahren".
  Future<void> _confirmDelete(BuildContext context, Attendance attendance) async {
    HapticHelper.medium();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Möchtest du den Termin wirklich entfernen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Fortfahren'),
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
              : 'Ablaufplan',
      defaultLive: EventListUtils.isRunning(att.date, att.durationDays),
    );
  }

  /// Termintyp filter popover (Ionic att-list "options" popover).
  Widget _buildTypeFilterButton(List<AttendanceType> types) {
    final filter = ref.watch(attendanceListTypeFilterProvider);
    final active = filter != null;
    return PopupMenuButton<String>(
      tooltip: 'Filter',
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
                  'Alle anzeigen',
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

  /// "{n} anwesend · {n} entschuldigt · {n} abwesend" line of the today card;
  /// duty Termine show "{text} besetzt" plus the names (Ionic ev-today__stats).
  Widget _buildTodayStats(Attendance att, DutyTermin? duty) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.medium);
    final strong = style?.copyWith(fontWeight: FontWeight.bold, color: AppColors.dark);
    final List<Widget> children;
    if (duty != null) {
      children = [
        Text('${dutyBadge(duty).text} besetzt', style: strong),
        Text(dutyNames(duty), style: style),
      ];
    } else {
      final counts = ref.watch(attendanceStatusCountsProvider(att.id!)).valueOrNull;
      if (counts == null) return const SizedBox.shrink();
      children = [
        Text('${(att.percentage ?? 0).round()} %', style: strong),
        Text('${counts.present} anwesend', style: style),
        if (counts.excused > 0) Text('${counts.excused} entschuldigt', style: style),
        if (counts.absent > 0) Text('${counts.absent} abwesend', style: style),
      ];
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(spacing: 12, runSpacing: 4, children: children),
    );
  }
  // END ATT_DETAIL

  // UX_ATT: create flow opens as sheet over the list (Ionic addAttModal).
  Future<void> _openCreate() async {
    final created = await showAttendanceCreateSheet(context);
    if (created && mounted) ref.invalidate(realtimeAttendanceListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final attendanceAsync = ref.watch(realtimeAttendanceListProvider);
    // Use effectiveRoleProvider to support debug role override
    final role = ref.watch(effectiveRoleProvider);

    return Scaffold(
      appBar: AppBar(
        // SETTINGS2: Ionic att-list header tenant switcher
        title: const TenantSwitcherTitle(
          fallbackTitle: 'Termine',
          singleTenantTitle: 'Termine',
        ),
        // UX_ATT: Ionic order: Filter, Dienste verteilen, Glocke
        // (Kalender is Flutter-only and sits before the bell).
        actions: [
          // ATT_DETAIL: Termintyp filter
          _buildTypeFilterButton(ref.watch(attendanceTypesProvider).valueOrNull ?? const []),
          // DUTY: "Dienste verteilen" for leaders when the tenant uses the Dienstplan
          if (role.isConductor && ref.watch(hasDutyTypesProvider))
            IconButton(
              icon: const Icon(Icons.shuffle),
              tooltip: 'Dienste verteilen',
              onPressed: () async {
                final saved = await openDutyDistributePage(context);
                if (saved && mounted) ref.invalidate(realtimeAttendanceListProvider);
              },
            ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Kalender',
            onPressed: () => _showCalendarView(context, ref),
          ),
          const NotificationBell(), // MESSAGES
        ],
      ),
      body: attendanceAsync.when(
        skipLoadingOnReload: true,
        loading: () => const ListSkeleton(
          itemCount: 8,
          showAvatar: true,
          showSubtitle: true,
          showTrailing: true,
        ),
        error: (error, stack) => EmptyStateWidget(
          icon: Icons.error_outline,
          title: 'Fehler beim Laden',
          subtitle: 'Die Anwesenheitsliste konnte nicht geladen werden.',
          actionLabel: 'Erneut versuchen',
          onAction: () => ref.invalidate(realtimeAttendanceListProvider),
        ),
        data: (attendances) {
          // ATT_DETAIL: an active type filter without matches still shows the list
          if (attendances.isEmpty && ref.watch(attendanceListTypeFilterProvider) == null) {
            // UX_ATT: Ionic noDataContainer
            final canCreate = ref.watch(canCreateAttendanceProvider);
            return EmptyStateWidget(
              icon: Icons.check_box_outlined,
              title: 'Bisher wurden noch keine Termine angelegt',
              actionLabel: canCreate ? 'Termin hinzufügen' : null,
              onAction: canCreate ? _openCreate : null,
            );
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
              // DUTY: names of the assigned persons
              if (dutyTermine[att.id] != null) dutyNames(dutyTermine[att.id]!),
            ]);
          }

          // UX_ATT: "{present} von {total} anwesend" of past rows
          final listCounts =
              ref.watch(attendanceListStatusCountsProvider).valueOrNull ?? const {};
          String countText(Attendance att) {
            final total = listCounts[att.id]?.total ?? 0;
            final present = ((att.percentage ?? 0) / 100 * total).round();
            return '$present von $total anwesend';
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
          // on list rows only for the Dirigent; icon-only trash option.
          Widget slidable(Attendance att, Widget child, {bool helperToo = false}) {
            final allowed = helperToo ? role.canAddAttendance : role.isConductor;
            if (!allowed) return child;
            return Slidable(
              key: ValueKey('att-${att.id}'),
              endActionPane: ActionPane(
                motion: const ScrollMotion(),
                extentRatio: 0.25,
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

          return RefreshIndicator(
            onRefresh: () async {
              // FN-008: invalidate to trigger fresh fetch from realtime provider
              ref.invalidate(realtimeAttendanceListProvider);
            },
            child: ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                // DUTY: own duties waiting for confirmation
                const MyDutyRequestsSection(),
                // "Heute" / "Nächster Termin" – full-width card (Ionic ev-today)
                if (current != null) ...[
                  EventMonthHeader(
                    label: EventListUtils.isRunning(current.date, current.durationDays)
                        ? 'Heute'
                        : 'Nächster Termin',
                  ),
                  slidable(
                    current,
                    helperToo: true,
                    EventTodayCard(
                      date: current.date,
                      title: title(current),
                      meta: meta(current, withDate: true, withPlace: false),
                      place: current.place,
                      // ATT_DETAIL: status counters / duty Besetzung
                      extraHeader: [
                        if (current.id != null)
                          _buildTodayStats(current, dutyTermine[current.id]),
                      ],
                      actions: [
                        FilledButton.icon(
                          onPressed: () => _navigateToDetail(current.id!),
                          icon: const Icon(Icons.check_box_outlined, size: 18),
                          label: Text(_hasPlan(current) ? 'Anwesenheit' : 'Anwesenheit erfassen'),
                        ),
                        // ATT_DETAIL: Ablaufplan
                        if (_hasPlan(current))
                          OutlinedButton.icon(
                            onPressed: () => _openPlanViewer(current),
                            icon: const Icon(Icons.description_outlined, size: 18),
                            label: const Text('Ablaufplan'),
                          ),
                      ],
                    ),
                  ),
                ],

                if (categorized.upcoming.isNotEmpty) ...[
                  EventSectionHeader(title: 'Anstehend', count: categorized.upcoming.length),
                  for (final group in upcomingGroups) ...[
                    EventMonthHeader(label: group.label),
                    EventListCard(children: [
                      for (final att in group.items)
                        slidable(
                          att,
                          EventRow(
                            date: att.date,
                            title: title(att),
                            subtitle: meta(att),
                            highlight: highlightedTypeIds.contains(att.typeId),
                            onTap: () => _navigateToDetail(att.id!),
                            trailing: [
                              // ATT_DETAIL: "Ablaufplan anzeigen"
                              if (_hasPlan(att))
                                IconButton(
                                  tooltip: 'Ablaufplan anzeigen',
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
                  EventSectionHeader(title: 'Vergangen', count: past.length),
                  if (averagePercent != null)
                    EventSummary(percentage: averagePercent.round()),
                  EventListCard(children: [
                    for (final att in pastPreview)
                      slidable(
                        att,
                        EventRow(
                          date: att.date,
                          title: title(att),
                          subtitle: '${readableDate(att)} · ${countText(att)}',
                          past: true,
                          highlight: highlightedTypeIds.contains(att.typeId),
                          onTap: () => _navigateToDetail(att.id!),
                          trailing: [percentPill(att)],
                        ),
                      ),
                    if (past.length > EventListUtils.pastPreviewCount)
                      EventMoreLink(
                        label: _showAllPast ? 'Weniger anzeigen' : 'Alle ${past.length} anzeigen',
                        onTap: () => setState(() => _showAllPast = !_showAllPast),
                      ),
                  ]),
                ],
              ],
            ),
          );
        },
      ),
      // FAB only for roles that can add attendances (not VIEWER).
      // SETTINGS_EXT: Helfer abhängig von Rollenberechtigung attendance_create
      // UX_ATT: round "+" FAB bottom right that opens the create sheet (Ionic ion-fab)
      floatingActionButton: ref.watch(canCreateAttendanceProvider)
          ? FloatingActionButton(
              onPressed: _openCreate,
              tooltip: 'Termin hinzufügen',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

/// Show calendar view modal
void _showCalendarView(BuildContext context, WidgetRef ref) {
  final attendances = ref.read(realtimeAttendanceListProvider).valueOrNull ?? [];

  // Build a map of dates to attendances
  final Map<DateTime, List<Attendance>> attendanceMap = {};
  for (final attendance in attendances) {
    final date = DateTime.tryParse(attendance.date);
    if (date != null) {
      final normalizedDate = DateTime(date.year, date.month, date.day);
      attendanceMap.putIfAbsent(normalizedDate, () => []).add(attendance);
    }
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => _CalendarViewSheet(
      attendanceMap: attendanceMap,
      onDateSelected: (date, attendances) {
        Navigator.of(context).pop();
        if (attendances.length == 1) {
          context.push('/attendance/${attendances.first.id}');
        } else if (attendances.length > 1) {
          // Show selection dialog
          _showAttendanceSelectionDialog(context, attendances);
        }
      },
    ),
  );
}

/// Show dialog to select an attendance when multiple exist on the same date
void _showAttendanceSelectionDialog(BuildContext context, List<Attendance> attendances) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('${attendances.length} Anwesenheiten'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: attendances.length,
          itemBuilder: (context, index) {
            final attendance = attendances[index];
            return ListTile(
              title: Text(attendance.displayTitle),
              subtitle: attendance.startTime != null
                  ? Text(attendance.startTime!)
                  : null,
              onTap: () {
                Navigator.of(ctx).pop();
                context.push('/attendance/${attendance.id}');
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Abbrechen'),
        ),
      ],
    ),
  );
}

/// Calendar view sheet widget
class _CalendarViewSheet extends ConsumerStatefulWidget {
  const _CalendarViewSheet({
    required this.attendanceMap,
    required this.onDateSelected,
  });

  final Map<DateTime, List<Attendance>> attendanceMap;
  final void Function(DateTime date, List<Attendance> attendances) onDateSelected;

  @override
  ConsumerState<_CalendarViewSheet> createState() => _CalendarViewSheetState();
}

class _CalendarViewSheetState extends ConsumerState<_CalendarViewSheet> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  List<Attendance> _getAttendancesForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return widget.attendanceMap[normalizedDay] ?? [];
  }

  Color? _getTypeColorForDay(DateTime day, List<AttendanceType> types) {
    final attendances = _getAttendancesForDay(day);
    if (attendances.isEmpty) return null;

    final attendance = attendances.first;
    if (attendance.typeId == null) return null;

    final type = types.cast<AttendanceType?>().firstWhere(
      (t) => t!.id == attendance.typeId,
      orElse: () => null,
    );
    if (type == null) return null;

    return ColorUtils.parseNamedColor(type.color);
  }

  @override
  Widget build(BuildContext context) {
    final typesAsync = ref.watch(attendanceTypesProvider);
    final types = typesAsync.valueOrNull ?? [];

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.medium,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Kalender',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Calendar
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                child: TableCalendar<Attendance>(
                  firstDay: DateTime.now().subtract(const Duration(days: 365)),
                  lastDay: DateTime.now().add(const Duration(days: 365)),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  locale: 'de_DE',
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  eventLoader: _getAttendancesForDay,
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                    final attendances = _getAttendancesForDay(selectedDay);
                    if (attendances.isNotEmpty) {
                      widget.onDateSelected(selectedDay, attendances);
                    }
                  },
                  onFormatChanged: (format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  },
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                  },
                  calendarStyle: const CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    todayTextStyle: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    markersMaxCount: 0,
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: true,
                    titleCentered: true,
                  ),
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, focusedDay) {
                      final color = _getTypeColorForDay(day, types);
                      if (color == null) return null;
                      return Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${day.day}',
                          style: TextStyle(color: color),
                        ),
                      );
                    },
                    todayBuilder: (context, day, focusedDay) {
                      return Container(
                        margin: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${day.day}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                    selectedBuilder: (context, day, focusedDay) {
                      final color = _getTypeColorForDay(day, types);
                      return Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: color ?? AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${day.day}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            // Legend
            if (types.isNotEmpty)
              _buildLegend(types),
          ],
        );
      },
    );
  }

  Widget _buildLegend(List<AttendanceType> types) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: types.where((t) => t.visible == true).map((type) {
          final color = ColorUtils.parseNamedColor(type.color);
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  type.name,
                  style: TextStyle(fontSize: 12, color: AppColors.dark),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}