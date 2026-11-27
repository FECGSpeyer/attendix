import 'package:flutter/material.dart';

import '../../../../data/models/plan/plan.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import 'plan_widgets.dart';

/// Values entered in a plan field dialog.
class PlanFieldInput {
  const PlanFieldInput({
    required this.name,
    this.conductor = '',
    this.info,
    this.minutes,
    this.needsBeamer,
  });

  final String name;
  final String conductor;
  final String? info;
  final int? minutes;
  final bool? needsBeamer;
}

/// Beamer options of the plan field sheet.
class PlanFieldBeamerOptions {
  const PlanFieldBeamerOptions({this.manual, this.songId, this.file});

  final bool? manual;
  final int? songId;
  final BeamerFile? file;
}

/// Opens the plan field sheet. Returns null when cancelled.
Future<PlanFieldInput?> showPlanFieldDialog(
  BuildContext context, {
  required String title,
  String? subtitle,
  String? message,
  String? nameLabel,
  String? nameHint,
  String? conductorLabel,
  String? conductorHint,
  String? infoHint,
  String? confirmText,
  String? emptyNameMessage,
  String? initialName,
  String? initialConductor,
  String? initialInfo,
  int? initialMinutes,
  bool withConductor = true,
  bool withInfo = true,
  bool withMinutes = true,
  bool requireName = true,
  VoidCallback? onDelete,
  PlanFieldBeamerOptions? beamer,
}) {
  return showRdPlanFieldSheet(
    context,
    title: title,
    subtitle: subtitle,
    message: message,
    nameLabel: nameLabel,
    nameHint: nameHint,
    conductorLabel: conductorLabel,
    conductorHint: conductorHint,
    infoHint: infoHint,
    confirmText: confirmText,
    emptyNameMessage: emptyNameMessage,
    initialName: initialName,
    initialConductor: initialConductor,
    initialInfo: initialInfo,
    initialMinutes: initialMinutes,
    withConductor: withConductor,
    withInfo: withInfo,
    withMinutes: withMinutes,
    requireName: requireName,
    onDelete: onDelete,
    beamer: beamer,
  );
}

/// Simple text prompt sheet (rename etc.).
Future<String?> showPlanTextPrompt(
  BuildContext context, {
  required String title,
  String? message,
  String? initialValue,
  String? hint,
  String? confirmText,
  bool allowEmpty = false,
  String? emptyMessage,
}) {
  return showRdPlanTextSheet(
    context,
    title: title,
    message: message,
    initialValue: initialValue,
    hint: hint,
    confirmText: confirmText,
    allowEmpty: allowEmpty,
    emptyMessage: emptyMessage,
  );
}

/// Confirm dialog returning true on confirm.
Future<bool> showPlanConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmText,
  bool destructive = false,
}) async {
  final result = await showAppDialog<bool>(
    context: context,
    builder: (ctx) => AppAlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(ctx.l10n.commonCancel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmText ?? ctx.l10n.commonOk),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Action sheet entry.
class PlanSheetAction<T> {
  const PlanSheetAction(
    this.value,
    this.label, {
    this.icon,
    this.destructive = false,
  });

  final T value;
  final String label;
  final IconData? icon;
  final bool destructive;
}

/// Bottom sheet with plan actions.
Future<T?> showPlanActionSheet<T>(
  BuildContext context, {
  String? title,
  String? subtitle,
  required List<PlanSheetAction<T>> actions,
  bool cancelDestructive = false,
}) {
  return showRdPlanActionSheet<T>(
    context,
    title: title,
    subtitle: subtitle,
    actions: actions,
  );
}

/// Opens the edit-field sheet with standard edit labels.
Future<PlanFieldInput?> showPlanFieldEditModal(
  BuildContext context, {
  String? initialName,
  String? initialConductor,
  String? initialInfo,
  int? initialMinutes,
  PlanFieldBeamerOptions? beamer,
}) {
  final l10n = context.l10n;
  return showPlanFieldDialog(
    context,
    title: l10n.planningEditField,
    nameLabel: l10n.planningItem,
    nameHint: l10n.planningEnterItem,
    infoHint: l10n.planningInfoOptionalEllipsis,
    confirmText: l10n.planningUpdate,
    initialName: initialName,
    initialConductor: initialConductor,
    initialInfo: initialInfo,
    initialMinutes: initialMinutes,
    beamer: beamer,
  );
}
