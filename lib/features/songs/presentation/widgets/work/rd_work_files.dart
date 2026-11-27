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
import '../../../../../core/theme/redesign/rd_palette.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
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
import '../../../data/import/rd_import_ai.dart' show rdImportAiProvider;
import '../../../data/import/rd_import_logic.dart' show RdImportCategory, RdImportPlan, RdImportQuestion;
import '../../../../../core/redesign/rd_words.dart';
import '../../../data/rd_work_files_controller.dart';
import '../../../data/rd_work_files_logic.dart';
import '../../../data/rd_work_upload_logic.dart';
import '../../../data/rd_works_logic.dart';
import '../../../data/sibelius/rd_sibelius_logic.dart' show RdSibeliusCheckout, rdIsSibeliusFile;
import '../../../data/sibelius/rd_sibelius_sync.dart';
import '../../../../../shared/widgets/redesign/rd_actions.dart';
import '../import/rd_import_widgets.dart' show rdImportCategoryLabel, rdImportCategoryOptions;
import 'rd_file_category_sheet.dart';
import 'rd_sibelius_actions.dart';
import 'rd_work_file_actions.dart' show rdReplaceWorkFile, rdIsAudioFile;
import '../../../../../shared/widgets/redesign/rd_widgets.dart';

/// REDESIGN: desktop file workspace of a Werk (shown on wide screens to
/// people who may edit it): the files as a table with part, type and
/// actions, multi-select with ZIP download, the upload queue and keys.
/// Files dropped anywhere on the Werk (see [RdWorkDropArea]) or picked with
/// "Hochladen" go through [rdAddWorkFiles].


part 'rd_work_files_upload.dart';
part 'rd_work_files_table.dart';
part 'rd_work_files_dialogs.dart';

