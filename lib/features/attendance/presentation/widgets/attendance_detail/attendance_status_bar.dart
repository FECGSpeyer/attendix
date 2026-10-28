import 'package:flutter/material.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/constants/enums.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../data/models/person/person.dart';
import '../../../../../l10n/l10n.dart';

/// Bottom status bar showing attendance summary statistics
class AttendanceStatusBar extends StatelessWidget {
  const AttendanceStatusBar({
    super.key,
    required this.persons,
    required this.localStatuses,
    this.availableStatuses,
  });

  final List<Person> persons;
  final Map<int, AttendanceStatus> localStatuses;
  final List<AttendanceStatus>? availableStatuses;

  @override
  Widget build(BuildContext context) {
    final total = persons.length;

    // Only count statuses for persons that are in the persons list
    // This excludes paused/archived persons whose status may still be in localStatuses
    final personIds = persons.map((p) => p.id).whereType<int>().toSet();
    final relevantStatuses = localStatuses.entries
        .where((e) => personIds.contains(e.key))
        .map((e) => e.value);

    // Count present (including late as they are physically present)
    final present = relevantStatuses.where((s) =>
        s == AttendanceStatus.present ||
        s == AttendanceStatus.late ||
        s == AttendanceStatus.lateExcused).length;
    // Count excused (but not lateExcused as those are counted in present)
    final excused = relevantStatuses.where((s) => s == AttendanceStatus.excused).length;
    final absent = relevantStatuses.where((s) => s == AttendanceStatus.absent).length;
    // Unknown = neutral status (not yet recorded)
    final showNeutral = availableStatuses == null ||
        availableStatuses!.contains(AttendanceStatus.neutral);
    final unknown = showNeutral
        ? relevantStatuses.where((s) => s == AttendanceStatus.neutral).length
        : 0;
    final percentage = total > 0 ? (present / total * 100) : 0.0;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(
              label: context.l10n.commonStatusPresent,
              value: '$present',
              color: AttendanceStatus.present.color,
            ),
            _StatItem(
              label: context.l10n.attendanceFlutterExcusedShort,
              value: '$excused',
              color: AttendanceStatus.excused.color,
            ),
            _StatItem(
              label: context.l10n.commonStatusAbsent,
              value: '$absent',
              color: AttendanceStatus.absent.color,
            ),
            if (showNeutral)
              _StatItem(
                label: context.l10n.attendanceFlutterOpen,
                value: '$unknown',
                color: AttendanceStatus.neutral.color,
              ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingM,
                vertical: AppDimensions.paddingS,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
              ),
              child: Text(
                '${percentage.round()}%',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.medium,
          ),
        ),
      ],
    );
  }
}
