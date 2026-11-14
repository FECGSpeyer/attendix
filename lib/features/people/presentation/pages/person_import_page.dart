import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/import_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/profile_providers.dart';
import '../../../../core/services/native/native_file_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/import_file_io.dart';
import '../../../../core/utils/import_mapper.dart';
import '../../../../core/utils/spreadsheet_reader.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../core/providers/user_registration_providers.dart';
import '../widgets/import_widgets.dart';
import '../widgets/ion/ion_widgets.dart'
    show IonSelectRow, IonToggleRow, IonText, ionLightColor, ionIsIos;
import '../../../../shared/widgets/layout/ionic_ios.dart' as ios27
    show IonInsetList, IonItem;
import '../../../../core/theme/redesign/rd_theme.dart' show RdSkinContext;
import 'package:attendix/core/theme/app_icons.dart';
import '../../people_list_utils.dart' show accountRoleForGroup;
import '../../../../l10n/l10n.dart';
import '../../../../core/providers/demo_providers.dart'; // DEMO_GUARD
import '../../../../core/services/error_reporter.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../data/repositories/player_repository.dart' show PersonNotAddedToAttendancesException;

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

  /// Rows (by file row) that were saved, but could not be added to the
  /// Termine. A second click only retries the Termine for them, so the
  /// person is not saved twice.
  final Map<int, Person> _savedWithoutTermine = {};

  /// Rows (by file row) that are completely imported; a retry skips them.
  final Set<int> _importedRows = {};

  List<Group> get _groups => ref.read(groupsProvider).valueOrNull ?? [];

  Future<PersonMapContext> _buildContext() async {
    final groups = await ref.read(groupsProvider.future);
    final mainGroup = await ref.read(mainGroupProvider.future);
    // Ionic db.getPersonExtraFields(): organisation + instance fields.
    return PersonMapContext(
      groups: groups,
      mainGroupId: mainGroup?.id,
      additionalFields: await _extraFields(),
    );
  }

  List<ImportTargetOption> _buildOptions() => [
        (key: null, label: context.l10n.peopleIgnore),
        (key: 'Vorname', label: context.l10n.peopleFirstName),
        (key: 'Nachname', label: context.l10n.peopleLastName),
        (key: kFullNameKey, label: context.l10n.peopleFullName),
        (key: 'Geburtsdatum', label: context.l10n.peopleBirthday),
        (key: 'Gruppe', label: context.l10n.peopleGroup),
        (key: 'E-Mail', label: context.l10n.peopleEmail),
        (key: 'Telefon', label: context.l10n.peoplePhone),
        (key: 'Eingetreten', label: context.l10n.peopleJoined),
        (key: 'Notizen', label: context.l10n.peopleNotes),
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
        if (mounted) ToastHelper.showWarning(context, context.l10n.peopleFileEmpty);
        return;
      }
      final ctx = await _buildContext();
      if (!mounted) return;
      setState(() {
        _fileName = picked.name;
        _rawRows = data.rows;
        _savedWithoutTermine.clear();
        _importedRows.clear();
        _headers = data.headers;
        _ctx = ctx;
        _options = _buildOptions();
        _mapping = autoMapPersonHeaders(_headers, ctx);
        _step = _Step.mapping;
      });
    } on SpreadsheetReadException catch (e) {
      if (mounted) ToastHelper.showError(context, e.message);
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.peopleFileUnreadable);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<List<ExtraField>> _extraFields() async {
    // Read the provider before awaiting: the ref must not be used after the
    // page was closed during the organisation query.
    final organisation = ref.read(currentOrganisationProvider.future);
    try {
      await organisation;
    } catch (_) {
      // Without the organisation only the instance fields are offered.
    }
    if (!mounted) return const <ExtraField>[];
    return ref.read(personListExtraFieldsProvider);
  }

  Future<void> _downloadTemplate() async {
    // Ionic Utils.saveWorkbook: native → system file viewer, mobile web →
    // share sheet, desktop → download; no message on failure.
    try {
      final groupsFuture = ref.read(groupsProvider.future);
      final fields = await _extraFields();
      final groups = await groupsFuture;
      if (!mounted) return;
      final headers = buildPersonImportTemplateHeaders(fields);
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
      await NativeFileService.saveBytes(
          Uint8List.fromList(bytes), 'Personen_Import_Vorlage.xlsx');
    } catch (e, st) {
      ErrorReporter.report(e, st, where: 'person_import_template');
    }
  }

  Future<void> _proceedToPreview() async {
    if (!mappingHasName(_mapping)) {
      ToastHelper.showWarning(context, context.l10n.peopleMapNames);
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
      if (mounted) ToastHelper.showError(context, context.l10n.peoplePreviewFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<MappedPersonRow> get _importable =>
      _mappedRows
          .where((r) =>
              !_importedRows.contains(r.rowIndex) &&
              // A saved person still missing its Termine stays retryable,
              // even when a new duplicate check now flags it.
              (r.isImportable || _savedWithoutTermine.containsKey(r.rowIndex)))
          .toList();

  Future<void> _startImport() async {
    final toImport = _importable;
    if (toImport.isEmpty) {
      ToastHelper.showWarning(context, context.l10n.peopleNothingToImport);
      return;
    }
    // DEMO_GUARD: Ionic `if (db.isDemo()) showToast(people.demoUnavailable)`.
    if (ref.read(isDemoProvider)) {
      ToastHelper.showDemoRestricted(context);
      return;
    }

    final playerRepo = ref.read(playerRepositoryWithTenantProvider);
    // AUTH: accounts are created server-side (attendix-user Edge Function)
    final registrationRepo =
        ref.read(userRegistrationRepositoryWithTenantProvider);
    final mainGroupId = _ctx.mainGroupId;

    setState(() {
      _busy = true;
      _progress = context.l10n.peopleImportProgress(0, toImport.length);
    });

    var imported = 0;
    final failed = <String>[];
    for (var i = 0; i < toImport.length; i++) {
      final row = toImport[i];
      final name = '${row.firstName} ${row.lastName}';
      try {
        final saved = _savedWithoutTermine[row.rowIndex];
        if (saved != null) {
          // Saved by an earlier click: only add it to the Termine.
          await playerRepo.addPlayerToAttendancesByDate(saved);
        } else {
          // Ionic importPlayers → addPlayer(player, register, role): the
          // account is registered first (a failed registration inserts no
          // person), an existing row of that account is reactivated instead
          // of duplicated, and the person is added to later Termine.
          final register = _createAccounts &&
              (row.email?.trim().isNotEmpty ?? false) &&
              registrationRepo.hasTenantId;
          await playerRepo.addPlayer(
            Person.fromJson({...row.data, 'tenantId': playerRepo.currentTenantId}),
            register: register,
            role: accountRoleForGroup(row.instrument, mainGroupId),
          );
        }
        _savedWithoutTermine.remove(row.rowIndex);
        _importedRows.add(row.rowIndex);
        imported++;
      } on PersonNotAddedToAttendancesException catch (e) {
        _savedWithoutTermine[row.rowIndex] = e.person;
        if (mounted) {
          failed.add(context.l10n.peopleFlutterImportNotAssigned(name, e.cause.toString()));
        }
      } catch (e) {
        failed.add('$name: $e');
      }
      if (mounted) {
        setState(() => _progress = context.l10n.peopleImportProgress(i + 1, toImport.length));
      }
    }

    if (!mounted) return;
    setState(() => _busy = false);
    // Also after failures: addPlayer saves the person before adding it to
    // the Termine, so a failed row may already exist (duplicate check of a
    // second import must see it).
    ref.invalidate(playersProvider);

    final parts = [
      context.l10n.peopleImportedCount(imported),
      if (failed.isNotEmpty) context.l10n.peopleFailedCount(failed.length),
    ];
    if (failed.isEmpty) {
      ToastHelper.showSuccess(context, parts.join(' '));
    } else {
      ToastHelper.showWarning(context, parts.join(' '));
      await showImportFailures(context, title: context.l10n.peopleNotImported, lines: failed);
    }

    // Ionic closes once a row was imported. Stay open while saved persons
    // still miss their Termine, so the retry can add only those.
    if (imported > 0 && _savedWithoutTermine.isEmpty && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(groupsProvider).valueOrNull ?? _groups;

    final classic = context.rdSkin == null;
    return Scaffold(
      // PEO-07: Ionic `ion-content color="light"`.
      backgroundColor: classic ? ionLightColor(context) : null,
      appBar: AppBar(
        title: Text(context.l10n.peopleImportPeople),
        automaticallyImplyLeading: false,
        actions: [
          // PEO-10: Ionic modal close (iOS glass circle).
          IonCloseButton(
            onPressed: _busy ? () {} : () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (classic)
            switch (_step) {
              _Step.file => _buildIonFileStep(context),
              _Step.mapping => _buildIonMappingStep(context),
              _Step.preview => _buildIonPreview(groups),
            }
          else
          switch (_step) {
            _Step.file => ImportFileStep(
                intro: context.l10n.peopleImportIntro,
                onPickFile: _pickFile,
                onDownloadTemplate: _downloadTemplate,
              ),
            _Step.mapping => ImportMappingStep(
                fileName: _fileName,
                rowCount: _rawRows.length,
                intro: context.l10n.peopleMappingIntro,
                headers: _headers,
                mapping: _mapping,
                options: _options,
                onChanged: (header, key) => setState(() => _mapping[header] = key),
                missingHint: context.l10n.peopleMappingMissing,
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
                          const AppSpinner(),
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
      bottomNavigationBar: classic
          ? switch (_step) {
              _Step.file => null,
              _Step.mapping => _IonFooterBar(
                  onBack: () => setState(() => _step = _Step.file),
                  primaryLabel: context.l10n.commonNext,
                  onPrimary: mappingHasName(_mapping) && !_busy ? _proceedToPreview : null,
                ),
              _Step.preview => _IonFooterBar(
                  onBack: () => setState(() => _step = _Step.mapping),
                  primaryLabel: context.l10n.peopleImportCount(_importable.length),
                  onPrimary: _busy || _importable.isEmpty ? null : _startImport,
                ),
            }
          : switch (_step) {
        _Step.file => null,
        _Step.mapping => ImportBottomBar(
            onBack: () => setState(() => _step = _Step.file),
            primaryLabel: context.l10n.commonNext,
            onPrimary: mappingHasName(_mapping) && !_busy ? _proceedToPreview : null,
          ),
        _Step.preview => ImportBottomBar(
            onBack: () => setState(() => _step = _Step.mapping),
            primaryLabel: context.l10n.peopleImportCount(_importable.length),
            onPrimary: _busy || _importable.isEmpty ? null : _startImport,
          ),
      },
    );
  }

  // PEO-07: Ionic import steps – intro text with `ion-padding`, inset lists
  // on the light background, stacked popover selects, outline chips.
  Widget _intro(List<Widget> children) => Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );

  Widget _buildIonFileStep(BuildContext context) {
    return ListView(
      children: [
        _intro([Text(context.l10n.peopleImportIntro)]),
        ios27.IonInsetList(children: [
          ios27.IonItem(
            leading: Icon(AppIcons.cloudUploadOutlined, color: AppColors.primary),
            title: Text(context.l10n.peopleChooseFile),
            titleColor: AppColors.primary,
            onTap: _pickFile,
          ),
          ios27.IonItem(
            leading: Icon(AppIcons.downloadOutlined),
            title: Text(context.l10n.peopleDownloadTemplate),
            onTap: _downloadTemplate,
          ),
        ]),
      ],
    );
  }

  Widget _buildIonMappingStep(BuildContext context) {
    final canProceed = mappingHasName(_mapping);
    return ListView(
      padding: const EdgeInsets.only(bottom: AppDimensions.paddingL),
      children: [
        _intro([
          Text.rich(TextSpan(children: [
            TextSpan(text: _fileName, style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: ' — ${context.l10n.peopleFileRows(_rawRows.length)}'),
          ])),
          const SizedBox(height: AppDimensions.paddingS),
          Text(context.l10n.peopleMappingIntro),
        ]),
        ios27.IonInsetList(children: [
          for (final header in _headers)
            IonSelectRow<String?>(
              lines: false,
              stacked: true,
              label: header,
              value: _mapping[header],
              placeholder: context.l10n.peopleChooseFieldPlaceholder,
              interface: AppSelectInterface.popover,
              options: [
                for (final opt in _options)
                  AppSelectOption<String?>(value: opt.key, label: opt.label),
              ],
              onChanged: (key) => setState(() => _mapping[header] = key),
            ),
        ]),
        if (!canProceed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
            child: Text(context.l10n.peopleMappingMissing,
                style: const TextStyle(color: AppColors.warning)),
          ),
      ],
    );
  }

  Widget _buildIonPreview(List<Group> groups) {
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
      padding: const EdgeInsets.only(bottom: AppDimensions.paddingL),
      children: [
        Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _OutlineChip(context.l10n.peopleReady(_importable.length), AppColors.success),
              if (warningCount > 0)
                _OutlineChip(context.l10n.peopleWithHint(warningCount), AppColors.warning),
              if (duplicateCount > 0)
                _OutlineChip(context.l10n.peopleDuplicates(duplicateCount), AppColors.medium),
              if (errorCount > 0)
                _OutlineChip(context.l10n.peopleFaulty(errorCount), AppColors.danger),
            ],
          ),
        ),
        if (unresolved > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
            child: Text(
              context.l10n.peopleUnresolvedGroups(unresolved),
              style: const TextStyle(color: AppColors.warning),
            ),
          ),
        ios27.IonInsetList(children: [
          IonToggleRow(
            label: context.l10n.peopleCreateAccounts,
            value: _createAccounts,
            editable: true,
            onChanged: (v) => setState(() => _createAccounts = v),
          ),
          if (_createAccounts)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Text(
                context.l10n.peopleCreateAccountsHint,
                style: IonText.note(context).copyWith(color: AppColors.warning),
              ),
            ),
        ]),
        ios27.IonInsetList(children: [
          for (final row in _mappedRows)
            Opacity(
              opacity: row.isImportable ? 1 : 0.6,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 0, 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2, right: 16),
                      child: ImportRowStatusIcon(status: row.status),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Text('${row.firstName} ${row.lastName}',
                                style: IonText.h3(context)),
                          ),
                          if (row.email != null)
                            Text(row.email!, style: IonText.p(context)),
                          if (row.errors.isEmpty &&
                              !_savedWithoutTermine.containsKey(row.rowIndex))
                            Transform.translate(
                              offset: const Offset(-16, 0),
                              child: IonSelectRow<int>(
                                lines: false,
                                stacked: true,
                                label: context.l10n.peopleGroup,
                                value: groups.any((g) => g.id == row.instrument)
                                    ? row.instrument
                                    : null,
                                interface: AppSelectInterface.popover,
                                options: [
                                  for (final g in groups)
                                    if (g.id != null)
                                      AppSelectOption<int>(value: g.id!, label: g.name),
                                ],
                                onChanged: (v) => setState(() {
                                  row.instrument = v;
                                  row.groupResolved = true;
                                }),
                              ),
                            )
                          else
                            Text(groupName(row.instrument), style: IonText.p(context)),
                          Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: ImportRowMessages(
                                errors: row.errors, warnings: row.warnings),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ]),
      ],
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
              context.l10n.peopleUnresolvedGroups(unresolved),
              style: const TextStyle(color: AppColors.warning),
            ),
          ),
        Card(
          child: Column(
            children: [
              SwitchListTile.adaptive(
                title: Text(context.l10n.peopleCreateAccounts),
                value: _createAccounts,
                onChanged: (v) => setState(() => _createAccounts = v),
              ),
              if (_createAccounts)
                ListTile(
                  dense: true,
                  title: Text(
                    context.l10n.peopleCreateAccountsHint,
                    style: const TextStyle(color: AppColors.warning),
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
                        // A saved row (Termine pending) keeps its group: the
                        // retry adds the saved person to the Termine as is.
                        if (row.errors.isEmpty &&
                            !_savedWithoutTermine.containsKey(row.rowIndex))
                          AppDropdownButton<int>(
                            value: groups.any((g) => g.id == row.instrument)
                                ? row.instrument
                                : null,
                            isExpanded: true,
                            hint: Text(context.l10n.peopleGroup),
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

/// Ionic `ion-chip outline="true"` with a colour.
class _OutlineChip extends StatelessWidget {
  const _OutlineChip(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 14)),
      );
}

/// Ionic `ion-footer` > `ion-toolbar` with "Zurück" (slot start) and the
/// `strong` primary text button (slot end).
class _IonFooterBar extends StatelessWidget {
  const _IonFooterBar({
    required this.onBack,
    required this.primaryLabel,
    required this.onPrimary,
  });

  final VoidCallback onBack;
  final String primaryLabel;
  final VoidCallback? onPrimary;

  @override
  Widget build(BuildContext context) {
    final ios = ionIsIos(context);
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Container(
          height: ios ? 44 : 56,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: theme.dividerColor, width: ios ? 0.5 : 1),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              TextButton(
                onPressed: onBack,
                child: IonButtonLabel(context.l10n.commonBack),
              ),
              const Spacer(),
              TextButton(
                onPressed: onPrimary,
                child: DefaultTextStyle.merge(
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  child: IonButtonLabel(primaryLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
