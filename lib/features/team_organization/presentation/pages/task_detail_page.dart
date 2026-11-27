import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../shared/widgets/redesign/rd_widgets.dart';
import '../../../../core/providers/team_org_providers.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/team_org/team_org.dart';
import '../../../../l10n/l10n.dart';
import '../../team_org_utils.dart';
import '../widgets/task_form_sheet.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';

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

  @override
  void initState() {
    super.initState();
    // Ionic: the task is loaded anew on every open (also after an earlier
    // load error); a cached task stays visible meanwhile.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) refreshUnlessLoading(ref, taskByIdProvider(widget.taskId));
    });
  }

  /// Ionic ion-refresher (in every state of the page).
  Future<void> _reload() async {
    ref.invalidate(taskByIdProvider(widget.taskId));
    try {
      await ref.read(taskByIdProvider(widget.taskId).future);
    } catch (_) {
      // "Diese Aufgabe gibt es nicht mehr…" stays.
    }
  }

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
    // Tasks of others (visible to who attended their Besprechung) are
    // read-only for members.
    final canChange = task != null && (isLeader || (me?.id != null && task.responsiblePersonId == me!.id));

    return _buildBeta(context, taskAsync, isLeader, canChange, me?.id, types, today);
  }

  /// Beta: same frame as the Besprechung page. "Bearbeiten" as text at the
  /// top, deleting as the last row, the description in its own card.
  Widget _buildBeta(BuildContext context, AsyncValue<TeamTask?> taskAsync, bool isLeader, bool canChange,
      int? myId, List<ProtocolType> types, String today) {
    final p = context.rd;
    final l10n = context.l10n;
    final task = taskAsync.valueOrNull;

    final back = RdBackLink(label: l10n.rdTeamTitle, onTap: () => rdBack(context, '/settings/team-organization'));
    if (task == null) {
      return RdPage(
        onRefresh: _reload,
        children: [
          back,
          const SizedBox(height: 10),
          if (taskAsync.isLoading)
            const Padding(padding: EdgeInsets.only(top: 48), child: Center(child: AppSpinner()))
          else
            RdCard(child: Text(l10n.tasksNotAvailable, style: RdType.meta(p))),
        ],
      );
    }

    final overdue = isTaskOverdue(task, today);
    final name = task.responsiblePerson.fullName;
    final isMine = myId != null && task.responsiblePersonId == myId;
    final description = task.description?.trim() ?? '';

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
    final topicTitle = task.agendaItem?.title;
    final showTopic = task.agendaItemId != null && (isLeader || topicTitle != null);

    return RdPage(
      onRefresh: _reload,
      children: [
        Row(
          children: [
            Expanded(child: back),
            if (isLeader)
              TextButton(
                key: const ValueKey('rd-task-edit'),
                onPressed: () => showTaskFormSheet(context, task: task),
                child: Text(l10n.commonEdit,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.link)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        RdEyebrow(l10n.tasksTask),
        const SizedBox(height: 4),
        Text(task.title, style: RdType.title(p)),
        const SizedBox(height: 16),
        RdSegmented<String>(
          key: const ValueKey('rd-task-status'),
          values: const ['open', 'in_progress', 'completed'],
          selected: task.status,
          labelOf: (s) => taskStatusLabels[s] ?? s,
          enabled: canChange && !_savingStatus,
          onChanged: (s) => _setStatus(task, s),
        ),
        const SizedBox(height: 18),
        RdGroupedList(
          children: [
            RdListRow(
              title: l10n.tasksResponsible,
              value: isMine ? l10n.rdTeamTaskYou : (name.isNotEmpty ? name : l10n.tasksNobody),
              showChevron: false,
            ),
            RdListRow(
              title: l10n.tasksDueOn,
              showChevron: false,
              trailing: Text(
                task.dueDate != null
                    ? '${formatLongDate(task.dueDate)}${overdue ? ' ${l10n.tasksOverdueSuffix}' : ''}'
                    : l10n.tasksNoDue,
                style: TextStyle(fontSize: 16, color: overdue ? p.absent : p.text2),
              ),
            ),
            RdListRow(
              title: l10n.tasksPriority,
              showChevron: false,
              trailing: RdPill(
                priorityLabels[task.priority] ?? task.priority,
                tone: task.priority == 'high' ? RdTone.absent : null,
              ),
            ),
          ],
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 18),
          RdGroupLabel(l10n.tasksDescription),
          RdCard(child: SelectableText(description, style: RdType.body(p))),
        ],
        if (task.attendanceId != null || showTopic) ...[
          const SizedBox(height: 18),
          RdGroupLabel(l10n.tasksOrigin),
          RdGroupedList(
            children: [
              if (task.attendanceId != null)
                RdListRow(
                  leading: const RdRowIcon(Icons.description_outlined),
                  title: l10n.tasksProtocol,
                  subtitle: attendanceLabel,
                  onTap: () => context.push('/settings/protocol/${task.attendanceId}'),
                ),
              if (showTopic)
                RdListRow(
                  leading: const RdRowIcon(Icons.list),
                  title: l10n.tasksTopic,
                  subtitle: topicTitle ?? l10n.teamOrgOpenTopic,
                  showChevron: isLeader,
                  onTap: isLeader ? () => context.push('/settings/agenda-items/${task.agendaItemId}') : null,
                ),
            ],
          ),
        ],
        // The status is set with the three fields above only (no extra
        // "Als erledigt markieren").
        if (isLeader) ...[
          const SizedBox(height: 18),
          RdGroupedList(
            children: [
              RdListRow(
                key: const ValueKey('rd-task-delete'),
                title: l10n.rdTeamTaskDelete,
                titleColor: p.absent,
                showChevron: false,
                onTap: () => _delete(task),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
