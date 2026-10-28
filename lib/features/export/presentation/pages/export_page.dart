import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
  Widget build(BuildContext context) {
    final tenant = ref.watch(currentTenantProvider);
    final extraFields = tenant?.additionalFields ?? const <ExtraField>[];
    final available = availableExportFields(_contentType, extraFields);
    final sortOptions = exportSortOptions(_contentType, extraFields);
    if (!sortOptions.any((o) => o.value == _sortField)) {
      _sortField = 'gruppe';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Export'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Content type selector
            _buildSection(
              title: 'Inhalt',
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'player', label: Text('Personen')),
                  ButtonSegment(value: 'attendance', label: Text('Anwesenheit')),
                ],
                selected: {_contentType},
                onSelectionChanged: (value) {
                  setState(() {
                    _contentType = value.first;
                    _sortField = 'gruppe';
                    _sortAscending = true;
                    _selectedFields = value.first == 'player'
                        ? [...defaultPlayerExportFields]
                        : [...defaultAttendanceExportFields];
                  });
                },
              ),
            ),
            const SizedBox(height: AppDimensions.paddingL),

            // Field selection
            _buildSection(
              title: 'Felder',
              child: Column(
                children: [
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
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
                      return Card(
                        key: ValueKey('$field-$index'),
                        margin: const EdgeInsets.only(bottom: 4),
                        child: ListTile(
                          leading: const Icon(Icons.drag_handle),
                          title: Text(field),
                          subtitle: available.contains(field)
                              ? null
                              : const Text('Eigenes Feld (leer)'),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () {
                              setState(() => _selectedFields.removeAt(index));
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: PopupMenuButton<String>(
                          onSelected: (field) {
                            setState(() {
                              if (!_selectedFields.contains(field)) {
                                _selectedFields.add(field);
                              }
                            });
                          },
                          itemBuilder: (context) => available
                              .where((f) => !_selectedFields.contains(f))
                              .map((f) => PopupMenuItem(
                                    value: f,
                                    child: Text(f),
                                  ))
                              .toList(),
                          child: _outlinedButtonLike(
                              Icons.add, 'Feld hinzufügen'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: _addCustomField,
                          borderRadius: BorderRadius.circular(8),
                          child: _outlinedButtonLike(
                              Icons.edit_note, 'Eigenes Feld'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.paddingL),

            // Sorting
            _buildSection(
              title: 'Sortierung',
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      value: _sortField,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Sortieren nach',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: sortOptions
                          .map((o) => DropdownMenuItem(
                                value: o.value,
                                child: Text(o.label,
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _sortField = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<bool>(
                      value: _sortAscending,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Reihenfolge',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: true, child: Text('Aufsteigend')),
                        DropdownMenuItem(value: false, child: Text('Absteigend')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _sortAscending = v);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.paddingL),

            // Export type selector
            _buildSection(
              title: 'Format',
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'pdf', label: Text('PDF')),
                  ButtonSegment(value: 'excel', label: Text('Excel')),
                ],
                selected: {_exportType},
                onSelectionChanged: (value) {
                  setState(() => _exportType = value.first);
                },
              ),
            ),
            const SizedBox(height: AppDimensions.paddingXL),

            // PDF limit hint for attendance export
            if (_contentType == 'attendance' && _exportType == 'pdf')
              Padding(
                padding: const EdgeInsets.only(bottom: AppDimensions.paddingM),
                child: Card(
                  color: AppColors.info.withAlpha(26),
                  child: const Padding(
                    padding: EdgeInsets.all(AppDimensions.paddingS),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: AppColors.info),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'PDF-Export ist auf die letzten 8 Termine begrenzt. Für alle Termine der Saison nutze den Excel-Export.',
                            style: TextStyle(fontSize: 12, color: AppColors.info),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isExporting ? null : _export,
                icon: _isExporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(_exportType == 'pdf'
                        ? Icons.picture_as_pdf
                        : Icons.table_chart),
                label: Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingM),
                  child: Text(_isExporting ? 'Exportiere...' : 'Exportieren'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _outlinedButtonLike(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.medium),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.medium,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
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
