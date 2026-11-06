import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/organisation/organisation.dart';
import '../../../../data/repositories/base_repository.dart' show RepositoryException;
import '../../../../data/repositories/organisation_repository.dart' show OrganisationRepository;
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';

/// UX_SETTINGS: Ionic org-settings `openOrganisationAlert()`.
///
/// With existing organisations of the user: radio list "Organisation
/// auswählen" (Abbrechen / Auswählen / Neue Organisation erstellen);
/// otherwise directly "Organisation erstellen".
///
/// Ionic OrganisationService.getOrganisationsFromUser: a load error shows a
/// danger toast („Fehler beim Laden der Mandanten“ for the own instances,
/// „Fehler beim Laden der Organisationen“ for the links) and opens no dialog,
/// so the admin is not led to create a duplicate organisation.
/// Returns whether the group that was current when called is still the
/// current one; the dialogs write nothing after a group switch.
bool Function() bindCurrentTenant(BuildContext context) {
  final container = ProviderScope.containerOf(context, listen: false);
  final tenantId = container.read(currentTenantIdProvider);
  return () => tenantId != null && container.read(currentTenantIdProvider) == tenantId;
}

Future<void> showOrganisationLinkDialog(BuildContext context, WidgetRef ref) async {
  final stillCurrent = bindCurrentTenant(context);
  final notifier = ref.read(organisationNotifierProvider.notifier);
  List<Organisation> organisations;
  try {
    organisations = await ref.read(userOrganisationsProvider.future);
  } catch (e) {
    if (!context.mounted) return;
    final tenantsFailed =
        e is RepositoryException && e.operation == OrganisationRepository.opLoadUserOrgTenants;
    ToastHelper.showError(
      context,
      tenantsFailed ? context.l10n.dbLoadTenantsFailed2 : context.l10n.svcLoadOrgsFailed,
    );
    return;
  }
  if (!context.mounted) return;

  if (organisations.isEmpty) {
    await showCreateOrganisationDialog(context, ref, stillCurrent: stillCurrent);
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

  if (!stillCurrent()) return;
  if (result == 'create') {
    await showCreateOrganisationDialog(context, ref, stillCurrent: stillCurrent);
  } else if (result == 'choose') {
    if (selected == null) {
      ToastHelper.showWarning(context, context.l10n.orgPleaseSelect);
      return;
    }
    final ok = await notifier.linkCurrentTenant(selected!);
    if (!context.mounted) return;
    ok
        ? ToastHelper.showSuccess(context, context.l10n.orgSelected)
        // Ionic OrganisationService.linkTenantToOrganisation toast.
        : ToastHelper.showError(context, context.l10n.svcLinkOrgFailed);
  }
}

/// Ionic org-settings `openCreateOrganisationAlert()`: an empty name shows
/// „Bitte gib gültige Werte ein.“ in the alert, which stays open; creating
/// runs behind a blocking spinner (Ionic getLoadingElement).
Future<void> showCreateOrganisationDialog(
  BuildContext context,
  WidgetRef ref, {
  bool Function()? stillCurrent,
}) async {
  final isCurrent = stillCurrent ?? bindCurrentTenant(context);
  final controller = TextEditingController();
  String? error;
  try {
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppAlertDialog(
          title: Text(context.l10n.orgCreate),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(error!)),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(hintText: context.l10n.orgNamePh),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(context.l10n.commonCancel)),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isEmpty) {
                  setDialogState(() => error = context.l10n.adminInvalidValues);
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              child: Text(context.l10n.attendanceAdd),
            ),
          ],
        ),
      ),
    );
    final name = controller.text.trim();
    if (ok != true || name.isEmpty || !context.mounted || !isCurrent()) return;
    final notifier = ref.read(organisationNotifierProvider.notifier);
    final navigator = Navigator.of(context, rootNavigator: true);
    showAppDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(canPop: false, child: Center(child: AppSpinner())),
    );
    Organisation? org;
    var linked = false;
    try {
      org = await notifier.create(name);
      // Ionic db.createOrganisation links the instance right away; a failed
      // link ends with 'Fehler beim Verknüpfen der Organisation', not success.
      // Group switched while creating: the new organisation stays unlinked.
      linked = org?.id != null && isCurrent() && await notifier.linkCurrentTenant(org!.id!);
    } finally {
      navigator.pop();
    }
    if (!context.mounted) return;
    if (org == null) {
      ToastHelper.showError(context, context.l10n.svcCreateOrgFailed);
    } else if (!linked) {
      ToastHelper.showError(context, context.l10n.svcLinkOrgFailed);
    } else {
      ToastHelper.showSuccess(context, context.l10n.orgCreated);
    }
  } finally {
    controller.dispose();
  }
}
