import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/organisation/organisation.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

/// UX_SETTINGS: Ionic org-settings `openOrganisationAlert()`.
///
/// With existing organisations of the user: radio list "Organisation
/// auswählen" (Abbrechen / Auswählen / Neue Organisation erstellen);
/// otherwise directly "Organisation erstellen".
Future<void> showOrganisationLinkDialog(BuildContext context, WidgetRef ref) async {
  List<Organisation> organisations;
  try {
    organisations = await ref.read(userOrganisationsProvider.future);
  } catch (_) {
    organisations = const [];
  }
  if (!context.mounted) return;

  if (organisations.isEmpty) {
    await showCreateOrganisationDialog(context, ref);
    return;
  }

  int? selected = organisations.first.id;
  final result = await showAppDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AppAlertDialog(
        title: Text(context.l10n.orgSelect),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final org in organisations)
                RadioListTile<int?>(
                  contentPadding: EdgeInsets.zero,
                  value: org.id,
                  groupValue: selected,
                  title: Text(org.name),
                  onChanged: (v) => setState(() => selected = v),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(context.l10n.commonCancel)),
          TextButton(onPressed: () => Navigator.of(ctx).pop('choose'), child: Text(context.l10n.orgChoose)),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('create'),
            child: Text(context.l10n.orgCreateNew),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted) return;

  if (result == 'create') {
    await showCreateOrganisationDialog(context, ref);
  } else if (result == 'choose') {
    if (selected == null) {
      ToastHelper.showWarning(context, context.l10n.orgPleaseSelect);
      return;
    }
    final ok = await ref.read(organisationNotifierProvider.notifier).linkCurrentTenant(selected!);
    if (!context.mounted) return;
    ok
        ? ToastHelper.showSuccess(context, context.l10n.orgSelected)
        : ToastHelper.showError(context, context.l10n.linkPersonsFailed);
  }
}

/// Ionic org-settings `openCreateOrganisationAlert()`.
Future<void> showCreateOrganisationDialog(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  try {
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(context.l10n.orgCreate),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: context.l10n.orgNamePh),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(context.l10n.commonCancel)),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(context.l10n.attendanceAdd)),
        ],
      ),
    );
    final name = controller.text.trim();
    if (ok != true || name.isEmpty || !context.mounted) return;
    final notifier = ref.read(organisationNotifierProvider.notifier);
    final org = await notifier.create(name);
    if (org?.id != null) await notifier.linkCurrentTenant(org!.id!);
    if (!context.mounted) return;
    org != null
        ? ToastHelper.showSuccess(context, context.l10n.orgCreated)
        : ToastHelper.showError(context, context.l10n.svcCreateOrgFailed);
  } finally {
    controller.dispose();
  }
}
