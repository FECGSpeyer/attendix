import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/redesign_providers.dart';
import '../../../../core/providers/team_org_providers.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../redesign/presentation/widgets/rd_widgets.dart';
import '../../../planning/presentation/widgets/ion_items.dart';
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
      await ref.read(teamTaskNotifierProvider.notifier).update(id, {'status': 'completed'});
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
    final open =
        groupTasksByDue(
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

    if (ref.watch(redesignEnabledProvider)) {
      return _buildBeta(
        context,
        shown: shown,
        openCount: open.length,
        subtitle: subtitle,
        isLeader: isLeader,
        today: today,
      );
    }

    return DashboardCard(
      icon: Ionicons.checkboxOutline,
      title: l10n.tasksMyTasks,
      subtitle: subtitle,
      strip: _strip,
      child: Column(
        children: [
          for (final task in shown) ...[
            // Ionic: ion-list lines="full"
            if (task != shown.first) const Divider(height: 1),
            ListTile(
              contentPadding: const EdgeInsets.only(left: 4, right: 12),
              leading: IconButton(
                tooltip: l10n.tasksMarkDone,
                icon: const Icon(Ionicons.ellipseOutline, color: AppColors.medium),
                onPressed: () => _complete(task),
              ),
              title: Text(task.title, style: const TextStyle(fontSize: 15)),
              subtitle: Text(
                _dueLabel(l10n, task, today),
                style: TextStyle(color: isTaskOverdue(task, today) ? AppColors.danger : AppColors.medium),
              ),
              trailing:
                  task.status == 'in_progress' ? IonBadge(label: l10n.tasksInProgress, color: AppColors.warning) : null,
              onTap: task.id == null ? null : () => context.push('/settings/tasks/${task.id}'),
            ),
          ],
          if (open.length > widget.limit || isLeader) ...[
            const Divider(height: 1),
            ListTile(
              title: Text(
                open.length > widget.limit ? l10n.tasksFlutterShowAllCount(open.length) : l10n.tasksFlutterAllTasks,
                style: const TextStyle(color: AppColors.primary),
              ),
              trailing: const IonDetailIcon(),
              onTap: () => context.push('/settings/team-organization?tab=tasks'),
            ),
          ],
        ],
      ),
    );
  }

  /// Beta Heute: section with grouped rows (same actions as the card).
  Widget _buildBeta(
    BuildContext context, {
    required List<TeamTask> shown,
    required int openCount,
    required String subtitle,
    required bool isLeader,
    required String today,
  }) {
    final p = context.rd;
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RdSectionHeader(l10n.tasksMyTasks, trailing: subtitle),
          RdGroupedList(
            children: [
              for (final task in shown)
                RdListRow(
                  key: ValueKey('rd-my-task-${task.id}'),
                  leading: IconButton(
                    tooltip: l10n.tasksMarkDone,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.radio_button_unchecked, color: p.text2),
                    onPressed: () => _complete(task),
                  ),
                  title: task.title,
                  subtitle: _dueLabel(l10n, task, today),
                  trailing: task.status == 'in_progress' ? RdPill(l10n.tasksInProgress, tone: RdTone.late) : null,
                  onTap: task.id == null ? null : () => context.push('/settings/tasks/${task.id}'),
                ),
              if (openCount > widget.limit || isLeader)
                RdListRow(
                  title:
                      openCount > widget.limit ? l10n.tasksFlutterShowAllCount(openCount) : l10n.tasksFlutterAllTasks,
                  titleColor: p.link,
                  onTap: () => context.push('/settings/team-organization?tab=tasks'),
                ),
            ],
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
