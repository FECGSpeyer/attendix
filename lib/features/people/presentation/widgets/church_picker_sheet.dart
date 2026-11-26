import 'package:flutter/material.dart';

import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../redesign/presentation/widgets/rd_widgets.dart';
import '../../../../data/models/church/church.dart';
import '../../../../l10n/l10n.dart';

/// Label of a `bfecg_church` value (Ionic person.page getChurchLabel).
String churchLabel(dynamic value, List<Church> churches) {
  if (value == null) return l10nWithoutContext.personPleaseChoose;
  if (value == '') return l10nWithoutContext.personNotListed;
  return churches.where((c) => c.id == value).firstOrNull?.name ??
      l10nWithoutContext.personPleaseChoose;
}

/// Searchable church picker with "Nicht gelistet" (Ionic person.page church
/// modal). Returns the church id, '' for "Nicht gelistet", or null when
/// closed.
Future<String?> showChurchPickerSheet(
  BuildContext context, {
  required String title,
  required List<Church> churches,
  String? selectedId,
}) {
  return showRdSheet<String>(
    context,
    RdChurchPicker(title: title, churches: churches, selectedId: selectedId),
  );
}

/// REDESIGN: Beta sheet of [showChurchPickerSheet]: search field on top,
/// "Nicht gelistet" and the churches as a grouped list, a check mark at
/// the chosen one.
class RdChurchPicker extends StatefulWidget {
  const RdChurchPicker({
    super.key,
    required this.title,
    required this.churches,
    this.selectedId,
  });

  final String title;
  final List<Church> churches;
  final String? selectedId;

  @override
  State<RdChurchPicker> createState() => _RdChurchPickerState();
}

class _RdChurchPickerState extends State<RdChurchPicker> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final term = _search.trim().toLowerCase();
    final filtered =
        term.isEmpty ? widget.churches : widget.churches.where((c) => c.name.toLowerCase().contains(term)).toList();
    Widget row(String label, String? id) => RdListRow(
          title: label,
          selected: widget.selectedId == id,
          showChevron: false,
          trailing: RdSheetCheck(widget.selectedId == id),
          onTap: () => Navigator.of(context).pop(id),
        );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RdSheetTitle(widget.title),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              textInputAction: TextInputAction.search,
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: l10n.personSearchChurch,
                prefixIcon: Icon(Icons.search, color: p.text2),
                filled: true,
                fillColor: p.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(p.buttonRadius),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                RdGroupedList(
                  children: [
                    row(l10n.personNotListed, ''),
                    for (final church in filtered) row(church.name, church.id),
                  ],
                ),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
                    child: Text(l10n.personNoChurchFound, style: RdType.meta(p, size: 14)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
