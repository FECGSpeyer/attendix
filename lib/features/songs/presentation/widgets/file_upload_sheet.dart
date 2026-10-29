import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../../core/services/song_file_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/instrument_matcher.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/models/song/song.dart';
import '../utils/song_utils.dart';
import 'file_drop/file_drop_target.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

/// Ionic `detectSpecialFileType`: category from the file name / extension
/// when no group matched. Returns null if nothing special was detected.
({int? instrumentId, String? note})? detectSpecialFileType(String filename) {
  final lower = filename.toLowerCase();
  final normalized = lower.replaceAll(RegExp(r'[_\-.]+'), ' ');
  bool any(List<String> words) => words.any(normalized.contains);

  if (InstrumentMatcher.audioExtensions.any((e) => lower.endsWith('.$e'))) {
    return (instrumentId: 1, note: null);
  }
  if (lower.endsWith('.doc') || lower.endsWith('.docx') || lower.endsWith('.txt')) {
    return (instrumentId: 2, note: null);
  }
  if (lower.contains('.sib')) return (instrumentId: null, note: 'Sibelius');
  if (any(['klavierauszug', 'piano reduction', 'vocal score', 'клавир', 'klavir', 'переложение'])) {
    return (instrumentId: null, note: 'Klavierauszug');
  }
  if (any(['partitur', 'score', 'full', 'conductor', 'партитура', 'partitura', 'дирижер', 'dirizher'])) {
    return (instrumentId: null, note: 'Partitur');
  }
  if (any(['liedtext', 'lyrics', 'text', 'words', 'текст', 'tekst', 'слова', 'slova'])) {
    return (instrumentId: 2, note: null);
  }
  if (any(['chor', 'choir', 'choral', 'хор', 'khor', 'хоровая'])) {
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

/// Ionic `addFiles` category detection: group by name/synonym, then special
/// types (Aufnahme, Liedtext, Partitur, ...), then "Chor" for PDFs in choirs.
({int? instrumentId, String? note}) detectFileCategory(
  String fileName, {
  required List<InstrumentInfo> instruments,
  required bool isChoir,
}) {
  int? id = instruments.isEmpty
      ? null
      : InstrumentMatcher.matchInstrument(fileName, instruments);
  String? note;
  if (id == null) {
    final special = detectSpecialFileType(fileName);
    if (special != null) {
      id = special.instrumentId;
      note = special.note;
    }
  }
  if (id == null && note == null && isChoir && _isPdfName(fileName)) {
    note = 'Chor';
  }
  return (instrumentId: id, note: note);
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
  });

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
      .map((g) => InstrumentInfo(id: g.id!, name: g.name))
      .toList();

  void _setCategory(int index, int? instrumentId, String? note) {
    final file = _files[index];
    final conflicts = findConflictingFiles(widget.existingFiles, instrumentId, note);
    setState(() {
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
    setState(() {
      for (final file in files) {
        if (file.size > _maxSizeBytes) {
          ToastHelper.showError(context, context.l10n.songsFileTooLarge(file.name));
          continue;
        }
        final cat = detectFileCategory(
          file.name,
          instruments: _instruments,
          isChoir: widget.isChoir,
        );
        final conflicts =
            findConflictingFiles(widget.existingFiles, cat.instrumentId, cat.note);
        _files.add(_FileToUpload(
          platformFile: file,
          instrumentId: cat.instrumentId,
          note: cat.note,
          conflicts: conflicts,
          toReplace: _defaultReplace(conflicts, file.name),
        ));
      }
    });
  }

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
                      icon: const Icon(Icons.close),
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
                                  onToggleReplace: (url) => setState(() {
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
  });

  final PlatformFile platformFile;
  int? instrumentId;
  String? note;
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
  });

  final _FileToUpload file;
  final List<Group> groups;
  final bool enabled;
  final void Function(int? instrumentId, String? note) onCategoryChanged;
  final ValueChanged<String> onToggleReplace;
  final VoidCallback onRemove;

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
                  child: Text(
                    file.platformFile.name,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
