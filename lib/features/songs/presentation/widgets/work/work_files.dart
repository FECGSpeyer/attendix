import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/providers/group_providers.dart';
import '../../../../../core/providers/song_providers.dart';
import '../../../../../core/services/audio_player/audio_player_service.dart';
import '../../../../../core/services/part_vision_service.dart';
import '../../../../../core/services/song_file_service.dart';
import '../../../../../core/services/zip_service.dart';
import '../../../../../core/services/zip_service_stub.dart'
    if (dart.library.io) '../../../../../core/services/zip_service_io.dart'
    if (dart.library.js_interop) '../../../../../core/services/zip_service_web.dart'
    as file_saver;
import '../../../../../core/theme/app_palette.dart';
import '../../../../../core/theme/design_theme.dart';
import '../../../../../core/utils/error_message.dart';
import '../../../../../core/utils/choir_file_utils.dart' show kChoirAllNote;
import '../../../../../core/utils/instrument_matcher.dart';
import '../../../../../core/utils/toast_helper.dart';
import '../../../../../data/models/instrument/instrument.dart';
import '../../../../../data/models/song/song.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/widgets/adaptive/app_dialog.dart';
import '../../../../../shared/widgets/adaptive/app_select.dart';
import '../../utils/song_utils.dart';
import '../file_drop/file_drop_target.dart';
import '../../../data/file_category_guess.dart' show learnableTerm;
import '../song_file_opener.dart';
import '../../../data/import/import_ai.dart' show rdImportAiProvider;
import '../../../data/import/import_logic.dart' show RdImportCategory, RdImportPlan, RdImportQuestion;
import '../../../../../core/logic/words.dart';
import '../../../data/work_files_controller.dart';
import '../../../data/work_files_logic.dart';
import '../../../data/work_upload_logic.dart';
import '../../../data/works_logic.dart';
import '../../../data/sibelius/sibelius_logic.dart' show RdSibeliusCheckout, rdIsSibeliusFile;
import '../../../data/sibelius/sibelius_sync.dart';
import '../../../../../shared/widgets/components/actions.dart';
import '../import/import_widgets.dart' show rdImportCategoryLabel, rdImportCategoryOptions;
import 'file_category_sheet.dart';
import 'sibelius_actions.dart';
import 'work_file_actions.dart' show rdReplaceWorkFile, rdIsAudioFile;
import '../../../../../shared/widgets/components/components.dart';

/// File workspace of a Werk (shown on wide screens to people who may edit
/// it): the files as a table with part, type and actions, multi-select with
/// ZIP download, the upload queue and keys. Files dropped anywhere on the
/// Werk (see [RdWorkDropArea]) or picked with "Hochladen" go through
/// [rdAddWorkFiles].

part 'work_files_upload.dart';
part 'work_files_table.dart';
part 'work_files_dialogs.dart';
part 'work_files_actions.dart';

/// Longest the upload waits for page-1 reading of a whole drop.
const Duration rdVisionBudget = Duration(minutes: 1);

/// Width from which the Werk page shows the workspace.
const double rdWorkFilesMinWidth = 560;

/// Files of [data] that are not deleted a moment ago.
List<SongFile> rdVisibleFiles(SongDetailData data, Set<String> hidden) =>
    (data.song.files ?? const <SongFile>[]).where((f) => !hidden.contains(f.url)).toList();


/// The whole Werk page as drop target: while files are dragged over it, a
/// frame with "Loslassen, um sie zu „…“ hochzuladen" covers it.
class RdWorkDropArea extends ConsumerWidget {
  const RdWorkDropArea({super.key, required this.data, required this.child});

