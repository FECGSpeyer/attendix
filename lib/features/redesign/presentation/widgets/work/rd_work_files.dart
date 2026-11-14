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
import '../../../../songs/presentation/utils/song_utils.dart';
import '../../../../songs/presentation/widgets/file_drop/file_drop_target.dart';
import '../../../../songs/presentation/widgets/file_upload_sheet.dart' show learnableTerm;
import '../../../../songs/presentation/widgets/song_file_opener.dart';
import '../../../data/import/rd_import_ai.dart' show rdImportAiProvider;
import '../../../data/import/rd_import_logic.dart' show RdImportCategory, RdImportPlan, RdImportQuestion;
import '../../../data/rd_words.dart';
import '../../../data/rd_work_files_controller.dart';
import '../../../data/rd_work_files_logic.dart';
import '../../../data/rd_work_upload_logic.dart';
import '../../../data/rd_works_logic.dart';
import '../../../data/sibelius/rd_sibelius_logic.dart' show RdSibeliusCheckout, rdIsSibeliusFile;
import '../../../data/sibelius/rd_sibelius_sync.dart';
import '../../rd_actions.dart';
import '../import/rd_import_widgets.dart' show rdImportCategoryLabel, rdImportCategoryOptions;
import 'rd_file_category_sheet.dart';
import 'rd_sibelius_actions.dart';
import 'rd_work_file_actions.dart' show rdReplaceWorkFile, rdIsAudioFile;
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
///
/// [fromSibelius]: part PDFs exported by the Attendix plug-in. One list
/// shows each with its part and the PDF it replaces; both can be changed
/// and parts left out.
///
/// Returns false when it stopped without an answer (the page was left).
Future<bool> rdAddWorkFiles(
  BuildContext context,
  WidgetRef ref,
  SongDetailData data,
  List<PlatformFile> files, {
  bool fromSibelius = false,
}) async {
  final l10n = context.l10n;
  final songId = data.song.id;
  if (songId == null || files.isEmpty) return true;
  final controller = ref.read(rdWorkFilesProvider(songId).notifier);
  final existing = rdVisibleFiles(data, ref.read(rdWorkFilesProvider(songId)).hidden);
  final instruments = [
    for (final g in data.partGroups)
      if (g.id != null) InstrumentInfo(id: g.id!, name: g.name, synonyms: g.synonyms),
  ];
  final workName = data.song.name;

  // The names as "Noten importieren" reads them.
  final reads = <({PlatformFile file, RdUploadRead read})>[];
  for (final file in files) {
    if (file.size > rdMaxUploadBytes) {
      ToastHelper.showError(context, l10n.songsFileTooLarge(file.name));
      continue;
    }
    reads.add((
      file: file,
      read: rdUploadRead(file.name, instruments: instruments, isChoir: data.isChoir, workName: workName),
    ));
  }
  if (reads.isEmpty) return true;

  // Sibelius parts carry the part's own name: one list to check them.
  if (fromSibelius) {
    final parts = await showAppDialog<List<_SibeliusPart>>(
      context: context,
      builder:
          (_) => _SibeliusPartsDialog(
            items: [
              for (final r in reads) (file: r.file, instrumentId: r.read.guess.instrumentId, note: r.read.guess.note),
            ],
            existing: existing,
            groups: data.partGroups,
            workName: workName,
            isChoir: data.isChoir,
          ),
    );
    if (parts == null) return context.mounted;
    if (parts.isNotEmpty) {
      controller.enqueue([
        for (final i in parts) (file: i.file, instrumentId: i.instrumentId, note: i.note, replace: i.replace),
      ], mainGroupId: data.mainGroupId);
    }
    return true;
  }

  // What each file to check gets proposed, and why.
  final proposals = <PlatformFile, _Proposal>{
    for (final r in reads)
      if (r.read.review) r.file: _Proposal.fromName(r.read),
  };
  final vision = ref.read(partVisionServiceProvider);
  // The tenant of this drop: after a switch nothing more is sent for it.
  final tenantId = vision.currentTenant();

  // 1. The KI guesses unclear part names (`part-suggest`, one request for
  // all), as in the import.
  final questions = instruments.isEmpty
      ? const <RdImportQuestion>[]
      : rdUploadQuestions([for (final r in reads) if (r.read.review) r.read], workName: workName);
  if (questions.isNotEmpty && tenantId != null) {
    controller.showNotice(l10n.songsFlutterAiReading);
    final result = await ref.read(rdImportAiProvider).suggest(
      tenantId,
      questions,
      groups: {for (final i in instruments) i.id},
      isChoir: data.isChoir,
    );
    if (!context.mounted) return false;
    for (final r in reads) {
      final answer = result.answers[r.read.questionKey];
      if (answer == null) continue;
      final category = rdUploadAiCategory(
        answer,
        r.read,
        instruments: instruments,
        isChoir: data.isChoir,
        workName: workName,
        readable: PartVisionService.supports(r.file.name),
      );
      if (category != null) proposals[r.file] = _Proposal(category, sure: answer.sure, why: _Why.ai);
    }
  }

  // 2. Page 1 (`part-detect`) for what is still open: no sure word of the
  // KI and no known instrument in the name.
  final unclear = [
    for (final r in reads)
      if (instruments.isNotEmpty &&
          r.read.review &&
          !r.read.byKnownName &&
          !(proposals[r.file]!.why == _Why.ai && proposals[r.file]!.sure) &&
          r.read.guess.canAskVision(r.file.name))
        r,
  ];
  if (unclear.isNotEmpty) {
    controller.showNotice(l10n.songsFlutterVisionReading);
    // A minute in all; files not read by then keep what the name or the KI
    // said (and land in the review below).
    final clock = Stopwatch()..start();
    for (final r in unclear) {
      final left = rdVisionBudget - clock.elapsed;
      if (left <= Duration.zero || !context.mounted) break;
      // Each file gets at most what is left of the minute; leaving the page
      // stops it.
      final match = await vision.detect(
        r.file,
        instruments,
        limit: left,
        tenantId: tenantId,
        cancelled: () => !context.mounted,
      );
      if (match != null && match.instrumentId != null) {
        proposals[r.file] = _Proposal(
          RdImportCategory(instrumentId: match.instrumentId),
          sure: match.confidence == MatchConfidence.sure,
          why: _Why.page,
          label: match.term,
        );
      }
    }
    if (!context.mounted) return false;
  }

  // Files whose part is not clear are checked first; terms assigned by hand
  // can be remembered as synonyms of the group.
  final chosen = <PlatformFile, RdImportCategory>{
    for (final r in reads) r.file: proposals[r.file]?.category ?? r.read.category,
  };
  final review = [
    for (final r in reads)
      if (proposals[r.file] case final p?) (file: r.file, read: r.read, proposal: p),
  ];
  var terms = const <int, List<String>>{};
  if (review.isNotEmpty) {
    final result = await showAppDialog<_ReviewResult>(
      context: context,
      builder:
          (_) => _ReviewDialog(
            items: review,
            groups: data.partGroups,
            instruments: instruments,
            isChoir: data.isChoir,
            workName: workName,
          ),
    );
    if (!context.mounted) return false;
    if (result == null) return true;
    chosen.addAll(result.categories);
    terms = result.terms;
  }

  // A part for several groups is uploaded once per group.
  final items = <_UploadItem>[
    for (final r in reads)
      for (final c in chosen[r.file]!.each)
        (
          file: r.file,
          instrumentId: c.instrumentId,
          note: c.note,
          newGroup: c.newGroup,
          conflicts: rdUploadConflicts(r.file.name, c.instrumentId, existing),
        ),
  ];

  var replace = false;
  final clashing = items.where((i) => i.conflicts.isNotEmpty).toList();
  if (clashing.isNotEmpty) {
    final choice = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => _ConflictDialog(items: clashing, groups: data.partGroups),
    );
    if (choice == null) return true;
    replace = choice;
  }

  // New groups ("Oboe" without a group yet) are created only now that the
  // upload really starts, as in the import.
  final groupNotifier = ref.read(groupNotifierProvider.notifier);
  final created = <String, int>{};
  for (final name in rdUploadNewGroups(chosen.values)) {
    final same = data.partGroups.where((g) => g.id != null && g.name.trim().toLowerCase() == name.trim().toLowerCase());
    final id = same.isNotEmpty ? same.first.id : (await groupNotifier.createGroup({'name': name, 'maingroup': false}))?.id;
    if (!context.mounted) return false;
    if (id == null) {
      ToastHelper.showError(context, l10n.rdWordsNewGroupFailed(rdGroupKindOf(context), name));
    } else {
      created[name] = id;
    }
  }

  controller.enqueue([
    for (final i in items)
      // A group that could not be created: the file goes without a part.
      (
        file: i.file,
        instrumentId: i.newGroup != null ? created[i.newGroup] : i.instrumentId,
        note: i.note,
        replace: replace ? i.conflicts : const <SongFile>[],
      ),
  ], mainGroupId: data.mainGroupId);

  // Only once the upload is really started (not on "Abbrechen" in the
  // conflict dialog).
  if (terms.isNotEmpty && context.mounted) {
    final ok = await groupNotifier.addSynonyms(terms);
    if (!ok && context.mounted) ToastHelper.showError(context, l10n.songsFlutterLearnFailed);
  }
  return true;
}

