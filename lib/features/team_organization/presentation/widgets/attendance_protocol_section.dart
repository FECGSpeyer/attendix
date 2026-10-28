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
import '../../team_org_utils.dart';
import 'agenda_picker_sheet.dart';

/// Status line of the protocol card (Ionic attendance.page "Protokoll"):
/// "Noch nicht begonnen" / "Freigegeben am …[ · geändert am …]" /
/// "Entwurf · zuletzt bearbeitet … Uhr".
String protocolCardStatus(Protocol? protocol) {
  if (protocol == null) return 'Noch nicht begonnen';
  final date = DateFormat('dd.MM.yyyy');
  if (protocol.status == 'published') {
    final pub = DateTime.tryParse(protocol.publishedAt ?? '')?.toLocal();
    var line = 'Freigegeben am ${pub != null ? date.format(pub) : ''}';
    if (isEditedAfterPublish(protocol)) {
      final upd = DateTime.tryParse(protocol.updatedAt ?? '')?.toLocal();
      line = '$line · geändert am ${upd != null ? date.format(upd) : ''}';
    }
    return line;
  }
  final edited = DateTime.tryParse(protocol.updatedAt ?? protocol.createdAt ?? '')?.toLocal();
  return 'Entwurf · zuletzt bearbeitet ${edited != null ? DateFormat('dd.MM.yyyy, HH:mm').format(edited) : ''} Uhr';
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
      'completed' => 'Erledigt',
      'in_progress' => 'In Arbeit',
      _ => 'Offen',
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: AppDimensions.paddingXS),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const Icon(Icons.description_outlined, color: AppColors.primary),
            title: const Text('Protokoll', style: TextStyle(fontWeight: FontWeight.w600)),
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
                      published ? 'Freigegeben' : 'Entwurf',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
          ),
          if (isLeader)
            ListTile(
              leading: Icon(protocol != null ? Icons.edit_outlined : Icons.play_circle_outline,
                  color: AppColors.primary),
              title: Text(
                protocol != null ? 'Protokoll öffnen' : 'Sitzung starten & protokollieren',
                style: const TextStyle(color: AppColors.primary),
              ),
              onTap: () => _push(context, ref, '/settings/protocol/$attendanceId'),
            )
          else if (published)
            ListTile(
              leading: const Icon(Icons.chrome_reader_mode_outlined, color: AppColors.primary),
              title: const Text('Protokoll lesen', style: TextStyle(color: AppColors.primary)),
              onTap: () => _push(context, ref, '/settings/protocol/$attendanceId'),
            ),
          if (tasks.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('Aufgaben aus diesem Termin', style: Theme.of(context).textTheme.titleSmall),
            ),
            for (final task in tasks) _taskTile(context, ref, task),
          ],
        ],
      ),
    );
  }

  Widget _taskTile(BuildContext context, WidgetRef ref, TeamTask task) {
    final done = task.status == 'completed';
    final who = task.responsiblePerson.fullName.isNotEmpty ? task.responsiblePerson.fullName : 'Niemand zugewiesen';
    final due = DateTime.tryParse(task.dueDate ?? '');
    final subtitle = due != null && !done ? '$who · fällig ${DateFormat('dd.MM.').format(due)}' : who;
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
