import 'package:flutter/material.dart';

import '../../../core/utils/event_list_utils.dart';
import '../../../data/models/attendance/attendance.dart';
import '../../../data/models/plan/plan.dart';
import '../../../l10n/l10n.dart';
import 'pages/plan_viewer_page.dart';

/// True when [att] has an Ablaufplan with entries (Ionic hasPlan). Callers
/// hide it from Beobachter themselves.
bool attendanceHasPlan(Attendance att) {
  final fields = att.plan?['fields'];
  return fields is List && fields.isNotEmpty;
}

/// Opens the Ablaufplan of [att] read-only; a Termin running today starts
/// in live mode (Ionic openPlanViewer).
Future<void> openAttendancePlanViewer(BuildContext context, Attendance att) async {
  Plan? plan;
  try {
    plan = Plan.fromJson(att.plan!);
  } catch (_) {
    return;
  }
  await showPlanViewer(
    context,
    attendance: PlanAttendance(
      id: att.id,
      date: att.date,
      durationDays: att.durationDays,
      plan: plan,
      typeId: att.typeId,
      typeInfo: att.typeInfo,
      startTime: att.startTime,
      sharePlan: att.sharePlan,
    ),
    plan: plan,
    title: (plan.title?.trim().isNotEmpty ?? false)
        ? plan.title!.trim()
        : (att.typeInfo?.isNotEmpty ?? false)
            ? att.typeInfo!
            : context.l10n.signoutRunSheet,
    defaultLive: EventListUtils.isRunning(att.date, att.durationDays),
  );
}
