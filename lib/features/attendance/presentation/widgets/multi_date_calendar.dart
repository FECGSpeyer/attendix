import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/providers/attendance_providers.dart';
import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/holiday_providers.dart';
import '../../../../core/services/holiday_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

/// Calendar highlight info for a specific date
class CalendarHighlight {
  final Color backgroundColor;
  final Color textColor;
  final String? tooltip;

  const CalendarHighlight({
    required this.backgroundColor,
    required this.textColor,
    this.tooltip,
  });
}

/// Widget that allows selecting multiple dates with visual highlighting
/// for existing attendances and holidays
class MultiDateCalendar extends ConsumerStatefulWidget {
  final List<DateTime> selectedDates;
  final ValueChanged<List<DateTime>> onDatesChanged;
  final DateTime? initialFocusedDay;

  const MultiDateCalendar({
    super.key,
    required this.selectedDates,
    required this.onDatesChanged,
    this.initialFocusedDay,
  });

  @override
  ConsumerState<MultiDateCalendar> createState() => _MultiDateCalendarState();
}

class _MultiDateCalendarState extends ConsumerState<MultiDateCalendar> {
  late DateTime _focusedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.initialFocusedDay ?? DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final attendancesAsync = ref.watch(attendancesProvider);
    final typesAsync = ref.watch(visibleAttendanceTypesProvider);
    final holidaysAsync = ref.watch(holidaysProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Calendar
        TableCalendar(
          firstDay: DateTime.now().subtract(const Duration(days: 365)),
          lastDay: DateTime.now().add(const Duration(days: 730)),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          locale: currentIntlLocale(),
          startingDayOfWeek: StartingDayOfWeek.monday,
          // Multi-select: a day is selected if it's in our list
          selectedDayPredicate: (day) => _isSelected(day),
          onDaySelected: (selectedDay, focusedDay) {
            _toggleDate(selectedDay);
            setState(() {
              _focusedDay = focusedDay;
            });
          },
          onFormatChanged: (format) {
            setState(() {
              _calendarFormat = format;
            });
          },
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
          },
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            selectedDecoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            todayTextStyle: const TextStyle(
              color: AppColors.dark,
              fontWeight: FontWeight.bold,
            ),
            selectedTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            markerDecoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
            markerSize: 6,
          ),
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (context, day, focusedDay) {
              final highlight = _getHighlight(
                day,
                attendancesAsync.valueOrNull ?? [],
                typesAsync.valueOrNull ?? [],
                holidaysAsync.valueOrNull ?? const HolidayData(),
              );

              if (highlight != null) {
                return Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: highlight.backgroundColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                        color: highlight.textColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }
              return null;
            },
            selectedBuilder: (context, day, focusedDay) {
              return Container(
                margin: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${day.day}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
          headerStyle: const HeaderStyle(
            formatButtonVisible: true,
            titleCentered: true,
          ),
        ),

        // Legend
        const Divider(),
        _buildLegend(typesAsync.valueOrNull ?? [], holidaysAsync.valueOrNull),
      ],
    );
  }

  bool _isSelected(DateTime day) {
    return widget.selectedDates.any((d) => isSameDay(d, day));
  }

  void _toggleDate(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day, 12);
    final newDates = List<DateTime>.from(widget.selectedDates);

    final existingIndex = newDates.indexWhere((d) => isSameDay(d, normalizedDay));
    if (existingIndex >= 0) {
      newDates.removeAt(existingIndex);
    } else {
      newDates.add(normalizedDay);
    }

    // Sort by date
    newDates.sort();
    widget.onDatesChanged(newDates);
  }

  CalendarHighlight? _getHighlight(
    DateTime day,
    List<Attendance> attendances,
    List<AttendanceType> types,
    HolidayData holidays,
  ) {
    // Check for existing attendance
    final attendance = attendances.firstWhere(
      (a) {
        final attDate = DateTime.tryParse(a.date);
        return attDate != null && isSameDay(attDate, day);
      },
      orElse: () => const Attendance(date: ''),
    );

    if (attendance.date.isNotEmpty && attendance.typeId != null) {
      final type = types.firstWhere(
        (t) => t.id == attendance.typeId,
        orElse: () => const AttendanceType(name: ''),
      );

      if (type.name.isNotEmpty) {
        final color = ColorUtils.parseNamedColor(type.color);
        return CalendarHighlight(
          backgroundColor: color.withValues(alpha: 0.18),
          textColor: color,
          tooltip: type.name,
        );
      }
    }

    // Check for public holidays
    final isPublicHoliday = holidays.publicHolidays.any((h) {
      return _isDateInRange(day, h.startDate, h.endDate);
    });

    if (isPublicHoliday) {
      return CalendarHighlight(
        backgroundColor: AppColors.danger.withValues(alpha: 0.18),
        textColor: AppColors.danger,
        tooltip: context.l10n.attendanceFlutterHoliday,
      );
    }

    // Check for school holidays
    final isSchoolHoliday = holidays.schoolHolidays.any((h) {
      return _isDateInRange(day, h.startDate, h.endDate);
    });

    if (isSchoolHoliday) {
      return CalendarHighlight(
        backgroundColor: AppColors.medium.withValues(alpha: 0.18),
        textColor: AppColors.medium,
        tooltip: context.l10n.attendanceFlutterSchoolHolidays,
      );
    }

    return null;
  }

  bool _isDateInRange(DateTime day, DateTime start, DateTime end) {
    final dayNormalized = DateTime(day.year, day.month, day.day);
    final startNormalized = DateTime(start.year, start.month, start.day);
    final endNormalized = DateTime(end.year, end.month, end.day);

    return (dayNormalized.isAtSameMomentAs(startNormalized) ||
            dayNormalized.isAfter(startNormalized)) &&
        (dayNormalized.isAtSameMomentAs(endNormalized) ||
            dayNormalized.isBefore(endNormalized));
  }

  Widget _buildLegend(List<AttendanceType> types, HolidayData? holidays) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Attendance types
          ...types.where((t) => t.visible == true).take(4).map((type) {
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
          }),
          // Holidays
          if (holidays != null && (holidays.publicHolidays.isNotEmpty || holidays.schoolHolidays.isNotEmpty)) ...[
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    context.l10n.attendanceFlutterHoliday,
                    style: TextStyle(fontSize: 12, color: AppColors.dark),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: AppColors.medium,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    context.l10n.attListSchoolHolidays,
                    style: TextStyle(fontSize: 12, color: AppColors.dark),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Modal dialog for multi-date selection
class MultiDateCalendarDialog extends StatelessWidget {
  final List<DateTime> initialDates;

  const MultiDateCalendarDialog({
    super.key,
    required this.initialDates,
  });

  @override
  Widget build(BuildContext context) {
    List<DateTime> selectedDates = List.from(initialDates);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.attendanceFlutterSelectDate,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Calendar
            Flexible(
              child: StatefulBuilder(
                builder: (context, setState) {
                  return SingleChildScrollView(
                    child: MultiDateCalendar(
                      selectedDates: selectedDates,
                      onDatesChanged: (dates) {
                        setState(() {
                          selectedDates = dates;
                        });
                      },
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            // Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.l10n.commonCancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(selectedDates),
                    child: Text(context.l10n.commonApply),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show the dialog and return selected dates
  static Future<List<DateTime>?> show(
    BuildContext context, {
    required List<DateTime> initialDates,
  }) {
    return showAppDialog<List<DateTime>>(
      context: context,
      builder: (context) => MultiDateCalendarDialog(
        initialDates: initialDates,
      ),
    );
  }
}
