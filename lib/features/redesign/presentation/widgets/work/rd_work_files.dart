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
    if (dart.library.html) '../../../../../core/services/zip_service_web.dart'
    as file_saver;
import '../../../../../core/theme/redesign/rd_palette.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../core/utils/error_message.dart';
import '../../../../../core/utils/instrument_matcher.dart';
import '../../../../../core/utils/toast_helper.dart';
import '../../../../../data/models/instrument/instrument.dart';
import '../../../../../data/models/song/song.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/widgets/adaptive/app_dialog.dart';
import '../../../../../shared/widgets/adaptive/app_select.dart';
import '../../../../songs/presentation/pages/song_detail_page.dart' show FileCategoryDialog;
import '../../../../songs/presentation/utils/song_utils.dart';
import '../../../../songs/presentation/widgets/file_drop/file_drop_target.dart';
import '../../../../songs/presentation/widgets/file_upload_sheet.dart' show FileCategoryGuess, guessFileCategory, learnableTerm;
import '../../../../songs/presentation/widgets/song_file_opener.dart';
import '../../../data/rd_work_files_controller.dart';
import '../../../data/rd_work_files_logic.dart';
import '../../../data/rd_works_logic.dart';
import '../../rd_actions.dart';
import '../rd_widgets.dart';

/// REDESIGN: desktop file workspace of a Werk (shown on wide screens to
/// people who may edit it): the files as a table with part, type and
/// actions, multi-select with ZIP download, the upload queue and keys.
/// Files dropped anywhere on the Werk (see [RdWorkDropArea]) or picked with
/// "Hochladen" go through [rdAddWorkFiles].

/// Longest the Beta upload waits for page-1 reading of a whole drop.
const Duration rdVisionBudget = Duration(minutes: 1);

/// Width from which the Werk page shows the workspace.
const double rdWorkFilesMinWidth = 560;

/// Files of [data] that are not deleted a moment ago.
List<SongFile> rdVisibleFiles(SongDetailData data, Set<String> hidden) =>
    (data.song.files ?? const <SongFile>[]).where((f) => !hidden.contains(f.url)).toList();

