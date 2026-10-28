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
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/event_list_utils.dart';
import '../../../../data/models/attendance/attendance.dart';
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

  Future<void> _confirmDelete(BuildContext context, Attendance attendance) async {
    final dateFormatted = _formatDateForDialog(attendance.date);
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: 'Anwesenheit löschen?',
      message: 'Möchtest du "${attendance.displayTitle}" am $dateFormatted wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.',
      confirmText: 'Löschen',
      isDestructive: true,
    );
    if (confirmed && context.mounted) {
      await ref.read(attendanceNotifierProvider.notifier).deleteAttendance(attendance.id!);
      ref.invalidate(realtimeAttendanceListProvider);
    }
  }

  String _formatDateForDialog(String dateString) {
    final date = DateTime.tryParse(dateString);
    if (date == null) return dateString;
    return '${date.day}.${date.month}.${date.year}';
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
        actions: [
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
          if (attendances.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.fact_check_outlined,
              title: 'Keine Anwesenheiten',
              subtitle: 'Erstelle die erste Anwesenheitsliste',
              actionLabel: 'Neue Anwesenheit',
              onAction: () => context.push('/attendance/new'),
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

          String meta(Attendance att, {bool withDate = false}) {
            final type = typesById[att.typeId];
            return EventListUtils.meta([
              if (withDate)
                EventListUtils.readableDate(
                  att.date,
                  allDay: type?.allDay ?? false,
                  durationDays: att.durationDays,
                ),
              if (!(type?.allDay ?? false)) EventListUtils.timeRange(att.startTime, att.endTime),
              att.place,
              // DUTY: names of the assigned persons
              if (dutyTermine[att.id] != null) dutyNames(dutyTermine[att.id]!),
            ]);
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

          Widget slidable(Attendance att, Widget child) {
            if (!role.canAddAttendance) return child;
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
                    icon: Icons.delete,
                    label: 'Löschen',
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
                    EventTodayCard(
                      date: current.date,
                      title: current.displayTitle,
                      meta: meta(current, withDate: true),
                      status: percentPill(current),
                      actions: [
                        FilledButton.icon(
                          onPressed: () => _navigateToDetail(current.id!),
                          icon: const Icon(Icons.fact_check_outlined, size: 18),
                          label: const Text('Anwesenheit erfassen'),
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
                            title: att.displayTitle,
                            subtitle: meta(att),
                            highlight: highlightedTypeIds.contains(att.typeId),
                            onTap: () => _navigateToDetail(att.id!),
                            trailing: [percentPill(att)],
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
                          title: att.displayTitle,
                          subtitle: meta(att, withDate: true),
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
      floatingActionButton: ref.watch(canCreateAttendanceProvider)
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/attendance/new'),
              icon: const Icon(Icons.add),
              label: const Text('Neue Anwesenheit'),
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