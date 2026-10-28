import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/team_org_providers.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/team_org/team_org.dart';
import '../../../dashboard/presentation/widgets/dashboard_card.dart';
import '../../team_org_utils.dart';

/// INTEGRATION: compact "Meine Aufgaben" card (Ionic `app-my-tasks`): the
/// signed-in person's open tasks. Used as a dashboard card (leadership) and
/// on "Meine Termine" (members). Renders nothing when the Teamorganisation is
/// off or nothing is open.
class MyTasksCard extends ConsumerStatefulWidget {
  const MyTasksCard({super.key, this.limit = 5});

  /// Maximum number of tasks listed in the card.
  final int limit;

  @override
  ConsumerState<MyTasksCard> createState() => _MyTasksCardState();
}

class _MyTasksCardState extends ConsumerState<MyTasksCard> {
  /// Tasks completed in this card (hidden optimistically).
  final Set<String> _done = {};

  static const _strip = [Color(0xFF438E96), Color(0xFF2B6168)];

  Future<void> _complete(TeamTask task) async {
    final id = task.id;
    if (id == null || _done.contains(id)) return;
    setState(() => _done.add(id));
    try {
      await ref
          .read(teamTaskNotifierProvider.notifier)
          .update(id, {'status': 'completed'});
      if (mounted) ToastHelper.showSuccess(context, context.l10n.tasksDone);
    } catch (_) {
      if (!mounted) return;
      setState(() => _done.remove(id));
      ToastHelper.showError(context, context.l10n.tasksStatusFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(teamOrgEnabledProvider)) return const SizedBox.shrink();
    final tasks = ref.watch(myTasksProvider).valueOrNull;
    if (tasks == null) return const SizedBox.shrink();

    final today = localToday();
    final open = groupTasksByDue(
      tasks.where((t) => t.status != 'completed' && !_done.contains(t.id)).toList(),
      today,
    ).expand((g) => g.tasks).toList();
    if (open.isEmpty) return const SizedBox.shrink();

    final overdue = open.where((t) => isTaskOverdue(t, today)).length;
    final l10n = context.l10n;
    final openText = l10n.tasksOpenCount(open.length);
    final subtitle = overdue > 0 ? '$openText · ${l10n.tasksOverdueCount(overdue)}' : openText;
    final isLeader = ref.watch(isTeamLeaderProvider);
    final shown = open.take(widget.limit).toList();

    return DashboardCard(
      icon: Icons.check_box_outlined,
      title: l10n.tasksMyTasks,
      subtitle: subtitle,
      strip: _strip,
      child: Column(
        children: [
          for (final task in shown)
            ListTile(
              contentPadding: const EdgeInsets.only(left: 4, right: 12),
              leading: IconButton(
                tooltip: l10n.tasksMarkDone,
                icon: const Icon(Icons.radio_button_unchecked, color: AppColors.medium),
                onPressed: () => _complete(task),
              ),
              title: Text(task.title),
              subtitle: Text(
                _dueLabel(l10n, task, today),
                style: isTaskOverdue(task, today)
                    ? const TextStyle(color: AppColors.danger)
                    : null,
              ),
              trailing: task.status == 'in_progress'
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.warning,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(l10n.tasksInProgress, style: const TextStyle(fontSize: 12)),
                    )
                  : null,
              onTap: task.id == null ? null : () => context.push('/settings/tasks/${task.id}'),
            ),
          if (open.length > widget.limit || isLeader)
            ListTile(
              title: Text(
                open.length > widget.limit
                    ? l10n.tasksFlutterShowAllCount(open.length)
                    : l10n.tasksFlutterAllTasks,
                style: const TextStyle(color: AppColors.primary),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/team-organization?tab=tasks'),
            ),
        ],
      ),
    );
  }

  String _dueLabel(AppLocalizations l10n, TeamTask task, String today) {
    if (task.dueDate == null) return l10n.tasksNoDue;
    final label = formatTaskDue(task, today);
    return isTaskOverdue(task, today) ? l10n.tasksOverdueLabel(label) : l10n.tasksDueLabel(label);
  }
}
