import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../../core/providers/group_providers.dart';
import '../../../../core/services/part_vision_service.dart';
import '../../../../core/services/song_file_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/instrument_matcher.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/models/song/song.dart';
import '../utils/song_utils.dart';
import 'file_drop/file_drop_target.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';

/// Ionic `detectSpecialFileType`: category from the file name / extension
/// when no group matched. Returns null if nothing special was detected.
/// Words are matched whole ("Soundtrack" is no "track", "Kontext" no "text").
({int? instrumentId, String? note})? detectSpecialFileType(String filename) {
  final lower = filename.toLowerCase();
  final words = InstrumentMatcher.tokenize(lower).join(' ');
  bool any(List<String> terms) => terms.any((t) {
        final term = InstrumentMatcher.tokenize(t).join(' ');
        return RegExp('(^| )${RegExp.escape(term)}( |\$)').hasMatch(words);
      });

  if (InstrumentMatcher.audioExtensions.any((e) => lower.endsWith('.$e'))) {
    return (instrumentId: 1, note: null);
  }
  if (lower.endsWith('.doc') || lower.endsWith('.docx') || lower.endsWith('.txt')) {
    return (instrumentId: 2, note: null);
  }
  if (lower.contains('.sib')) return (instrumentId: null, note: 'Sibelius');
  if (any(['klavierauszug', 'piano reduction', 'vocal score', 'klavier auszug', 'клавир', 'klavir', 'переложение'])) {
    return (instrumentId: null, note: 'Klavierauszug');
  }
  if (any(['partitur', 'score', 'full score', 'conductor', 'direktion', 'dirigent', 'партитура', 'partitura', 'дирижер', 'dirizher'])) {
    return (instrumentId: null, note: 'Partitur');
  }
  if (any(['liedtext', 'songtext', 'lyrics', 'text', 'texte', 'words', 'текст', 'tekst', 'слова', 'slova'])) {
    return (instrumentId: 2, note: null);
  }
  if (any(['chor', 'choir', 'choral', 'chorsatz', 'хор', 'khor', 'хоровая'])) {
    return (instrumentId: null, note: 'Chor');
  }
  return null;
}

/// Ionic `findConflictingFiles`: existing files with the same category.
List<SongFile> findConflictingFiles(List<SongFile> files, int? instrumentId, String? note) {
  if (instrumentId != null) {
    return files.where((f) => f.instrumentId == instrumentId).toList();
  }
  return files
      .where((f) => f.instrumentId == null && (f.note ?? '') == (note ?? ''))
      .toList();
}

bool _isPdfName(String name) => name.toLowerCase().endsWith('.pdf');

/// Category of an uploaded file with how sure the detection is.
class FileCategoryGuess {
  const FileCategoryGuess({
    required this.instrumentId,
    required this.note,
    required this.confidence,
    this.term,
    this.byVision = false,
  });

  /// [match] read on the first page (`part-detect`).
  factory FileCategoryGuess.vision(PartMatch match) => FileCategoryGuess(
        instrumentId: match.instrumentId,
        note: null,
        confidence: match.confidence,
        term: match.term,
        byVision: true,
      );

  final int? instrumentId;
  final String? note;
  final MatchConfidence confidence;

  /// The words of the file name the guess is based on.
  final String? term;

  /// Read on the first page instead of the file name.
  final bool byVision;

  /// The page may still help: the name was not clear and it is a PDF/image.
  bool canAskVision(String fileName) => !byVision && needsReview && PartVisionService.supports(fileName);

  /// The person should look at it before uploading. A part read on page 1
  /// is always confirmed by hand: the model's own "sure" is no proof (a
  /// page can carry misleading text).
  bool get needsReview => byVision || confidence != MatchConfidence.sure;
}

/// Ionic `addFiles` category detection: group by name/synonym, then special
/// types (Aufnahme, Liedtext, Partitur, ...), then "Chor" for PDFs in choirs.
({int? instrumentId, String? note}) detectFileCategory(
  String fileName, {
  required List<InstrumentInfo> instruments,
  required bool isChoir,
}) {
  final guess = guessFileCategory(fileName, instruments: instruments, isChoir: isChoir);
  return (instrumentId: guess.instrumentId, note: guess.note);
}

