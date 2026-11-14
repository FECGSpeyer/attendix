import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/import_providers.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/utils/import_file_io.dart';
import '../../../../core/utils/import_mapper.dart';
import '../../../../core/utils/spreadsheet_reader.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../people/presentation/widgets/import_widgets.dart';
import '../../../../core/providers/demo_providers.dart'; // DEMO_GUARD
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/layout/ionic_ios.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../redesign/presentation/widgets/rd_widgets.dart';

enum _Step { file, mapping, preview }

/// Import songs from an Excel/CSV file (Ionic songs/import).
///
/// Returns `true` via Navigator.pop when at least one song was imported.
class SongImportPage extends ConsumerStatefulWidget {
  const SongImportPage({super.key, this.beta = false});

  /// Beta "Werkliste importieren": the same steps as a page of the Werke
  /// tab ("‹ Werke", one button per step) instead of the full-screen modal.
  final bool beta;

  @override
  ConsumerState<SongImportPage> createState() => _SongImportPageState();
}

class _SongImportPageState extends ConsumerState<SongImportPage> {
  _Step _step = _Step.file;
  String _fileName = '';
  List<String> _headers = [];
  List<Map<String, dynamic>> _rawRows = [];
  ColumnMapping _mapping = {};
  List<ImportTargetOption> _options = [];
  List<MappedSongRow> _mappedRows = [];
  SongMapContext _ctx = const SongMapContext();
  bool _busy = false;
  String _progress = '';

  Future<SongMapContext> _buildContext() async {
    final categories = await ref.read(songCategoriesProvider.future);
    final fields = await ref.read(songAdditionalFieldsProvider.future);
    return SongMapContext(songCategories: categories, additionalFields: fields);
  }

