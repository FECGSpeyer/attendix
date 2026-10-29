import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/attendance_detail_providers.dart';
import '../../../../core/providers/plan_providers.dart';
import '../../../../core/providers/team_org_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/team_org/team_org.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive_platform.dart' show useIosLook; // PARITY_R9
import '../../../../shared/widgets/layout/ionic_md.dart' show IonMd; // PARITY_R9
import '../../team_org_utils.dart';
import 'agenda_picker_sheet.dart';

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
  } catch (_) {}
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
    final published = protocol?.status == 'published';

    // PARITY_R9: an `ion-item-group` of Ionic's inset list, not an
    // ion-card – md shows a flat block with radius 16 and no shadow.
    final ios = useIosLook(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: AppDimensions.paddingXS),
      elevation: ios ? null : 0,
      shape: ios ? null : IonMd.insetGroupShape,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const Icon(Icons.description_outlined, color: AppColors.primary),
            title: Text(context.l10n.attendanceProtocol, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: protocolAsync.isLoading && protocol == null
                ? const Text('…')
                : Text(protocolCardStatus(protocol)),
            trailing: protocol == null
                ? null
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: published ? AppColors.success : AppColors.medium,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      published ? context.l10n.attendancePublished : context.l10n.attendanceDraft,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
          ),
          if (isLeader)
            ListTile(
              leading: Icon(protocol != null ? Icons.edit_outlined : Icons.play_circle_outline,
                  color: AppColors.primary),
              title: Text(
                protocol != null ? context.l10n.attendanceOpenProtocol : context.l10n.attendanceStartSession,
                style: const TextStyle(color: AppColors.primary),
              ),
              onTap: () => _push(context, ref, '/settings/protocol/$attendanceId'),
            )
          else if (published)
            ListTile(
              leading: const Icon(Icons.chrome_reader_mode_outlined, color: AppColors.primary),
              title: Text(context.l10n.attendanceReadProtocol, style: const TextStyle(color: AppColors.primary)),
              onTap: () => _push(context, ref, '/settings/protocol/$attendanceId'),
            ),
          if (tasks.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(context.l10n.attendanceTasksFromEvent, style: Theme.of(context).textTheme.titleSmall),
            ),
            for (final task in tasks) _taskTile(context, ref, task),
          ],
        ],
      ),
    );
  }

  Widget _taskTile(BuildContext context, WidgetRef ref, TeamTask task) {
    final done = task.status == 'completed';
    final who = task.responsiblePerson.fullName.isNotEmpty ? task.responsiblePerson.fullName : context.l10n.attendanceNobodyAssigned;
    final due = DateTime.tryParse(task.dueDate ?? '');
    final subtitle = due != null && !done
        ? '$who ${context.l10n.attendanceDueOn(DateFormat(dateFmt(DateFmtKind.dayMonth)).format(due))}'
        : who;
    return ListTile(
      leading: Icon(
        done ? Icons.check_circle : Icons.radio_button_unchecked,
        color: done ? AppColors.success : AppColors.medium,
      ),
      title: Text(task.title, style: done ? const TextStyle(decoration: TextDecoration.lineThrough) : null),
      subtitle: Text(subtitle),
      trailing: Text(taskStatusLabel(task.status), style: const TextStyle(color: AppColors.medium)),
      onTap: () => _push(context, ref, '/settings/tasks/${task.id}'),
    );
  }
}