/// [detectFileCategory] with the confidence of the guess.
FileCategoryGuess guessFileCategory(
  String fileName, {
  required List<InstrumentInfo> instruments,
  required bool isChoir,
}) {
  final match = instruments.isEmpty ? PartMatch.none : InstrumentMatcher.detect(fileName, instruments);
  if (match.instrumentId != null) {
    return FileCategoryGuess(
      instrumentId: match.instrumentId,
      note: null,
      confidence: match.confidence,
      term: match.term,
    );
  }
  final special = detectSpecialFileType(fileName);
  if (special != null) {
    return FileCategoryGuess(
      instrumentId: special.instrumentId,
      note: special.note,
      confidence: MatchConfidence.sure,
    );
  }
  if (isChoir && _isPdfName(fileName)) {
    return const FileCategoryGuess(instrumentId: null, note: 'Chor', confidence: MatchConfidence.sure);
  }
  return const FileCategoryGuess(instrumentId: null, note: null, confidence: MatchConfidence.none);
}

/// The file-name term to remember as synonym when the person assigned
/// [fileName] to group [chosenId] by hand (upload: "künftig so erkennen").
/// Null for recordings / lyrics / free text, or when the name already leads
/// to that group for sure.
String? learnableTerm(
  String fileName, {
  required int? chosenId,
  required List<InstrumentInfo> instruments,
  String? workName,
}) {
  if (chosenId == null ||
      chosenId == InstrumentMatcher.recordingId ||
      chosenId == InstrumentMatcher.lyricsId) {
    return null;
  }
  final now = InstrumentMatcher.detect(fileName, instruments);
  if (now.instrumentId == chosenId && now.confidence == MatchConfidence.sure) return null;
  return InstrumentMatcher.partTerm(fileName, workName: workName);
}

/// Ionic: preselect same-named files, otherwise all conflicts.
Set<String> defaultReplaceSelection(List<SongFile> conflicts, String name) {
  final same = conflicts.where((f) => f.fileName == name).map((f) => f.url).toSet();
  return same.isNotEmpty ? same : conflicts.map((f) => f.url).toSet();
}

/// File upload sheet (Ionic file upload modal): multi-file selection with
/// automatic category detection, free-text categories, replacement of
/// existing files of the same category and a progress indicator.
class FileUploadSheet extends ConsumerStatefulWidget {
  final int songId;
  final List<Group> groups;
  final List<SongFile> existingFiles;
  final int? mainGroupId;
  final bool isChoir;

  const FileUploadSheet({
    super.key,
    required this.songId,
    required this.groups,
    this.existingFiles = const [],
    this.mainGroupId,
    this.isChoir = false,
    this.initialFiles = const [],
    this.workName,
  });

  /// Name of the Werk, left out of terms remembered as synonyms.
  final String? workName;

  /// Files dropped onto the song page (Ionic `handlePageDrop` with >1 file).
  final List<PlatformFile> initialFiles;

  @override
  ConsumerState<FileUploadSheet> createState() => _FileUploadSheetState();
}

class _FileUploadSheetState extends ConsumerState<FileUploadSheet> {
  static const _maxSizeBytes = 20 * 1024 * 1024;

  final List<_FileToUpload> _files = [];
  bool _isUploading = false;
  double _uploadProgress = 0;
  int _doneCount = 0;

  List<InstrumentInfo> get _instruments => widget.groups
      .where((g) => g.id != null)
      .map((g) => InstrumentInfo(id: g.id!, name: g.name, synonyms: g.synonyms))
      .toList();

  void _setCategory(int index, int? instrumentId, String? note) {
    final file = _files[index];
    final conflicts = findConflictingFiles(widget.existingFiles, instrumentId, note);
    setState(() {
      // Also when the suggested (unsure) part is confirmed explicitly.
      if (file.instrumentId != instrumentId || instrumentId != null) {
        file.learnTerm = learnableTerm(
          file.platformFile.name,
          chosenId: instrumentId,
          instruments: _instruments,
          workName: widget.workName,
        );
        file.learn = file.learnTerm != null;
      }
      // Every change by hand (also typed free text) is kept: a late
      // page-1 result no longer overrides it.
      file.reviewed = true;
      file.instrumentId = instrumentId;
      file.note = note;
      file.conflicts = conflicts;
      file.toReplace = _defaultReplace(conflicts, file.platformFile.name);
    });
  }