/// Sorts [files] into parts (as the old upload sheet), asks once what to do
/// with files that are already there and puts them into the upload queue.
Future<void> rdAddWorkFiles(BuildContext context, WidgetRef ref, SongDetailData data, List<PlatformFile> files) async {
  final l10n = context.l10n;
  final songId = data.song.id;
  if (songId == null || files.isEmpty) return;
  final controller = ref.read(rdWorkFilesProvider(songId).notifier);
  final existing = rdVisibleFiles(data, ref.read(rdWorkFilesProvider(songId)).hidden);
  final instruments = [
    for (final g in data.instruments)
      if (g.id != null) InstrumentInfo(id: g.id!, name: g.name, synonyms: g.synonyms),
  ];

  final guesses = <({PlatformFile file, FileCategoryGuess guess})>[];
  for (final file in files) {
    if (file.size > rdMaxUploadBytes) {
      ToastHelper.showError(context, l10n.songsFileTooLarge(file.name));
      continue;
    }
    guesses.add((file: file, guess: guessFileCategory(file.name, instruments: instruments, isChoir: data.isChoir)));
  }
  if (guesses.isEmpty) return;

  // Unclear names: the part printed on page 1 (`part-detect`), one at a time.
  final unclear = [
    for (var i = 0; i < guesses.length; i++)
      if (instruments.isNotEmpty && guesses[i].guess.canAskVision(guesses[i].file.name)) i,
  ];
  if (unclear.isNotEmpty) {
    controller.showNotice(l10n.songsFlutterVisionReading);
    final vision = ref.read(partVisionServiceProvider);
    // The tenant of this drop: after a switch nothing more is sent for it.
    final tenantId = vision.currentTenant();
    // A minute in all; files not read by then keep the file-name result
    // (and land in the review below).
    final clock = Stopwatch()..start();
    for (final i in unclear) {
      final left = rdVisionBudget - clock.elapsed;
      if (left <= Duration.zero || !context.mounted) break;
      // Each file gets at most what is left of the minute; leaving the page
      // stops it.
      final match = await vision.detect(
        guesses[i].file,
        instruments,
        limit: left,
        tenantId: tenantId,
        cancelled: () => !context.mounted,
      );
      if (match != null) guesses[i] = (file: guesses[i].file, guess: FileCategoryGuess.vision(match));
    }
    if (!context.mounted) return;
  }

  // Files whose part is not clear are checked first; terms assigned by hand
  // can be remembered as synonyms of the group.
  final chosen = <PlatformFile, ({int? instrumentId, String? note})>{
    for (final g in guesses) g.file: (instrumentId: g.guess.instrumentId, note: g.guess.note),
  };
  final review = guesses.where((g) => g.guess.needsReview).toList();
  var terms = const <int, List<String>>{};
  if (review.isNotEmpty) {
    final result = await showAppDialog<_ReviewResult>(
      context: context,
      builder: (_) => _ReviewDialog(items: review, groups: data.instruments, instruments: instruments, workName: data.song.name),
    );
    if (result == null || !context.mounted) return;
    chosen.addAll(result.categories);
    terms = result.terms;
  }

  final items = <({PlatformFile file, int? instrumentId, String? note, List<SongFile> conflicts})>[
    for (final g in guesses)
      (
        file: g.file,
        instrumentId: chosen[g.file]!.instrumentId,
        note: chosen[g.file]!.note,
        conflicts: rdUploadConflicts(g.file.name, chosen[g.file]!.instrumentId, existing),
      ),
  ];

  var replace = false;
  final clashing = items.where((i) => i.conflicts.isNotEmpty).toList();
  if (clashing.isNotEmpty) {
    final choice = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => _ConflictDialog(items: clashing, groups: data.instruments),
    );
    if (choice == null) return;
    replace = choice;
  }
  controller.enqueue([
    for (final i in items)
      (file: i.file, instrumentId: i.instrumentId, note: i.note, replace: replace ? i.conflicts : const <SongFile>[]),
  ], mainGroupId: data.mainGroupId);

  // Only once the upload is really started (not on "Abbrechen" in the
  // conflict dialog).
  if (terms.isNotEmpty && context.mounted) {
    final notifier = ref.read(groupNotifierProvider.notifier);
    final ok = await notifier.addSynonyms(terms);
    if (!ok && context.mounted) ToastHelper.showError(context, l10n.songsFlutterLearnFailed);
  }
}

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

  /// Keyboard row (by URL) and start of a Umschalt range.
  String? _cursor;
  String? _anchor;

  /// File being renamed (by URL).
  String? _renaming;
  bool _busy = false;

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

  Future<void> _run(Future<void> Function() task) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await task();
    } catch (e) {
      if (mounted) ToastHelper.showError(context, friendlyErrorMessage(e));
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
      final result = await showAppDialog<({int? instrumentId, String? note})>(
        context: context,
        builder:
            (_) => FileCategoryDialog(
              instruments: widget.data.instruments,
              initialInstrumentId: null,
              initialNote: file.instrumentId == null ? (file.note ?? '') : '',
            ),
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

  void _tapRow(SongFile file) {
    final order = _current.map((f) => f.url).toList();
    final shift = HardwareKeyboard.instance.isShiftPressed;
    setState(() {
      if (shift && _anchor != null) {
        _selected = rdRangeSelection(order, _anchor!, file.url);
      } else if (_modPressed) {
        _selected = {..._selected};
        if (!_selected.remove(file.url)) _selected.add(file.url);
        _anchor = file.url;
      } else {
        _selected = {file.url};
        _anchor = file.url;
      }
      _cursor = file.url;
    });
    _focus.requestFocus();
  }

  void _toggle(SongFile file, bool? value) {
    setState(() {
      _selected = {..._selected};
      value == true ? _selected.add(file.url) : _selected.remove(file.url);
      _anchor = file.url;
      _cursor = file.url;
    });
    _focus.requestFocus();
  }

  void _selectAll(List<SongFile> files, bool all) {
    setState(() => _selected = all ? {for (final f in files) f.url} : {});
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
        } else {
          _selected = {next};
          _anchor = next;
        }
        _cursor = next;
      });
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
        if (_selected.isEmpty) return KeyEventResult.ignored;
        setState(() => _selected = {});
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
    final urls = {for (final f in files) f.url};
    // Rows that disappeared (deleted elsewhere) leave the selection.
    final selected = _selected.where(urls.contains).toSet();
    final allSelected = files.isNotEmpty && selected.length == files.length;
    final isMac = defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS;
    final modLabel = isMac ? '⌘' : (Localizations.localeOf(context).languageCode == 'de' ? 'Strg' : 'Ctrl');

    final toolbar = Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              selected.isEmpty
                  ? '${l10n.redesignFilesTitle} · ${files.length}'
                  : l10n.redesignFilesSelected(selected.length),
              style: RdType.section(p),
            ),
          ),
        ),
        if (selected.isNotEmpty) ...[
          _ToolButton(
            icon: Icons.download_outlined,
            label: selected.length == 1 ? l10n.redesignFilesDownload : l10n.redesignFilesDownloadZip,
            onPressed: _busy ? null : () => _download(files.where((f) => selected.contains(f.url)).toList()),
          ),
          _ToolButton(
            icon: Icons.delete_outline,
            label: l10n.redesignFilesDelete,
            color: p.absent,
            onPressed: () => _delete(files.where((f) => selected.contains(f.url)).toList()),
          ),
          IconButton(
            tooltip: l10n.redesignCommonCancel,
            icon: Icon(Icons.close, color: p.text2),
            onPressed: () => _selectAll(files, false),
          ),
        ] else ...[
          if (files.length > 1)
            _ToolButton(
              icon: Icons.folder_zip_outlined,
              label: l10n.redesignFilesDownloadAll,
              onPressed: _busy ? null : () => _download(files),
            ),
          IconButton(
            tooltip: l10n.redesignFilesShortcuts,
            icon: Icon(Icons.keyboard_outlined, color: p.text2),
            onPressed:
                () => showAppDialog<void>(
                  context: context,
                  builder: (_) => _ShortcutsDialog(help: l10n.redesignFilesShortcutsHelp(modLabel)),
                ),
          ),
          const SizedBox(width: 4),
          RdPrimaryButton(
            label: l10n.redesignFilesUpload,
            icon: Icons.upload_outlined,
            height: 40,
            onPressed: _pickAndUpload,
          ),
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
          if (state.uploads.isNotEmpty) ...[
            _UploadQueue(
              state: state,
              groups: widget.groups,
              onRetry: (id) => ref.read(rdWorkFilesProvider(_songId).notifier).retry(id),
              onDismiss: () => ref.read(rdWorkFilesProvider(_songId).notifier).dismissFinished(),
            ),
            const SizedBox(height: 12),
          ],
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
                        allSelected: allSelected,
                        someSelected: selected.isNotEmpty,
                        onSelectAll: (v) => _selectAll(files, v ?? false),
                      ),
                      for (final file in files) ...[
                        Divider(height: 1, thickness: 0.5, color: p.line),
                        _FileRow(
                          key: ValueKey('rd-file-${file.url}'),
                          compact: compact,
                          file: file,
                          groups: widget.groups,
                          instruments: widget.data.instruments,
                          selected: selected.contains(file.url),
                          cursor: _cursor == file.url,
                          renaming: _renaming == file.url,
                          renameController: _rename,
                          renameFocus: _renameFocus,
                          onTap: () => _tapRow(file),
                          onDoubleTap: () => _open(file),
                          onToggle: (v) => _toggle(file, v),
                          onCategory: (c) => _setCategory(file, c),
                          onRenameDone: (save) => _endRename(save: save),
                          onAction: (action, row) {
                            switch (action) {
                              case _RowAction.open:
                                _open(file);
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

class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.icon, required this.label, required this.onPressed, this.color});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: color ?? p.link,
        minimumSize: const Size(0, 40),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Empty Werk: a frame to drop files into or to click for the picker.
class _DropHint extends StatelessWidget {
  const _DropHint({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return RdCard(
      onTap: onTap,
      border: Border.all(color: p.offBorder, width: 1.5),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        children: [
          Icon(Icons.cloud_upload_outlined, size: 36, color: p.text2),
          const SizedBox(height: 8),
          Text(
            isFileDropSupported ? context.l10n.redesignFilesDropHint : context.l10n.redesignFilesPickHint,
            textAlign: TextAlign.center,
            style: RdType.meta(p, size: 15),
          ),
        ],
      ),
    );
  }
}

const double _checkWidth = 44;
const double _partWidth = 200;
const double _partWidthCompact = 140;
const double _typeWidth = 64;
const double _menuWidth = 44;

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.compact,
    required this.allSelected,
    required this.someSelected,
    required this.onSelectAll,
  });

  final bool compact;
  final bool allSelected;
  final bool someSelected;
  final ValueChanged<bool?> onSelectAll;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final style = TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.text2, letterSpacing: 0.3);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: _checkWidth,
            child: Checkbox(
              tristate: true,
              value: allSelected ? true : (someSelected ? null : false),
              activeColor: p.primary,
              semanticLabel: l10n.redesignFilesSelectAll,
              onChanged: (_) => onSelectAll(!allSelected),
            ),
          ),
          const SizedBox(width: 36),
          Expanded(child: Text(l10n.redesignFilesColName.toUpperCase(), style: style)),
          SizedBox(
            width: compact ? _partWidthCompact : _partWidth,
            child: Text(l10n.redesignFilesColPart.toUpperCase(), style: style),
          ),
          if (!compact) SizedBox(width: _typeWidth, child: Text(l10n.redesignFilesColType.toUpperCase(), style: style)),
          const SizedBox(width: _menuWidth),
        ],
      ),
    );
  }
}

