import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/attendance_detail_providers.dart';
import '../../../../core/providers/plan_providers.dart';
import '../../../../core/providers/team_org_providers.dart';
import '../../../../data/models/team_org/team_org.dart';
import '../../../../l10n/l10n.dart';
import '../../team_org_utils.dart';
import 'agenda_picker_sheet.dart';
import '../../../../core/services/error_reporter.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../shared/widgets/redesign/rd_widgets.dart';

/// Status line of the protocol card (Ionic attendance.page "Protokoll"):
/// "Noch nicht begonnen" / "Freigegeben am …[ · geändert am …]" /
/// "Entwurf · zuletzt bearbeitet … Uhr".
String protocolCardStatus(Protocol? protocol) {
  final l10n = l10nWithoutContext;
  if (protocol == null) return l10n.attendanceNotStarted;
  final date = DateFormat(dateFmt());
  if (protocol.status == 'published') {
    final pub = DateTime.tryParse(protocol.publishedAt ?? '')?.toLocal();
    var line = l10n.attendancePublishedOn(pub != null ? date.format(pub) : '');
    if (isEditedAfterPublish(protocol)) {
      final upd = DateTime.tryParse(protocol.updatedAt ?? '')?.toLocal();
      line = '$line ${l10n.attendanceChangedOn(upd != null ? date.format(upd) : '')}';
    }
    return line;
  }
  final edited = DateTime.tryParse(protocol.updatedAt ?? protocol.createdAt ?? '')?.toLocal();
  return l10n.attendanceDraftEdited(
    edited != null ? DateFormat('${dateFmt()}, HH:mm').format(edited) : '',
  );
}

/// "Themen aufnehmen" for a Termin (Ionic attendance.page `openAgendaPicker`):
/// loads the current plan, opens the picker and refreshes the Termin.
/// Returns true when the plan was saved.
Future<bool> openAgendaPickerForAttendance(
  BuildContext context,
  WidgetRef ref, {
  required int attendanceId,
  ProtocolType? type,
}) async {
  ProtocolAttendance? attendance;
  try {
    attendance = await ref.read(protocolRepositoryWithTenantProvider).getAttendance(attendanceId);
  } catch (e, st) {
    ErrorReporter.report(e, st, where: 'attendance_protocol_section');
  }
  if (attendance == null || !context.mounted) return false;
  final plan = await showAgendaPickerSheet(context, attendance: attendance, type: type);
  if (plan == null) return false;
  ref.invalidate(attendanceDetailProvider(attendanceId));
  ref.invalidate(planAttendanceByIdProvider(attendanceId));
  ref.invalidate(upcomingProtocolAttendancesProvider);
  return true;
}

/// Ionic `openPlanField`: a TOP opens its topic (leadership only).
void openPlanFieldTopic(BuildContext context, WidgetRef ref, String? agendaItemId) {
  if (agendaItemId == null || !ref.read(isTeamLeaderProvider)) return;
  context.push('/settings/agenda-items/$agendaItemId');
}

/// "Offen" / "In Arbeit" / "Erledigt".
String taskStatusLabel(String status) => switch (status) {
      'completed' => l10nWithoutContext.tasksStatusCompleted,
      'in_progress' => l10nWithoutContext.tasksStatusInProgress,
      _ => l10nWithoutContext.tasksStatusOpen,
    };

/// Protocol card and "Aufgaben aus diesem Termin" of a Termin whose type has
/// "Protokoll & Tagesordnung" (Ionic attendance.page l.670-730). Renders
/// nothing for other types.
class AttendanceProtocolSection extends ConsumerWidget {
  const AttendanceProtocolSection({super.key, required this.attendanceId, required this.typeId});

  final int attendanceId;
  final String? typeId;

  Future<void> _push(BuildContext context, WidgetRef ref, String location) async {
    await context.push(location);
    // Refresh after coming back from the protocol or a task.
    ref.invalidate(protocolForAttendanceProvider(attendanceId));
    ref.invalidate(tasksForAttendanceProvider(attendanceId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = ref.watch(protocolTypeByIdProvider(typeId));
    if (type == null || !type.enableProtocol) return const SizedBox.shrink();
    final isLeader = ref.watch(isTeamLeaderProvider);
    final protocolAsync = ref.watch(protocolForAttendanceProvider(attendanceId));
    final protocol = protocolAsync.valueOrNull;
    final tasks = ref.watch(tasksForAttendanceProvider(attendanceId)).valueOrNull ?? const <TeamTask>[];
    final p = context.rd;
    final l10n = context.l10n;
    final published = protocol?.status == 'published';
    final open = '/settings/protocol/$attendanceId';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdGroupLabel(l10n.redesignDutyProtocolTitle),
        RdGroupedList(
          children: [
            RdListRow(
              leading: const RdRowIcon(Icons.description_outlined),
              title: l10n.attendanceProtocol,
              subtitle: protocolAsync.isLoading && protocol == null ? '…' : protocolCardStatus(protocol),
              showChevron: false,
              trailing: protocol == null
                  ? null
                  : RdPill(
                      published ? l10n.attendancePublished : l10n.attendanceDraft,
                      tone: published ? RdTone.present : RdTone.late,
                    ),
            ),
            if (isLeader)
              RdListRow(
                leading: Icon(protocol != null ? Icons.edit_outlined : Icons.play_circle_outline, color: p.primary),
                title: protocol != null ? l10n.attendanceOpenProtocol : l10n.attendanceStartSession,
                titleColor: p.primary,
                onTap: () => _push(context, ref, open),
              )
            else if (published)
              RdListRow(
                leading: Icon(Icons.chrome_reader_mode_outlined, color: p.primary),
                title: l10n.attendanceReadProtocol,
                titleColor: p.primary,
                onTap: () => _push(context, ref, open),
              ),
          ],
        ),
        if (tasks.isNotEmpty) ...[
          const SizedBox(height: 18),
          RdGroupLabel(l10n.redesignDutyTasksTitle),
          RdGroupedList(
            children: [
              for (final task in tasks) _taskRowBeta(context, ref, task),
            ],
          ),
        ],
      ],
    );
  }

  Widget _taskRowBeta(BuildContext context, WidgetRef ref, TeamTask task) {
    final p = context.rd;
    final l10n = context.l10n;
    final done = task.status == 'completed';
    final who = task.responsiblePerson.fullName.isNotEmpty ? task.responsiblePerson.fullName : l10n.attendanceNobodyAssigned;
    final due = DateTime.tryParse(task.dueDate ?? '');
    final subtitle = due != null && !done
        ? '$who ${l10n.attendanceDueOn(DateFormat(dateFmt(DateFmtKind.dayMonth)).format(due))}'
        : who;
    return RdListRow(
      leading: Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: done ? p.present : p.text2),
      title: task.title,
      titleColor: done ? p.text2 : null,
      subtitle: subtitle,
      trailing: RdPill(
        taskStatusLabel(task.status),
        tone: switch (task.status) {
          'completed' => RdTone.present,
          'in_progress' => RdTone.primary,
          _ => RdTone.late,
        },
      ),
      onTap: () => _push(context, ref, '/settings/tasks/${task.id}'),
    );
  }
}
