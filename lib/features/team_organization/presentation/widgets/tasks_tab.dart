import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/team_org_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/team_org/team_org.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/loading/loading.dart';
import '../../team_org_utils.dart';
import 'task_form_sheet.dart';

/// Tab "Aufgaben": leadership sees all tasks with person filters and can add
/// tasks; members see only their own tasks (RLS) and can complete them.
class TasksTab extends ConsumerStatefulWidget {
  const TasksTab({super.key});

  @override
  ConsumerState<TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends ConsumerState<TasksTab> {
  Object _filter = 'all';
  bool _includeArchived = false;
  final Map<String, String> _optimistic = {};

  Future<void> _toggle(TeamTask task) async {
    final id = task.id;
    if (id == null || _optimistic.containsKey(id)) return;
    final next = toggledStatus(task.status);
    setState(() => _optimistic[id] = next);
    try {
      await ref.read(teamTaskNotifierProvider.notifier).update(id, {'status': next});
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.tasksStatusFailed);
    } finally {
      if (mounted) setState(() => _optimistic.remove(id));
    }
  }

  Future<void> _addTask() async {
    await showTaskFormSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final isLeader = ref.watch(isTeamLeaderProvider);
    final tasksAsync = ref.watch(teamTasksProvider);
    final myPersonId = ref.watch(teamPersonProvider).valueOrNull?.id;
    final today = localToday();
    final l10n = context.l10n;

    return Scaffold(
      floatingActionButton: isLeader
          ? FloatingActionButton(
              heroTag: 'team-org-add-task',
              tooltip: l10n.teamOrgCreateTask,
              onPressed: _addTask,
              child: const Icon(Icons.add),
            )
          : null,
      body: tasksAsync.when(
        loading: () => const TeamOrgListSkeleton(), // Ionic ion-skeleton-text (3 rows)
        error: (_, __) => Center(child: Text(l10n.teamOrgTasksLoadFailed)),
        data: (raw) {
          final tasks = raw
              .map((t) => _optimistic.containsKey(t.id)
                  ? t.copyWith(
                      status: _optimistic[t.id]!,
                      completedAt: _optimistic[t.id] == 'completed' ? DateTime.now().toIso8601String() : null,
                    )
                  : t)
              .toList();
          final chips = isLeader ? taskPersonChips(tasks) : <TaskPersonChip>[];
          var filter = _filter;
          if (filter is int && !chips.any((c) => c.personId == filter)) filter = 'all';
          final visible = isLeader ? filterTasks(tasks, filter, myPersonId) : tasks;
          final archivedCount = visible.where((t) => isCompletedTaskArchived(t)).length;
          final groups = groupTasksByDue(visible, today, includeArchived: _includeArchived);
          final allOpen = tasks.where((t) => t.status != 'completed').length;
          final myOpen = myPersonId == null
              ? 0
              : tasks.where((t) => t.responsiblePersonId == myPersonId && t.status != 'completed').length;

          String emptyText() {
            if (!isLeader) return l10n.teamOrgEmptyMineAssigned;
            if (filter == 'mine') return l10n.teamOrgEmptyMine;
            if (tasks.isEmpty) return l10n.teamOrgEmptyAll;
            return l10n.teamOrgEmptyPerson;
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(teamTasksProvider),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                  AppDimensions.paddingM, AppDimensions.paddingS, AppDimensions.paddingM, 96),
              children: [
                if (isLeader && tasks.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _chip(l10n.teamOrgAllCount(allOpen), filter == 'all', () => setState(() => _filter = 'all')),
                        if (myPersonId != null)
                          _chip(l10n.teamOrgMineCount(myOpen), filter == 'mine', () => setState(() => _filter = 'mine')),
                        for (final c in chips)
                          if (c.personId != myPersonId)
                            _chip('${c.label} · ${c.openCount}', filter == c.personId,
                                () => setState(() => _filter = c.personId)),
                      ],
                    ),
                  ),
                if (groups.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      children: [
                        const Icon(Icons.task_alt, size: 56, color: AppColors.medium),
                        const SizedBox(height: AppDimensions.paddingM),
                        Text(emptyText(), textAlign: TextAlign.center),
                        if (isLeader && tasks.isEmpty)
                          TextButton.icon(
                            onPressed: _addTask,
                            icon: const Icon(Icons.add),
                            label: Text(l10n.teamOrgCreateTask),
                          ),
                      ],
                    ),
                  ),
                for (final group in groups) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: AppDimensions.paddingM, bottom: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            group.label,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: group.key == 'overdue' ? AppColors.danger : null,
                                ),
                          ),
                        ),
                        Text('${group.tasks.length}', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (final task in group.tasks)
                          TaskListTile(
                            task: task,
                            today: today,
                            showPerson: isLeader,
                            onToggle: () => _toggle(task),
                          ),
                      ],
                    ),
                  ),
                ],
                if (archivedCount > 0 || _includeArchived)
                  Card(
                    margin: const EdgeInsets.only(top: AppDimensions.paddingM),
                    child: SwitchListTile(
                      value: _includeArchived,
                      onChanged: (v) => setState(() => _includeArchived = v),
                      title: Text(l10n.teamOrgShowOlderDone),
                      subtitle: Text(l10n.teamOrgDoneDisappear),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: AppDimensions.paddingS),
        child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
      );
}