enum _RowAction { open, share, download, rename, delete }

class _FileRow extends StatelessWidget {
  const _FileRow({
    super.key,
    required this.compact,
    required this.file,
    required this.groups,
    required this.instruments,
    required this.selected,
    required this.cursor,
    required this.renaming,
    required this.renameController,
    required this.renameFocus,
    required this.onTap,
    required this.onDoubleTap,
    required this.onToggle,
    required this.onCategory,
    required this.onRenameDone,
    required this.onAction,
  });

  final SongFile file;
  final List<Group> groups;

  /// Groups a file can be moved to (as the old category dialog).
  final List<Group> instruments;
  final bool selected;
  final bool cursor;
  final bool compact;
  final bool renaming;
  final TextEditingController renameController;
  final FocusNode renameFocus;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final ValueChanged<bool?> onToggle;

  /// null: "Sonstige …" (free text).
  final ValueChanged<_Category?> onCategory;
  final ValueChanged<bool> onRenameDone;
  /// The row's context comes along as anchor for the share sheet.
  final void Function(_RowAction action, BuildContext row) onAction;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final isAudio = SongUtils.isAudio(file);
    final icon =
        isAudio
            ? Icons.graphic_eq
            : (SongUtils.isPdf(file) ? Icons.description_outlined : Icons.insert_drive_file_outlined);

