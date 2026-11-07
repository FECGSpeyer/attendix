import 'package:flutter/material.dart';

import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../core/utils/choir_file_utils.dart';
import '../../../../../data/models/instrument/instrument.dart';
import '../../../../../l10n/l10n.dart';
import '../manage/rd_settings_sheets.dart';
import '../rd_widgets.dart';

/// REDESIGN: "Für wen ist die Datei?" (canvas "Beta: Gruppe und Daten",
/// board "Datei-Dialoge im Werk"). Same options and result as the old
/// `FileCategoryDialog`, as a sheet with grouped choices: "Chor (alle)"
/// (choirs), the parts, then Aufnahme, Liedtext and "Sonstige (Freitext)";
/// the free text appears only with "Sonstige". "Fertig" returns the choice
/// (via [resolveFileCategoryOption]), "Abbrechen" null.
Future<({int? instrumentId, String? note})?> showRdFileCategorySheet(
  BuildContext context, {
  required String title,
  required List<Group> instruments,
  required bool isChoir,
  required int? initialInstrumentId,
  required String initialNote,
}) {
  return showRdSettingsSheet<({int? instrumentId, String? note})>(
    context,
    (_) => _FileCategorySheet(
      title: title,
      instruments: instruments,
      isChoir: isChoir,
      initialInstrumentId: initialInstrumentId,
      initialNote: initialNote,
    ),
  );
}

class _FileCategorySheet extends StatefulWidget {
  const _FileCategorySheet({
    required this.title,
    required this.instruments,
    required this.isChoir,
    required this.initialInstrumentId,
    required this.initialNote,
  });

  final String title;
  final List<Group> instruments;
  final bool isChoir;
  final int? initialInstrumentId;
  final String initialNote;

  @override
  State<_FileCategorySheet> createState() => _FileCategorySheetState();
}

class _FileCategorySheetState extends State<_FileCategorySheet> {
  late int? _id = widget.initialInstrumentId;
  late final _note = TextEditingController(text: widget.initialNote);

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _done() => Navigator.of(context).pop(resolveFileCategoryOption(_id, _note.text.trim()));

  Widget _row(int? value, String label, {String? subtitle}) {
    final selected = _id == value;
    return RdListRow(
      key: ValueKey('rd-file-category-${value ?? 'other'}'),
      title: label,
      subtitle: subtitle,
      selected: selected,
      showChevron: false,
      trailing: RdSheetCheck(selected),
      onTap: () => setState(() => _id = value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            RdSheetHead(title: widget.title, onDone: _done),
            if (widget.isChoir) ...[
              RdGroupedList(
                children: [_row(kChoirAllOptionValue, l10n.songsChoirAll, subtitle: l10n.songsChoirAllHint)],
              ),
              const SizedBox(height: 18),
            ],
            if (widget.instruments.isNotEmpty) ...[
              RdGroupLabel(widget.isChoir ? l10n.coreFlutterVoices : l10n.planningGroups),
              RdGroupedList(children: [for (final g in widget.instruments) _row(g.id, g.name)]),
              const SizedBox(height: 18),
            ],
            RdGroupLabel(l10n.commonOther),
            RdGroupedList(
              children: [_row(1, l10n.songsRecording), _row(2, l10n.songsLyrics), _row(null, l10n.songsOtherFreeText)],
            ),
            if (_id == null) ...[
              const SizedBox(height: 12),
              RdCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: TextField(
                  key: const Key('rd-file-category-note'),
                  controller: _note,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _done(),
                  decoration: InputDecoration(
                    hintText: l10n.songsEnterCategory,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                  ),
                  style: RdType.body(p),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