/// Longest the Beta upload waits for page-1 reading of a whole drop.
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

  // ---------------------------------------------------------------- actions

  Future<void> _pickAndUpload() async {
    final files = await ref.read(songFileServiceProvider).pickMultipleFiles();
    if (files == null || files.isEmpty || !mounted) return;
    await rdAddWorkFiles(context, ref, widget.data, files);
  }

  Future<void> _open(SongFile file) async {
    if (rdOpensInSibelius(file)) {
      await rdEditInSibelius(context, ref, widget.data, file);
      return;
    }
    if (SongUtils.isAudio(file) || AudioPlayerService.isAudioFile(file.fileName)) {
      final audio = ref.read(audioPlayerServiceProvider);
      final service = ref.read(audioPlayerServiceProvider.notifier);
      if (audio.currentUrl == file.url) {
        await service.togglePlayPause();
      } else {
        await service.playFromUrl(file.url, file.fileName, widget.data.song.name);
      }
      return;
    }
    await openSongFile(context, file);
  }

  /// Offers the parts the Attendix plug-in exported for this Werk.
  Future<void> _takeSibeliusParts(String folder) async {
    try {
      if (!mounted) return;
      final sync = ref.read(rdSibeliusSyncProvider.notifier);
      final taken = await sync.takeParts(folder);
      if (taken == null || !mounted) return;
      // Leaving the page before answering keeps them for the next visit.
      final answered =
          taken.files.isEmpty || await rdAddWorkFiles(context, ref, widget.data, taken.files, fromSibelius: true);
      if (answered) {
        await sync.partsAnswered(taken.parts);
      } else {
        sync.partsKept(taken.parts);
      }
    } catch (e) {
      if (mounted) ToastHelper.showError(context, friendlyErrorMessage(e));
    } finally {
      _takingParts = false;
    }
  }

  Future<void> _run(Future<void> Function() task) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await task();
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, e is ZipDownloadException ? e.message(context.l10n) : friendlyErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download(List<SongFile> files) async {
    if (files.isEmpty) return;
    final l10n = context.l10n;
    if (files.length == 1) {
      final file = files.single;
      return _run(() async {
        final bytes = await ref.read(songFileServiceProvider).downloadFileBytes(file.url);
        if (bytes == null) throw Exception(l10n.songsFlutterDownloadFileFailed);
        await file_saver.saveZipFile(bytes, file.fileName);
      });
    }
    ref.read(rdWorkFilesProvider(_songId).notifier).showNotice(l10n.redesignFilesZipPreparing);
    return _run(
      () => ref
          .read(zipServiceProvider)
          .downloadSongFilesAsZip(
            files: files,
            songName: widget.data.song.name.isEmpty ? 'songs' : widget.data.song.name,
          ),
    );
  }

  void _delete(List<SongFile> files) {
    if (files.isEmpty) return;
    final l10n = context.l10n;
    final order = _current.map((f) => f.url).toList();
    final gone = {for (final f in files) f.url};
    // The keyboard row moves to the next file that stays.
    final start = order.indexOf(_cursor ?? files.first.url);
    String? next;
    for (var i = start < 0 ? 0 : start; i < order.length && next == null; i++) {
      if (!gone.contains(order[i])) next = order[i];
    }
    for (var i = (start < 0 ? order.length : start) - 1; i >= 0 && next == null; i--) {
      if (!gone.contains(order[i])) next = order[i];
    }
    setState(() {
      _selected = {};
      _selecting = false;
      _cursor = next;
      _anchor = next;
    });
    ref
        .read(rdWorkFilesProvider(_songId).notifier)
        .delete(
          files,
          mainGroupId: widget.data.mainGroupId,
          notice:
              files.length == 1
                  ? l10n.redesignFilesDeletedOne(files.single.fileName)
                  : l10n.redesignFilesDeletedMany(files.length),
        );
    _focus.requestFocus();
  }

  void _undo() {
    ref.read(rdWorkFilesProvider(_songId).notifier).undoDelete(notice: context.l10n.redesignFilesRestored);
  }

  Future<void> _setCategory(SongFile file, _Category? category) async {
    var target = category;
    if (target == null) {
      // "Sonstige …": free text in the dialog of the old page.
      final result = await showRdFileCategorySheet(
        context,
        title: file.fileName,
        instruments: widget.data.partGroups,
        isChoir: widget.data.isChoir,
        initialInstrumentId: null,
        initialNote: file.instrumentId == null ? (file.note ?? '') : '',
      );
      if (result == null) return;
      target = (id: result.instrumentId, note: result.note);
    }
    if (target.id == file.instrumentId && (target.id != null || target.note == file.note)) return;
    final chosen = target;
    await _run(
      () => ref
          .read(rdWorkFilesProvider(_songId).notifier)
          .setCategory(file, chosen.id, chosen.note, mainGroupId: widget.data.mainGroupId),
    );
  }

  void _startRename(SongFile file) {
    if (!rdCanRename(file)) return;
    setState(() {
      _renaming = file.url;
      _cursor = file.url;
    });
    final dot = file.fileName.lastIndexOf('.');
    _rename.value = TextEditingValue(
      text: file.fileName,
      selection: TextSelection(baseOffset: 0, extentOffset: dot > 0 ? dot : file.fileName.length),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _renameFocus.requestFocus();
    });
  }

  void _endRename({required bool save}) {
    final url = _renaming;
    if (url == null) return;
    setState(() => _renaming = null);
    _focus.requestFocus();
    if (!save) return;
    final file = _current.where((f) => f.url == url).firstOrNull;
    if (file == null) return;
    final name = rdRenamedFileName(file.fileName, _rename.text);
    if (name == null) return;
    _run(() => ref.read(rdWorkFilesProvider(_songId).notifier).rename(file, name));
  }

  // -------------------------------------------------------------- selection

  bool get _modPressed {
    final keys = HardwareKeyboard.instance;
    return keys.isMetaPressed || keys.isControlPressed;
  }

  /// A plain click opens the file; in selection mode it toggles the row.
  /// ⌘/Strg- and Umschalt-clicks still select (and start selection mode).
  void _tapRow(SongFile file) {
    final order = _current.map((f) => f.url).toList();
    final shift = HardwareKeyboard.instance.isShiftPressed;
    if (!_selecting && !_modPressed && !shift) {
      setState(() {
        _cursor = file.url;
        _anchor = file.url;
      });
      _focus.requestFocus();
      _open(file);
      return;
    }
    setState(() {
      _selecting = true;
      if (shift && _anchor != null) {
        _selected = rdRangeSelection(order, _anchor!, file.url);
      } else if (_modPressed) {
        _selected = {..._selected};
        if (!_selected.remove(file.url)) _selected.add(file.url);
        _anchor = file.url;
      } else {
        _selected = {..._selected};
        if (!_selected.remove(file.url)) _selected.add(file.url);
        _anchor = file.url;
      }
      _cursor = file.url;
    });
    _focus.requestFocus();
  }

  void _startSelecting([SongFile? file]) {
    setState(() {
      _selecting = true;
      if (file != null) {
        _selected = {..._selected, file.url};
        _anchor = file.url;
        _cursor = file.url;
      }
    });
    _focus.requestFocus();
  }

  void _stopSelecting() {
    setState(() {
      _selecting = false;
      _selected = {};
    });
    _focus.requestFocus();
  }

  void _toggle(SongFile file, bool? value) {
    setState(() {
      _selecting = true;
      _selected = {..._selected};
      value == true ? _selected.add(file.url) : _selected.remove(file.url);
      _anchor = file.url;
      _cursor = file.url;
    });
    _focus.requestFocus();
  }

  void _selectAll(List<SongFile> files, bool all) {
    setState(() {
      if (all) _selecting = true;
      _selected = all ? {for (final f in files) f.url} : {};
    });
    _focus.requestFocus();
  }

  /// ↑ ↓ (with Umschalt: extend the selection), Enter open, Leertaste
  /// preview / play, Entf delete, ⌘/Strg + U upload, A all, D download,
  /// Z undo, F2 rename, Esc clear the selection. Typing in a text field is
  /// left alone.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (_renaming != null) return KeyEventResult.ignored;
    final primary = FocusManager.instance.primaryFocus;
    if (primary != null && primary != node && primary.context?.findAncestorWidgetOfExactType<EditableText>() != null) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    // Held keys repeat only ↑ ↓; a held Entf must not delete row after row
    // (each delete stores the one before, Rückgängig brings back only one).
    if (event is KeyRepeatEvent && key != LogicalKeyboardKey.arrowDown && key != LogicalKeyboardKey.arrowUp) {
      return KeyEventResult.handled;
    }
    final files = _current;
    final order = files.map((f) => f.url).toList();
    final mod = _modPressed;

    if (mod) {
      switch (key) {
        case LogicalKeyboardKey.keyA:
          _selectAll(files, true);
        case LogicalKeyboardKey.keyU:
          _pickAndUpload();
        case LogicalKeyboardKey.keyD:
          final targets = _targets();
          _download(targets.isEmpty ? files : targets);
        case LogicalKeyboardKey.keyZ:
          if (!ref.read(rdWorkFilesProvider(_songId).notifier).canUndoDelete) return KeyEventResult.ignored;
          _undo();
        default:
          return KeyEventResult.ignored;
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp) {
      if (order.isEmpty) return KeyEventResult.handled;
      final current = _cursor == null ? null : order.indexOf(_cursor!);
      final next =
          order[rdNextIndex(
            current == -1 ? null : current,
            key == LogicalKeyboardKey.arrowDown ? 1 : -1,
            order.length,
          )];
      setState(() {
        if (HardwareKeyboard.instance.isShiftPressed) {
          _anchor ??= _cursor ?? next;
          _selected = rdRangeSelection(order, _anchor!, next);
          _selecting = true;
        } else {
          // Outside selection mode ↑ ↓ only move the row marker (Enter
          // opens it, Entf deletes it); in selection mode they select.
          if (_selecting) _selected = {next};
          _anchor = next;
        }
        _cursor = next;
      });
      return KeyEventResult.handled;
    }

    if (event.character == '?') {
      showRdWorkFilesShortcuts(context);
      return KeyEventResult.handled;
    }

    final cursorFile = files.where((f) => f.url == _cursor).firstOrNull;
    switch (key) {
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
      case LogicalKeyboardKey.space:
        if (cursorFile == null) return KeyEventResult.ignored;
        _open(cursorFile);
      case LogicalKeyboardKey.delete:
      case LogicalKeyboardKey.backspace:
        final targets = _targets();
        if (targets.isEmpty) return KeyEventResult.ignored;
        _delete(targets);
      case LogicalKeyboardKey.f2:
        if (cursorFile == null) return KeyEventResult.ignored;
        _startRename(cursorFile);
      case LogicalKeyboardKey.escape:
        if (_selected.isEmpty && !_selecting) return KeyEventResult.ignored;
        _stopSelecting();
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
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
