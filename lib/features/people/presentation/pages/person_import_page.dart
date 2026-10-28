import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/import_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/import_file_io.dart';
import '../../../../core/utils/import_mapper.dart';
import '../../../../core/utils/spreadsheet_reader.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../core/providers/user_registration_providers.dart'; // AUTH
import '../widgets/import_widgets.dart';

enum _Step { file, mapping, preview }

/// Import persons from an Excel/CSV file (Ionic people/import).
///
/// Returns `true` via Navigator.pop when at least one person was imported.
class PersonImportPage extends ConsumerStatefulWidget {
  const PersonImportPage({super.key});

  @override
  ConsumerState<PersonImportPage> createState() => _PersonImportPageState();
}

class _PersonImportPageState extends ConsumerState<PersonImportPage> {
  _Step _step = _Step.file;
  String _fileName = '';
  List<String> _headers = [];
  List<Map<String, dynamic>> _rawRows = [];
  ColumnMapping _mapping = {};
  List<ImportTargetOption> _options = [];
  List<MappedPersonRow> _mappedRows = [];
  PersonMapContext _ctx = const PersonMapContext(groups: []);
  bool _createAccounts = false;
  bool _busy = false;
  String _progress = '';

  List<Group> get _groups => ref.read(groupsProvider).valueOrNull ?? [];

  Future<PersonMapContext> _buildContext() async {
    final groups = await ref.read(groupsProvider.future);
    final mainGroup = await ref.read(mainGroupProvider.future);
    final tenant = ref.read(currentTenantProvider);
    return PersonMapContext(
      groups: groups,
      mainGroupId: mainGroup?.id,
      additionalFields: tenant?.additionalFields ?? const <ExtraField>[],
    );
  }

  List<ImportTargetOption> _buildOptions() => [
        (key: null, label: 'Ignorieren'),
        (key: 'Vorname', label: 'Vorname'),
        (key: 'Nachname', label: 'Nachname'),
        (key: kFullNameKey, label: 'Name (Vor- und Nachname)'),
        (key: 'Geburtsdatum', label: 'Geburtsdatum'),
        (key: 'Gruppe', label: 'Gruppe'),
        (key: 'E-Mail', label: 'E-Mail'),
        (key: 'Telefon', label: 'Telefon'),
        (key: 'Eingetreten', label: 'Eingetreten'),
        (key: 'Notizen', label: 'Notizen'),
        for (final f in _ctx.additionalFields)
          (key: '$kExtraPrefix${f.id}', label: f.name),
      ];

