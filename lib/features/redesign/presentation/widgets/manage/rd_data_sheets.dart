import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/providers/player_providers.dart';
import '../../../../../core/providers/tenant_providers.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../data/models/instrument/instrument.dart';
import '../../../../../data/models/person/person.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../settings/presentation/widgets/vorkurs_certificates.dart';
import '../../../data/rd_words.dart';
import '../rd_widgets.dart';
import 'rd_settings_sheets.dart';

/// REDESIGN: "Urkunden" with the groups in a sheet (canvas board
/// "G3 Urkunden"); the PDF is made by [generateVorkursCertificates].
Future<void> rdGenerateCertificates(BuildContext context, WidgetRef ref) async {
  // Bound to the group it started in: after a group switch nothing is made.
  final tenantId = ref.read(currentTenantIdProvider);
  List<Person> people = const [];
  try {
    people = await ref.read(playersProvider.future);
  } catch (_) {}
  if (!context.mounted) return;
  await generateVorkursCertificates(
    context,
    ref,
    pickGroups: (groups) async {
      final picked = await showRdSettingsSheet<Set<int>>(
        context,
        (_) => _CertificatesSheet(groups: groups, people: people),
      );
      return ref.read(currentTenantIdProvider) == tenantId ? picked : null;
    },
  );
}

class _CertificatesSheet extends StatefulWidget {
  const _CertificatesSheet({required this.groups, required this.people});

  final List<Group> groups;
  final List<Person> people;

  @override
  State<_CertificatesSheet> createState() => _CertificatesSheetState();
}

class _CertificatesSheetState extends State<_CertificatesSheet> {
  late final Set<int> _selected = widget.groups.map((g) => g.id).whereType<int>().toSet();

  int _count(Set<int> ids) => filterCertificatePersons(widget.people, ids).length;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final total = _count(_selected);
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          RdSheetHead(title: l10n.rdDataCertificates),
          Text(l10n.rdDataCertificatesFor(rdGroupKindOf(context)), style: RdType.meta(p)),
          const SizedBox(height: 12),
          RdGroupedList(
            children: [
              for (final g in widget.groups)
                if (g.id != null)
                  RdListRow(
                    leading: Icon(
                      _selected.contains(g.id) ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: _selected.contains(g.id) ? p.primary : p.text2,
                    ),
                    title: g.name,
                    value: l10n.rdDataGroupCount(_count({g.id!})),
                    showChevron: false,
                    onTap:
                        () => setState(() {
                          if (!_selected.remove(g.id)) _selected.add(g.id!);
                        }),
                  ),
            ],
          ),
          const SizedBox(height: 16),
          RdPrimaryButton(
            label: l10n.rdDataCertificatesCreate(total),
            onPressed: _selected.isEmpty ? null : () => Navigator.of(context).pop(_selected),
          ),
        ],
      ),
    );
  }
}
