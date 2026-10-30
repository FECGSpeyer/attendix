import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_colors.dart';
import 'attendance_detail/status_chip.dart';
import '../../../../l10n/l10n.dart';

/// Shows a modal bottom sheet explaining attendance status types
///
/// If [availableStatuses] is provided, only those statuses are shown.
void showAttendanceLegendSheet(
  BuildContext context, {
  Set<AttendanceStatus>? availableStatuses,
}) {
  showModalBottomSheet(
    context: context,
    useRootNavigator: true, // IOS_SHELL2: above the tab bar
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => AttendanceLegendSheet(
      availableStatuses: availableStatuses,
    ),
  );
}

/// Bottom sheet with legend explaining all attendance statuses
class AttendanceLegendSheet extends StatelessWidget {
  const AttendanceLegendSheet({super.key, this.availableStatuses});

  final Set<AttendanceStatus>? availableStatuses;

  // UX_ATT: Ionic legend modal (badge + common.status label, Ionic order)
  static List<(AttendanceStatus, String)> _allItems(AppLocalizations l10n) => [
        (AttendanceStatus.present, l10n.commonStatusPresent),
        (AttendanceStatus.excused, l10n.commonStatusExcused),
        (AttendanceStatus.absent, l10n.commonStatusAbsent),
        (AttendanceStatus.late, l10n.commonStatusLate),
        (AttendanceStatus.lateExcused, l10n.commonStatusLateExcused),
        (AttendanceStatus.neutral, l10n.commonStatusNeutral),
      ];

  List<Widget> _buildLegendItems(AppLocalizations l10n) {
    final all = _allItems(l10n);
    final items = availableStatuses != null
        ? all.where((item) => availableStatuses!.contains(item.$1))
        : all;
    return items
        .map((item) => _LegendItem(status: item.$1, label: item.$2))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.75,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.medium.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: Row(
                  children: [
                    const Icon(Icons.help_outline, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.signoutLegend,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, semanticLabel: context.l10n.commonClose),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Legend items
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppDimensions.paddingM),
                  children: _buildLegendItems(context.l10n),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LegendItem extends StatelessWidget {
  final AttendanceStatus status;
  final String label;

  const _LegendItem({
    required this.status,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.paddingM),
      child: Row(
        children: [
          SizedBox(width: 40, child: Center(child: AttendanceStatusBadge(status: status))),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
