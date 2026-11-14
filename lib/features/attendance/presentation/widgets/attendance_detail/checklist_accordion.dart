import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../data/models/attendance/attendance.dart';
import '../../../../../l10n/l10n.dart';
import 'attendance_accordion.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
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
    final beta = context.rdSkin != null;

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
              // Ionic: „{relativ} · {dd.MM.yyyy HH:mm} Uhr“ (local time).
              final relative = formatDeadlineRelative(item);
              final due = item.dueDate == null ? null : DateTime.tryParse(item.dueDate!)?.toLocal();
              final deadlineText = relative.isEmpty || due == null
                  ? relative
                  : '$relative · ${context.l10n.attendanceTimeOClock(DateFormat('dd.MM.yyyy HH:mm').format(due))}';

              Color? tileColor;
              Color? barColor;
              if (!item.completed) {
                if (deadlineStatus == DeadlineStatus.overdue) {
                  barColor = AppColors.danger;
                } else if (deadlineStatus == DeadlineStatus.warning) {
                  barColor = AppColors.warning;
                }
                tileColor = barColor?.withValues(alpha: 0.1);
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
                      icon: AppIcons.deleteOutline,
                    ),
                  ],
                ),
                // TER-24: Ionic `.checklist-overdue` / `.checklist-warning`:
                // 10 % tint plus a 3 px bar on the left.
                child: Container(
                  decoration: BoxDecoration(
                    color: tileColor,
                    border: beta || barColor == null
                        ? null
                        : Border(left: BorderSide(color: barColor, width: 3)),
                  ),
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
                    // TER-15: theme item size in the classic design.
                    dense: beta,
                  ),
                ),
              );
            }),
          // UX_ATT: Ionic "To-Do hinzufügen" row (primary, add-circle icon)
          if (beta)
            ListTile(
              dense: true,
              leading: Icon(AppIcons.addCircleOutline, color: AppColors.primary),
              title: Text(context.l10n.attendanceAddTodo, style: const TextStyle(color: AppColors.primary)),
              onTap: onAdd,
            )
          else
            // TER-24: Ionic shows the add-circle icon inline in the label.
            ListTile(
              title: Text.rich(
                TextSpan(
                  children: [
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Icon(AppIcons.addCircleOutline, color: AppColors.primary, size: 18),
                    ),
                    const TextSpan(text: ' '),
                    TextSpan(text: context.l10n.attendanceAddTodo),
                  ],
                ),
                style: const TextStyle(color: AppColors.primary),
              ),
              onTap: onAdd,
            ),
          // UX_ATT: "Checkliste zurücksetzen" lives in the header menu (Ionic)
        ],
    );
  }
}