  /// Ionic: preselect same-named files, otherwise all conflicts
  Set<String> _defaultReplace(List<SongFile> conflicts, String name) =>
      defaultReplaceSelection(conflicts, name);

  @override
  void initState() {
    super.initState();
    if (widget.initialFiles.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _addFiles(widget.initialFiles);
      });
    }
  }

  Future<void> _pickFiles() async {
    final files = await ref.read(songFileServiceProvider).pickMultipleFiles();
    if (files == null || files.isEmpty || !mounted) return;
    _addFiles(files);
  }

  /// Ionic `addFiles`: size check, automatic category, conflicts.
  void _addFiles(List<PlatformFile> files) {
    final added = <_FileToUpload>[];
    setState(() {
      for (final file in files) {
        if (file.size > _maxSizeBytes) {
          ToastHelper.showError(context, context.l10n.songsFileTooLarge(file.name));
          continue;
        }
        final cat = guessFileCategory(
          file.name,
          instruments: _instruments,
          isChoir: widget.isChoir,
        );
        final conflicts =
            findConflictingFiles(widget.existingFiles, cat.instrumentId, cat.note);
        final item = _FileToUpload(
          platformFile: file,
          instrumentId: cat.instrumentId,
          note: cat.note,
          confidence: cat.confidence,
          conflicts: conflicts,
          toReplace: _defaultReplace(conflicts, file.name),
        )
          ..learnTerm = _suggestedTerm(file.name, cat)
          ..reading = cat.canAskVision(file.name) && _instruments.isNotEmpty;
        _files.add(item);
        added.add(item);
      }
    });
    _readFirstPages(added.where((f) => f.reading));
  }

  /// Fallback for unclear names: the part printed on page 1 (one at a time,
  /// rows the person already changed stay as they are).
  Future<void> _readFirstPages(Iterable<_FileToUpload> items) async {
    final vision = ref.read(partVisionServiceProvider);
    // The tenant these files were added in: after a switch nothing is sent.
    final tenantId = vision.currentTenant();
    for (final item in items.toList()) {
      // Removed, changed by hand or uploading meanwhile: no (paid) request,
      // also not one already under way that has not been sent yet.
      bool gone() => !mounted || !_files.contains(item) || item.reviewed || item.status != null;
      if (gone()) {
        if (mounted) setState(() => item.reading = false);
        continue;
      }
      final match = await vision.detect(item.platformFile, _instruments, cancelled: gone, tenantId: tenantId);
      if (!mounted) return;
      setState(() {
        item.reading = false;
        if (match == null || item.reviewed || item.status != null || !_files.contains(item)) return;
        final conflicts = findConflictingFiles(widget.existingFiles, match.instrumentId, null);
        item
          ..instrumentId = match.instrumentId
          ..note = null
          ..confidence = match.confidence
          ..visionLabel = match.term ?? widget.groups.where((g) => g.id == match.instrumentId).firstOrNull?.name ?? ''
          ..byVision = true
          ..learnTerm = null
          ..learn = false
          ..conflicts = conflicts
          ..toReplace = _defaultReplace(conflicts, item.platformFile.name);
      });
    }
  }

  /// An unsure part can be confirmed for learning right away (unchecked).
  String? _suggestedTerm(String name, FileCategoryGuess cat) => cat.confidence == MatchConfidence.unsure
      ? learnableTerm(name, chosenId: cat.instrumentId, instruments: _instruments, workName: widget.workName)
      : null;

  static bool _isPdf(PlatformFile f) => _isPdfName(f.name);

  Future<void> _upload({required bool replace}) async {
    if (_files.isEmpty) return;
    final invalidLyrics =
        _files.where((f) => f.instrumentId == 2 && !_isPdf(f.platformFile)).length;
    if (invalidLyrics > 0) {
      final proceed = await showAppDialog<bool>(
        context: context,
        builder: (ctx) => AppAlertDialog(
          title: Text(context.l10n.songsLyricsWarning),
          content: Text(context.l10n.songsLyricsWarningMessage(invalidLyrics)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.l10n.songsUploadAnyway),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    final service = await ref.read(readySongFileServiceProvider.future);
    final infos = [..._files];
    final totalBytes = infos.fold<int>(0, (s, f) => s + (f.platformFile.size == 0 ? 1 : f.platformFile.size));
    var doneBytes = 0;
    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
      _doneCount = 0;
      for (final f in infos) {
        f.status = _UploadStatus.pending;
      }
    });

    for (final info in infos) {
      setState(() => info.status = _UploadStatus.uploading);
      try {
        if (replace) {
          for (final c in info.conflicts.where((c) => info.toReplace.contains(c.url))) {
            await service.deleteFile(
              songId: widget.songId,
              url: c.url,
              storageName: c.storageName,
              fileName: c.fileName,
              mainGroupId: widget.mainGroupId,
            );
          }
        }
        await service.uploadFile(
          songId: widget.songId,
          file: info.platformFile,
          instrumentId: info.instrumentId,
          note: info.instrumentId == null ? info.note : null,
          mainGroupId: widget.mainGroupId,
        );
        info.status = _UploadStatus.done;
        _doneCount++;
      } catch (_) {
        info.status = _UploadStatus.error;
      }
      doneBytes += info.platformFile.size == 0 ? 1 : info.platformFile.size;
      if (mounted) setState(() => _uploadProgress = doneBytes / totalBytes);
    }

    await _rememberTerms(infos.where((f) => f.status == _UploadStatus.done));

    if (!mounted) return;
    final failed = infos.where((f) => f.status == _UploadStatus.error).toList();
    setState(() => _isUploading = false);
    if (failed.isNotEmpty) {
      // Keep only failed files so they can be retried (Ionic)
      setState(() {
        _files
          ..clear()
          ..addAll(failed.map((f) => f..status = null));
      });
      ToastHelper.showError(
        context,
        context.l10n.songsUploadPartialFail(failed.length, infos.length),
      );
      return;
    }
    ToastHelper.showSuccess(
      context,
      context.l10n.songsUploadDone(infos.length),
    );
    Navigator.pop(context, true);
  }

  /// Saves the terms of hand-assigned files as group synonyms.
  Future<void> _rememberTerms(Iterable<_FileToUpload> uploaded) async {
    final terms = <int, List<String>>{};
    for (final f in uploaded) {
      if (f.learn && f.learnTerm != null && f.instrumentId != null) {
        (terms[f.instrumentId!] ??= []).add(f.learnTerm!);
      }
    }
    if (terms.isEmpty) return;
    final ok = await ref.read(groupNotifierProvider.notifier).addSynonyms(terms);
    if (!ok && mounted) ToastHelper.showError(context, context.l10n.songsFlutterLearnFailed);
  }

  @override
  Widget build(BuildContext context) {
    final percent = (_uploadProgress * 100).round();
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_isUploading,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.95),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Ionic toolbar: title + close button (+ progress bar while uploading)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.songsUploadFiles,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, semanticLabel: context.l10n.commonClose),
                      onPressed: _isUploading ? null : () => Navigator.pop(context, false),
                    ),
                  ],
                ),
              ),
              if (_isUploading)
                LinearProgressIndicator(value: _uploadProgress, minHeight: 2)
              else
                const Divider(height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    // Ionic accordion "Wichtige Infos" (warning colour, collapsed)
                    Material(
                      color: AppColors.warning.withAlpha(45),
                      child: ExpansionTile(
                        leading: const Icon(Icons.info_outline),
                        title: Text(context.l10n.songsImportantInfo),
                        shape: const Border(),
                        collapsedShape: const Border(),
                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        expandedAlignment: Alignment.centerLeft,
                        children: [
                          Text(
                            // Ionic renders this key as HTML (<br>, link).
                            context.l10n.songsUploadInfo
                                .replaceAll('<br>', '\n')
                                .replaceAll(RegExp(r'<[^>]+>'), ''),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: _isUploading
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        context.l10n.songsUploadProgress(_doneCount, _files.length),
                                        style: const TextStyle(
                                            fontSize: 14, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    Text(
                                      '$percent %',
                                      style: const TextStyle(
                                          fontSize: 14, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: _uploadProgress,
                                    minHeight: 8,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  context.l10n.songsDontClose,
                                  style: const TextStyle(fontSize: 12, color: AppColors.medium),
                                ),
                              ],
                            )
                          : FileDropZone(onTap: _pickFiles, onFiles: _addFiles),
                    ),
                    if (_files.isNotEmpty)
                      Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        color: scheme.surface,
                        clipBehavior: Clip.antiAlias,
                        child: SlidableAutoCloseBehavior(
                          child: Column(
                            children: [
                              for (var i = 0; i < _files.length; i++) ...[
                                if (i > 0) const Divider(height: 1),
                                _FileItem(
                                  key: ObjectKey(_files[i]),
                                  file: _files[i],
                                  groups: widget.groups,
                                  enabled: !_isUploading,
                                  onCategoryChanged: (id, note) => _setCategory(i, id, note),
                                  onToggleLearn: (v) => setState(() {
                                    // Confirmed by hand: a late page-1 result keeps it.
                                    _files[i]
                                      ..learn = v
                                      ..reviewed = true;
                                  }),
                                  onToggleReplace: (url) => setState(() {
                                    // Chosen by hand: a late page-1 result keeps it.
                                    _files[i].reviewed = true;
                                    final set = _files[i].toReplace;
                                    set.contains(url) ? set.remove(url) : set.add(url);
                                  }),
                                  onRemove: () => setState(() => _files.removeAt(i)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    // Ionic: both buttons as soon as files are selected
                    if (_files.isNotEmpty && !_isUploading)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FilledButton(
                              onPressed: () => _upload(replace: true),
                              child: IonButtonLabel(context.l10n.songsReplaceAndAdd),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: () => _upload(replace: false),
                              child: IonButtonLabel(context.l10n.songsAddWithoutReplace),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _UploadStatus { pending, uploading, done, error }

class _FileToUpload {
  _FileToUpload({
    required this.platformFile,
    required this.instrumentId,
    required this.note,
    required this.conflicts,
    required this.toReplace,
    this.confidence = MatchConfidence.sure,
  });

  final PlatformFile platformFile;
  int? instrumentId;
  String? note;

  /// How sure the automatic detection was.
  MatchConfidence confidence;

  /// The first page is being read / the part was read there (label).
  bool reading = false;
  bool byVision = false;
  String visionLabel = '';

  /// Changed by hand: the detection hint is no longer shown.
  bool reviewed = false;

  /// File-name term to remember for the chosen group, and whether to.
  String? learnTerm;
  bool learn = false;
  List<SongFile> conflicts;
  Set<String> toReplace;
  _UploadStatus? status;
}

class _FileItem extends StatefulWidget {
  const _FileItem({
    super.key,
    required this.file,
    required this.groups,
    required this.enabled,
    required this.onCategoryChanged,
    required this.onToggleReplace,
    required this.onRemove,
    this.onToggleLearn,
  });

  final _FileToUpload file;
  final List<Group> groups;
  final bool enabled;
  final void Function(int? instrumentId, String? note) onCategoryChanged;
  final ValueChanged<String> onToggleReplace;
  final VoidCallback onRemove;
  final ValueChanged<bool>? onToggleLearn;

  @override
  State<_FileItem> createState() => _FileItemState();
}

class _FileItemState extends State<_FileItem> {
  late final _note = TextEditingController(text: widget.file.note ?? '');

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// Ionic: upload status icon, otherwise a warning icon for conflicts.
  Widget? _leading() {
    switch (widget.file.status) {
      case _UploadStatus.uploading:
        return const SizedBox(
            width: 20, height: 20, child: AppSpinner(strokeWidth: 2));
      case _UploadStatus.done:
        return const Icon(Icons.check_circle, color: AppColors.success, size: 20);
      case _UploadStatus.error:
        return const Icon(Icons.error, color: AppColors.danger, size: 20);
      case _UploadStatus.pending:
        return const Icon(Icons.schedule, color: AppColors.medium, size: 20);
      case null:
        final conflicts = widget.file.conflicts;
        if (conflicts.isEmpty) return null;
        const icon = Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20);
        return conflicts.length == 1
            ? Tooltip(
                message: context.l10n.songsReplaces(conflicts.first.fileName),
                triggerMode: TooltipTriggerMode.tap,
                child: icon,
              )
            : icon;
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = widget.file;
    final items = <DropdownMenuItem<int?>>[
      DropdownMenuItem(value: null, child: Text(context.l10n.songsOtherFreeText)),
      DropdownMenuItem(value: 1, child: Text(context.l10n.songsRecording)),
      DropdownMenuItem(value: 2, child: Text(context.l10n.songsLyrics)),
      for (final g in widget.groups)
        if (g.id != null) DropdownMenuItem(value: g.id, child: Text(g.name)),
    ];
    final leading = _leading();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Ionic ion-item-sliding: swipe left to remove the selected file
        Slidable(
          key: ValueKey(file),
          enabled: widget.enabled,
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.25,
            dismissible: DismissiblePane(onDismissed: widget.onRemove),
            children: [
              SlidableAction(
                onPressed: (_) => widget.onRemove(),
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                icon: Icons.delete_outline,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
            child: Row(
              children: [
                if (leading != null) ...[leading, const SizedBox(width: 12)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        file.platformFile.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (file.status == null && !file.reviewed && file.reading)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            context.l10n.songsFlutterVisionReading,
                            style: const TextStyle(fontSize: 12, color: AppColors.medium),
                          ),
                        )
                      else if (file.status == null && !file.reviewed && file.byVision)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            file.confidence == MatchConfidence.sure
                                ? context.l10n.songsFlutterVisionSure(file.visionLabel)
                                : context.l10n.songsFlutterVisionUnsure,
                            style: TextStyle(
                              fontSize: 12,
                              color: file.confidence == MatchConfidence.sure ? AppColors.success : AppColors.warning,
                            ),
                          ),
                        )
                      else if (file.status == null && !file.reviewed && file.confidence != MatchConfidence.sure)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            file.confidence == MatchConfidence.unsure
                                ? context.l10n.songsFlutterDetectUnsure
                                : context.l10n.songsFlutterDetectNone,
                            style: TextStyle(
                              fontSize: 12,
                              color: file.confidence == MatchConfidence.unsure ? AppColors.warning : AppColors.danger,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: file.instrumentId,
                      items: items,
                      isExpanded: true,
                      hint: Text(context.l10n.songsInstrument),
                      onChanged: widget.enabled
                          ? (id) => widget.onCategoryChanged(
                              id, id == null ? _note.text.trim() : null)
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (file.instrumentId == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _note,
              enabled: widget.enabled,
              decoration: InputDecoration(
                labelText: context.l10n.songsFreeText,
                hintText: context.l10n.songsEnterCategory,
                isDense: true,
              ),
              onChanged: (v) => widget.onCategoryChanged(null, v.trim()),
            ),
          ),
        if (file.learnTerm != null && file.instrumentId != null && widget.onToggleLearn != null)
          CheckboxListTile(
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            value: file.learn,
            title: Text(
              context.l10n.songsFlutterLearnTerm(
                file.learnTerm!,
                widget.groups.where((g) => g.id == file.instrumentId).firstOrNull?.name ?? '',
              ),
              style: const TextStyle(fontSize: 13),
            ),
            onChanged: widget.enabled ? (v) => widget.onToggleLearn!(v ?? false) : null,
          ),
        // Ionic: checkbox per conflicting file when more than one
        if (file.conflicts.length > 1)
          for (final c in file.conflicts)
            CheckboxListTile(
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              value: file.toReplace.contains(c.url),
              title: Text(c.fileName, style: const TextStyle(fontSize: 13)),
              secondary: SongBadge(
                color: SongUtils.fileBadgeColor(c),
                label: SongUtils.fileLabel(c, widget.groups),
              ),
              onChanged: widget.enabled ? (_) => widget.onToggleReplace(c.url) : null,
            ),
      ],
    );
  }
}
