import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/utils/shift_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/shift/shift_plan.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../core/utils/demo_guard.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';

/// Ionic ShiftPage.copyToInstance: copies a shift plan into another instance
/// of the user.
///
/// 1. Alert "In Instanz kopieren" with the target instances as radio list
///    (nothing preselected), Abbrechen / Weiter.
/// 2. Only when people with an account (appId) use the plan: alert
///    "Zuweisungen kopieren?" with Abbrechen / Nur Schichtplan / Mit
///    Zuweisungen.
/// 3. Copy behind a blocking spinner, then the Ionic result toast.
Future<void> copyShiftToTenant(
  BuildContext context,
  WidgetRef ref,
  ShiftPlan shift,
) async {
  final l10n = context.l10n;
  final currentTenantId = ref.read(currentTenantIdProvider);
  final shiftId = shift.id;
  if (currentTenantId == null || shiftId == null) return;

  final tenants = (await ref.read(userTenantsProvider.future))
      .where((t) => t.id != currentTenantId && t.id != null)
      .toList();
  if (!context.mounted) return;
  if (tenants.isEmpty) {
    ToastHelper.showWarning(context, l10n.shiftsNoOtherTenants);
    return;
  }

  final targetTenantId = await showAppDialog<int>(
    context: context,
    builder: (_) => _TargetTenantAlert(tenants: tenants),
  );
  if (targetTenantId == null || !context.mounted) return;
  final target = tenants.firstWhere((t) => t.id == targetTenantId);

  final supabase = ref.read(supabaseClientProvider);

  // Ionic getPlayersWithShift: people of this plan with an account.
  final List<Map<String, dynamic>> playersWithShift;
  try {
    final rows = await supabase
        .from('player')
        .select('id, appId, shift_name, shift_start')
        .eq('tenantId', currentTenantId)
        .eq('shift_id', shiftId)
        .not('appId', 'is', null);
    playersWithShift = (rows as List).cast<Map<String, dynamic>>();
  } catch (_) {
    if (context.mounted) {
      ToastHelper.showError(context, l10n.svcLoadShiftPeopleFailed);
    }
    return;
  }
  if (!context.mounted) return;

  var copyAssignments = false;
  if (playersWithShift.isNotEmpty) {
    final choice = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AppAlertDialog(
        title: Text(l10n.shiftsCopyAssignments),
        content: Text(l10n.shiftsCopyAssignmentsMessage(
          playersWithShift.length,
          target.longName,
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.shiftsOnlyPlan),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.shiftsWithAssignments),
          ),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;
    copyAssignments = choice;
  }

  if (DemoGuard.blocked()) return; // DEMO_GUARD

  // Ionic Utils.getLoadingElement(): blocking spinner until done.
  final navigator = Navigator.of(context, rootNavigator: true);
  showAppDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(child: AppSpinner()),
    ),
  );
  final int assignedCount;
  try {
    assignedCount = await _executeCopy(
      supabase,
      shift,
      targetTenantId: targetTenantId,
      copyAssignments: copyAssignments,
      playersWithShift: playersWithShift,
    );
  } catch (_) {
    navigator.pop();
    if (context.mounted) ToastHelper.showError(context, l10n.shiftsCopyFailed);
    return;
  }
  navigator.pop();
  if (!context.mounted) return;

  if (copyAssignments && assignedCount > 0) {
    ToastHelper.showSuccess(
      context,
      l10n.shiftsCopiedAssigned(target.longName, assignedCount),
    );
  } else if (copyAssignments && playersWithShift.isNotEmpty) {
    ToastHelper.showWarning(context, l10n.shiftsCopiedNoMatch(target.longName));
  } else {
    ToastHelper.showSuccess(context, l10n.shiftsCopied(target.longName));
  }
}

/// Ionic alert with `type: 'radio'` inputs (longName, value = id, nothing
/// checked). "Weiter" without a choice keeps the alert open with a toast.
class _TargetTenantAlert extends StatefulWidget {
  const _TargetTenantAlert({required this.tenants});

  final List<Tenant> tenants;

  @override
  State<_TargetTenantAlert> createState() => _TargetTenantAlertState();
}

class _TargetTenantAlertState extends State<_TargetTenantAlert> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppAlertDialog(
      title: Text(l10n.shiftsCopyToTenant),
      scrollable: true,
      content: RadioGroup<int>(
        groupValue: _selected,
        onChanged: (value) => setState(() => _selected = value),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.shiftsChooseTarget),
            const SizedBox(height: 8),
            for (final t in widget.tenants)
              RadioListTile<int>(
                value: t.id!,
                title: Text(t.longName),
                contentPadding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () {
            if (_selected == null) {
              ToastHelper.showWarning(context, l10n.shiftsSelectTenant);
              return;
            }
            Navigator.of(context).pop(_selected);
          },
          child: Text(l10n.commonNext),
        ),
      ],
    );
  }
}