/// One task row with the round check button.
class TaskListTile extends StatelessWidget {
  const TaskListTile({
    super.key,
    required this.task,
    required this.today,
    required this.showPerson,
    required this.onToggle,
  });

  final TeamTask task;
  final String today;
  final bool showPerson;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final done = task.status == 'completed';
    final overdue = isTaskOverdue(task, today);
    final l10n = context.l10n;
    final parts = <String>[];
    if (showPerson) {
      final name = task.responsiblePerson.fullName;
      parts.add(name.isNotEmpty ? name : l10n.teamOrgNobodyAssigned);
    }
    final due = formatTaskDue(task, today);
    if (due.isNotEmpty) {
      parts.add(due);
    } else if (!showPerson) {
      parts.add(l10n.tasksNoDue);
    }

    return ListTile(
      onTap: task.id == null ? null : () => context.push('/settings/tasks/${task.id}'),
      leading: IconButton(
        tooltip: done ? l10n.tasksFlutterReopen : l10n.tasksMarkDone,
        icon: Icon(
          done ? Icons.check_circle : Icons.radio_button_unchecked,
          color: done ? AppColors.success : AppColors.medium,
        ),
        onPressed: onToggle,
      ),
      title: Text(
        task.title,
        style: done
            ? const TextStyle(decoration: TextDecoration.lineThrough, color: AppColors.medium)
            : null,
      ),
      subtitle: Text(
        parts.join(' · '),
        style: overdue ? const TextStyle(color: AppColors.danger) : null,
      ),
      trailing: Wrap(
        spacing: 4,
        children: [
          if (task.status == 'in_progress') _Badge(label: l10n.tasksInProgress, color: AppColors.warning),
          if (!done && task.priority == 'high') _Badge(label: l10n.agendaHigh, color: AppColors.danger),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      );
}

/// Colored pill badge used across the Teamorganisation pages.
class TeamOrgBadge extends StatelessWidget {
  const TeamOrgBadge({super.key, required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => _Badge(label: label, color: color);
}

Color priorityColor(String priority) => switch (priority) {
      'high' => AppColors.danger,
      'low' => AppColors.medium,
      _ => AppColors.warning,
    };

Color outcomeColor(String? outcome) => switch (outcome) {
      'decided' => AppColors.success,
      'postponed' => AppColors.warning,
      'discussed' => AppColors.primary,
      _ => AppColors.medium,
    };

/// Loading placeholder of the Aufgaben / Themen tabs (Ionic: inset list with
/// three skeleton rows).
class TeamOrgListSkeleton extends StatelessWidget {
  const TeamOrgListSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(AppDimensions.paddingM),
        child: Card(
          margin: EdgeInsets.zero,
          child: ListSkeleton(itemCount: 3, showAvatar: false),
        ),
      );
}
