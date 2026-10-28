import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/services/certificate_service.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/models/person/person.dart';

/// Persons that receive a certificate: active (not left/paused/pending)
/// members of the selected groups (Ionic settings.page filter).
List<Person> filterCertificatePersons(List<Person> persons, Set<int> groupIds) {
  return persons
      .where((p) =>
          (p.left == null || p.left!.isEmpty) &&
          !p.paused &&
          !p.pending &&
          p.instrument != null &&
          groupIds.contains(p.instrument))
      .toList();
}

/// "Urkunden generieren" (Ionic settings.page generateVorkursCertificates):
/// choose groups, then create one multi-page PDF and share/download it.
Future<void> generateVorkursCertificates(BuildContext context, WidgetRef ref) async {
  final groups = await ref.read(groupsProvider.future);
  if (!context.mounted) return;
  final selected = await showDialog<Set<int>>(
    context: context,
    builder: (_) => _GroupSelectDialog(groups: groups),
  );
  if (selected == null || !context.mounted) return;
  if (selected.isEmpty) {
    ToastHelper.showWarning(context, 'Bitte mindestens eine Gruppe auswählen.');
    return;
  }

  ToastHelper.showInfo(context, 'Urkunden werden erstellt...');
  try {
    ref.invalidate(playersProvider);
    final persons = filterCertificatePersons(await ref.read(playersProvider.future), selected);
    if (persons.isEmpty) {
      if (context.mounted) {
        ToastHelper.showWarning(context, 'Keine Personen in den gewählten Gruppen gefunden.');
      }
      return;
    }
    final bytes = await const CertificateService().buildVorkursCertificates(
      persons.map((p) => (firstName: p.firstName, lastName: p.lastName)).toList(),
    );
    final fileName = 'Urkunden_Vorkurs_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf';
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  } catch (_) {
    if (context.mounted) ToastHelper.showError(context, 'Fehler beim Erstellen der Urkunden.');
  }
}

class _GroupSelectDialog extends StatefulWidget {
  const _GroupSelectDialog({required this.groups});

  final List<Group> groups;

  @override
  State<_GroupSelectDialog> createState() => _GroupSelectDialogState();
}

class _GroupSelectDialogState extends State<_GroupSelectDialog> {
  late final Set<int> _selected = widget.groups.map((g) => g.id).whereType<int>().toSet();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Gruppen auswählen'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Für welche Gruppen sollen Urkunden erstellt werden?'),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final g in widget.groups)
                    if (g.id != null)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: _selected.contains(g.id),
                        title: Text(g.name),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selected.add(g.id!);
                          } else {
                            _selected.remove(g.id);
                          }
                        }),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('Generieren'),
        ),
      ],
    );
  }
}