/// Ionic executeCopy: inserts a clean copy of [shift] into the target
/// instance and – with [copyAssignments] – assigns it to the active people
/// there with the same account (appId), then recalculates their upcoming
/// attendances. Returns the number of assigned people.
Future<int> _executeCopy(
  SupabaseClient supabase,
  ShiftPlan shift, {
  required int targetTenantId,
  required bool copyAssignments,
  required List<Map<String, dynamic>> playersWithShift,
}) async {
  // Create a clean copy without IDs
  final copiedShift = {
    'name': '${shift.name} (Kopie)',
    'description': shift.description,
    'tenant_id': targetTenantId,
    'definition': shift.definition
        .map((def) => {
              'start_time': def.startTime,
              'duration': def.duration,
              'free': def.free,
              'index': def.index,
              'repeat_count': def.repeatCount,
            })
        .toList(),
    'shifts': shift.shifts
        .map((s) => {
              'name': s.name,
              'date': s.date,
            })
        .toList(),
  };

  final insertResponse = await supabase
      .from('shifts')
      .insert(copiedShift)
      .select()
      .single();
  final newShiftId = insertResponse['id'] as String;

  if (!copyAssignments || playersWithShift.isEmpty) return 0;

  final appIds = playersWithShift
      .map((p) => p['appId'] as String?)
      .where((id) => id != null && id.isNotEmpty)
      .toList();
  if (appIds.isEmpty) return 0;

  // Find matching players in target tenant by appId
  // DB_REVIEW_REST (M5): only active people (Ionic `.is('left', null)`).
  final targetPlayersResponse = await supabase
      .from('player')
      .select('id, appId')
      .eq('tenantId', targetTenantId)
      .inFilter('appId', appIds)
      .isFilter('left', null);

  // Create mapping: appId -> target player id
  final appIdToTargetId = <String, int>{};
  for (final player in targetPlayersResponse as List) {
    final appId = player['appId'] as String?;
    if (appId != null) appIdToTargetId[appId] = player['id'] as int;
  }

  // Update target players with shift assignment
  var assignedCount = 0;
  final shiftDataByPersonId =
      <int, ({String? shiftName, String? shiftStart})>{};
  for (final sourcePlayer in playersWithShift) {
    final appId = sourcePlayer['appId'] as String?;
    final targetPlayerId = appIdToTargetId[appId];
    if (targetPlayerId == null) continue;
    final shiftName = _emptyToNull(sourcePlayer['shift_name']);
    final shiftStart = _emptyToNull(sourcePlayer['shift_start']);

    await supabase.from('player').update({
      'shift_id': newShiftId,
      'shift_name': shiftName,
      'shift_start': shiftStart,
    }).eq('id', targetPlayerId).eq('tenantId', targetTenantId);

    shiftDataByPersonId[targetPlayerId] =
        (shiftName: shiftName, shiftStart: shiftStart);
    assignedCount++;
  }

  // DB_REVIEW_REST (M5): Ionic updateShiftAttendancesInTenant –
  // excuse upcoming Termine that collide with the copied shift.
  if (shiftDataByPersonId.isNotEmpty) {
    await _updateShiftAttendancesInTenant(
      supabase,
      ShiftPlan.fromJson(insertResponse),
      shiftDataByPersonId,
      targetTenantId: targetTenantId,
    );
  }
  return assignedCount;
}

String? _emptyToNull(dynamic value) {
  final s = value?.toString();
  return (s == null || s.isEmpty) ? null : s;
}

/// DB_REVIEW_REST (M5): Ionic ShiftService.updateShiftAttendancesInTenant.
/// All reads are scoped to the target tenant; person_attendances has no
/// tenant column, so it is filtered through the attendance join.
Future<void> _updateShiftAttendancesInTenant(
  SupabaseClient supabase,
  ShiftPlan shift,
  Map<int, ({String? shiftName, String? shiftStart})> shiftDataByPersonId, {
  required int targetTenantId,
}) async {
  final types = await supabase
      .from('attendance_types')
      .select('id, all_day, start_time, end_time, default_status')
      .eq('tenant_id', targetTenantId);
  final today = DateTime.now().toIso8601String().substring(0, 10);
  final upcoming = await supabase
      .from('attendance')
      .select('id, date, type_id, start_time, end_time')
      .eq('tenantId', targetTenantId)
      .gte('date', today);
  if ((upcoming as List).isEmpty) return;

  final personAttendances = await supabase
      .from('person_attendances')
      .select(
          'id, person_id, attendance_id, status, attendance:attendance_id!inner(tenantId)')
      .inFilter('person_id', shiftDataByPersonId.keys.toList())
      .inFilter('attendance_id', upcoming.map((a) => a['id']).toList())
      .eq('attendance.tenantId', targetTenantId);

  final updates = ShiftUtils.copiedShiftAttendanceUpdates(
    shift: shift,
    attendances: upcoming.cast<Map<String, dynamic>>(),
    types: (types as List).cast<Map<String, dynamic>>(),
    personAttendances: (personAttendances as List).cast<Map<String, dynamic>>(),
    shiftDataByPersonId: shiftDataByPersonId,
  );
  for (final u in updates) {
    await supabase
        .from('person_attendances')
        .update({'status': u.status.value, 'notes': u.notes})
        .eq('id', u.id);
  }
}
