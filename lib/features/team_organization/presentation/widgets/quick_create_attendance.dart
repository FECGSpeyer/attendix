import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/providers/attendance_providers.dart';
import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/duty_providers.dart';
import '../../../../core/providers/plan_providers.dart';
import '../../../../core/providers/player_absence_providers.dart';
import '../../../../core/providers/shift_providers.dart';
import '../../../../core/providers/team_org_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/utils/duty_utils.dart';
import '../../../../core/utils/shift_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../data/models/duty/person_unavailability.dart';
import '../../../../data/models/player_absence/player_absence.dart';
import '../../../../data/models/shift/shift_plan.dart';
import '../../../../data/models/team_org/team_org.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

/// Protocol-enabled, visible types a Termin can be created for ad hoc
/// (Ionic `protocolAttendanceTypes`), ordered by index.
List<AttendanceType> protocolAttendanceTypes(List<AttendanceType> types, List<ProtocolType> protocolTypes) {
  final enabled = protocolTypes.where((t) => t.enableProtocol).map((t) => t.id).toSet();
  return types.where((t) => t.id != null && enabled.contains(t.id) && t.visible).toList()
    ..sort((a, b) => (a.index ?? 0).compareTo(b.index ?? 0));
}

/// Persons of a new Termin: in the type's groups and its extra-field filter
/// (Ionic `personsForAttendanceType`; paused persons are already excluded).
List<Map<String, dynamic>> personsForAttendanceType(
  List<Map<String, dynamic>> persons,
  AttendanceType type,
  List<ExtraField> extraFields,
) {
  var result = persons.where((p) {
    final groups = type.relevantGroups;
    if (groups == null || groups.isEmpty) return true;
    final instrument = (p['instrument'] as num?)?.toInt();
    return instrument != null && groups.contains(instrument);
  }).toList();
  final filter = type.additionalFieldsFilter;
  final key = filter?['key']?.toString();
  final field = key == null ? null : extraFields.where((f) => f.id == key).firstOrNull;
  if (field != null && filter?['option'] != null) {
    result = result.where((p) {
      final fields = p['additional_fields'];
      final value = (fields is Map ? fields[key] : null) ?? field.defaultValue;
      return value == filter!['option'];
    }).toList();
  }
  return result;
}

DateTime _noon(DateTime d) => DateTime(d.year, d.month, d.day, 12);

/// Row of the new Termin (Ionic `createAttendanceForType`): date at 12:00,
/// times of the type, the checklist with computed due dates and `is_org_plan`
/// (= `attendance_types.is_default_org_plan`, passed as [isOrgPlan]).
Map<String, dynamic> newAttendanceRow(
  AttendanceType type,
  DateTime day, {
  bool isOrgPlan = false,
}) {
  final date = _noon(day);
  List<Map<String, dynamic>>? checklist;
  if (type.checklist != null && type.checklist!.isNotEmpty) {
    final start = type.startTime ?? '';
    final h = start.length >= 5 ? int.tryParse(start.substring(0, 2)) : null;
    final m = start.length >= 5 ? int.tryParse(start.substring(3, 5)) : null;
    final eventAt = DateTime(date.year, date.month, date.day, h ?? 19, m ?? 0);
    checklist = [
      for (final item in type.checklist!)
        {
          'id': const Uuid().v4(),
          'text': item.text,
          'deadlineHours': item.deadlineHours,
          'completed': false,
          'dueDate': item.deadlineHours != null
              ? eventAt.subtract(Duration(hours: item.deadlineHours!)).toUtc().toIso8601String()
              : null,
        },
    ];
  }
  return {
    'date': date.toUtc().toIso8601String(),
    'type_id': type.id,
    'notes': '',
    'save_in_history': true,
    'typeInfo': '',
    'start_time': type.startTime,
    'end_time': type.endTime,
    'duration_days': type.allDay ? (type.durationDays ?? 1) : 1,
    'is_org_plan': isOrgPlan,
    if (checklist != null) 'checklist': checklist,
    // PARITY_A (D9): Ionic createAttendanceForType writes no created_by.
  };
}

/// Person attendances of the new Termin: default status (Neutral for duty
/// types), shift-based status (persons with `shift_id`, not for all-day
/// types), planned absences and "Regelmäßig verhindert" excuse
/// (Ionic `createAttendanceForType`, same order).
List<Map<String, dynamic>> newPersonAttendanceRows(
  List<Map<String, dynamic>> persons,
  AttendanceType type,
  DateTime day, {
  List<PlayerAbsence> absences = const [],
  List<PersonUnavailability> unavailability = const [],
  List<ShiftPlan> shifts = const [],
}) {
  final date = _noon(day);
  final dayKey = DateFormat('yyyy-MM-dd').format(date);
  final canExcuse = type.availableStatuses?.contains(AttendanceStatus.excused) ?? true;
  final rows = <Map<String, dynamic>>[];
  for (final p in persons) {
    final personId = (p['id'] as num).toInt();
    var status = type.dutyMode ? AttendanceStatus.neutral : type.defaultStatus;
    var notes = '';
    final shiftId = p['shift_id']?.toString();
    if (shiftId != null && shiftId.isNotEmpty && !type.allDay) {
      try {
        final result = ShiftUtils.getStatusByShift(
          shift: ShiftUtils.findShift(shifts, shiftId),
          attendanceDate: day,
          attendanceStart: type.startTime ?? '19:00',
          attendanceEnd: type.endTime ?? '21:00',
          defaultStatus: status,
          shiftStart: p['shift_start']?.toString(),
          shiftName: p['shift_name']?.toString(),
        );
        status = result.status;
        notes = result.note;
      } on ShiftNameNotFoundException {
        // Ionic: unknown shift name keeps the default status.
      }
    }
    final absence = absences.where((a) =>
        a.personId == personId &&
        a.fromDate.substring(0, 10).compareTo(dayKey) <= 0 &&
        a.untilDate.substring(0, 10).compareTo(dayKey) >= 0).firstOrNull;
    if (absence != null) {
      status = AttendanceStatus.excused;
      notes = absence.reason;
    } else if (canExcuse) {
      final rule = matchingUnavailability(unavailability, personId, date.toIso8601String(), type.id);
      if (rule != null) {
        status = AttendanceStatus.excused;
        notes = unavailabilityNote(rule);
      }
    }
    rows.add({'person_id': personId, 'status': status.value, 'notes': notes});
  }
  return rows;
}