  List<ImportTargetOption> _buildOptions() => [
        (key: null, label: context.l10n.peopleIgnore),
        (key: 'Nummer', label: context.l10n.songsNumber),
        (key: 'Präfix', label: context.l10n.songsPrefix),
        (key: 'Name', label: context.l10n.songsName),
        (key: 'Chor & Orchester', label: context.l10n.songsChoirOrchestra),
        (key: 'Mit Solo', label: context.l10n.songsWithSolo),
        (key: 'Link', label: context.l10n.songsLink),
        (key: 'Schwierigkeit', label: context.l10n.songsDifficulty123),
        (key: 'Kategorien', label: context.l10n.songsCategories),
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
      setState(() {
        _fileName = picked.name;
        _rawRows = data.rows;
        _headers = data.headers;
        _ctx = ctx;
        _options = _buildOptions();
        _mapping = autoMapSongHeaders(_headers, ctx);
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

  Future<void> _downloadTemplate() async {
    final fields = await ref.read(songAdditionalFieldsProvider.future);
    final headers = buildSongImportTemplateHeaders(fields);
    const example = ['42', 'W', 'Stille Nacht', 'ja', 'nein', '', '2', 'Weihnachten'];
    final bytes = buildTemplateXlsx(headers, example);
    if (bytes == null) return;
    try {
      await saveGeneratedFile(bytes, 'Werke_Import_Vorlage.xlsx');
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.songsFlutterErrorWith(friendlyErrorMessage(e)));
    }
  }

  Future<void> _proceedToPreview() async {
    final importRepo = ref.read(importRepositoryWithTenantProvider);
    if (!mappingSongHasRequired(_mapping)) {
      ToastHelper.showWarning(context, context.l10n.songsMapNumberName);
      return;
    }
    setState(() => _busy = true);
    try {
      final mapped = mapSongRows(_rawRows, _mapping, _ctx);
      // Ionic getExistingNumbers: effective song library (Werk-Synchronisierung).
      final settings = await ref.read(songTenantSettingsProvider.future);
      final existing = await importRepo
          .getExistingSongKeys(songTenantId: settings.songSourceTenantId);
      setState(() {
        _mappedRows = detectSongDuplicates(mapped, existing);
        _step = _Step.preview;
      });
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.peoplePreviewFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<MappedSongRow> get _importable =>
      _mappedRows.where((r) => r.isImportable).toList();

  Future<void> _startImport() async {
    final toImport = _importable;
    if (toImport.isEmpty) {
      ToastHelper.showWarning(context, context.l10n.songsNothingToImport);
      return;
    }
    // DEMO_GUARD: Ionic `if (db.isDemo()) showToast(people.demoUnavailable)`.
    if (ref.read(isDemoProvider)) {
      ToastHelper.showDemoRestricted(context);
      return;
    }
    final repo = ref.read(importRepositoryWithTenantProvider);
    // Ionic importSongs → addSong: songs go into the effective song library.
    final songTenantId =
        (await ref.read(songTenantSettingsProvider.future)).songSourceTenantId;
    if (!mounted) return;

    setState(() {
      _busy = true;
      _progress = context.l10n.peopleImportProgress(0, toImport.length);
    });

    var imported = 0;
    final failed = <String>[];
    for (var i = 0; i < toImport.length; i++) {
      final row = toImport[i];
      try {
        await repo.insertSong(row.data, songTenantId: songTenantId);
        imported++;
      } catch (e) {
        failed.add('${row.displayTitle}: $e');
      }
      if (mounted) {
        setState(() => _progress = context.l10n.peopleImportProgress(i + 1, toImport.length));
      }
    }

    if (!mounted) return;
    setState(() => _busy = false);

    final parts = [
      context.l10n.songsImportedCount(imported),
      if (failed.isNotEmpty) context.l10n.peopleFailedCount(failed.length),
    ];
    if (failed.isEmpty) {
      ToastHelper.showSuccess(context, parts.join(' '));
    } else {
      ToastHelper.showWarning(context, parts.join(' '));
      await showImportFailures(context, title: context.l10n.songsNotImported, lines: failed);
    }

    if (imported > 0) {
      ref.invalidate(songsProvider);
      if (mounted) _leave(true);
    }
  }

  void _leave(bool imported) {
    if (!widget.beta) return Navigator.of(context).pop(imported ? true : null);
    context.canPop() ? context.pop(imported ? true : null) : context.go(RedesignRoutes.works);
  }

  Widget _busyOverlay() => Positioned.fill(
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
      );

  /// Beta: step 1 as a Beta page (template as a row, one button), steps 2
  /// and 3 keep the shared mapping and preview with one button below.
  Widget _buildBeta(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final title = Semantics(header: true, child: Text(l10n.redesignWorksAddImport, style: RdType.title(p)));
    if (_step == _Step.file) {
      return Stack(
        children: [
          RdPage(
            children: [
              RdBackLink(
                label: l10n.redesignTabWorks,
                onTap: () {
                  if (!_busy) _leave(false);
                },
              ),
              const SizedBox(height: 4),
              title,
              const SizedBox(height: 6),
              Text(l10n.rdTextWorkListIntro, style: RdType.meta(p, size: 15)),
              const SizedBox(height: 18),
              RdGroupedList(
                children: [
                  RdListRow(
                    key: const Key('rd-worklist-template'),
                    leading: const RdRowIcon(Icons.download_outlined),
                    title: l10n.peopleDownloadTemplate,
                    showChevron: false,
                    onTap: _downloadTemplate,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              RdPrimaryButton(
                key: const Key('rd-worklist-pick'),
                label: l10n.peopleChooseFile,
                icon: Icons.upload_file_outlined,
                onPressed: _busy ? null : _pickFile,
              ),
            ],
          ),
          if (_busy) _busyOverlay(),
        ],
      );
    }
    final mapping = _step == _Step.mapping;
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RdBackLink(
                            label: l10n.commonBack,
                            onTap: () => setState(() => _step = mapping ? _Step.file : _Step.mapping),
                          ),
                          const SizedBox(height: 4),
                          title,
                        ],
                      ),
                    ),
                    Expanded(
                      child: mapping
                          ? ImportMappingStep(
                              fileName: _fileName,
                              rowCount: _rawRows.length,
                              intro: l10n.songsMappingIntro,
                              headers: _headers,
                              mapping: _mapping,
                              options: _options,
                              onChanged: (header, key) => setState(() => _mapping[header] = key),
                              missingHint: l10n.songsMapNumberName,
                              canProceed: mappingSongHasRequired(_mapping),
                            )
                          : _buildPreview(),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: RdPrimaryButton(
                        key: const Key('rd-worklist-next'),
                        label: mapping ? l10n.commonNext : l10n.peopleImportCount(_importable.length),
                        onPressed: _busy
                            ? null
                            : mapping
                            ? (mappingSongHasRequired(_mapping) ? _proceedToPreview : null)
                            : (_importable.isEmpty ? null : _startImport),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_busy) _busyOverlay(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.beta) return _buildBeta(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.songsImportSongs),
        automaticallyImplyLeading: false,
        // IOS_PAGES3: iOS → ✕ in a Liquid Glass circle (ion-buttons end)
        actions: [
          ToolbarButtonGroup(children: [
            IconButton(
              icon: Icon(AppIcons.close, semanticLabel: context.l10n.commonClose),
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
            ),
          ]),
        ],
      ),
      body: Stack(
        children: [
          switch (_step) {
            _Step.file => ImportFileStep(
                intro: context.l10n.songsImportIntro,
                onPickFile: _pickFile,
                onDownloadTemplate: _downloadTemplate,
              ),
            _Step.mapping => ImportMappingStep(
                fileName: _fileName,
                rowCount: _rawRows.length,
                intro: context.l10n.songsMappingIntro,
                headers: _headers,
                mapping: _mapping,
                options: _options,
                onChanged: (header, key) => setState(() => _mapping[header] = key),
                missingHint: context.l10n.songsMapNumberName,
                canProceed: mappingSongHasRequired(_mapping),
              ),
            _Step.preview => _buildPreview(),
          },
          if (_busy) _busyOverlay(),
        ],
      ),
      bottomNavigationBar: switch (_step) {
        _Step.file => null,
        _Step.mapping => ImportBottomBar(
            onBack: () => setState(() => _step = _Step.file),
            primaryLabel: context.l10n.commonNext,
            onPrimary:
                mappingSongHasRequired(_mapping) && !_busy ? _proceedToPreview : null,
          ),
        _Step.preview => ImportBottomBar(
            onBack: () => setState(() => _step = _Step.mapping),
            primaryLabel: context.l10n.peopleImportCount(_importable.length),
            onPrimary: _busy || _importable.isEmpty ? null : _startImport,
          ),
      },
    );
  }

  Widget _buildPreview() {
    final errorCount = _mappedRows.where((r) => r.errors.isNotEmpty).length;
    final duplicateCount =
        _mappedRows.where((r) => r.isDuplicate && r.errors.isEmpty).length;
    final warningCount = _mappedRows
        .where((r) => r.errors.isEmpty && !r.isDuplicate && r.warnings.isNotEmpty)
        .length;

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      children: [
        ImportSummaryChips(
          ready: _importable.length,
          warnings: warningCount,
          duplicates: duplicateCount,
          errors: errorCount,
        ),
        const SizedBox(height: AppDimensions.paddingS),
        // Ionic ion-list inset (iOS radius, inset hairlines)
        IonInsetList(
          margin: EdgeInsets.zero,
          grouped: false,
          children: [
              for (final row in _mappedRows)
                Opacity(
                  opacity: row.isImportable ? 1 : 0.6,
                  child: ListTile(
                    leading: ImportRowStatusIcon(status: row.status),
                    title: Text(row.displayTitle),
                    subtitle: row.errors.isEmpty && row.warnings.isEmpty
                        ? null
                        : ImportRowMessages(errors: row.errors, warnings: row.warnings),
                  ),
                ),
          ],
        ),
      ],
    );
  }
}
