import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../data/models/attendance/attendance.dart';
import '../../../../../l10n/l10n.dart';
import 'attendance_accordion.dart';
import '../../../../../shared/widgets/display/ion_badge_text.dart';

/// Deadline status for checklist items
enum DeadlineStatus { normal, warning, overdue }

/// Accordion widget for displaying and managing checklist items
class ChecklistAccordion extends StatelessWidget {
  const ChecklistAccordion({
    super.key,
    required this.checklist,
    required this.onToggle,
    required this.onAdd,
    required this.onRemove,
    required this.onRestore,
    required this.getDeadlineStatus,
    required this.formatDeadlineRelative,
  });

  final List<ChecklistItem> checklist;
  final void Function(int index) onToggle;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;
  final VoidCallback onRestore;
  final DeadlineStatus Function(ChecklistItem) getDeadlineStatus;
  final String Function(ChecklistItem) formatDeadlineRelative;

  @override
  Widget build(BuildContext context) {
    final completedCount = checklist.where((item) => item.completed).length;
    final totalCount = checklist.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    // IOS_DETAIL: shared accordion (iOS header look, Ionic state reset)
    return AttendanceAccordion(
        clipBehavior: Clip.none,
        // UX_ATT: Ionic header: label + solid `ion-badge slot="end"`
        // (success when everything is done, else primary).
        title: Row(
          children: [
            Expanded(child: Text(context.l10n.attendanceChecklist)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: progress == 1.0 ? AppColors.success : AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$completedCount/$totalCount',
                // PARITY_R8: real bold (700) also on the web
                style: ionBadgeTextStyle(color: Colors.white, height: null),
              ),
            ),
          ],
        ),
        children: [
          if (checklist.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: Text(
                context.l10n.attendanceFlutterNoTodos,
                style: const TextStyle(color: AppColors.medium),
              ),
            )
          else
            ...checklist.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final deadlineStatus = getDeadlineStatus(item);
              final deadlineText = formatDeadlineRelative(item);

              Color? tileColor;
              if (!item.completed) {
                if (deadlineStatus == DeadlineStatus.overdue) {
                  tileColor = AppColors.danger.withValues(alpha: 0.1);
                } else if (deadlineStatus == DeadlineStatus.warning) {
                  tileColor = AppColors.warning.withValues(alpha: 0.1);
                }
              }

              return Slidable(
                key: ValueKey(item.id),
                endActionPane: ActionPane(
                  motion: const ScrollMotion(),
                  extentRatio: 0.25,
                  children: [
                    SlidableAction(
                      onPressed: (_) => onRemove(index),
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                      icon: Icons.delete_outline,
                    ),
                  ],
                ),
                child: Container(
                  color: tileColor,
                  child: CheckboxListTile(
                    value: item.completed,
                    onChanged: (_) => onToggle(index),
                    title: Text(
                      item.text,
                      style: TextStyle(
                        decoration: item.completed
                            ? TextDecoration.lineThrough
                            : null,
                        color: item.completed ? AppColors.medium : null,
                      ),
                    ),
                    subtitle: deadlineText.isNotEmpty
                        ? Text(
                            deadlineText,
                            style: TextStyle(
                              fontSize: 12,
                              color: deadlineStatus == DeadlineStatus.overdue
                                  ? AppColors.danger
                                  : deadlineStatus == DeadlineStatus.warning
                                      ? AppColors.warning
                                      : AppColors.medium,
                            ),
                          )
                        : null,
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  ),
                ),
              );
            }),
          // UX_ATT: Ionic "To-Do hinzufügen" row (primary, add-circle icon)
          ListTile(
            dense: true,
            leading: const Icon(Icons.add_circle_outline, color: AppColors.primary),
            title: Text(context.l10n.attendanceAddTodo, style: const TextStyle(color: AppColors.primary)),
            onTap: onAdd,
          ),
          // UX_ATT: "Checkliste zurücksetzen" lives in the header menu (Ionic)
        ],
    );
  }
}
