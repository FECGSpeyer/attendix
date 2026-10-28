import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/team_org_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/team_org/team_org.dart';
import '../../../dashboard/presentation/widgets/dashboard_card.dart';
import '../../team_org_utils.dart';

/// Header strip of the tasks card (Ionic `.strip-tasks`).
const _tasksStrip = [Color(0xFF438E96), Color(0xFF2B6168)];

/// Open tasks of the signed-in person, overdue first, then by due date
/// (Ionic `MyTasksComponent.load`).
List<TeamTask> openTasksSorted(List<TeamTask> tasks, String today) =>
    groupTasksByDue(tasks.where((t) => t.status != 'completed').toList(), today)
        .expand((g) => g.tasks)
        .toList();

/// "Fällig Di, 28.10." / "Überfällig seit 12.10." / "Ohne Fälligkeit".
String myTaskDueLabel(TeamTask task, String today) {
  if (task.dueDate == null) return 'Ohne Fälligkeit';
  final label = formatTaskDue(task, today);
  return isTaskOverdue(task, today) ? 'Überfällig $label' : 'Fällig $label';
}

/// "3 offen · 1 überfällig".
String myTasksSubtitle(List<TeamTask> open, String today) {
  final overdue = open.where((t) => isTaskOverdue(t, today)).length;
  final text = '${open.length} offen';
  return overdue > 0 ? '$text · $overdue überfällig' : text;
}

/// "Meine Aufgaben" (Ionic `app-my-tasks`): compact card with the signed-in
/// person's open tasks. Used on the dashboard (leadership) and on "Meine
/// Termine" (members). Renders nothing while the Teamorganisation is off or
/// nothing is open.
class MyTasksCard extends ConsumerStatefulWidget {
  const MyTasksCard({super.key, this.limit = 5});

  /// Maximum number of tasks listed.
  final int limit;

  @override
  ConsumerState<MyTasksCard> createState() => _MyTasksCardState();
}

class _MyTasksCardState extends ConsumerState<MyTasksCard> {
  final Set<String> _busy = {};
  final Set<String> _hidden = {};

  Future<void> _complete(TeamTask task) async {
    final id = task.id;
    if (id == null || _busy.contains(id)) return;
    setState(() {
      _busy.add(id);
      _hidden.add(id);
    });
    try {
      await ref.read(teamTaskNotifierProvider.notifier).update(id, {'status': 'completed'});
      if (mounted) ToastHelper.showSuccess(context, 'Erledigt');
    } catch (_) {
      if (mounted) {
        setState(() => _hidden.remove(id));
        ToastHelper.showError(context, 'Status konnte nicht geändert werden');
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(teamOrgEnabledProvider)) return const SizedBox.shrink();
    final tasks = ref.watch(myTasksProvider).valueOrNull;
    if (tasks == null) return const SizedBox.shrink();
    final today = localToday();
    final open = openTasksSorted(tasks, today).where((t) => !_hidden.contains(t.id)).toList();
    if (open.isEmpty) return const SizedBox.shrink();
    final isLeader = ref.watch(isTeamLeaderProvider);
    final shown = open.take(widget.limit).toList();

    return DashboardCard(
      icon: Icons.check_box_outlined,
      title: 'Meine Aufgaben',
      subtitle: myTasksSubtitle(open, today),
      strip: _tasksStrip,
      child: Column(
        children: [
          for (final task in shown) _row(context, task, today),
          if (open.length > widget.limit || isLeader)
            ListTile(
              dense: true,
              title: Text(
                open.length > widget.limit ? 'Alle anzeigen (${open.length})' : 'Alle Aufgaben',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
              trailing: const Icon(Icons.chevron_right, color: AppColors.primary),
              onTap: () => context.push('/settings/team-organization?tab=tasks'),
            ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, TeamTask task, String today) {
    final overdue = isTaskOverdue(task, today);
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 4, right: 16),
      leading: IconButton(
        tooltip: 'Als erledigt markieren',
        icon: const Icon(Icons.radio_button_unchecked, color: AppColors.medium),
        onPressed: _busy.contains(task.id) ? null : () => _complete(task),
      ),
      title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        myTaskDueLabel(task, today),
        style: overdue ? const TextStyle(color: AppColors.danger) : null,
      ),
      trailing: task.status == 'in_progress'
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.warning,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('In Arbeit', style: TextStyle(color: Colors.white, fontSize: 12)),
            )
          : null,
      onTap: () => context.push('/settings/tasks/${task.id}'),
    );
  }
}
