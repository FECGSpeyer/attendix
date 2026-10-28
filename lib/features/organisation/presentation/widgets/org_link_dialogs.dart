import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/organisation/organisation.dart';

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
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Organisation auswählen'),
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
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.of(ctx).pop('choose'), child: const Text('Auswählen')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('create'),
            child: const Text('Neue Organisation erstellen'),
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
      ToastHelper.showWarning(context, 'Bitte wähle eine Organisation aus.');
      return;
    }
    final ok = await ref.read(organisationNotifierProvider.notifier).linkCurrentTenant(selected!);
    if (!context.mounted) return;
    ok
        ? ToastHelper.showSuccess(context, 'Die Organisation wurde erfolgreich ausgewählt.')
        : ToastHelper.showError(context, 'Fehler beim Verknüpfen');
  }
}

/// Ionic org-settings `openCreateOrganisationAlert()`.
Future<void> showCreateOrganisationDialog(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  try {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Organisation erstellen'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Name eingeben...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Hinzufügen')),
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
        ? ToastHelper.showSuccess(context, 'Die Organisation wurde erfolgreich erstellt.')
        : ToastHelper.showError(context, 'Fehler beim Erstellen der Organisation');
  } finally {
    controller.dispose();
  }
}