    final name =
        renaming
            ? CallbackShortcuts(
              bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => onRenameDone(false)},
              child: TextField(
                controller: renameController,
                focusNode: renameFocus,
                autofocus: true,
                style: TextStyle(fontSize: 15, color: p.text),
                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                onSubmitted: (_) => onRenameDone(true),
                onTapOutside: (_) => onRenameDone(true),
              ),
            )
            : Text(
              file.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: p.text),
            );

    return Semantics(
      selected: selected,
      child: Material(
        color: selected ? p.soft : (cursor ? p.track.withValues(alpha: 0.5) : Colors.transparent),
        child: InkWell(
          onTap: onTap,
          onDoubleTap: onDoubleTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: _checkWidth,
                  child: Checkbox(
                    value: selected,
                    activeColor: p.primary,
                    semanticLabel: file.fileName,
                    onChanged: onToggle,
                  ),
                ),
                SizedBox(width: 36, child: Icon(icon, size: 22, color: p.text2)),
                Expanded(child: name),
                const SizedBox(width: 8),
                SizedBox(
                  width: compact ? _partWidthCompact : _partWidth,
                  child: _CategoryButton(file: file, groups: groups, instruments: instruments, onSelected: onCategory),
                ),
                if (!compact)
                  SizedBox(width: _typeWidth, child: Text(rdFileKind(file), style: RdType.meta(p, size: 13))),
                SizedBox(
                  width: _menuWidth,
                  child: PopupMenuButton<_RowAction>(
                    tooltip: l10n.redesignFilesActions(file.fileName),
                    icon: Icon(Icons.more_horiz, color: p.text2),
                    onSelected: (action) => onAction(action, context),
                    itemBuilder:
                        (_) => [
                          _menuItem(_RowAction.open, Icons.open_in_new, l10n.redesignFilesOpen),
                          _menuItem(_RowAction.share, Icons.ios_share, l10n.redesignWorkShare),
                          _menuItem(_RowAction.download, Icons.download_outlined, l10n.redesignFilesDownload),
                          if (rdCanRename(file))
                            _menuItem(_RowAction.rename, Icons.drive_file_rename_outline, l10n.redesignFilesRename),
                          _menuItem(_RowAction.delete, Icons.delete_outline, l10n.redesignFilesDelete, color: p.absent),
                        ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<_RowAction> _menuItem(_RowAction value, IconData icon, String label, {Color? color}) => PopupMenuItem(
    value: value,
    child: Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: color)),
      ],
    ),
  );
}