  Future<void> _pickFile() async {
    final picked = await pickSpreadsheetFile();
    if (picked == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final data = readSpreadsheet(picked.bytes, picked.name);
      if (data.rows.isEmpty) {
        if (mounted) ToastHelper.showWarning(context, 'Die Datei enthält keine Daten.');
        return;
      }
      final ctx = await _buildContext();
      setState(() {
        _fileName = picked.name;
        _rawRows = data.rows;
        _headers = data.headers;
        _ctx = ctx;
        _options = _buildOptions();
        _mapping = autoMapPersonHeaders(_headers, ctx);
        _step = _Step.mapping;
      });
    } on SpreadsheetReadException catch (e) {
      if (mounted) ToastHelper.showError(context, e.message);
    } catch (_) {
      if (mounted) ToastHelper.showError(context, 'Die Datei konnte nicht gelesen werden.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadTemplate() async {
    final tenant = ref.read(currentTenantProvider);
    final headers =
        buildPersonImportTemplateHeaders(tenant?.additionalFields ?? const []);
    final groups = await ref.read(groupsProvider.future);
    final example = [
      'Anna',
      'Müller',
      '15.03.1990',
      groups.isNotEmpty ? groups.first.name : '',
      'anna@example.com',
      '0170 1234567',
      '01.01.2024',
      '',
    ];
    final bytes = buildTemplateXlsx(headers, example);
    if (bytes == null) return;
    try {
      await saveGeneratedFile(bytes, 'Personen_Import_Vorlage.xlsx');
    } catch (e) {
      if (mounted) ToastHelper.showError(context, 'Fehler: $e');
    }
  }

  Future<void> _proceedToPreview() async {
    if (!mappingHasName(_mapping)) {
      ToastHelper.showWarning(context, 'Bitte Spalten für Vor- und Nachnamen zuordnen.');
      return;
    }
    setState(() => _busy = true);
    try {
      final mapped = mapPersonRows(_rawRows, _mapping, _ctx);
      final existing =
          await ref.read(importRepositoryWithTenantProvider).getExistingPlayerEmails();
      setState(() {
        _mappedRows = detectPersonDuplicates(mapped, existing);
        _step = _Step.preview;
      });
    } catch (_) {
      if (mounted) ToastHelper.showError(context, 'Fehler bei der Vorschau.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<MappedPersonRow> get _importable =>
      _mappedRows.where((r) => r.isImportable).toList();

  Future<void> _startImport() async {
    final toImport = _importable;
    if (toImport.isEmpty) {
      ToastHelper.showWarning(context, 'Keine importierbaren Personen.');
      return;
    }

    final importRepo = ref.read(importRepositoryWithTenantProvider);
    final playerRepo = ref.read(playerRepositoryWithTenantProvider);
    // AUTH: accounts are created server-side (attendix-user Edge Function)
    final registrationRepo =
        ref.read(userRegistrationRepositoryWithTenantProvider);
    final mainGroupId = _ctx.mainGroupId;

    setState(() {
      _busy = true;
      _progress = '0 / ${toImport.length} importiert...';
    });

    var imported = 0;
    final failed = <String>[];
    for (var i = 0; i < toImport.length; i++) {
      final row = toImport[i];
      try {
        final person = await importRepo.insertPlayer(row.data);
        // Ionic addPlayer: backfill attendances (best effort).
        try {
          await playerRepo.addToUpcomingAttendances(person);
        } catch (_) {}
        // Accounts only when the toggle is on and an email exists.
        if (_createAccounts &&
            (person.email?.isNotEmpty ?? false) &&
            registrationRepo.hasTenantId) {
          await registrationRepo.createPlayerAccount(
            person,
            mainGroupId: mainGroupId,
          );
        }
        imported++;
      } catch (e) {
        failed.add('${row.firstName} ${row.lastName}: $e');
      }
      if (mounted) {
        setState(() => _progress = '${i + 1} / ${toImport.length} importiert...');
      }
    }

    if (!mounted) return;
    setState(() => _busy = false);

    final parts = [
      imported == 1 ? '1 Person importiert.' : '$imported Personen importiert.',
      if (failed.isNotEmpty) '${failed.length} fehlgeschlagen.',
    ];
    if (failed.isEmpty) {
      ToastHelper.showSuccess(context, parts.join(' '));
    } else {
      ToastHelper.showWarning(context, parts.join(' '));
      await showImportFailures(context, title: 'Nicht importierte Personen', lines: failed);
    }

    if (imported > 0) {
      ref.invalidate(playersProvider);
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(groupsProvider).valueOrNull ?? _groups;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personen importieren'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Stack(
        children: [
          switch (_step) {
            _Step.file => ImportFileStep(
                intro: 'Importiere Personen aus einer Excel- (.xlsx) oder CSV-Datei. '
                    'Die erste Zeile muss Spaltenüberschriften enthalten. Am einfachsten '
                    'ist es, die Vorlage herunterzuladen und auszufüllen.',
                onPickFile: _pickFile,
                onDownloadTemplate: _downloadTemplate,
              ),
            _Step.mapping => ImportMappingStep(
                fileName: _fileName,
                rowCount: _rawRows.length,
                intro: 'Ordne die Spalten deiner Datei den Personenfeldern zu. Vorname '
                    'und Nachname (oder eine kombinierte Namensspalte) sind erforderlich.',
                headers: _headers,
                mapping: _mapping,
                options: _options,
                onChanged: (header, key) => setState(() => _mapping[header] = key),
                missingHint: 'Bitte ordne Spalten für Vor- und Nachnamen zu '
                    '(oder eine kombinierte Namensspalte).',
                canProceed: mappingHasName(_mapping),
              ),
            _Step.preview => _buildPreview(groups),
          },
          if (_busy)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black26,
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.paddingL),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          if (_progress.isNotEmpty) ...[
                            const SizedBox(height: AppDimensions.paddingM),
                            Text(_progress),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: switch (_step) {
        _Step.file => null,
        _Step.mapping => ImportBottomBar(
            onBack: () => setState(() => _step = _Step.file),
            primaryLabel: 'Weiter',
            onPrimary: mappingHasName(_mapping) && !_busy ? _proceedToPreview : null,
          ),
        _Step.preview => ImportBottomBar(
            onBack: () => setState(() => _step = _Step.mapping),
            primaryLabel: '${_importable.length} importieren',
            onPrimary: _busy || _importable.isEmpty ? null : _startImport,
          ),
      },
    );
  }

  Widget _buildPreview(List<Group> groups) {
    final errorCount = _mappedRows.where((r) => r.errors.isNotEmpty).length;
    final duplicateCount =
        _mappedRows.where((r) => r.isDuplicate && r.errors.isEmpty).length;
    final warningCount = _mappedRows
        .where((r) => r.errors.isEmpty && !r.isDuplicate && r.warnings.isNotEmpty)
        .length;
    final unresolved = _mappedRows.where((r) => !r.groupResolved).length;

    String groupName(int? id) =>
        groups.where((g) => g.id == id).map((g) => g.name).firstOrNull ?? '';

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      children: [
        ImportSummaryChips(
          ready: _importable.length,
          warnings: warningCount,
          duplicates: duplicateCount,
          errors: errorCount,
        ),
        if (unresolved > 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingS),
            child: Text(
              '${unresolved == 1 ? '1 Person konnte' : '$unresolved Personen konnten'} '
              'keiner Gruppe zugeordnet werden. Bitte prüfe und passe die Gruppe unten '
              'an – vorerst ist die Hauptgruppe hinterlegt.',
              style: const TextStyle(color: AppColors.warning),
            ),
          ),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Konten erstellen'),
                value: _createAccounts,
                onChanged: (v) => setState(() => _createAccounts = v),
              ),
              if (_createAccounts)
                const ListTile(
                  dense: true,
                  title: Text(
                    'Für Personen mit E-Mail-Adresse werden Benutzerkonten erstellt '
                    'und Einladungs-E-Mails versendet.',
                    style: TextStyle(color: AppColors.warning),
                  ),
                ),
            ],
          ),
        ),
        Card(
          child: Column(
            children: [
              for (final row in _mappedRows)
                Opacity(
                  opacity: row.isImportable ? 1 : 0.6,
                  child: ListTile(
                    leading: ImportRowStatusIcon(status: row.status),
                    title: Text('${row.firstName} ${row.lastName}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (row.email != null) Text(row.email!),
                        if (row.errors.isEmpty)
                          DropdownButton<int>(
                            value: groups.any((g) => g.id == row.instrument)
                                ? row.instrument
                                : null,
                            isExpanded: true,
                            hint: const Text('Gruppe'),
                            style: row.groupResolved
                                ? null
                                : Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: AppColors.warning),
                            items: [
                              for (final g in groups)
                                DropdownMenuItem(value: g.id, child: Text(g.name)),
                            ],
                            onChanged: (v) => setState(() {
                              row.instrument = v;
                              row.groupResolved = true;
                            }),
                          )
                        else
                          Text(groupName(row.instrument)),
                        ImportRowMessages(errors: row.errors, warnings: row.warnings),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