/// "Neuen Termin anlegen" from the Teamorganisation (Ionic
/// `promptCreateProtocolAttendance`): asks for the type (only when several
/// types have "Protokoll & Tagesordnung") and the day, then creates the
/// Termin with its persons. Returns the new Termin id, or null.
Future<int?> promptCreateProtocolAttendance(BuildContext context, WidgetRef ref) async {
  // UI_TENANT_HOIST: bind tenant + repositories before the first await.
  final repo = ref.read(protocolRepositoryWithTenantProvider);
  final tenant = ref.read(currentTenantProvider);
  final absenceRepo = ref.read(playerAbsenceRepositoryWithTenantProvider);
  final dutyRepo = ref.read(dutyRepositoryWithTenantProvider);
  List<AttendanceType> types;
  try {
    final all = await ref.read(attendanceTypesProvider.future);
    final protocol = await ref.read(protocolTypesProvider.future);
    types = protocolAttendanceTypes(all, protocol);
  } catch (_) {
    types = const [];
  }
  if (!context.mounted) return null;
  if (types.isEmpty) {
    ToastHelper.showWarning(context, context.l10n.dateDialogNoProtocolType);
    return null;
  }

  var type = types.first;
  if (types.length > 1) {
    String? selected = type.id;
    final chosen = await showAppDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AppAlertDialog(
          title: Text(ctx.l10n.dateDialogWhichType),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final t in types)
                RadioListTile<String>(
                  value: t.id!,
                  groupValue: selected,
                  title: Text(t.name),
                  onChanged: (v) => setLocal(() => selected = v),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(ctx.l10n.commonCancel)),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(selected), child: Text(ctx.l10n.commonNext)),
          ],
        ),
      ),
    );
    if (chosen == null || !context.mounted) return null;
    type = types.firstWhere((t) => t.id == chosen, orElse: () => types.first);
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = await showAppDatePicker(
    context: context,
    initialDate: today,
    firstDate: today,
    lastDate: today.add(const Duration(days: 3650)),
    helpText: '${context.l10n.teamOrgFlutterCreateType(type.name)} – ${context.l10n.dateDialogWhichDay}',
    confirmText: context.l10n.commonCreate,
    cancelText: context.l10n.commonCancel,
  );
  if (day == null || !context.mounted) return null;
  if (day.isBefore(today)) {
    ToastHelper.showWarning(context, context.l10n.dateDialogFromToday);
    return null;
  }

  try {
    // Ionic: is_org_plan = type.is_default_org_plan
    var isOrgPlan = false;
    try {
      final planTypes = await ref.read(planAttendanceTypesProvider.future);
      isOrgPlan = planTypes.any((t) => t.id == type.id && t.isDefaultOrgPlan);
    } catch (_) {}
    final results = await Future.wait([
      repo.getPersonsForNewAttendance(),
      absenceRepo
          .getAbsencesForTenant()
          .catchError((_) => <PlayerAbsence>[]),
      dutyRepo.getUnavailabilityForTenant(),
      ref.read(shiftsProvider.future).catchError((_) => <ShiftPlan>[]),
    ]);
    final persons = personsForAttendanceType(
      results[0] as List<Map<String, dynamic>>,
      type,
      tenant?.additionalFields ?? const [],
    );
    final id = await repo.createAttendance(newAttendanceRow(
      type,
      day,
      isOrgPlan: isOrgPlan,
    ));
    await repo.createPersonAttendances(
      id,
      newPersonAttendanceRows(
        persons,
        type,
        day,
        absences: results[1] as List<PlayerAbsence>,
        unavailability: results[2] as List<PersonUnavailability>,
        shifts: results[3] as List<ShiftPlan>,
      ),
    );
    ref.invalidate(attendancesProvider);
    ref.invalidate(upcomingAttendancesProvider);
    ref.invalidate(upcomingProtocolAttendancesProvider);
    if (context.mounted) {
      ToastHelper.showSuccess(
        context,
        context.l10n.dateDialogCreated(DateFormat(dateFmt(DateFmtKind.dayMonth)).format(day)),
      );
    }
    return id;
  } catch (_) {
    if (context.mounted) ToastHelper.showError(context, context.l10n.dateDialogCreateFailed);
    return null;
  }
}
