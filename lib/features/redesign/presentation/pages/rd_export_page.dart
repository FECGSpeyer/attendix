import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/profile_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../l10n/l10n.dart';
import '../../../export/export_fields.dart';
import '../../../export/presentation/pages/export_page.dart';
import '../../data/rd_manage_logic.dart' show RdManageArea;
import '../widgets/manage/rd_settings_sheets.dart';
import '../widgets/rd_widgets.dart';
import 'rd_handover_page.dart' show RdStepButton;

/// REDESIGN: Verwaltung › Auswertung & Daten › Export (canvas "Beta: Gruppe
/// und Daten", board "G3 Export"). Its own page with three questions: what,
/// which columns, which format. Columns and their order in one sheet; the
/// button stays visible at the bottom. Same export as the old page
/// ([ExportLogic]).
class RdExportPage extends ConsumerStatefulWidget {
  const RdExportPage({super.key});

  @override
  ConsumerState<RdExportPage> createState() => _RdExportPageState();
}

class _RdExportPageState extends ConsumerState<RdExportPage> with ExportLogic {
  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RedesignRoutes.manageArea(RdManageArea.data.key));
    }
  }

  Future<void> _editColumns(List<String> available) async {
    final result = await showRdSettingsSheet<List<String>>(
      context,
      (_) => _ColumnsSheet(selected: selectedFields, available: available),
    );
    if (result != null && mounted) setState(() => selectedFields = result);
  }

  Future<void> _pickSort(List<ExportSortOption> options) async {
    final l10n = context.l10n;
    final picked = await showRdChoiceSheet<String>(
      context,
      title: l10n.rdDataSort,
      selected: sortField,
      options: [for (final o in options) (o.value, o.label)],
    );
    if (picked != null && mounted) setState(() => sortField = picked);
  }

  String _fileName() {
    final l10n = context.l10n;
    final name = ref.watch(currentTenantProvider)?.shortName ?? '';
    final date = DateFormat(dateFmt()).format(DateTime.now());
    if (exportType == 'pdf')
      return '${name}_${contentType == 'player' ? l10n.exportPlayers : l10n.exportAttendance}.pdf';
    return contentType == 'player'
        ? '${l10n.exportPlayerListFile(name, date)}.xlsx'
        : '${l10n.exportAttendanceFileAsOf(name, date)}.xlsx';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    // Columns may name extra fields of one group: a group switch starts
    // with the default columns again.
    ref.listen(currentTenantIdProvider, (prev, next) {
      if (prev == next) return;
      setState(() {
        sortField = 'gruppe';
        sortAscending = true;
        selectedFields = contentType == 'player' ? [...defaultPlayerExportFields] : [...defaultAttendanceExportFields];
      });
    });
    final extraFields = ref.watch(personListExtraFieldsProvider);
    final available = availableExportFields(contentType, extraFields);
    final sortOptions = exportSortOptions(contentType, extraFields);
    if (!sortOptions.any((o) => o.value == sortField)) sortField = 'gruppe';
    final sortLabel = sortOptions.where((o) => o.value == sortField).map((o) => o.label).firstOrNull ?? '';
    final columns = selectedFields.map((f) => exportFieldLabel(f, l10n)).join(', ');

    return RdPage(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: RdStepButton(
        label: l10n.exportExport,
        loading: isExporting,
        onPressed: isExporting ? null : runExport,
      ),
      children: [
        RdBackLink(label: l10n.rdDataBack, onTap: _back),
        const SizedBox(height: 4),
        Semantics(header: true, child: Text(l10n.rdDataExportTitle, style: RdType.largeTitle(p))),
        const SizedBox(height: 18),
        RdGroupLabel(l10n.rdDataWhat),
        RdSegmented<String>(
          values: const ['player', 'attendance'],
          selected: contentType,
          labelOf: (v) => v == 'player' ? l10n.rdDataMembers : l10n.rdDataAttendance,
          onChanged: setContentType,
        ),
        const SizedBox(height: 24),
        RdGroupLabel(l10n.rdDataColumns),
        RdGroupedList(
          children: [
            RdListRow(
              title: columns.isEmpty ? '–' : columns,
              value: l10n.rdDataColumnsCount(selectedFields.length),
              onTap: () => _editColumns(available),
            ),
            RdListRow(title: l10n.rdDataSort, value: sortLabel, onTap: () => _pickSort(sortOptions)),
            RdListRow(
              title: l10n.exportOrder,
              value: sortAscending ? l10n.exportAsc : l10n.exportDesc,
              onTap: () => setState(() => sortAscending = !sortAscending),
              showChevron: false,
            ),
          ],
        ),
        const SizedBox(height: 24),
        RdGroupLabel(l10n.rdDataFormat),
        RdSegmented<String>(
          values: const ['excel', 'pdf'],
          selected: exportType,
          labelOf: (v) => v == 'pdf' ? 'PDF' : 'Excel',
          onChanged: (v) => setState(() => exportType = v),
        ),
        const SizedBox(height: 8),
        RdListNote(l10n.rdDataFile(_fileName())),
        if (contentType == 'attendance' && exportType == 'pdf') RdListNote(l10n.exportFlutterPdfLimitHint),
      ],
    );
  }
}

/// Columns of the export: chosen ones to sort or remove, the others to add,
/// plus an own (empty) column.
class _ColumnsSheet extends StatefulWidget {
  const _ColumnsSheet({required this.selected, required this.available});

  final List<String> selected;
  final List<String> available;

  @override
  State<_ColumnsSheet> createState() => _ColumnsSheetState();
}

class _ColumnsSheetState extends State<_ColumnsSheet> {
  late final List<String> _cols = [...widget.selected];

  Future<void> _addOwn() async {
    final l10n = context.l10n;
    final name = await showRdTextSheet(
      context,
      title: l10n.rdDataAddOwn,
      hint: l10n.exportFlutterColumnName,
      required: true,
    );
    if (name != null && name.trim().isNotEmpty && mounted) setState(() => _cols.add(name.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final rest = widget.available.where((f) => !_cols.contains(f)).toList();
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          RdSheetHead(title: l10n.rdDataColumns, onDone: () => Navigator.of(context).pop(_cols)),
          if (_cols.isNotEmpty)
            RdCard(
              padding: EdgeInsets.zero,
              child: ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorderItem: (oldIndex, newIndex) => setState(() => _cols.insert(newIndex, _cols.removeAt(oldIndex))),
                children: [
                  for (var i = 0; i < _cols.length; i++)
                    Row(
                      key: ValueKey('rd-col-${_cols[i]}-$i'),
                      children: [
                        ReorderableDragStartListener(
                          index: i,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Icon(Icons.drag_handle, color: p.text2),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(exportFieldLabel(_cols[i], l10n), style: RdType.body(p)),
                              if (!widget.available.contains(_cols[i]))
                                Text(l10n.rdDataOwnEmpty, style: RdType.meta(p)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.remove_circle_outline, color: p.absent),
                          tooltip: l10n.commonDelete,
                          onPressed: () => setState(() => _cols.removeAt(i)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          RdGroupLabel(l10n.rdDataAddColumn),
          RdGroupedList(
            children: [
              for (final f in rest)
                RdListRow(
                  leading: Icon(Icons.add_circle_outline, color: p.primary),
                  title: exportFieldLabel(f, l10n),
                  showChevron: false,
                  onTap: () => setState(() => _cols.add(f)),
                ),
              RdListRow(title: l10n.rdDataAddOwn, titleColor: p.primary, showChevron: false, onTap: _addOwn),
            ],
          ),
          RdListNote(l10n.rdDataColumnsHint),
        ],
      ),
    );
  }
}