/// "Stimme" cell: the current part; a click opens the parts to move to.
class _CategoryButton extends StatelessWidget {
  const _CategoryButton({
    required this.file,
    required this.groups,
    required this.instruments,
    required this.onSelected,
  });

  final SongFile file;
  final List<Group> groups;
  final List<Group> instruments;
  final ValueChanged<_Category?> onSelected;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final options = <(_Category, String)>[
      for (final g in instruments)
        if (g.id != null) ((id: g.id, note: null), g.name),
      ((id: 1, note: null), l10n.songsRecording),
      ((id: 2, note: null), l10n.songsLyrics),
      ((id: null, note: 'Partitur'), 'Partitur'),
      ((id: null, note: 'Klavierauszug'), 'Klavierauszug'),
    ];
    return PopupMenuButton<int>(
      tooltip: l10n.songsChangeCategory,
      position: PopupMenuPosition.under,
      onSelected: (i) => onSelected(i < 0 ? null : options[i].$1),
      itemBuilder:
          (_) => [
            for (var i = 0; i < options.length; i++)
              CheckedPopupMenuItem(
                value: i,
                checked:
                    options[i].$1.id == file.instrumentId &&
                    (options[i].$1.id != null || options[i].$1.note == file.note),
                child: Text(options[i].$2),
              ),
            const PopupMenuDivider(),
            PopupMenuItem(value: -1, child: Text(l10n.redesignFilesOtherCategory)),
          ],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Flexible(
              child: Text(
                SongUtils.fileLabel(file, groups),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: p.link, fontWeight: FontWeight.w500),
              ),
            ),
            Icon(Icons.arrow_drop_down, color: p.link),
          ],
        ),
      ),
    );
  }
}

/// The upload queue: "Hochladen: 3 von 7", a bar and one row per file.
class _UploadQueue extends StatelessWidget {
  const _UploadQueue({required this.state, required this.groups, required this.onRetry, required this.onDismiss});