  final SongDetailData data;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FileDropTarget(
      onFiles: (files) => rdAddWorkFiles(context, ref, data, files),
      builder: (context, hovering) {
        final p = context.rd;
        return Stack(
          children: [
            child,
            if (hovering)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: p.soft.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(p.cardRadius),
                      border: Border.all(color: p.primary, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_upload_outlined, size: 48, color: p.primary),
                        const SizedBox(height: 12),
                        Text(
                          context.l10n.redesignFilesDropOverlay(data.song.name),
                          textAlign: TextAlign.center,
                          style: RdType.section(p).copyWith(color: p.softText),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A part / category of the "Stimme" menu.
typedef _Category = ({int? id, String? note});

class RdWorkFiles extends ConsumerStatefulWidget {
  const RdWorkFiles({super.key, required this.data, required this.groups});

  final SongDetailData data;

  /// All groups (labels of the files).
  final List<Group> groups;

  @override
  ConsumerState<RdWorkFiles> createState() => _RdWorkFilesState();
}

class _RdWorkFilesState extends ConsumerState<RdWorkFiles> {
  final _focus = FocusNode(debugLabel: 'rd-work-files');
  final _rename = TextEditingController();
  final _renameFocus = FocusNode(debugLabel: 'rd-work-files-rename');

  /// Selected files (by URL).
  Set<String> _selected = {};

  /// Selection mode ("••• › Mehrere auswählen"): a click toggles a row
  /// instead of opening it. Without it a click opens the file.
  bool _selecting = false;

  /// Keyboard row (by URL) and start of a Umschalt range.
  String? _cursor;
  String? _anchor;

  /// File being renamed (by URL).
  String? _renaming;
  bool _busy = false;

  /// Parts exported from Sibelius are being offered.
  bool _takingParts = false;

  int get _songId => widget.data.song.id!;

  void _update(VoidCallback fn) => setState(fn);

  @override
  void dispose() {
    _focus.dispose();
    _rename.dispose();
    _renameFocus.dispose();
    super.dispose();
  }

  List<SongFile> _files(Set<String> hidden) =>
      SongUtils.sortedFiles(rdVisibleFiles(widget.data, hidden), widget.groups);

  List<SongFile> get _current => _files(ref.read(rdWorkFilesProvider(_songId)).hidden);

  /// The files an action is about: the selection, else the keyboard row.
  List<SongFile> _targets() {
    final files = _current;
    final selected = files.where((f) => _selected.contains(f.url)).toList();
    if (selected.isNotEmpty) return selected;
    return files.where((f) => f.url == _cursor).toList();
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final state = ref.watch(rdWorkFilesProvider(_songId));
    final files = _files(state.hidden);
    var waiting = const <RdSibeliusCheckout>[];
    var pluginInstalled = true;
    if (rdSibeliusSupported) {
      if (files.any(rdIsSibeliusFile)) {
        pluginInstalled = ref.watch(rdSibeliusPluginInstalledProvider).valueOrNull ?? true;
      }
      final tenantId = rdSongTenantId(ref);
      waiting = [
        if (tenantId != null)
          for (final c in ref.watch(rdSibeliusSyncProvider.select((s) => s.waiting)))
            if (c.tenantId == tenantId && c.songId == _songId) c,
      ];
      final parts = tenantId == null
          ? null
          : ref.watch(rdSibeliusSyncProvider.select((s) => s.partsFor(tenantId, _songId)));
      if (parts != null && !_takingParts) {
        _takingParts = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _takeSibeliusParts(parts.folder));
      }
    }
    final urls = {for (final f in files) f.url};
    // Rows that disappeared (deleted elsewhere) leave the selection.
    final selected = _selected.where(urls.contains).toSet();
    final allSelected = files.isNotEmpty && selected.length == files.length;
    // Checkboxes show only while selecting (also when keys or ⌘-clicks
    // picked rows), so a plain click reads as "open".
    final selecting = _selecting || selected.isNotEmpty;
    final toolbar = Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              !selecting
                  ? '${l10n.redesignFilesTitle} · ${files.length}'
                  : (selected.isEmpty ? l10n.redesignFilesSelectHint : l10n.redesignFilesSelected(selected.length)),
              style: RdType.section(p),
            ),
          ),
        ),
        if (selecting) ...[
          _ToolButton(
            icon: Icons.download_outlined,
            label: selected.length > 1 ? l10n.redesignFilesDownloadZip : l10n.redesignFilesDownload,
            onPressed:
                _busy || selected.isEmpty
                    ? null
                    : () => _download(files.where((f) => selected.contains(f.url)).toList()),
          ),
          _ToolButton(
            icon: Icons.delete_outline,
            label: l10n.redesignFilesDelete,
            color: p.absent,
            onPressed: selected.isEmpty ? null : () => _delete(files.where((f) => selected.contains(f.url)).toList()),
          ),
          IconButton(
            tooltip: l10n.redesignCommonCancel,
            icon: Icon(Icons.close, color: p.text2),
            onPressed: _stopSelecting,
          ),
        ] else ...[
          RdPrimaryButton(
            label: l10n.redesignFilesUpload,
            icon: Icons.upload_outlined,
            height: 40,
            onPressed: _pickAndUpload,
          ),
          if (files.isNotEmpty) ...[
            const SizedBox(width: 4),
            PopupMenuButton<_ListAction>(
              tooltip: l10n.redesignFilesMore,
              icon: Icon(Icons.more_horiz, color: p.text2),
              position: PopupMenuPosition.under,
              onSelected: (action) {
                switch (action) {
                  case _ListAction.select:
                    _startSelecting();
                  case _ListAction.downloadAll:
                    _download(files);
                }
              },
              itemBuilder:
                  (_) => [
                    _menuItem(_ListAction.select, Icons.check_circle_outline, l10n.redesignFilesSelectMany),
                    if (files.length > 1)
                      _menuItem(
                        _ListAction.downloadAll,
                        Icons.folder_zip_outlined,
                        l10n.redesignFilesDownloadAll,
                        enabled: !_busy,
                      ),
                  ],
            ),
          ],
        ],
      ],
    );

    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          toolbar,
          const SizedBox(height: 10),
          // Collapses smoothly once everything is uploaded (see rdUploadQueueHideDelay).
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child:
                state.uploads.isEmpty
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: RdUploadQueue(
                        state: state,
                        groups: widget.groups,
                        onRetry: (id) => ref.read(rdWorkFilesProvider(_songId).notifier).retry(id),
                        onDismiss: () => ref.read(rdWorkFilesProvider(_songId).notifier).dismissFinished(),
                      ),
                    ),
          ),
          if (_busy) ...[
            LinearProgressIndicator(minHeight: 2, color: p.primary, backgroundColor: p.track),
            const SizedBox(height: 8),
          ],
          if (files.isEmpty)
            _DropHint(onTap: _pickAndUpload)
          else
            RdCard(
              padding: EdgeInsets.zero,
              child: LayoutBuilder(
                builder: (context, c) {
                  // Narrow pages: smaller part column, no type column.
                  final compact = c.maxWidth < 680;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HeaderRow(
                        compact: compact,
                        selecting: selecting,
                        allSelected: allSelected,
                        someSelected: selected.isNotEmpty,
                        onSelectAll: (v) => _selectAll(files, v ?? false),
                      ),
                      for (final file in files) ...[
                        Divider(height: 1, thickness: 0.5, color: p.line),
                        _FileRow(
                          key: ValueKey('rd-file-${file.url}'),
                          compact: compact,
                          selecting: selecting,
                          file: file,
                          groups: widget.groups,
                          instruments: widget.data.partGroups,
                          onlyOnMac: waiting.any((c) => c.matches(c.tenantId, _songId, file)),
                          offerPlugin: !pluginInstalled,
                          selected: selected.contains(file.url),
                          cursor: _cursor == file.url,
                          renaming: _renaming == file.url,
                          renameController: _rename,
                          renameFocus: _renameFocus,
                          onTap: () => _tapRow(file),
                          onToggle: (v) => _toggle(file, v),
                          onCategory: (c) => _setCategory(file, c),
                          onRenameDone: (save) => _endRename(save: save),
                          onAction: (action, row) {
                            switch (action) {
                              case _RowAction.select:
                                _startSelecting(file);
                              case _RowAction.share:
                                rdShareSongFile(
                                  row,
                                  ref,
                                  file,
                                  subject: '${widget.data.song.name} · ${SongUtils.fileLabel(file, widget.groups)}',
                                  copiedMessage: l10n.songsLinkCopied,
                                );
                              case _RowAction.download:
                                _download([file]);
                              case _RowAction.rename:
                                _startRename(file);
                              case _RowAction.delete:
                                _delete([file]);
                              case _RowAction.sibelius:
                                rdEditInSibelius(context, ref, widget.data, file);
                              case _RowAction.sibeliusPlugin:
                                rdInstallSibeliusPlugin(context, ref);
                              case _RowAction.word:
                                rdEditInWord(context, ref, widget.data, file);
                              case _RowAction.replace:
                                rdReplaceWorkFile(context, ref, _songId, file);
                            }
                          },
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          if (files.isNotEmpty && isFileDropSupported) ...[
            const SizedBox(height: 8),
            Text(l10n.redesignFilesDropHint, style: RdType.meta(p, size: 13)),
          ],
        ],
      ),
    );
  }
}
