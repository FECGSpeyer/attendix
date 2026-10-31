import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/group_providers.dart';
import '../../../../core/services/part_vision_service.dart';
import '../../../../core/services/song_file_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/instrument_matcher.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/models/song/song.dart';
import '../utils/song_utils.dart';
import 'file_upload_sheet.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/ion_button_label.dart';

/// Result of [SingleFileUploadSheet].
enum SingleFileUploadResult {
  /// The file was uploaded.
  uploaded,

  /// "Hinzufügen" with conflicts: continue in the multi-file upload sheet.
  openUploadSheet,
}

/// Ionic single-file modal ("Datei hochladen") that opens when exactly one
/// file is dropped onto the file list of a song: category radio list,
/// replacement of existing files of that category, direct upload.
class SingleFileUploadSheet extends ConsumerStatefulWidget {
  const SingleFileUploadSheet({
    super.key,
    required this.songId,
    required this.file,
    required this.groups,
    required this.existingFiles,
    this.mainGroupId,
    this.isChoir = false,
    this.workName,
  });

  /// Name of the Werk, left out of terms remembered as synonyms.
  final String? workName;

  final int songId;
  final PlatformFile file;
  final List<Group> groups;
  final List<SongFile> existingFiles;
  final int? mainGroupId;
  final bool isChoir;

  @override
  ConsumerState<SingleFileUploadSheet> createState() => _SingleFileUploadSheetState();
}

class _SingleFileUploadSheetState extends ConsumerState<SingleFileUploadSheet> {
  int? _instrumentId;
  final _note = TextEditingController();
  List<SongFile> _conflicts = const [];
  Set<String> _toReplace = {};
  bool _uploading = false;

  /// How sure the automatic detection was; changed by hand → hint hidden.
  MatchConfidence _confidence = MatchConfidence.sure;
  bool _reviewed = false;

  /// File-name term to remember for the chosen group, and whether to.
  String? _learnTerm;
  bool _learn = false;

  /// The first page is being read / the part was read there (label).
  bool _reading = false;
  String? _visionLabel;

  List<InstrumentInfo> get _instruments => [
        for (final g in widget.groups)
          if (g.id != null) InstrumentInfo(id: g.id!, name: g.name, synonyms: g.synonyms),
      ];

  @override
  void initState() {
    super.initState();
    final cat = guessFileCategory(
      widget.file.name,
      instruments: _instruments,
      isChoir: widget.isChoir,
    );
    _instrumentId = cat.instrumentId;
    _note.text = cat.note ?? '';
    _confidence = cat.confidence;
    // An unsure part can be confirmed for learning right away (unchecked).
    if (cat.confidence == MatchConfidence.unsure) {
      _learnTerm = learnableTerm(
        widget.file.name,
        chosenId: cat.instrumentId,
        instruments: _instruments,
        workName: widget.workName,
      );
    }
    _refreshConflicts();
    if (cat.canAskVision(widget.file.name) && _instruments.isNotEmpty) {
      _reading = true;
      _readFirstPage();
    }
  }

  /// Fallback for an unclear name: the part printed on page 1.
  Future<void> _readFirstPage() async {
    final vision = ref.read(partVisionServiceProvider);
    // Pinned to the tenant the sheet was opened in.
    final match = await vision.detect(
      widget.file,
      _instruments,
      tenantId: vision.currentTenant(),
      cancelled: () => !mounted || _reviewed || _uploading,
    );
    if (!mounted) return;
    setState(() {
      _reading = false;
      if (match == null || _reviewed || _uploading) return;
      _instrumentId = match.instrumentId;
      _confidence = match.confidence;
      _visionLabel = match.term ?? widget.groups.where((g) => g.id == match.instrumentId).firstOrNull?.name ?? '';
      _learnTerm = null;
      _learn = false;
      _refreshConflicts();
    });
  }

  void _choose(int? id) {
    _instrumentId = id;
    _reviewed = true;
    _learnTerm = learnableTerm(
      widget.file.name,
      chosenId: id,
      instruments: _instruments,
      workName: widget.workName,
    );
    _learn = _learnTerm != null;
    _refreshConflicts();
  }