  final RdWorkFilesState state;
  final List<Group> groups;
  final ValueChanged<int> onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final finished = state.doneCount + state.failedCount;
    return RdCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    state.busy
                        ? l10n.redesignFilesQueueTitle(finished, state.total)
                        : l10n.redesignFilesQueueDone(state.doneCount),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.text),
                  ),
                ),
              ),
              if (!state.busy) RdTextLink(label: l10n.redesignFilesDismiss, onTap: onDismiss),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 4,
              value: state.total == 0 ? 0 : finished / state.total,
              color: state.failedCount > 0 ? p.late : p.primary,
              backgroundColor: p.track,
            ),
          ),
          const SizedBox(height: 4),
          for (final u in state.uploads)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  SizedBox(width: 28, child: _statusIcon(p, u.status)),
                  Expanded(
                    child: Text(
                      u.file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: p.text),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 160,
                    child: Text(
                      SongUtils.fileLabel(
                        SongFile(
                          fileName: u.file.name,
                          fileType: '',
                          url: '',
                          instrumentId: u.instrumentId,
                          note: u.note,
                        ),
                        groups,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RdType.meta(p, size: 13),
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child:
                        u.status == RdUploadStatus.failed
                            ? Align(
                              alignment: Alignment.centerRight,
                              child: Tooltip(
                                message: u.error ?? '',
                                child: RdTextLink(label: l10n.redesignCommonRetry, onTap: () => onRetry(u.id)),
                              ),
                            )
                            : Text(
                              switch (u.status) {
                                RdUploadStatus.waiting => l10n.redesignFilesWaiting,
                                RdUploadStatus.uploading => l10n.redesignFilesUploading,
                                _ => l10n.redesignFilesDone,
                              },
                              textAlign: TextAlign.end,
                              style: RdType.meta(p, size: 13),
                            ),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusIcon(RdPalette p, RdUploadStatus status) => switch (status) {
    RdUploadStatus.waiting => Icon(Icons.schedule, size: 18, color: p.text2),
    RdUploadStatus.uploading => SizedBox(
      width: 16,
      height: 16,
      child: Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: p.primary)),
      ),
    ),
    RdUploadStatus.done => Icon(Icons.check_circle, size: 18, color: p.present),
    RdUploadStatus.failed => Icon(Icons.error_outline, size: 18, color: p.absent),
  };
}

/// "Schon vorhanden": the files that clash, "Ersetzen" (true) or "Beide
/// behalten" (false).
class _ConflictDialog extends StatelessWidget {
  const _ConflictDialog({required this.items, required this.groups});

  final List<({PlatformFile file, int? instrumentId, String? note, List<SongFile> conflicts})> items;
  final List<Group> groups;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppAlertDialog(
      title: Text(l10n.redesignFilesConflictTitle),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.redesignFilesConflictMessage(items.length)),
              const SizedBox(height: 12),
              for (final i in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${i.file.name} → ${i.conflicts.map((c) => c.fileName).join(', ')}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel)),
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.redesignFilesKeepBoth)),
        TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.redesignFilesReplace)),
      ],
    );
  }
}

typedef _ReviewResult = ({
  Map<PlatformFile, ({int? instrumentId, String? note})> categories,
  Map<int, List<String>> terms,
});

