import 'package:flutter/material.dart';

import '../../../core/utils/event_list_utils.dart';
import '../../../data/models/attendance/attendance.dart';
import '../../../data/models/plan/plan.dart';
import '../../../data/models/song/song.dart';
import '../../../l10n/l10n.dart';
import '../../self_service/presentation/widgets/song_options_sheet.dart';
import 'pages/plan_viewer_page.dart';

/// True when [att] has an Ablaufplan with entries (Ionic hasPlan). Callers
/// hide it from Beobachter themselves.
bool attendanceHasPlan(Attendance att) {
  final fields = att.plan?['fields'];
  return fields is List && fields.isNotEmpty;
}

/// Opens the Ablaufplan of [att] read-only; a Termin running today starts
/// in live mode (Ionic att-list openPlanViewer).
///
/// Like Ionic the viewer gets the Termin with its `extra_plans` (several
/// plans → day/plan chips, today's plan preselected), the instance's Werke
/// [songs] (Werk rows open the score options) and, for Dirigent/Helfer,
/// [onEdit] (pencil; closes the viewer and opens the editor on that plan).
Future<void> openAttendancePlanViewer(
  BuildContext context,
  Attendance att, {
  List<Song> songs = const [],
  List<Plan> extraPlans = const [],
  void Function(int planIndex)? onEdit,
}) async {
  Plan? plan;
  try {
    plan = Plan.fromJson(att.plan!);
  } catch (_) {
    return;
  }
  final extra = extraPlans;
  Song? songOf(int? id) => id == null ? null : songs.where((s) => s.id == id).firstOrNull;
  await showPlanViewer(
    context,
    attendance: PlanAttendance(
      id: att.id,
      date: att.date,
      durationDays: att.durationDays,
      plan: plan,
      extraPlans: extra.isEmpty ? null : extra,
      typeId: att.typeId,
      typeInfo: att.typeInfo,
      startTime: att.startTime,
      sharePlan: att.sharePlan,
    ),
    // An explicit plan disables the chips (Ionic: only when it differs from
    // attendance.plan), so leave it out when there are further plans.
    plan: extra.isEmpty ? plan : null,
    title: (plan.title?.trim().isNotEmpty ?? false)
        ? plan.title!.trim()
        : (att.typeInfo?.isNotEmpty ?? false)
            ? att.typeInfo!
            : context.l10n.signoutRunSheet,
    defaultLive: EventListUtils.isRunning(att.date, att.durationDays),
    onEdit: onEdit,
    // Ionic: no playerInstrument from the Terminliste → no "Keine Noten"
    // warning, every Werk row opens the score options.
    songAction: songs.isEmpty
        ? null
        : (f) {
            final song = songOf(f.songId);
            if (song == null) return null;
            return () => showSongOptionsSheet(context, song: song);
          },
  );
}
