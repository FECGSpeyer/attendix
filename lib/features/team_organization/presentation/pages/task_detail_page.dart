import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/team_org_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/team_org/team_org.dart';
import '../../../planning/presentation/widgets/ion_items.dart';
import '../../../../l10n/l10n.dart';
import '../../team_org_utils.dart';
import '../widgets/task_form_sheet.dart';
import '../widgets/tasks_tab.dart' show TeamOrgBadge, priorityColor;
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

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
      if (mounted && status == 'completed') ToastHelper.showSuccess(context, context.l10n.tasksDoneThanks);
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.tasksStatusFailed);
    } finally {
      if (mounted) setState(() => _savingStatus = false);
    }
  }

  Future<void> _delete(TeamTask task) async {
    final ok = await DialogHelper.showConfirmation(
      context,
      title: context.l10n.tasksDeleteConfirm,
      message: context.l10n.tasksDeleteMessage,
      confirmText: context.l10n.commonDelete,
      isDestructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(teamTaskNotifierProvider.notifier).delete(task);
      if (!mounted) return;
      ToastHelper.showSuccess(context, context.l10n.tasksDeleted);
      context.go('/settings/team-organization');
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.tasksDeleteFailed);
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
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tasksTask),
        actions: [
          if (isLeader && task != null) ...[
            IconButton(
              tooltip: l10n.commonEdit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showTaskFormSheet(context, task: task),
            ),
            IconButton(
              tooltip: l10n.commonDelete,
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              onPressed: () => _delete(task),
            ),
          ],
        ],
      ),
      bottomNavigationBar: task != null && task.status != 'completed'
          // Ionic `.task-footer`: round success button (50px, 600).
          ? ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      onPressed: _savingStatus ? null : () => _setStatus(task, 'completed'),
                      icon: const Icon(Icons.check),
                      label: Text(l10n.tasksMarkDone),
                    ),
                  ),
                ),
              ),
            )
          : null,
      body: taskAsync.isLoading && task == null
          ? const Center(child: AppSpinner())
          : task == null
              ? IonEmptyState(
                  icon: Icons.search,
                  iconSize: 48,
                  padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 32),
                  text: l10n.tasksNotAvailable,
                  action: TextButton(onPressed: () => context.pop(), child: Text(l10n.commonBack)),
                )
              : RefreshIndicator.adaptive(
                  onRefresh: () async => ref.invalidate(taskByIdProvider(widget.taskId)),
                  child: _buildBody(context, task, isLeader, me?.id, types, today),
                ),
    );
  }

  Widget _buildBody(
      BuildContext context, TeamTask task, bool isLeader, int? myId, List<ProtocolType> types, String today) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final isMine = myId != null && task.responsiblePersonId == myId;
    final overdue = isTaskOverdue(task, today);
    final name = task.responsiblePerson.fullName;
    final assignee = isMine
        ? l10n.tasksAssignedToYou
        : name.isNotEmpty
            ? l10n.tasksAssignedTo(name)
            : l10n.tasksNotAssigned;

    String? attendanceLabel;
    final att = task.attendance;
    if (att != null) {
      String? typeName = att.typeInfo?.isNotEmpty == true ? att.typeInfo : null;
      if (typeName == null) {
        for (final t in types) {
          if (t.id == att.typeId) typeName = t.name;
        }
      }
      attendanceLabel = l10n.tasksEventFrom(typeName ?? l10n.attendanceEventFallback, formatLongDate(att.date));
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // Ionic `.task-hero`
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                style: TextStyle(
                  fontSize: 25.6,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  color: task.status == 'completed' ? AppColors.medium : theme.colorScheme.onSurface,
                  decoration: task.status == 'completed' ? TextDecoration.lineThrough : null,
                ),
              ),
              const SizedBox(height: 8),
              Text(assignee, style: const TextStyle(color: AppColors.medium)),
            ],
          ),
        ),
        // Ionic `.task-status`: ion-segment
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: IonSegment<String>(
            value: task.status,
            items: [
              for (final s in const ['open', 'in_progress', 'completed'])
                IonSegmentItem<String>(value: s, label: Text(taskStatusLabels[s]!)),
            ],
            onChanged: _savingStatus ? null : (s) => _setStatus(task, s),
          ),
        ),
        IonInsetList(
          header: l10n.tasksDetails,
          children: [
            if (isLeader)
              ListTile(
                title: Text(l10n.tasksResponsible),
                trailing: IonNote(name.isNotEmpty ? name : l10n.tasksNobody),
              ),
            ListTile(
              title: Text(l10n.tasksDueOn),
              trailing: IonNote(
                task.dueDate != null
                    ? '${formatLongDate(task.dueDate)}${overdue ? ' ${l10n.tasksOverdueSuffix}' : ''}'
                    : l10n.tasksNoDue,
                style: overdue ? const TextStyle(color: AppColors.danger) : null,
              ),
            ),
            ListTile(
              title: Text(l10n.tasksPriority),
              trailing: TeamOrgBadge(
                label: priorityLabels[task.priority] ?? task.priority,
                color: priorityColor(task.priority),
              ),
            ),
            if (task.description?.isNotEmpty == true)
              ListTile(
                title: Text(l10n.tasksDescription, style: const TextStyle(fontSize: 14, color: AppColors.medium)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: SelectableText(task.description!,
                      style: TextStyle(height: 1.4, color: theme.colorScheme.onSurface)),
                ),
              ),
          ],
        ),
        if (task.attendanceId != null || task.agendaItemId != null)
          IonInsetList(
            header: l10n.tasksOrigin,
            dividerIndent: 56,
            children: [
              if (task.attendanceId != null)
                ListTile(
                  leading: const Icon(Icons.description_outlined, color: AppColors.primary),
                  title: Text(l10n.tasksProtocol),
                  subtitle: attendanceLabel != null
                      ? Text(attendanceLabel, style: const TextStyle(color: AppColors.medium))
                      : null,
                  trailing: const IonDetailIcon(),
                  onTap: () => context.push('/settings/protocol/${task.attendanceId}'),
                ),
              if (task.agendaItemId != null)
                if (isLeader)
                  ListTile(
                    leading: const Icon(Icons.list, color: AppColors.primary),
                    title: Text(l10n.tasksTopic),
                    subtitle: Text(task.agendaItem?.title ?? l10n.teamOrgOpenTopic,
                        style: const TextStyle(color: AppColors.medium)),
                    trailing: const IonDetailIcon(),
                    onTap: () => context.push('/settings/agenda-items/${task.agendaItemId}'),
                  )
                else if (task.agendaItem?.title != null)
                  ListTile(
                    leading: const Icon(Icons.list, color: AppColors.medium),
                    title: Text(l10n.tasksTopic),
                    subtitle: Text(task.agendaItem!.title!, style: const TextStyle(color: AppColors.medium)),
                  ),
            ],
          ),
        if (task.status != 'completed' && task.dueDate != null)
          // Ionic `.task-hint`: grey note under the lists.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Text(
              isMine ? l10n.tasksReminderSelf : l10n.tasksReminderOther,
              style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.medium),
            ),
          ),
      ],
    );
  }
}