/// "Zuordnung prüfen": the dropped files whose part was not recognised for
/// sure, each with a part menu and "künftig so erkennen" once changed.
class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({required this.items, required this.groups, required this.instruments, required this.workName});

  final List<({PlatformFile file, FileCategoryGuess guess})> items;
  final List<Group> groups;
  final List<InstrumentInfo> instruments;
  final String workName;

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  late final Map<PlatformFile, int?> _ids = {for (final i in widget.items) i.file: i.guess.instrumentId};
  /// An unsure part can be confirmed for learning right away (unchecked).
  late final Map<PlatformFile, String> _terms = {
    for (final i in widget.items)
      if (i.guess.confidence == MatchConfidence.unsure && !i.guess.byVision)
        if (learnableTerm(i.file.name, chosenId: i.guess.instrumentId, instruments: widget.instruments, workName: widget.workName)
            case final term?)
          i.file: term,
  };
  final Set<PlatformFile> _learn = {};

  void _choose(PlatformFile file, int? id) {
    setState(() {
      _ids[file] = id;
      final term = learnableTerm(file.name, chosenId: id, instruments: widget.instruments, workName: widget.workName);
      if (term == null) {
        _terms.remove(file);
        _learn.remove(file);
      } else {
        _terms[file] = term;
        _learn.add(file);
      }
    });
  }

  void _submit() {
    Navigator.pop<_ReviewResult>(context, (
      categories: {
        for (final i in widget.items)
          i.file: (
            instrumentId: _ids[i.file],
            note: _ids[i.file] == null ? i.guess.note : null,
          ),
      },
      terms: _learnedTerms(),
    ));
  }

  /// What page 1 showed: the printed name, else the group it was matched to.
  String _visionLabel(FileCategoryGuess guess) =>
      guess.term ?? widget.groups.where((g) => g.id == guess.instrumentId).firstOrNull?.name ?? '';

  Map<int, List<String>> _learnedTerms() {
    final terms = <int, List<String>>{};
    for (final f in _learn) {
      final id = _ids[f];
      final term = _terms[f];
      if (id != null && term != null) (terms[id] ??= []).add(term);
    }
    return terms;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.rd;
    final menu = <DropdownMenuItem<int?>>[
      DropdownMenuItem(value: null, child: Text(l10n.songsOther)),
      DropdownMenuItem(value: InstrumentMatcher.recordingId, child: Text(l10n.songsRecording)),
      DropdownMenuItem(value: InstrumentMatcher.lyricsId, child: Text(l10n.songsLyrics)),
      for (final g in widget.groups)
        if (g.id != null) DropdownMenuItem(value: g.id, child: Text(g.name)),
    ];
    return AppAlertDialog(
      title: Text(l10n.songsFlutterReviewTitle),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.songsFlutterReviewHint),
              const SizedBox(height: 12),
              for (final i in widget.items) ...[
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(i.file.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          Text(
                            i.guess.byVision && i.guess.confidence == MatchConfidence.sure
                                ? l10n.songsFlutterVisionSure(_visionLabel(i.guess))
                                : i.guess.byVision
                                ? l10n.songsFlutterVisionUnsure
                                : i.guess.confidence == MatchConfidence.unsure
                                ? l10n.songsFlutterDetectUnsure
                                : l10n.songsFlutterDetectNone,
                            style: TextStyle(
                              fontSize: 12,
                              color: i.guess.confidence == MatchConfidence.sure
                                  ? p.present
                                  : i.guess.confidence == MatchConfidence.unsure
                                  ? p.late
                                  : p.absent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 180,
                      child: AppDropdownButton<int?>(
                        value: _ids[i.file],
                        items: menu,
                        isExpanded: true,
                        onChanged: (id) => _choose(i.file, id),
                      ),
                    ),
                  ],
                ),
                if (_terms[i.file] != null && _ids[i.file] != null)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _learn.contains(i.file),
                    title: Text(
                      l10n.songsFlutterLearnTerm(
                        _terms[i.file]!,
                        widget.groups.where((g) => g.id == _ids[i.file]).firstOrNull?.name ?? '',
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                    onChanged: (v) => setState(() => v == true ? _learn.add(i.file) : _learn.remove(i.file)),
                  ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel)),
        TextButton(onPressed: _submit, child: Text(l10n.songsFlutterReviewUpload)),
      ],
    );
  }
}

/// The shortcuts of the file table, one per line (the toolbar's keyboard icon).
class _ShortcutsDialog extends StatelessWidget {
  const _ShortcutsDialog({required this.help});

  /// `redesignFilesShortcutsHelp`: the shortcuts separated by " · ".
  final String help;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppAlertDialog(
      title: Text(l10n.redesignFilesShortcuts),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in help.split(' · '))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(line, style: const TextStyle(fontSize: 14)),
                ),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonOk))],
    );
  }
}
