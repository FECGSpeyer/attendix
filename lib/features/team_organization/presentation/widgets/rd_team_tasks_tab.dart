import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/team_org_providers.dart';
import '../../../../core/services/error_reporter.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/team_org/team_org.dart';
import '../../../../l10n/l10n.dart';
import '../../../redesign/presentation/widgets/rd_widgets.dart';
import '../../team_org_utils.dart';
import 'task_form_sheet.dart';
import 'tasks_tab.dart' show TeamOrgListSkeleton;

/// Beta tab "Aufgaben": opens on the own tasks. Leadership can switch to
/// the tasks of the whole team and add tasks; members only have their own
/// (RLS).
class RdTeamTasksTab extends ConsumerStatefulWidget {
  const RdTeamTasksTab({super.key});

  @override
  ConsumerState<RdTeamTasksTab> createState() => _RdTeamTasksTabState();
}

class _RdTeamTasksTabState extends ConsumerState<RdTeamTasksTab> {
  bool _team = false;
  bool _includeArchived = false;
  final Map<String, String> _optimistic = {};

  Future<void> _toggle(TeamTask task) async {
    final id = task.id;
    if (id == null || _optimistic.containsKey(id)) return;
    final next = toggledStatus(task.status);
    setState(() => _optimistic[id] = next);
    try {
      await ref.read(teamTaskNotifierProvider.notifier).update(id, {'status': next});
      // Keep the optimistic status until the reloaded list carries it.
      try {
        await ref.read(rdTeamTasksProvider.future);
      } catch (e, st) {
        ErrorReporter.report(e, st, where: 'rd_team_tasks_tab');
      }
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.tasksStatusFailed);
    } finally {
      if (mounted) setState(() => _optimistic.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final isLeader = ref.watch(isTeamLeaderProvider);
    final tasksAsync = ref.watch(rdTeamTasksProvider);
    // The circle sees the tasks of its Besprechungen next to its own.
    final hasTeam = isLeader || ref.watch(inTeamCircleProvider);
    ref.listen(rdTeamTasksProvider, (_, next) {
      if (next is AsyncError && !next.isLoading) {
        ToastHelper.showError(context, context.l10n.teamOrgTasksLoadFailed);
      }
    });
    final myPersonId = ref.watch(teamPersonProvider).valueOrNull?.id;
    final today = localToday();

    final tasks = (tasksAsync.valueOrNull ?? const <TeamTask>[])
        .map((t) => _optimistic.containsKey(t.id)
            ? t.copyWith(
                status: _optimistic[t.id]!,
                completedAt: _optimistic[t.id] == 'completed' ? DateTime.now().toIso8601String() : null,
              )
            : t)
        .toList();
    // Leadership without an own person row only has the team view.
    final team = hasTeam && (_team || (isLeader && myPersonId == null));
    final visible = hasTeam ? filterTasks(tasks, team ? 'all' : 'mine', myPersonId) : tasks;
    final archivedCount = visible.where((t) => isCompletedTaskArchived(t)).length;
    final groups = groupTasksByDue(visible, today, includeArchived: _includeArchived);
    final allOpen = tasks.where((t) => t.status != 'completed').length;
    final myOpen =
        tasks.where((t) => t.responsiblePersonId == myPersonId && t.status != 'completed').length;

    String subtitle(TeamTask task) {
      final parts = <String>[];
      if (team) {
        final name = task.responsiblePerson.fullName;
        parts.add(name.isNotEmpty ? name : l10n.teamOrgNobodyAssigned);
      }
      final due = formatTaskDue(task, today);
      if (due.isNotEmpty) {
        parts.add(due);
      } else if (!team) {
        parts.add(l10n.tasksNoDue);
      }
      return parts.join(' · ');
    }

    Widget row(TeamTask task) {
      final done = task.status == 'completed';
      // Members tick off their own tasks only.
      final mayToggle = isLeader || task.responsiblePersonId == myPersonId;
      return RdListRow(
        key: ValueKey('rd-team-task-${task.id}'),
        leading: IconButton(
          tooltip: done ? l10n.tasksFlutterReopen : l10n.tasksMarkDone,
          visualDensity: VisualDensity.compact,
          icon: Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            color: done ? p.primary : p.text2,
          ),
          disabledColor: done ? p.primary : p.text2,
          onPressed: mayToggle ? () => _toggle(task) : null,
        ),
        title: task.title,
        titleColor: done ? p.text2 : null,
        subtitle: subtitle(task),
        trailing: task.status == 'in_progress'
            ? RdPill(l10n.tasksInProgress, tone: RdTone.late)
            : (!done && task.priority == 'high' ? RdPill(l10n.agendaHigh, tone: RdTone.absent) : null),
        showChevron: false,
        onTap: task.id == null ? null : () => context.push('/settings/tasks/${task.id}'),
      );
    }

    final loading = tasksAsync.isLoading && !tasksAsync.hasValue;
    return RdPage(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      onRefresh: () => reloadTeamOrgTab(ref, 'tasks'),
      floatingActionButton: isLeader
          ? FloatingActionButton(
              heroTag: 'rd-team-add-task',
              tooltip: l10n.teamOrgCreateTask,
              backgroundColor: p.primary,
              foregroundColor: p.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              onPressed: () => showTaskFormSheet(context),
              child: const Icon(Icons.add, size: 28),
            )
          : null,
      children: [
        if (hasTeam && myPersonId != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Wrap(
              spacing: 6,
              children: [
                RdChoiceChip(
                  label: l10n.teamOrgMineCount(myOpen),
                  selected: !team,
                  onTap: () => setState(() => _team = false),
                ),
                RdChoiceChip(
                  label: l10n.rdTeamChipTeam(allOpen),
                  selected: team,
                  onTap: () => setState(() => _team = true),
                ),
              ],
            ),
          ),
        if (loading)
          const TeamOrgListSkeleton()
        else if (groups.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: RdCard(
              child: Text(
                !hasTeam
                    ? l10n.teamOrgEmptyMineAssigned
                    : tasks.isEmpty
                        ? l10n.teamOrgEmptyAll
                        : (team ? l10n.rdTeamEmptyTeamTasks : l10n.teamOrgEmptyMine),
                style: RdType.meta(p),
              ),
            ),
          ),
        for (final group in groups) ...[
          RdGroupLabel(group.label),
          RdGroupedList(children: [for (final task in group.tasks) row(task)]),
          const SizedBox(height: 18),
        ],
        if (archivedCount > 0 || _includeArchived)
          RdGroupedList(
            children: [
              RdSwitchRow(
                title: l10n.teamOrgShowOlderDone,
                value: _includeArchived,
                onChanged: (v) => setState(() => _includeArchived = v),
              ),
            ],
          ),
        SizedBox(height: isLeader ? 72 : 0),
      ],
    );
  }
}
