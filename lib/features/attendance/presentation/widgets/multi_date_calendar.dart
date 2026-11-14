import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:attendix/core/theme/app_icons.dart';
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
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../core/theme/redesign/rd_theme.dart';

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
  ) =>
      multiDateHighlight(
        context,
        day,
        attendances,
        types,
        holidays,
        // TER-26: Ionic `--ion-color-holiday`; the Beta keeps its red.
        holidayColor: context.rdSkin == null ? AppColors.holiday : AppColors.danger,
      );

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

/// Highlight of [day] in the multi-date calendars (Ionic att-list
/// `highlightedDates`): the Terminart colour of an existing Termin, then
/// public holidays ([holidayColor]), then school holidays (medium).
CalendarHighlight? multiDateHighlight(
  BuildContext context,
  DateTime day,
  List<Attendance> attendances,
  List<AttendanceType> types,
  HolidayData holidays, {
  Color holidayColor = AppColors.holiday,
}) {
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
    return _isDayInRange(day, h.startDate, h.endDate);
  });

  if (isPublicHoliday) {
    return CalendarHighlight(
      backgroundColor: holidayColor.withValues(alpha: 0.18),
      textColor: holidayColor,
      tooltip: context.l10n.attendanceFlutterHoliday,
    );
  }

  // Check for school holidays
  final isSchoolHoliday = holidays.schoolHolidays.any((h) {
    return _isDayInRange(day, h.startDate, h.endDate);
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

bool _isDayInRange(DateTime day, DateTime start, DateTime end) {
  final dayNormalized = DateTime(day.year, day.month, day.day);
  final startNormalized = DateTime(start.year, start.month, start.day);
  final endNormalized = DateTime(end.year, end.month, end.day);

  return (dayNormalized.isAtSameMomentAs(startNormalized) ||
          dayNormalized.isAfter(startNormalized)) &&
      (dayNormalized.isAtSameMomentAs(endNormalized) ||
          dayNormalized.isBefore(endNormalized));
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
                    icon: Icon(AppIcons.close, semanticLabel: context.l10n.commonClose),
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
                    child: IonButtonLabel(context.l10n.commonCancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(selectedDates),
                    child: IonButtonLabel(context.l10n.commonApply),
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

/// TER-02: the Ionic `ion-modal.dateModal` of "Termin hinzufügen" – a bare
/// card (290 × 382, radius 8) holding only an `ion-datetime multiple
/// presentation="date"` with the highlighted dates. No title, buttons or
/// legend: every tap applies at once ([onChanged]) and a tap on the
/// backdrop closes the card. Classic design only (the Beta keeps
/// [MultiDateCalendarDialog]).
Future<void> showIonMultiDateCard(
  BuildContext context, {
  required List<DateTime> initialDates,
  required ValueChanged<List<DateTime>> onChanged,
}) {
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: context.l10n.commonClose,
    // Ionic modal backdrop (`--backdrop-opacity` .32 md / ios27 theme .4).
    barrierColor: Colors.black.withValues(alpha: useIosLook(context) ? 0.4 : 0.32),
    builder: (ctx) => Center(
      child: IonMultiDateCalendarCard(
        initialDates: initialDates,
        onChanged: onChanged,
      ),
    ),
  );
}

/// The card of [showIonMultiDateCard].
class IonMultiDateCalendarCard extends ConsumerStatefulWidget {
  const IonMultiDateCalendarCard({
    super.key,
    required this.initialDates,
    required this.onChanged,
  });

  final List<DateTime> initialDates;
  final ValueChanged<List<DateTime>> onChanged;

  /// Ionic `.dateModal`: `--width: 290px; --height: 382px; --border-radius: 8px`.
  static const double width = 290;
  static const double height = 382;

  @override
  ConsumerState<IonMultiDateCalendarCard> createState() => _IonMultiDateCalendarCardState();
}

class _IonMultiDateCalendarCardState extends ConsumerState<IonMultiDateCalendarCard> {
  late List<DateTime> _dates = List.of(widget.initialDates);
  late DateTime _focusedDay = _dates.isNotEmpty ? _dates.first : DateTime.now();
  PageController? _pages;

  void _toggle(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day, 12);
    final next = List<DateTime>.from(_dates);
    final i = next.indexWhere((d) => isSameDay(d, normalized));
    if (i >= 0) {
      next.removeAt(i);
    } else {
      next.add(normalized);
    }
    next.sort();
    setState(() => _dates = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final ios = useIosLook(context);
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final attendances = ref.watch(attendancesProvider).valueOrNull ?? const <Attendance>[];
    final types = ref.watch(visibleAttendanceTypesProvider).valueOrNull ?? const <AttendanceType>[];
    final holidays = ref.watch(holidaysProvider).valueOrNull ?? const HolidayData();
    final locale = currentIntlLocale();
    final now = DateTime.now();

    // ion-datetime day: iOS 20px in a 40px circle, md 14px in a 42px circle.
    final dayFont = ios ? 20.0 : 14.0;
    Widget day(DateTime d, {bool selected = false, bool today = false}) {
      final highlight = multiDateHighlight(context, d, attendances, types, holidays);
      Color? background = highlight?.backgroundColor;
      Color textColor = highlight?.textColor ?? onSurface;
      BoxBorder? border;
      var weight = FontWeight.w400;
      if (today && !selected) {
        textColor = AppColors.primary;
        weight = ios ? FontWeight.w600 : FontWeight.w400;
        if (!ios) border = Border.all(color: AppColors.primary);
      }
      if (selected) {
        // iOS: primary text on a 20 % primary circle (today: solid);
        // md: solid primary circle with white text.
        if (ios && !today) {
          background = AppColors.primary.withValues(alpha: 0.2);
          textColor = AppColors.primary;
        } else {
          background = AppColors.primary;
          textColor = Colors.white;
        }
        weight = ios ? FontWeight.w600 : FontWeight.w500;
      }
      return Center(
        child: Container(
          width: ios ? 36 : 36,
          height: ios ? 36 : 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: background, shape: BoxShape.circle, border: border),
          child: Text(
            '${d.day}',
            style: TextStyle(fontSize: dayFont, fontWeight: weight, color: textColor, height: 1),
          ),
        ),
      );
    }

    final monthTitle = DateFormat.yMMMM(locale).format(_focusedDay);
    final chevronColor = ios ? AppColors.primary : onSurface.withValues(alpha: 0.6);
    final header = Padding(
      padding: EdgeInsets.fromLTRB(ios ? 16 : 20, ios ? 8 : 12, 4, ios ? 4 : 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              monthTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: ios ? 17 : 14,
                fontWeight: ios ? FontWeight.w600 : FontWeight.w500,
                color: onSurface,
              ),
            ),
          ),
          IconButton(
            tooltip: MaterialLocalizations.of(context).previousMonthTooltip,
            icon: Icon(ios ? AppIcons.chevronLeft : AppIcons.chevronLeft, color: chevronColor),
            onPressed: () => _pages?.previousPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            ),
          ),
          IconButton(
            tooltip: MaterialLocalizations.of(context).nextMonthTooltip,
            icon: Icon(AppIcons.chevronRight, color: chevronColor),
            onPressed: () => _pages?.nextPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            ),
          ),
        ],
      ),
    );

    final calendar = TableCalendar<void>(
      firstDay: now.subtract(const Duration(days: 365)),
      lastDay: now.add(const Duration(days: 730)),
      focusedDay: _focusedDay,
      locale: locale,
      headerVisible: false,
      sixWeekMonthsEnforced: true,
      startingDayOfWeek: StartingDayOfWeek.monday,
      availableGestures: AvailableGestures.horizontalSwipe,
      rowHeight: 46,
      daysOfWeekHeight: ios ? 24 : 28,
      onCalendarCreated: (controller) => _pages = controller,
      onPageChanged: (d) => setState(() => _focusedDay = d),
      selectedDayPredicate: (d) => _dates.any((x) => isSameDay(x, d)),
      onDaySelected: (d, _) => _toggle(d),
      daysOfWeekStyle: DaysOfWeekStyle(
        // Ionic: iOS `weekday: 'short'` upper case, md `narrow`.
        dowTextFormatter: (date, loc) => ios
            ? DateFormat.E(loc).format(date).replaceAll('.', '').toUpperCase()
            : DateFormat.E(loc).format(date).substring(0, 1).toUpperCase(),
        weekdayStyle: TextStyle(
          fontSize: ios ? 12 : 14,
          fontWeight: ios ? FontWeight.w600 : FontWeight.w400,
          color: ios ? AppColors.medium : onSurface.withValues(alpha: 0.6),
        ),
        weekendStyle: TextStyle(
          fontSize: ios ? 12 : 14,
          fontWeight: ios ? FontWeight.w600 : FontWeight.w400,
          color: ios ? AppColors.medium : onSurface.withValues(alpha: 0.6),
        ),
      ),
      calendarBuilders: CalendarBuilders<void>(
        defaultBuilder: (context, d, _) => day(d),
        todayBuilder: (context, d, _) => day(d, today: true),
        selectedBuilder: (context, d, _) => day(d, selected: true, today: isSameDay(d, now)),
        // Ionic hides the days of the previous / next month.
        outsideBuilder: (context, d, _) => const SizedBox.shrink(),
      ),
    );

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      elevation: ios ? 0 : 24,
      child: SizedBox(
        width: math.min(IonMultiDateCalendarCard.width, MediaQuery.sizeOf(context).width - 32),
        height: IonMultiDateCalendarCard.height,
        child: Column(
          children: [
            header,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: calendar,
            ),
          ],
        ),
      ),
    );
  }
}
