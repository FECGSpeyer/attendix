import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/providers/attendance_detail_providers.dart';
import '../../../../../core/providers/attendance_providers.dart';
import '../../../../../core/providers/attendance_type_providers.dart';
import '../../../../../core/providers/conductor_providers.dart';
import '../../../../../core/constants/enums.dart';
import '../../../../../core/providers/debug_providers.dart';
import '../../../../../core/providers/organisation_providers.dart';
import '../../../../../core/providers/plan_providers.dart';
import '../../../../../core/providers/role_permission_providers.dart';
import '../../../../../core/providers/song_providers.dart';
import '../../../../../core/providers/tenant_providers.dart';
import '../../../../../core/router/app_routes.dart';
import '../../../../../core/router/route_access.dart' show canOpenSongsTab;
import '../../../../../core/services/error_reporter.dart';
import '../../../../../core/services/offline_queue_service.dart';
import '../../../../../core/theme/design_theme.dart';
import '../../../../../core/utils/attendance_logic_utils.dart' show showSongsForType;
import '../../../../../core/utils/dialog_helper.dart';
import '../../../../../core/utils/error_message.dart';
import '../../../../../core/utils/event_list_utils.dart';
import '../../../../../core/utils/haptic_helper.dart';
import '../../../../../core/utils/plan_utils.dart';
import '../../../../../core/utils/toast_helper.dart';
import '../../../../../data/models/attendance/attendance.dart';
import '../../../../../data/models/person/person.dart';
import '../../../../../data/models/plan/plan.dart' show Plan, PlanAttendance, PlanAttendanceType;
import '../../../../../data/models/song/song.dart';
import '../../../../../data/repositories/attendance_repository.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../../shared/widgets/event_list/event_list_widgets.dart' show openEventNavigation;
import '../../attendance_song_history.dart';
import '../attendance_detail/attendance_detail_sheets.dart'
    show showConductorChangeDialog;
import '../attendance_detail/description_attachment_sheet.dart';
import '../songs_selection_sheet.dart';
import '../../../../planning/presentation/attendance_plan_viewer.dart';
import '../../../../planning/presentation/widgets/plan_start.dart';
import '../../../../planning/presentation/widgets/plan_widgets.dart' show PlanEventWork, showRdEventWorksSheet;
import '../../../../self_service/presentation/widgets/self_service_event_actions.dart' show openFilesFolderRoute;
import '../../../data/providers/event_works_providers.dart';
import '../../../../today/data/providers/today_providers.dart' show rdDeadlineLabel;
import '../../../data/event_details_logic.dart';
import '../../../../../core/logic/type_flags.dart';
import '../../../../../shared/widgets/components/components.dart';
import '../../../../today/presentation/widgets/today_common.dart';
import 'event_now.dart' show rdPlanOf;

part 'event_plan_checklist_sections.dart';
part 'event_program_section.dart';

/// REDESIGN: sections of a Termin's "Überblick" for Dirigent and Helfer
/// (Programm/Werke, Ablauf, Vorbereitung, Infos zum Termin). They replace
/// the old Termin page ("Alle Details") in the new design. Every write
/// goes through the tenant repositories like the old Termin page.

/// Uppercase label with an optional text action on the right ("+ Werk").
class RdSectionLabel extends StatelessWidget {
  const RdSectionLabel(
    this.text, {
    super.key,
    this.actionLabel,
    this.actionSemantics,
    this.onAction,
    this.actionIcon = Icons.add,
  });

  final String text;
  final String? actionLabel;
  final String? actionSemantics;
  final VoidCallback? onAction;

  /// "+ Aufgabe"; [Icons.chevron_right] goes after the label ("Ganz
  /// ansehen ›").
  final IconData actionIcon;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: RdGroupLabel(text)),
        if (actionLabel != null && onAction != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Semantics(
              button: true,
              label: actionSemantics,
              excludeSemantics: actionSemantics != null,
              child: InkWell(
                onTap: onAction,
                borderRadius: BorderRadius.circular(10),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 40),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (actionIcon != Icons.chevron_right) ...[
                          Icon(actionIcon, size: 18, color: p.link),
                          const SizedBox(width: 2),
                        ],
                        Text(actionLabel!, style: TextStyle(fontSize: 15, color: p.link)),
                        if (actionIcon == Icons.chevron_right) Icon(actionIcon, size: 18, color: p.link),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Round number in front of a Werk ("1").
class RdProgramNumber extends StatelessWidget {
  const RdProgramNumber(this.number, {super.key});

  final int number;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(color: p.soft, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text('$number', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.softText)),
    );
  }
}

// ---------------------------------------------------------------------------
// Infos zum Termin
// ---------------------------------------------------------------------------

/// Navigation, Beschreibung & Anhang, Ordner, Antwort bis: only rows with
/// content (all of them are edited in "Termin bearbeiten"). After the
/// Termin without Navigation and Antwort bis.
class RdEventInfoSection extends ConsumerWidget {
  const RdEventInfoSection({super.key, required this.attendance, this.title, this.ended = false});

  final Attendance attendance;

  /// Heading; default "Infos".
  final String? title;
  final bool ended;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final att = attendance;
    final place = (att.place ?? '').trim();
    final description = rdPlainText(att.description);
    final attachment = (att.attachmentName ?? '').trim();
    final hasDescription = description.isNotEmpty || (att.attachmentUrl ?? '').isNotEmpty;
    final folder = (att.filesFolder ?? '').trim();
    final canFiles = ref.watch(canAccessFilesProvider);
    final deadline = EventListUtils.deadlineLocal(att.deadline);
    final rows = <Widget>[
      if (place.isNotEmpty && !ended)
        RdListRow(
          leading: const RdRowIcon(Icons.navigation_outlined),
          title: l10n.signoutOpenNavigation,
          subtitle: place,
          onTap: () => openEventNavigation(context, place),
        ),
      if (hasDescription)
        RdListRow(
          leading: const RdRowIcon(Icons.info_outline),
          title: l10n.redesignEventDescription,
          subtitle: [
            if (description.isNotEmpty) description,
            if (attachment.isNotEmpty) attachment,
          ].join(' · '),
          onTap: () => showDescriptionAttachmentSheet(context, attendance: att),
        ),
      if (folder.isNotEmpty && canFiles)
        RdListRow(
          leading: const RdRowIcon(Icons.folder_outlined),
          title: l10n.attendanceFilesFolder,
          subtitle: folder,
          onTap: () => openFilesFolderRoute(context, folder),
        ),
      if (deadline != null && !ended)
        RdListRow(
          leading: const RdRowIcon(Icons.schedule),
          title: l10n.redesignCreateDeadline,
          subtitle: rdDeadlineLabel(deadline),
          showChevron: false,
        ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        RdGroupLabel(title ?? l10n.redesignOwnInfos),
        RdGroupedList(children: rows),
      ],
    );
  }
}