/// A file of the upload with the part it goes to (a group to create:
/// [newGroup]) and the files at the Werk it would replace.
typedef _UploadItem = ({
  PlatformFile file,
  int? instrumentId,
  String? note,
  String? newGroup,
  List<SongFile> conflicts,
});

/// Where a proposal for a file to check comes from.
enum _Why { name, ai, page }

/// What a file to check is proposed: from its name, the KI's guess from the
/// name, or what page 1 shows ([label]: the part as printed).
class _Proposal {
  const _Proposal(this.category, {required this.sure, required this.why, this.label, this.knownName = false});

  factory _Proposal.fromName(RdUploadRead read) => _Proposal(
        read.category,
        sure: read.guess.confidence == MatchConfidence.sure,
        why: _Why.name,
        knownName: read.byKnownName,
      );

  final RdImportCategory category;
  final bool sure;
  final _Why why;
  final String? label;

  /// A known instrument without a group, or a part for several groups.
  final bool knownName;
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

/// Left gap of the rows outside selection mode (no checkbox column).
const double _checkGap = 8;
const double _partWidth = 200;
const double _partWidthCompact = 140;
const double _typeWidth = 64;
const double _menuWidth = 44;

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.compact,
    required this.selecting,
    required this.allSelected,
    required this.someSelected,
    required this.onSelectAll,
  });

  final bool compact;
  final bool selecting;
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
            width: selecting ? _checkWidth : _checkGap,
            child:
                !selecting
                    ? null
                    : Checkbox(
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

enum _RowAction { select, sibelius, sibeliusPlugin, word, share, download, replace, rename, delete }

enum _ListAction { select, downloadAll }

PopupMenuItem<T> _menuItem<T>(T value, IconData icon, String label, {Color? color, bool enabled = true}) =>
    PopupMenuItem(
      value: value,
      enabled: enabled,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Flexible(child: Text(label, style: TextStyle(color: color), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );

class _FileRow extends StatelessWidget {
  const _FileRow({
    super.key,
    required this.compact,
    required this.selecting,
    required this.file,
    required this.groups,
    required this.instruments,
    this.onlyOnMac = false,
    this.offerPlugin = false,
    required this.selected,
    required this.cursor,
    required this.renaming,
    required this.renameController,
    required this.renameFocus,
    required this.onTap,
    required this.onToggle,
    required this.onCategory,
    required this.onRenameDone,
    required this.onAction,
  });

  final SongFile file;
  final List<Group> groups;

  /// Groups a file can be moved to (as the old category dialog).
  final List<Group> instruments;

  /// A save from Sibelius is only on the Mac so far (offline): it goes up by
  /// itself once online again.
  final bool onlyOnMac;

  /// "Sibelius-Plugin installieren" in the menu of a .sib (not installed yet).
  final bool offerPlugin;
  final bool selected;
  final bool cursor;
  final bool compact;

  /// Selection mode: the checkbox column shows.
  final bool selecting;
  final bool renaming;
  final TextEditingController renameController;
  final FocusNode renameFocus;
  final VoidCallback onTap;
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: selecting ? _checkWidth : _checkGap,
                  child:
                      !selecting
                          ? null
                          : Checkbox(
                            value: selected,
                            activeColor: p.primary,
                            semanticLabel: file.fileName,
                            onChanged: onToggle,
                          ),
                ),
                SizedBox(width: 36, child: Icon(icon, size: 22, color: p.text2)),
                Expanded(child: name),
                if (onlyOnMac && !renaming)
                  Tooltip(
                    message: l10n.redesignFilesSibeliusWaiting,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(
                        Icons.cloud_off_outlined,
                        size: 20,
                        color: p.late,
                        semanticLabel: l10n.redesignFilesSibeliusWaiting,
                      ),
                    ),
                  ),
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
                          if (!selecting)
                            _menuItem(_RowAction.select, Icons.check_circle_outline, l10n.redesignFilesSelectOne),
                          if (rdOpensInSibelius(file)) ...[
                            _menuItem(_RowAction.sibelius, Icons.edit_note, l10n.redesignFilesSibeliusEdit),
                            if (offerPlugin)
                              _menuItem(
                                _RowAction.sibeliusPlugin,
                                Icons.extension_outlined,
                                l10n.redesignFilesSibeliusPlugin,
                              ),
                          ],
                          if (rdEditsInWord(file)) _menuItem(_RowAction.word, Icons.edit_note, l10n.redesignFilesWordEdit),
                          _menuItem(_RowAction.share, Icons.ios_share, l10n.redesignWorkShare),
                          _menuItem(_RowAction.download, Icons.download_outlined, l10n.redesignFilesDownload),
                          if (!rdIsAudioFile(file))
                            _menuItem(_RowAction.replace, Icons.upload_file_outlined, l10n.redesignFilesReplace),
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
      ((id: null, note: 'Sibelius'), 'Sibelius'),
      ((id: null, note: 'MIDI'), 'MIDI'),
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
class RdUploadQueue extends StatelessWidget {
  const RdUploadQueue({
    super.key,
    required this.state,
    required this.groups,
    required this.onRetry,
    required this.onDismiss,
  });

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
              child: LayoutBuilder(
                builder: (context, c) {
                  final part = SongUtils.fileLabel(
                    SongFile(fileName: u.file.name, fileType: '', url: '', instrumentId: u.instrumentId, note: u.note),
                    groups,
                  );
                  // Phones: the part goes under the name, the status gets
                  // only the room it needs.
                  final compact = c.maxWidth < 520;
                  final name = Text(
                    u.file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: p.text),
                  );
                  return Row(
                    children: [
                      SizedBox(width: 28, child: _statusIcon(p, u.status)),
                      Expanded(
                        child:
                            compact
                                ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    name,
                                    Text(
                                      part,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: RdType.meta(p, size: 13),
                                    ),
                                  ],
                                )
                                : name,
                      ),
                      const SizedBox(width: 8),
                      if (!compact)
                        SizedBox(
                          width: 160,
                          child: Text(
                            part,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: RdType.meta(p, size: 13),
                          ),
                        ),
                      SizedBox(
                        width: compact ? null : 150,
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
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusIcon(RdPalette p, RdUploadStatus status) => switch (status) {
    RdUploadStatus.waiting => Icon(Icons.schedule, size: 18, color: p.text2),
    // Same 18px box as the icons, the ring inset like their glyphs, so
    // it sits centred in the column exactly where the check and clock do.
    RdUploadStatus.uploading => Center(
      child: SizedBox(
        width: 18,
        height: 18,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: CircularProgressIndicator(strokeWidth: 2, color: p.primary),
        ),
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

  final List<_UploadItem> items;
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

/// One part of [_SibeliusPartsDialog] as it is taken over.
typedef _SibeliusPart = ({PlatformFile file, int? instrumentId, String? note, List<SongFile> replace});

/// "Neue Stimmen aus Sibelius": one row per exported part PDF with a
/// checkbox, its part and the PDF it replaces (or "neu"); both can be
/// changed. "Übernehmen" returns the checked parts.
class _SibeliusPartsDialog extends StatefulWidget {
  const _SibeliusPartsDialog({
    required this.items,
    required this.existing,
    required this.groups,
    required this.workName,
    required this.isChoir,
  });

  final List<({PlatformFile file, int? instrumentId, String? note})> items;
  final List<SongFile> existing;
  final List<Group> groups;
  final String workName;
  final bool isChoir;

  @override
  State<_SibeliusPartsDialog> createState() => _SibeliusPartsDialogState();
}

class _SibeliusPartsDialogState extends State<_SibeliusPartsDialog> {
  late final List<_Category> _parts = [for (final i in widget.items) (id: i.instrumentId, note: i.note)];
  late final List<SongFile?> _replace = rdPartReplacements([
    for (final i in widget.items) (name: i.file.name, instrumentId: i.instrumentId, note: i.note),
  ], widget.existing);
  late final List<bool> _take = List.filled(widget.items.length, true);

  RdPartPdf _pdf(int i) => (name: widget.items[i].file.name, instrumentId: _parts[i].id, note: _parts[i].note);

  void _choosePart(int i, _Category part) {
    setState(() {
      _parts[i] = part;
      // The file it replaces follows the part (unless taken by another).
      final others = {
        for (var j = 0; j < _replace.length; j++)
          if (j != i && _replace[j] != null) _replace[j]!,
      };
      _replace[i] = rdPartReplacements([_pdf(i)], widget.existing.where((f) => !others.contains(f)).toList()).single;
    });
  }

  void _chooseReplace(int i, SongFile? file) {
    setState(() {
      // A file is replaced by one part only.
      if (file != null) {
        for (var j = 0; j < _replace.length; j++) {
          if (_replace[j] == file) _replace[j] = null;
        }
      }
      _replace[i] = file;
    });
  }

  String _partName(PlatformFile file) {
    final dot = file.name.lastIndexOf('.');
    return dot > 0 ? file.name.substring(0, dot) : file.name;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.rd;
    final count = _take.where((t) => t).length;
    final head = TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.text2, letterSpacing: 0.3);
    final options = <(_Category, String)>[
      for (final g in widget.groups)
        if (g.id != null) ((id: g.id, note: null), g.name),
      ((id: null, note: 'Partitur'), 'Partitur'),
      ((id: null, note: 'Klavierauszug'), 'Klavierauszug'),
      if (widget.isChoir) ((id: null, note: kChoirAllNote), kChoirAllNote),
    ];
    return AppAlertDialog(
      title: Text(l10n.redesignFilesSibeliusPartsTitle),
      content: SizedBox(
        width: 640,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.redesignFilesSibeliusPartsMessage(widget.items.length, widget.workName)),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Checkbox(
                    tristate: true,
                    value: count == _take.length ? true : (count == 0 ? false : null),
                    activeColor: p.primary,
                    semanticLabel: l10n.redesignFilesSelectAll,
                    onChanged: (_) => setState(() => _take.fillRange(0, _take.length, count != _take.length)),
                  ),
                ),
                Expanded(child: Text(l10n.redesignFilesSibeliusColFile.toUpperCase(), style: head)),
                SizedBox(width: 168, child: Text(l10n.redesignFilesColPart.toUpperCase(), style: head)),
                const SizedBox(width: 12),
                SizedBox(width: 200, child: Text(l10n.redesignFilesSibeliusColReplaces.toUpperCase(), style: head)),
              ],
            ),
            Divider(height: 1, color: p.line),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [for (var i = 0; i < widget.items.length; i++) _row(context, i, options)],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, const <_SibeliusPart>[]), child: Text(l10n.commonCancel)),
        TextButton(
          onPressed:
              count == 0
                  ? null
                  : () => Navigator.pop<List<_SibeliusPart>>(context, [
                    for (var i = 0; i < widget.items.length; i++)
                      if (_take[i])
                        (
                          file: widget.items[i].file,
                          instrumentId: _parts[i].id,
                          note: _parts[i].id == null ? _parts[i].note : null,
                          replace: [if (_replace[i] case final f?) f],
                        ),
                  ]),
          child: Text(l10n.redesignFilesSibeliusPartsApplyCount(count)),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, int i, List<(_Category, String)> options) {
    final l10n = context.l10n;
    final p = context.rd;
    final on = _take[i];
    final part = _parts[i];
    final partOptions = [
      ...options,
      if (part != (id: null, note: null) && !options.any((o) => o.$1 == part))
        (part, part.note ?? l10n.redesignFilesSibeliusPartNone),
      ((id: null, note: null) as _Category, l10n.redesignFilesSibeliusPartNone),
    ];
    final replaceOptions = rdPartReplaceOptions(_pdf(i), widget.existing);
    final dense = TextStyle(fontSize: 14, color: on ? p.text : p.text2);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Checkbox(value: on, activeColor: p.primary, onChanged: (v) => setState(() => _take[i] = v ?? false)),
          ),
          Expanded(
            child: Text(
              _partName(widget.items[i].file),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: dense.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          SizedBox(
            width: 168,
            child: AppDropdownButton<_Category>(
              value: part,
              isExpanded: true,
              isDense: true,
              style: dense,
              items: [
                for (final o in partOptions)
                  DropdownMenuItem(value: o.$1, child: Text(o.$2, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: on ? (v) => _choosePart(i, v ?? (id: null, note: null)) : null,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 200,
            child: AppDropdownButton<SongFile?>(
              value: _replace[i],
              isExpanded: true,
              isDense: true,
              style: dense,
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(l10n.redesignFilesSibeliusPartNew, style: TextStyle(color: p.present)),
                ),
                for (final f in replaceOptions)
                  DropdownMenuItem(value: f, child: Text(f.fileName, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: on ? (f) => _chooseReplace(i, f) : null,
            ),
          ),
        ],
      ),
    );
  }
}

typedef _ReviewResult = ({Map<PlatformFile, RdImportCategory> categories, Map<int, List<String>> terms});

/// "Zuordnung prüfen": the dropped files whose part was not recognised for
/// sure (or that need a new group), each with a part menu and "künftig so
/// erkennen" once changed.
class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({
    required this.items,
    required this.groups,
    required this.instruments,
    required this.isChoir,
    required this.workName,
  });

  final List<({PlatformFile file, RdUploadRead read, _Proposal proposal})> items;
  final List<Group> groups;
  final List<InstrumentInfo> instruments;
  final bool isChoir;
  final String workName;

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  late final Map<PlatformFile, RdImportCategory> _chosen = {for (final i in widget.items) i.file: i.proposal.category};

  /// The import's labels and options need only the groups.
  late final RdImportPlan _plan = RdImportPlan(
    works: const [],
    questions: const [],
    songs: const {},
    instruments: widget.instruments,
    junk: 0,
    isChoir: widget.isChoir,
  );

  /// An unsure part (by name or by the KI) can be confirmed for learning
  /// right away (unchecked).
  late final Map<PlatformFile, String> _terms = {
    for (final i in widget.items)
      if (i.proposal.why != _Why.page && !i.proposal.knownName && i.proposal.category.instrumentId != null)
        if (_term(i.file, i.proposal.category) case final term?) i.file: term,
  };
  final Set<PlatformFile> _learn = {};

  String? _term(PlatformFile file, RdImportCategory c) {
    final id = c.instrumentId;
    if (id == null || id <= InstrumentMatcher.lyricsId) return null;
    return learnableTerm(file.name, chosenId: id, instruments: widget.instruments, workName: widget.workName);
  }

  void _choose(PlatformFile file, RdImportCategory c) {
    setState(() {
      _chosen[file] = c;
      final term = _term(file, c);
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
    Navigator.pop<_ReviewResult>(context, (categories: Map.of(_chosen), terms: _learnedTerms()));
  }

  Map<int, List<String>> _learnedTerms() {
    final terms = <int, List<String>>{};
    for (final f in _learn) {
      final id = _chosen[f]?.instrumentId;
      final term = _terms[f];
      if (id != null && term != null) (terms[id] ??= []).add(term);
    }
    return terms;
  }

  /// Why the file is shown, and how sure the proposal is.
  String _status(BuildContext context, _Proposal p) {
    final l10n = context.l10n;
    switch (p.why) {
      case _Why.page:
        return p.sure
            ? l10n.songsFlutterVisionSure(p.label ?? rdImportCategoryLabel(context, _plan, p.category))
            : l10n.songsFlutterVisionUnsure;
      case _Why.ai:
        return l10n.songsFlutterAiSuggested;
      case _Why.name:
        if (p.category.isSeveral) return l10n.rdWordsSeveralGroups(rdGroupKindOf(context));
        if (p.category.newGroup != null) return l10n.redesignImportNewGroupMessage(rdGroupKindOf(context));
        return p.category.instrumentId != null || p.category.note != null
            ? l10n.songsFlutterDetectUnsure
            : l10n.songsFlutterDetectNone;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.rd;
    final proposed = {for (final i in widget.items) i.proposal.category};
    final newGroups = rdUploadNewGroups(proposed.where((c) => !c.isSeveral));
    final options = [
      // A part for several groups ("Posaune + Tuba") first.
      for (final c in proposed)
        if (c.isSeveral) (c, rdImportCategoryLabel(context, _plan, c)),
      ...rdImportCategoryOptions(context, _plan, newGroups: newGroups),
    ];
    final menu = <DropdownMenuItem<RdImportCategory>>[
      for (final (c, label) in options) DropdownMenuItem(value: c, child: Text(label, overflow: TextOverflow.ellipsis)),
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
                          Text(
                            i.file.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            _status(context, i.proposal),
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  i.proposal.sure || i.proposal.knownName
                                      ? p.present
                                      : i.proposal.category != RdImportCategory.other
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
                      child: AppDropdownButton<RdImportCategory>(
                        value: _chosen[i.file],
                        items: menu,
                        isExpanded: true,
                        onChanged: (c) {
                          if (c != null) _choose(i.file, c);
                        },
                      ),
                    ),
                  ],
                ),
                if (_terms[i.file] != null && _chosen[i.file]?.instrumentId != null)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _learn.contains(i.file),
                    title: Text(
                      l10n.songsFlutterLearnTerm(
                        _terms[i.file]!,
                        widget.groups.where((g) => g.id == _chosen[i.file]!.instrumentId).firstOrNull?.name ?? '',
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

/// Shows the file table's keyboard shortcuts (Ich › Hilfe, or "?" in
/// the file table). Kept out of the toolbar so the main UI stays calm.
Future<void> showRdWorkFilesShortcuts(BuildContext context) {
  final isMac = defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS;
  final modLabel = isMac ? '⌘' : (Localizations.localeOf(context).languageCode == 'de' ? 'Strg' : 'Ctrl');
  return showAppDialog<void>(
    context: context,
    builder: (_) => _ShortcutsDialog(help: context.l10n.redesignFilesShortcutsHelp(modLabel)),
  );
}

/// The shortcuts of the file table, one per line.
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
              // Mac app: how to give the Attendix plug-in a shortcut.
              if (rdSibeliusSupported) ...[
                const SizedBox(height: 10),
                Text(
                  l10n.redesignFilesSibeliusShortcutTitle,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(l10n.redesignFilesSibeliusShortcutTip, style: const TextStyle(fontSize: 14)),
              ],
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonOk))],
    );
  }
}
