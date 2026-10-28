import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/l10n.dart';

/// Shows a modal bottom sheet with status overview (counts per status)
void showStatusOverviewSheet(
  BuildContext context, {
  required Map<AttendanceStatus, int> statusCounts,
  required int total,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StatusOverviewSheet(
      statusCounts: statusCounts,
      total: total,
    ),
  );
}

/// Bottom sheet showing attendance status overview with counts
class StatusOverviewSheet extends StatelessWidget {
  final Map<AttendanceStatus, int> statusCounts;
  final int total;

  const StatusOverviewSheet({
    super.key,
    required this.statusCounts,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.3,
      maxChildSize: 0.6,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(16),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                    const Icon(Icons.pie_chart, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.attendanceStatusOverview,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        context.l10n.attendanceTotalPeople(total),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Status-Liste
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppDimensions.paddingM),
                  children: [
                    _buildStatusRow(context, AttendanceStatus.present),
                    _buildStatusRow(context, AttendanceStatus.excused),
                    _buildStatusRow(context, AttendanceStatus.late),
                    _buildStatusRow(context, AttendanceStatus.lateExcused),
                    _buildStatusRow(context, AttendanceStatus.absent),
                    _buildStatusRow(context, AttendanceStatus.neutral),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusRow(BuildContext context, AttendanceStatus status) {
    final count = statusCounts[status] ?? 0;
    final percentage = total > 0 ? (count / total * 100) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: status.color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              status.icon,
              color: status.color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.label,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: AppColors.medium.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation(status.color),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: status.color,
                ),
              ),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.medium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
