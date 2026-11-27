import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/shift_providers.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/shift/shift_plan.dart';
import '../../../../l10n/l10n.dart';
import '../../../redesign/presentation/widgets/manage/rd_settings_sheets.dart';
import '../../../../shared/widgets/redesign/rd_widgets.dart';

/// Opens the "Neuer Schichtplan" sheet, creates the plan, and navigates to its
/// detail page.
Future<void> showCreateShiftPlanSheet(BuildContext context, WidgetRef ref) async {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();

  try {
    final result = await showRdSettingsSheet<Map<String, String>?>(
      context,
      (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RdSheetTitle(sheetContext.l10n.shiftsCreate),
            TextField(
              controller: nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: sheetContext.l10n.typeSettingsName,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: sheetContext.l10n.tasksDescription,
              ),
            ),
            const SizedBox(height: 16),
            RdPrimaryButton(
              label: sheetContext.l10n.filesCreate,
              onPressed: () => Navigator.pop(sheetContext, {
                'name': nameController.text,
                'description': descriptionController.text,
              }),
            ),
          ],
        ),
      ),
    );

    if (result == null || !context.mounted) return;
    final name = result['name']?.trim() ?? '';
    if (name.isEmpty) {
      ToastHelper.showError(context, context.l10n.shiftsEnterName);
      return;
    }
    await _createShift(context, ref, name, result['description']?.trim() ?? '');
  } finally {
    nameController.dispose();
    descriptionController.dispose();
  }
}

Future<void> _createShift(
  BuildContext context,
  WidgetRef ref,
  String name,
  String description,
) async {
  final notifier = ref.read(shiftNotifierProvider.notifier);
  final plan = ShiftPlan(name: name, description: description);
  final result = await notifier.createShift(plan);

  if (context.mounted) {
    if (result != null) {
      ToastHelper.showSuccess(context, context.l10n.shiftsFlutterCreated(name));
      if (result.id != null) {
        context.push('/settings/shifts/${result.id}');
      }
    } else {
      final error = ref.read(shiftNotifierProvider);
      if (error.hasError) {
        ToastHelper.showError(
          context,
          context.l10n.shiftsFlutterCreateFailed(friendlyErrorMessage(error.error)),
        );
      }
    }
  }
}
