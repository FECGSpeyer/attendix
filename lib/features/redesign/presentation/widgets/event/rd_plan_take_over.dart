import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/providers/attendance_type_providers.dart';
import '../../../../../core/providers/plan_providers.dart' show planAttendanceTypesProvider;
import '../../../../../core/providers/team_org_providers.dart' show protocolTypesProvider;
import '../../../../../core/utils/demo_guard.dart';
import '../../../../../core/utils/dialog_helper.dart';
import '../../../../../core/utils/toast_helper.dart';
import '../../../../../data/models/attendance/attendance.dart';
import '../../../../../data/models/team_org/team_org.dart' show agendaItemsPlaceholderId;
import '../../../../../l10n/l10n.dart';
import '../../../../settings/presentation/pages/attendance_type_edit_page.dart' show buildDefaultPlanUpdate;
import '../../../../settings/presentation/widgets/type_protocol_settings.dart' show agendaPlaceholderField;
import '../../../data/rd_type_flags.dart';

/// "Für neue Termine dieser Art übernehmen" (••• of the Ablauf editor):
/// the Ablauf [rows] become the template of [type] after a confirmation
/// (Werke as placeholders, see [rdPlanAsTypeTemplate]). Leitung only.
Future<void> rdTakeOverPlanForType(
  BuildContext context,
  WidgetRef ref,
  AttendanceType type,
  List<Map<String, dynamic>> rows,
) async {
  final l10n = context.l10n;
  final notifier = ref.read(attendanceTypeNotifierProvider.notifier);
  final container = ProviderScope.containerOf(context, listen: false);
  final id = type.id;
  if (id == null || rows.isEmpty) return;
  final ok = await DialogHelper.showConfirmation(
    context,
    title: l10n.rdTypeTakeOverPlan,
    message: l10n.rdTypeTakeOverPlanConfirm(type.name),
    confirmText: l10n.rdTypeTakeOverPlan,
    cancelText: l10n.commonCancel,
  );
  if (!ok || !context.mounted) return;
  final fields = rdPlanAsTypeTemplate(
    rows,
    songPlaceholderName: (n) => l10n.typeSettingsSongPlaceholderN(n),
    agendaMarker: agendaPlaceholderField,
    agendaMarkerId: agendaItemsPlaceholderId,
  );
  AttendanceType? updated;
  try {
    updated = await notifier.updateType(id, {'default_plan': buildDefaultPlanUpdate(type.defaultPlan, fields)});
    if (updated != null) {
      // An open Ablauf editor takes the new template too.
      container
        ..invalidate(planAttendanceTypesProvider)
        ..invalidate(protocolTypesProvider);
    }
  } on DemoModeException {
    return;
  }
  if (!context.mounted) return;
  if (updated == null) {
    ToastHelper.showError(context, l10n.rdTypeTakeOverPlanFailed);
  } else {
    ToastHelper.showSuccess(context, l10n.rdTypeTakeOverPlanDone(type.name));
  }
}
