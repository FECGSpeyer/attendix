import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/shift/shift_definition.dart';
import '../../../../data/models/shift/shift_instance.dart';
import '../../../../data/models/shift/shift_plan.dart';
import '../../../../l10n/l10n.dart';

/// Shows a preview sheet with calculated shifts for the next 30 days
void showShiftPreviewSheet(BuildContext context, ShiftPlan plan, {ShiftInstance? startInstance}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => ShiftPreviewSheet(
        plan: plan,
        scrollController: scrollController,
        startInstance: startInstance,
      ),
    ),
  );
}

/// Preview sheet showing shift calculations
class ShiftPreviewSheet extends StatelessWidget {
  final ShiftPlan plan;
  final ScrollController scrollController;
  final ShiftInstance? startInstance;

  const ShiftPreviewSheet({
    super.key,
    required this.plan,
    required this.scrollController,
    this.startInstance,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final startDate = startInstance?.dateTime ?? today;
    final dateFormat = DateFormat('E, d. MMM', currentIntlLocale());
    // RT-011: Extract name once for null-safe access
    final startInstanceName = startInstance?.name;
    final hasCustomStart = startInstanceName != null;

    return Column(
      children: [
        // Handle bar
        Container(
          margin: const EdgeInsets.symmetric(vertical: AppDimensions.paddingM),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.medium.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasCustomStart
                          ? context.l10n.shiftsFlutterPreviewOf(startInstanceName)
                          : context.l10n.shiftsExample,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      hasCustomStart
                          ? context.l10n.shiftsFlutterNext30From(dateFormat.format(startDate))
                          : context.l10n.shiftsFlutterNext30Today,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.medium,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),

        const Divider(),

        // Info card
        Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          child: Card(
            color: AppColors.info.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.info),
                  const SizedBox(width: AppDimensions.paddingM),
                  Expanded(
                    child: Text(
                      hasCustomStart
                          ? '${context.l10n.shiftsFlutterStartDateWith(dateFormat.format(startDate), startInstanceName)}\n'
                              '${context.l10n.shiftsFlutterCycle(plan.cycleLengthDays)}'
                          : '${context.l10n.shiftsFlutterStartDateToday(dateFormat.format(today))}\n'
                              '${context.l10n.shiftsFlutterCycle(plan.cycleLengthDays)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // List of days
        Expanded(
          child: plan.definition.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.timeline_outlined,
                          size: 48, color: AppColors.medium),
                      const SizedBox(height: AppDimensions.paddingM),
                      Text(
                        context.l10n.shiftsFlutterNoDefinitionYet,
                        style: TextStyle(color: AppColors.medium),
                      ),
                      const SizedBox(height: AppDimensions.paddingS),
                      Text(
                        context.l10n.shiftsFlutterAddSegmentsHint,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.medium,
                            ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: scrollController,
                  itemCount: 30,
                  itemBuilder: (context, index) {
                    final date = startDate.add(Duration(days: index));
                    final dayInCycle = plan.getDayInCycle(date, startDate);
                    final segment = plan.getSegmentForDay(dayInCycle);
                    final isStartDate = index == 0;
                    final isTodayDate = date.year == today.year &&
                        date.month == today.month &&
                        date.day == today.day;

                    return _DayPreviewTile(
                      date: date,
                      dateFormat: dateFormat,
                      dayInCycle: dayInCycle,
                      segment: segment,
                      isToday: isTodayDate,
                      isStartDate: isStartDate && hasCustomStart,
                      startInstanceName: startInstanceName,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _DayPreviewTile extends StatelessWidget {
  final DateTime date;
  final DateFormat dateFormat;
  final int dayInCycle;
  final ShiftDefinition? segment;
  final bool isToday;
  final bool isStartDate;
  final String? startInstanceName;

  const _DayPreviewTile({
    required this.date,
    required this.dateFormat,
    required this.dayInCycle,
    required this.segment,
    required this.isToday,
    this.isStartDate = false,
    this.startInstanceName,
  });

  @override
  Widget build(BuildContext context) {
    final isFree = segment?.free ?? true;
    final isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
    final isHighlighted = isToday || isStartDate;

    return Container(
      decoration: BoxDecoration(
        color: isHighlighted ? AppColors.primary.withValues(alpha: 0.05) : null,
        border: Border(
          bottom: BorderSide(
            color: AppColors.medium.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isFree
                ? AppColors.success.withValues(alpha: 0.2)
                : AppColors.warning.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: isHighlighted
                ? Border.all(color: AppColors.primary, width: 2)
                : null,
          ),
          child: Center(
            child: Text(
              '${date.day}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isFree ? AppColors.success : AppColors.warning,
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            Text(
              dateFormat.format(date),
              style: TextStyle(
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
                color: isWeekend ? AppColors.medium : null,
              ),
            ),
            if (isToday) ...[
              const SizedBox(width: AppDimensions.paddingS),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  context.l10n.teamOrgTodayCap,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            if (isStartDate) ...[
              const SizedBox(width: AppDimensions.paddingS),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  context.l10n.shiftsFlutterStart,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          _getSubtitle(context.l10n),
          style: TextStyle(
            color: isFree ? AppColors.success : AppColors.warning,
            fontSize: 12,
          ),
        ),
        trailing: Text(
          context.l10n.shiftsFlutterDayN(dayInCycle + 1),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.medium,
              ),
        ),
      ),
    );
  }

  String _getSubtitle(AppLocalizations l10n) {
    if (segment == null) {
      return l10n.shiftsFlutterNoDefinition;
    }

    if (segment!.free) {
      return l10n.shiftsFree;
    }

    return '${segment!.startTime} - ${segment!.endTime} (${segment!.duration}h)';
  }
}
