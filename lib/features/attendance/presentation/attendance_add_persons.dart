import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/enums.dart';
import '../../../core/providers/attendance_detail_providers.dart';
import '../../../core/providers/attendance_providers.dart';
import '../../../core/providers/group_providers.dart';
import '../../../core/providers/profile_providers.dart';
import '../../../core/providers/shift_providers.dart';
import '../../../core/utils/shift_utils.dart';
import '../../../core/utils/toast_helper.dart';
import '../../../data/models/attendance/attendance.dart';
import '../../../data/models/shift/shift_plan.dart';
import '../../../l10n/l10n.dart';
import 'widgets/attendance_detail/add_persons_sheet.dart';

/// "Person hinzufügen" (Ionic openAddPersonModal / addPersonsToAttendance),
/// shared by the Termin page and the Termin page of the new design: picks
/// persons not yet in the Termin and creates their rows with the type's
/// default status (or the status of their shift). [currentPersonIds] are
/// the persons the Termin already has. Writes go through the tenant
/// repository (`tenantId` filtered).
Future<void> addPersonsToAttendance(
  BuildContext context,
  WidgetRef ref, {
  required int attendanceId,
  required Set<int> currentPersonIds,
}) async {
  final repo = ref.read(attendanceRepositoryWithTenantProvider);
  final AddPersonCandidates candidates;
  try {
    final allPersons = await ref.read(allPersonsForAttendanceProvider.future);
    final type = await ref.read(attendanceTypeForAttendanceProvider(attendanceId).future);
    final groups = await ref.read(groupsProvider.future);
    final extraFields = ref.read(personExtraFieldsProvider).valueOrNull ?? const [];
    candidates = computeAddPersonCandidates(
      allPersons: allPersons,
      currentPersonIds: currentPersonIds,
      type: type,
      groups: groups,
      extraFieldDefaults: {for (final f in extraFields) f.id: f.defaultValue},
    );
  } catch (_) {
    if (context.mounted) ToastHelper.showError(context, context.l10n.attendanceLoadPeopleFailed);
    return;
  }
  if (!context.mounted) return;
  final selected = await showAddPersonsSheet(
    context,
    candidates: candidates,
    groupNameOf: (p) => p.groupName ?? context.l10n.attendanceNoGroup,
  );
  if (selected == null || selected.isEmpty || !context.mounted) return;

  try {
    final attendance = ref.read(attendanceDetailProvider(attendanceId)).valueOrNull;
    final type = ref.read(attendanceTypeForAttendanceProvider(attendanceId)).valueOrNull;
    final defaultStatus = type?.defaultStatus ?? AttendanceStatus.neutral;
    final date = DateTime.tryParse(attendance?.date ?? '') ?? DateTime.now();
    final shifts = await ref.read(shiftsProvider.future).catchError((_) => <ShiftPlan>[]);
    final all = [...candidates.matching, ...candidates.others];
    final records = <PersonAttendance>[];
    for (final personId in selected) {
      final person = all.where((p) => p.id == personId).firstOrNull;
      if (person == null) continue;
      var status = defaultStatus;
      var notes = '';
      if (person.shiftId != null && type?.allDay != true) {
        final result = ShiftUtils.statusByShiftOrDefault(
          shift: ShiftUtils.findShift(shifts, person.shiftId),
          attendanceDate: date,
          attendanceStart: type?.startTime ?? '19:00',
          attendanceEnd: type?.endTime ?? '21:00',
          defaultStatus: defaultStatus,
          shiftStart: person.shiftStart,
          shiftName: person.shiftName,
        );
        status = result.status;
        notes = result.note;
      }
      records.add(PersonAttendance(
        attendanceId: attendanceId,
        personId: personId,
        status: status,
        notes: notes,
      ));
    }
    await repo.createPersonAttendances(records);
    ref.invalidate(personAttendancesForAttendanceProvider(attendanceId));
    if (!context.mounted) return;
    ToastHelper.showSuccess(context, context.l10n.attendancePeopleAdded(records.length));
  } catch (_) {
    if (context.mounted) ToastHelper.showError(context, context.l10n.attendanceAddPeopleFailed);
  }
}