  /// Saves the term of a hand-assigned file as group synonym.
  Future<void> _rememberTerm() async {
    final id = _instrumentId;
    final term = _learnTerm;
    if (!_learn || id == null || term == null) return;
    final ok = await ref.read(groupNotifierProvider.notifier).addSynonyms({id: [term]});
    if (!ok && mounted) ToastHelper.showError(context, context.l10n.songsFlutterLearnFailed);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  String? get _effectiveNote => _instrumentId == null ? _note.text.trim() : null;

  /// Ionic `refreshSingleFileConflicts`
  void _refreshConflicts() {
    _conflicts = findConflictingFiles(widget.existingFiles, _instrumentId, _effectiveNote);
    _toReplace = defaultReplaceSelection(_conflicts, widget.file.name);
  }

  /// Ionic `performDirectUpload`
  Future<void> _upload({required bool replace}) async {
    setState(() => _uploading = true);
    final service = await ref.read(readySongFileServiceProvider.future);
    try {
      if (replace) {
        for (final c in _conflicts.where((c) => _toReplace.contains(c.url))) {
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
        file: widget.file,
        instrumentId: _instrumentId,
        note: _effectiveNote,
        mainGroupId: widget.mainGroupId,
      );
      if (!mounted) return;
      await _rememberTerm();
      if (mounted) Navigator.pop(context, SingleFileUploadResult.uploaded);
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ToastHelper.showError(context, context.l10n.songsFlutterUploadFailedWith(friendlyErrorMessage(e)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = <(int?, String)>[
      (null, context.l10n.songsOtherFreeText),
      (1, context.l10n.songsRecording),
      (2, context.l10n.songsLyrics),
      for (final g in widget.groups)
        if (g.id != null) (g.id, g.name),
    ];
    return PopScope(
      canPop: !_uploading,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.95),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.songsUploadFile,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, semanticLabel: context.l10n.commonClose),
                      onPressed: _uploading ? null : () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              if (_uploading)
                const LinearProgressIndicator(minHeight: 2)
              else
                const Divider(height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: Text(widget.file.name),
                      subtitle: _reading && !_reviewed
                          ? Text(
                              context.l10n.songsFlutterVisionReading,
                              style: const TextStyle(fontSize: 12, color: AppColors.medium),
                            )
                          : _visionLabel != null && !_reviewed
                          ? Text(
                              _confidence == MatchConfidence.sure
                                  ? context.l10n.songsFlutterVisionSure(_visionLabel!)
                                  : context.l10n.songsFlutterVisionUnsure,
                              style: TextStyle(
                                fontSize: 12,
                                color: _confidence == MatchConfidence.sure ? AppColors.success : AppColors.warning,
                              ),
                            )
                          : !_reviewed && _confidence != MatchConfidence.sure
                          ? Text(
                              _confidence == MatchConfidence.unsure
                                  ? context.l10n.songsFlutterDetectUnsure
                                  : context.l10n.songsFlutterDetectNone,
                              style: TextStyle(
                                fontSize: 12,
                                color: _confidence == MatchConfidence.unsure ? AppColors.warning : AppColors.danger,
                              ),
                            )
                          : null,
                    ),
                    const Divider(height: 1),
                    for (final o in options)
                      RadioListTile<int?>(
                        dense: true,
                        value: o.$1,
                        groupValue: _instrumentId,
                        title: Text(o.$2),
                        onChanged: _uploading
                            ? null
                            : (v) => setState(() => _choose(v)),
                      ),
                    if (_learnTerm != null && _instrumentId != null)
                      CheckboxListTile(
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _learn,
                        title: Text(
                          context.l10n.songsFlutterLearnTerm(
                            _learnTerm!,
                            widget.groups.where((g) => g.id == _instrumentId).firstOrNull?.name ?? '',
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                        onChanged: _uploading
                            ? null
                            : (v) => setState(() {
                                // Confirmed by hand: a late page-1 result keeps it.
                                _learn = v ?? false;
                                _reviewed = true;
                              }),
                      ),
                    if (_instrumentId == null) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Text(
                          context.l10n.songsFreeText,
                          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.medium),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: _note,
                          decoration: InputDecoration(hintText: context.l10n.songsEnterCategory),
                          onChanged: (_) => setState(() {
                            // Typed by hand: a late page-1 result keeps it.
                            _reviewed = true;
                            _refreshConflicts();
                          }),
                        ),
                      ),
                    ],
                    if (_conflicts.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        color: AppColors.warning.withAlpha(60),
                        child: ListTile(
                          leading: const Icon(Icons.warning_amber_rounded),
                          title: Text(_conflicts.length == 1
                              ? context.l10n.songsReplaces(_conflicts.first.fileName)
                              : context.l10n.songsWhichReplace),
                        ),
                      ),
                    if (_conflicts.length > 1)
                      for (final c in _conflicts)
                        CheckboxListTile(
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _toReplace.contains(c.url),
                          title: Text(c.fileName),
                          secondary: SongBadge(
                            color: SongUtils.fileBadgeColor(c),
                            label: SongUtils.fileLabel(c, widget.groups),
                          ),
                          onChanged: (_) => setState(() {
                            // Chosen by hand: a late page-1 result keeps it.
                            _reviewed = true;
                            _toReplace.contains(c.url)
                                ? _toReplace.remove(c.url)
                                : _toReplace.add(c.url);
                          }),
                        ),
                  ],
                ),
              ),
              // Ionic footer toolbar
              const Divider(height: 1),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: _uploading ? null : () => Navigator.pop(context),
                        child: IonButtonLabel(context.l10n.commonCancel),
                      ),
                      const Spacer(),
                      if (_conflicts.isNotEmpty) ...[
                        TextButton(
                          onPressed: _uploading
                              ? null
                              : () => Navigator.pop(
                                  context, SingleFileUploadResult.openUploadSheet),
                          child: IonButtonLabel(context.l10n.attendanceAdd),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                          onPressed: _uploading ? null : () => _upload(replace: true),
                          child: IonButtonLabel(context.l10n.personReplace),
                        ),
                      ] else
                        TextButton(
                          onPressed: _uploading ? null : () => _upload(replace: false),
                          child: IonButtonLabel(context.l10n.songsUpload),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
