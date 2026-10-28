import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/attendance_providers.dart';
import '../../../../core/providers/church_providers.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/services/export_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../data/repositories/attendance_repository.dart';
import '../../export_fields.dart';
import '../../../../core/services/tracking/tracking_event.dart';
import '../../../../core/services/tracking/tracking_service.dart';

/// Export Page
///
/// Allows exporting player lists and attendance data to PDF or Excel.
/// Port of Ionic export.page.ts: standard fields + tenant extra fields
/// (additional_fields), custom empty columns, sorting, season-wide
/// attendance export.
class ExportPage extends ConsumerStatefulWidget {
  const ExportPage({super.key});

  @override
  ConsumerState<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends ConsumerState<ExportPage> {
  String _exportType = 'pdf';
  String _contentType = 'player';
  List<String> _selectedFields = [...defaultPlayerExportFields];
  String _sortField = 'gruppe';
  bool _sortAscending = true;
  bool _isExporting = false;

  List<ExtraField> get _extraFields =>
      ref.read(currentTenantProvider)?.additionalFields ?? const [];

  void _setContentType(String value) {
    if (value == _contentType) return;
    setState(() {
      _contentType = value;
      _sortField = 'gruppe';
      _sortAscending = true;
      _selectedFields = value == 'player'
          ? [...defaultPlayerExportFields]
          : [...defaultAttendanceExportFields];
    });
  }

  /// Ionic `ion-select multiple` "Felder": keeps the current order of the
  /// fields that stay selected, appends newly selected ones.
  Future<void> _pickFields(List<String> available) async {
    final selection = {..._selectedFields};
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Felder'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final f in available)
                  CheckboxListTile(
                    dense: true,
                    title: Text(f),
                    value: selection.contains(f),
                    onChanged: (v) => setLocal(() {
                      v == true ? selection.add(f) : selection.remove(f);
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, selection),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _selectedFields = [
        // custom (free text) columns are not part of `available` and stay
        for (final f in _selectedFields)
          if (result.contains(f) || !available.contains(f)) f,
        for (final f in available)
          if (result.contains(f) && !_selectedFields.contains(f)) f,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final tenant = ref.watch(currentTenantProvider);
    final extraFields = tenant?.additionalFields ?? const <ExtraField>[];
    final available = availableExportFields(_contentType, extraFields);
    final sortOptions = exportSortOptions(_contentType, extraFields);
    if (!sortOptions.any((o) => o.value == _sortField)) {
      _sortField = 'gruppe';
    }
    final selectedAvailable = _selectedFields.where(available.contains).join(', ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daten exportieren'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppDimensions.paddingL),
        children: [
          // Ionic `ion-segment mode="md"`: Spieler | Anwesenheit
          _ExportSegment(
            value: _contentType,
            options: const [('player', 'Spieler'), ('attendance', 'Anwesenheit')],
            onChanged: _setContentType,
          ),
          // "Felder" multi select
          ListTile(
            title: const Text('Felder'),
            trailing: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.55),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      selectedAvailable,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.medium),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: AppColors.medium),
                ],
              ),
            ),
            onTap: () => _pickFields(available),
          ),
          const Divider(height: 1),
          // Selected fields: reorder via handle, swipe left to remove (Ionic
          // ion-reorder-group + ion-item-sliding)
          SlidableAutoCloseBehavior(
            child: ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _selectedFields.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _selectedFields.removeAt(oldIndex);
                  _selectedFields.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final field = _selectedFields[index];
                return Slidable(
                  key: ValueKey('$field-$index'),
                  endActionPane: ActionPane(
                    motion: const DrawerMotion(),
                    extentRatio: 0.22,
                    children: [
                      SlidableAction(
                        onPressed: (_) => setState(() => _selectedFields.removeAt(index)),
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                        icon: Icons.delete,
                      ),
                    ],
                  ),
                  child: Material(
                    color: Theme.of(context).colorScheme.surface,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          title: Text(field),
                          subtitle: available.contains(field)
                              ? null
                              : const Text('Eigenes Feld (leer)'),
                          trailing: ReorderableDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.reorder, color: AppColors.medium),
                            ),
                          ),
                        ),
                        const Divider(height: 1, indent: 16),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontSize: 13),
                ),
                onPressed: _addCustomField,
                child: const Text('Extrafeld hinzufügen'),
              ),
            ),
          ),
          _SelectItem<String>(
            label: 'Sortieren nach',
            value: _sortField,
            options: [for (final o in sortOptions) (o.value, o.label)],
            onChanged: (v) => setState(() => _sortField = v),
          ),
          _SelectItem<bool>(
            label: 'Reihenfolge',
            value: _sortAscending,
            options: const [(true, 'Aufsteigend (A–Z)'), (false, 'Absteigend (Z–A)')],
            onChanged: (v) => setState(() => _sortAscending = v),
          ),
          _SelectItem<String>(
            label: 'Export-Typ',
            value: _exportType,
            options: const [('pdf', 'PDF'), ('excel', 'Excel')],
            onChanged: (v) => setState(() => _exportType = v),
          ),
          // Flutter hint: the PDF attendance export is limited to 8 dates
          if (_contentType == 'attendance' && _exportType == 'pdf')
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'PDF-Export ist auf die letzten 8 Termine begrenzt. Für alle Termine der Saison nutze den Excel-Export.',
                style: TextStyle(fontSize: 12, color: AppColors.medium),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: FilledButton(
              onPressed: _isExporting ? null : _export,
              child: _isExporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Exportieren'),
            ),
          ),
        ],
      ),
    );
  }

  /// Ionic addExtraField(): free text column (values stay empty)
  Future<void> _addCustomField() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Feld hinzufügen'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Spaltenname'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.isNotEmpty && mounted) {
      setState(() => _selectedFields.add(name));
    }
  }

  Future<void> _export() async {
    if (_selectedFields.isEmpty) {
      ToastHelper.showError(context, 'Bitte mindestens ein Feld auswählen');
      return;
    }

    setState(() => _isExporting = true);

    try {
      final tenant = ref.read(currentTenantProvider);
      final tenantId = ref.read(currentTenantIdProvider);
      if (tenant == null || tenantId == null) {
        throw Exception('Kein Tenant ausgewählt');
      }
      final tenantName = tenant.shortName;

      // Active (not left) players incl. paused — Ionic db.getPlayers()
      ref.invalidate(playersProvider);
      final rawPlayers = await ref.read(playersProvider.future);
      final groupsMap = await ref.read(groupsMapProvider.future);
      final players = rawPlayers
          .map((p) => p.copyWith(
                groupName:
                    p.instrument != null ? groupsMap[p.instrument] : null,
              ))
          .toList();

      final percentages =
          await ref.read(playerAttendancePercentagesProvider.future);
      final extraFields = _extraFields;
      final churchNames = <String, String>{};
      if (extraFields.any((f) => f.type == 'bfecg_church')) {
        try {
          for (final c in await ref.read(churchesProvider.future)) {
            if (c.id != null) churchNames[c.id!] = c.name;
          }
        } catch (_) {
          // Church names are optional — fall back to raw ids
        }
      }

      String valueOf(Person p, String field) => exportFieldValue(
            p,
            field,
            extraFields: extraFields,
            churchNames: churchNames,
            percentage: p.id != null ? percentages[p.id] : null,
          );

      final sortedPlayers = sortPlayersForExport(
        players,
        _sortField,
        ascending: _sortAscending,
        percentages: percentages,
      );

      final exportService = ExportService();
      final date = DateFormat('dd.MM.yyyy').format(DateTime.now());
      ref.read(trackingServiceProvider).track(TrackingEvent.reportExported, properties: {'format': _exportType == 'pdf' ? 'pdf' : 'xlsx', 'kind': _contentType == 'player' ? 'player' : 'attendance'});

      if (_contentType == 'player') {
        if (_exportType == 'pdf') {
          if (!mounted) return;
          await exportService.exportPlayerListPdf(
            context: context,
            players: sortedPlayers,
            fields: _selectedFields,
            tenantName: tenantName,
            valueOf: valueOf,
          );
        } else {
          final bytes = await exportService.exportPlayerListExcel(
            players: sortedPlayers,
            fields: _selectedFields,
            tenantName: tenantName,
            valueOf: valueOf,
          );
          await _shareExcel(bytes, '$tenantName Personenliste Stand $date');
        }
      } else {
        // All attendances of the current season up to yesterday
        // (Ionic: getAttendance(false, true) + date < today).
        final attendanceRepo = ref.read(attendanceRepositoryProvider)
          ..setTenantId(tenantId);
        final seasonStart = tenant.seasonStart != null
            ? DateTime.tryParse(tenant.seasonStart!)
            : null;
        final attendances = await attendanceRepo.getAttendances(
          since: seasonStart ?? DateTime(2020, 1, 1),
          limit: 10000,
        );
        final now = DateTime.now();
        final startOfToday = DateTime(now.year, now.month, now.day);
        final pastAttendances = attendances.where((a) {
          final d = DateTime.tryParse(a.date);
          return d != null && d.isBefore(startOfToday);
        }).toList()
          ..sort((a, b) => a.date.compareTo(b.date));

        final personAttendances = await attendanceRepo
            .getPersonAttendancesForAttendances(
                pastAttendances.map((a) => a.id).whereType<int>().toList());

        // Only attendances that actually have person entries
        final withPersons =
            personAttendances.map((pa) => pa.attendanceId).toSet();
        final relevant =
            pastAttendances.where((a) => withPersons.contains(a.id)).toList();

        if (_exportType == 'pdf') {
          if (!mounted) return;
          await exportService.exportAttendancePdf(
            context: context,
            players: sortedPlayers,
            attendances: relevant,
            personAttendances: personAttendances,
            fields: _selectedFields,
            tenantName: tenantName,
            valueOf: valueOf,
          );
        } else {
          final bytes = await exportService.exportAttendanceExcel(
            players: sortedPlayers,
            attendances: relevant,
            personAttendances: personAttendances,
            fields: _selectedFields,
            tenantName: tenantName,
            valueOf: valueOf,
          );
          await _shareExcel(bytes, '$tenantName Anwesenheit Stand $date');
        }
      }

      if (mounted) {
        ToastHelper.showSuccess(context, 'Export erfolgreich');
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Fehler beim Export: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  /// Share/download the Excel file (works on web/PWA as well)
  Future<void> _shareExcel(Uint8List bytes, String baseName) async {
    await Printing.sharePdf(bytes: bytes, filename: '$baseName.xlsx');
  }
}

/// Ionic `ion-segment mode="md"` spanning the full width.
class _ExportSegment extends StatelessWidget {
  const _ExportSegment({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final List<(String, String)> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final o in options)
          Expanded(
            child: InkWell(
              onTap: () => onChanged(o.$1),
              child: Container(
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: value == o.$1 ? AppColors.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  o.$2.toUpperCase(),
                  style: TextStyle(
                    color: value == o.$1 ? AppColors.primary : AppColors.medium,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Ionic `ion-item` with `ion-select interface="popover"`: label left,
/// current value right, popup menu on tap.
class _SelectItem<T> extends StatelessWidget {
  const _SelectItem({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final current = options.where((o) => o.$1 == value).firstOrNull?.$2 ?? '';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PopupMenuButton<T>(
          initialValue: value,
          onSelected: onChanged,
          itemBuilder: (_) => [
            for (final o in options) PopupMenuItem<T>(value: o.$1, child: Text(o.$2)),
          ],
          child: ListTile(
            title: Text(label),
            trailing: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      current,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.medium),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: AppColors.medium),
                ],
              ),
            ),
          ),
        ),
        const Divider(height: 1, indent: 16),
      ],
    );
  }
}
