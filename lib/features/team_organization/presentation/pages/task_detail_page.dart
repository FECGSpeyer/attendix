import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/team_org_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/team_org/team_org.dart';
import '../../team_org_utils.dart';
import '../widgets/task_form_sheet.dart';
import '../widgets/tasks_tab.dart' show TeamOrgBadge, priorityColor;

/// Aufgabe: leadership edits everything (task form) and can delete; the
/// responsible person only changes the status.
class TaskDetailPage extends ConsumerStatefulWidget {
  const TaskDetailPage({super.key, required this.taskId});
  final String taskId;

  @override
  ConsumerState<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends ConsumerState<TaskDetailPage> {
  bool _savingStatus = false;

  Future<void> _setStatus(TeamTask task, String status) async {
    if (task.status == status || _savingStatus) return;
    setState(() => _savingStatus = true);
    try {
      await ref.read(teamTaskNotifierProvider.notifier).update(task.id!, {'status': status});
      if (mounted && status == 'completed') ToastHelper.showSuccess(context, 'Erledigt – danke!');
    } catch (_) {
      if (mounted) ToastHelper.showError(context, 'Status konnte nicht geändert werden');
    } finally {
      if (mounted) setState(() => _savingStatus = false);
    }
  }

  Future<void> _delete(TeamTask task) async {
    final ok = await DialogHelper.showConfirmation(
      context,
      title: 'Aufgabe löschen?',
      message: 'Die Aufgabe wird endgültig entfernt.',
      confirmText: 'Löschen',
      isDestructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(teamTaskNotifierProvider.notifier).delete(task);
      if (!mounted) return;
      ToastHelper.showSuccess(context, 'Aufgabe gelöscht');
      context.go('/settings/team-organization');
    } catch (_) {
      if (mounted) ToastHelper.showError(context, 'Löschen fehlgeschlagen');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLeader = ref.watch(isTeamLeaderProvider);
    final me = ref.watch(teamPersonProvider).valueOrNull;
    final taskAsync = ref.watch(taskByIdProvider(widget.taskId));
    final types = ref.watch(protocolTypesProvider).valueOrNull ?? const <ProtocolType>[];
    final task = taskAsync.valueOrNull;
    final today = localToday();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aufgabe'),
        actions: [
          if (isLeader && task != null) ...[
            IconButton(
              tooltip: 'Bearbeiten',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showTaskFormSheet(context, task: task),
            ),
            IconButton(
              tooltip: 'Löschen',
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              onPressed: () => _delete(task),
            ),
          ],
        ],
      ),
      bottomNavigationBar: task != null && task.status != 'completed'
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: FilledButton.icon(
                  onPressed: _savingStatus ? null : () => _setStatus(task, 'completed'),
                  icon: const Icon(Icons.check),
                  label: const Text('Als erledigt markieren'),
                ),
              ),
            )
          : null,
      body: taskAsync.isLoading && task == null
          ? const Center(child: CircularProgressIndicator())
          : task == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.search, size: 56, color: AppColors.medium),
                      const SizedBox(height: AppDimensions.paddingM),
                      const Text('Diese Aufgabe gibt es nicht mehr oder du kannst sie nicht sehen.',
                          textAlign: TextAlign.center),
                      TextButton(onPressed: () => context.pop(), child: const Text('Zurück')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async => ref.invalidate(taskByIdProvider(widget.taskId)),
                  child: _buildBody(context, task, isLeader, me?.id, types, today),
                ),
    );
  }

  Widget _buildBody(
      BuildContext context, TeamTask task, bool isLeader, int? myId, List<ProtocolType> types, String today) {
    final theme = Theme.of(context);
    final isMine = myId != null && task.responsiblePersonId == myId;
    final overdue = isTaskOverdue(task, today);
    final name = task.responsiblePerson.fullName;
    final assignee = isMine
        ? 'Dir zugewiesen'
        : name.isNotEmpty
            ? 'Zugewiesen an $name'
            : 'Noch niemandem zugewiesen';

    String? attendanceLabel;
    final att = task.attendance;
    if (att != null) {
      String? typeName = att.typeInfo?.isNotEmpty == true ? att.typeInfo : null;
      if (typeName == null) {
        for (final t in types) {
          if (t.id == att.typeId) typeName = t.name;
        }
      }
      attendanceLabel = '${typeName ?? 'Termin'} vom ${formatLongDate(att.date)}';
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      children: [
        Text(
          task.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            decoration: task.status == 'completed' ? TextDecoration.lineThrough : null,
          ),
        ),
        const SizedBox(height: 4),
        Text(assignee, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.medium)),
        const SizedBox(height: AppDimensions.paddingM),
        SegmentedButton<String>(
          segments: [
            for (final s in const ['open', 'in_progress', 'completed'])
              ButtonSegment(value: s, label: Text(taskStatusLabels[s]!)),
          ],
          selected: {task.status},
          showSelectedIcon: false,
          onSelectionChanged: _savingStatus ? null : (s) => _setStatus(task, s.first),
        ),
        const SizedBox(height: AppDimensions.paddingM),
        Text('Details', style: theme.textTheme.titleSmall),
        Card(
          child: Column(
            children: [
              if (isLeader)
                ListTile(
                  title: const Text('Verantwortlich'),
                  trailing: Text(name.isNotEmpty ? name : 'Niemand'),
                ),
              ListTile(
                title: const Text('Fällig am'),
                trailing: Text(
                  task.dueDate != null
                      ? '${formatLongDate(task.dueDate)}${overdue ? ' · überfällig' : ''}'
                      : 'Ohne Fälligkeit',
                  style: overdue ? const TextStyle(color: AppColors.danger) : null,
                ),
              ),
              ListTile(
                title: const Text('Priorität'),
                trailing: TeamOrgBadge(
                  label: priorityLabels[task.priority] ?? task.priority,
                  color: priorityColor(task.priority),
                ),
              ),
              if (task.description?.isNotEmpty == true)
                ListTile(
                  title: const Text('Beschreibung'),
                  subtitle: SelectableText(task.description!),
                ),
            ],
          ),
        ),
        if (task.attendanceId != null || task.agendaItemId != null) ...[
          const SizedBox(height: AppDimensions.paddingM),
          Text('Herkunft', style: theme.textTheme.titleSmall),
          Card(
            child: Column(
              children: [
                if (task.attendanceId != null)
                  ListTile(
                    leading: const Icon(Icons.description_outlined, color: AppColors.primary),
                    title: const Text('Protokoll'),
                    subtitle: attendanceLabel != null ? Text(attendanceLabel) : null,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/settings/protocol/${task.attendanceId}'),
                  ),
                if (task.agendaItemId != null)
                  if (isLeader)
                    ListTile(
                      leading: const Icon(Icons.list, color: AppColors.primary),
                      title: const Text('Thema'),
                      subtitle: Text(task.agendaItem?.title ?? 'Thema öffnen'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/settings/agenda-items/${task.agendaItemId}'),
                    )
                  else if (task.agendaItem?.title != null)
                    ListTile(
                      leading: const Icon(Icons.list, color: AppColors.medium),
                      title: const Text('Thema'),
                      subtitle: Text(task.agendaItem!.title!),
                    ),
              ],
            ),
          ),
        ],
        if (task.status != 'completed' && task.dueDate != null)
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingS),
            child: Text(
              isMine
                  ? 'Du bekommst 2 Tage vor Fälligkeit eine Erinnerung und noch eine, falls die Aufgabe überfällig wird.'
                  : 'Die verantwortliche Person bekommt 2 Tage vor Fälligkeit eine Erinnerung und noch eine, falls die Aufgabe überfällig wird.',
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
