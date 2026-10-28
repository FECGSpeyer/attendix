import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/duty_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/duty_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

/// Shared UI actions of the Dienstplan (confirm / decline / take).

Color dutyFillColor(DutyFill fill) {
  switch (fill) {
    case DutyFill.full:
      return AppColors.success;
    case DutyFill.open:
      return AppColors.danger;
    case DutyFill.partial:
    case DutyFill.requested:
      return AppColors.warning;
  }
}

/// "1/2" (+ " ?" when some are unconfirmed) plus color for duty Termine.
({String text, Color color}) dutyBadge(DutyTermin t) {
  final fill = dutyFill(t.persons, t.required);
  return (
    text: '${t.occupied}/${t.required}${fill == DutyFill.requested ? ' ?' : ''}',
    color: dutyFillColor(fill),
  );
}

/// First names of the persons on duty, "(angefragt)" for unconfirmed ones.
String dutyNames(DutyTermin t) {
  final names = t.persons.where(occupiesDuty).map((p) {
    final name = p.firstName ?? '';
    return p.dutyState == DutyState.requested ? l10nWithoutContext.dutyFlutterNameRequested(name) : name;
  }).toList();
  return names.isNotEmpty ? names.join(', ') : l10nWithoutContext.dutyFlutterNobodyAssigned;
}

/// Small colored pill used for duty badges.
class DutyPill extends StatelessWidget {
  const DutyPill({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

Future<void> confirmDutyAction(
  BuildContext context,
  WidgetRef ref,
  String personAttendanceId,
  int attendanceId,
) async {
  final ok = await ref.read(dutyNotifierProvider.notifier).confirm(personAttendanceId, attendanceId);
  if (!context.mounted) return;
  if (ok) {
    ToastHelper.showSuccess(context, context.l10n.signoutDutyConfirmed);
  } else {
    ToastHelper.showError(context, context.l10n.svcConfirmFailed);
  }
}

/// "Kann nicht": asks for an optional reason, cancels and informs the team.
Future<bool> declineDutyAction(
  BuildContext context,
  WidgetRef ref,
  String personAttendanceId,
  int attendanceId,
) async {
  final controller = TextEditingController();
  final reason = await showAppDialog<String>(
    context: context,
    builder: (ctx) => AppAlertDialog(
      title: Text(context.l10n.signoutCannot),
      content: TextField(
        controller: controller,
        maxLines: 3,
        decoration: InputDecoration(hintText: context.l10n.dutyReasonOptional),
        autofocus: true,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(context.l10n.commonCancel)),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
          child: Text(context.l10n.commonConfirm),
        ),
      ],
    ),
  );
  controller.dispose();
  if (reason == null) return false;
  final ok = await ref.read(dutyNotifierProvider.notifier).decline(personAttendanceId, attendanceId, reason);
  if (!context.mounted) return ok;
  if (ok) {
    ToastHelper.showSuccess(context, context.l10n.dutyDeclinedToast);
  } else {
    ToastHelper.showError(context, context.l10n.dutyFlutterDeclineFailed);
  }
  return ok;
}

/// "Ich übernehme"
Future<void> takeDutyAction(BuildContext context, WidgetRef ref, int attendanceId) async {
  final result = await ref.read(dutyNotifierProvider.notifier).take(attendanceId);
  if (!context.mounted) return;
  switch (result) {
    case DutyTakeResult.ok:
      ToastHelper.showSuccess(context, context.l10n.signoutDutySignedUp);
    case DutyTakeResult.full:
      ToastHelper.showWarning(context, context.l10n.signoutDutyFull);
    case null:
      ToastHelper.showError(context, context.l10n.svcSignUpFailed);
    default:
      ToastHelper.showWarning(context, context.l10n.signoutDutyNotAllowed);
  }
}
