import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/song_file_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/instrument_matcher.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/models/song/song.dart';

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
  });

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

  bool get _hasReplacements => _files.any((f) => f.toReplace.isNotEmpty);

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
  Set<String> _defaultReplace(List<SongFile> conflicts, String name) {
    final same = conflicts.where((f) => f.fileName == name).map((f) => f.url).toSet();
    return same.isNotEmpty ? same : conflicts.map((f) => f.url).toSet();
  }

  Future<void> _pickFiles() async {
    final files = await ref.read(songFileServiceProvider).pickMultipleFiles();
    if (files == null || files.isEmpty || !mounted) return;

    setState(() {
      for (final file in files) {
        if (file.size > _maxSizeBytes) {
          ToastHelper.showError(
            context,
            'Die Datei ${file.name} überschreitet die maximale Größe von 20MB.',
          );
          continue;
        }
        int? id = _instruments.isEmpty
            ? null
            : InstrumentMatcher.matchInstrument(file.name, _instruments);
        String? note;
        if (id == null) {
          final special = detectSpecialFileType(file.name);
          if (special != null) {
            id = special.instrumentId;
            note = special.note;
          }
        }
        if (id == null && note == null && widget.isChoir && _isPdf(file)) {
          note = 'Chor';
        }
        final conflicts = findConflictingFiles(widget.existingFiles, id, note);
        _files.add(_FileToUpload(
          platformFile: file,
          instrumentId: id,
          note: note,
          conflicts: conflicts,
          toReplace: _defaultReplace(conflicts, file.name),
        ));
      }
    });
  }

  static bool _isPdf(PlatformFile f) => f.name.toLowerCase().endsWith('.pdf');

  Future<void> _upload({required bool replace}) async {
    if (_files.isEmpty) return;
    final invalidLyrics =
        _files.where((f) => f.instrumentId == 2 && !_isPdf(f.platformFile)).length;
    if (invalidLyrics > 0) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Warnung: Liedtext-Format'),
          content: Text(invalidLyrics == 1
              ? '1 Datei wurde als "Liedtext" kategorisiert, ist aber keine PDF-Datei. Die Spieler und Sänger können diese Dateien daher nicht in ihrer Übersicht bei den aktuellen Werken sehen.'
              : '$invalidLyrics Dateien wurden als "Liedtext" kategorisiert, sind aber keine PDF-Dateien. Die Spieler und Sänger können diese Dateien daher nicht in ihrer Übersicht bei den aktuellen Werken sehen.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Trotzdem hochladen'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    final service = ref.read(songFileServiceProvider);
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
        '${failed.length} von ${infos.length} Datei(en) konnten nicht hochgeladen werden.',
      );
      return;
    }
    ToastHelper.showSuccess(
      context,
      infos.length == 1
          ? '1 Datei erfolgreich hochgeladen.'
          : '${infos.length} Dateien erfolgreich hochgeladen.',
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  const Icon(Icons.cloud_upload),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Dateien hochladen',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isUploading ? null : () => Navigator.pop(context, false),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (_files.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  color: AppColors.primary.withAlpha(20),
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Wichtige Infos',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '- Die Besetzung wird nach dem Hochladen automatisch anhand der ausgewählten Instrumente aktualisiert.\n'
                          '- Füge den Instrumenten Synonyme hinzu (Gruppeneinstellungen), um die automatische Zuordnung der Dateien zu verbessern.\n'
                          '- Beim Hochladen mehrerer Dateien kann es je nach Dateigröße und Internetverbindung einige Zeit dauern, bis alle Dateien vollständig hochgeladen sind. Bitte schließen Sie das Fenster nicht, bis der Upload abgeschlossen ist.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_files.isNotEmpty)
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _files.length,
                  itemBuilder: (context, index) => _FileItem(
                    key: ObjectKey(_files[index]),
                    file: _files[index],
                    groups: widget.groups,
                    enabled: !_isUploading,
                    onCategoryChanged: (id, note) => _setCategory(index, id, note),
                    onToggleReplace: (url) => setState(() {
                      final set = _files[index].toReplace;
                      set.contains(url) ? set.remove(url) : set.add(url);
                    }),
                    onRemove: () => setState(() => _files.removeAt(index)),
                  ),
                ),
              ),
            if (_isUploading)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  children: [
                    LinearProgressIndicator(value: _uploadProgress),
                    const SizedBox(height: 8),
                    Text(
                      '$_doneCount von ${_files.length} Dateien hochgeladen',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const Text(
                      'Bitte das Fenster nicht schließen, bis der Upload abgeschlossen ist.',
                      style: TextStyle(fontSize: 12, color: AppColors.medium),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isUploading ? null : _pickFiles,
                    icon: const Icon(Icons.add),
                    label: Text(_files.isEmpty ? 'Dateien wählen' : 'Weitere'),
                  ),
                  if (_files.isNotEmpty && _hasReplacements) ...[
                    OutlinedButton(
                      onPressed: _isUploading ? null : () => _upload(replace: false),
                      child: const Text('Ohne Ersetzen hinzufügen'),
                    ),
                    ElevatedButton(
                      onPressed: _isUploading ? null : () => _upload(replace: true),
                      child: const Text('Ersetzen & Hinzufügen'),
                    ),
                  ] else if (_files.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: _isUploading ? null : () => _upload(replace: false),
                      icon: const Icon(Icons.upload),
                      label: const Text('Hochladen'),
                    ),
                ],
              ),
            ),
          ],
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

  Widget _statusIcon() {
    switch (widget.file.status) {
      case _UploadStatus.uploading:
        return const SizedBox(
            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2));
      case _UploadStatus.done:
        return const Icon(Icons.check_circle, color: AppColors.success, size: 20);
      case _UploadStatus.error:
        return const Icon(Icons.error, color: AppColors.danger, size: 20);
      case _UploadStatus.pending:
        return const Icon(Icons.schedule, color: AppColors.medium, size: 20);
      case null:
        return IconButton(
          icon: const Icon(Icons.close, size: 20),
          onPressed: widget.enabled ? widget.onRemove : null,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = widget.file;
    final items = <DropdownMenuItem<int?>>[
      const DropdownMenuItem(value: null, child: Text('Sonstige (Freitext)')),
      const DropdownMenuItem(value: 1, child: Text('Aufnahme')),
      const DropdownMenuItem(value: 2, child: Text('Liedtext')),
      for (final g in widget.groups)
        if (g.id != null) DropdownMenuItem(value: g.id, child: Text(g.name)),
    ];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    file.platformFile.name,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _statusIcon(),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int?>(
              value: file.instrumentId,
              items: items,
              isExpanded: true,
              onChanged: widget.enabled
                  ? (id) => widget.onCategoryChanged(id, id == null ? _note.text.trim() : null)
                  : null,
              decoration: const InputDecoration(
                labelText: 'Instrument',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            if (file.instrumentId == null) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _note,
                enabled: widget.enabled,
                decoration: const InputDecoration(
                  labelText: 'Freitext',
                  hintText: 'Kategorie eingeben...',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => widget.onCategoryChanged(null, v.trim()),
              ),
            ],
            if (file.conflicts.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Welche Dateien sollen ersetzt werden?',
                style: TextStyle(fontSize: 12, color: AppColors.warning),
              ),
              for (final c in file.conflicts)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: file.toReplace.contains(c.url),
                  title: Text('Ersetzt: ${c.fileName}', style: const TextStyle(fontSize: 13)),
                  onChanged: widget.enabled ? (_) => widget.onToggleReplace(c.url) : null,
                ),
            ],
          ],
        ),
      ),
    );
  }
}
