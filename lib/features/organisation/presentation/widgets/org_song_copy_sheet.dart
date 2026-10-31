import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/org_song_providers.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/demo_guard.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/song_copy.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/models/song/org_song.dart';
import '../../../../data/models/song/song.dart';
import '../../../../data/models/tenant/tenant.dart' show ExtraField;
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../shared/widgets/layout/ionic_ios.dart';
import '../../../songs/presentation/utils/song_utils.dart';

/// Opens the copy dialog of the organisation-wide Werk search (Ionic
/// `org-songs.page` copy modal). [onCopied] gets the target library id.
Future<void> showOrgSongCopySheet(
  BuildContext context, {
  required OrgSongResult source,
  required List<OrgSongCopyTarget> targets,
  required List<OrgSongTenant> orgTenants,
  void Function(int libraryId)? onCopied,
}) {
  return showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => OrgSongCopySheet(source: source, targets: targets, orgTenants: orgTenants, onCopied: onCopied),
  );
}

class _FieldOption {
  _FieldOption({
    required this.key,
    required this.label,
    required this.value,
    required this.checked,
    required this.apply,
    this.currentValue,
  });

  final String key;
  final String label;
  final String value;
  bool checked;

  /// Current value in the existing target Werk, shown when copying into it.
  final String? currentValue;
  final void Function(Map<String, dynamic> fields) apply;
}

class _FileOption {
  _FileOption({required this.file, required this.checked, required this.instrumentId, required this.existsInTarget});

  final OrgSongFile file;
  bool checked;
  int? instrumentId;
  final bool existsInTarget;
}

enum _Mode { existing, created }

class OrgSongCopySheet extends ConsumerStatefulWidget {
  const OrgSongCopySheet({
    super.key,
    required this.source,
    required this.targets,
    required this.orgTenants,
    this.onCopied,
  });

  final OrgSongResult source;
  final List<OrgSongCopyTarget> targets;
  final List<OrgSongTenant> orgTenants;
  final void Function(int libraryId)? onCopied;

  @override
  ConsumerState<OrgSongCopySheet> createState() => _OrgSongCopySheetState();
}

class _OrgSongCopySheetState extends ConsumerState<OrgSongCopySheet> {
  late int _targetLibraryId = widget.targets.first.libraryId;
  bool _loadingTarget = false;
  List<Song> _targetSongs = const [];
  Map<int, Map<String, dynamic>> _targetRows = const {};
  List<Group> _targetGroups = const [];
  List<Song> _duplicates = const [];
  _Mode _mode = _Mode.created;
  int? _existingSongId;
  final _prefix = TextEditingController();
  final _number = TextEditingController();
  List<_FieldOption> _fieldOptions = const [];
  List<_FileOption> _fileOptions = const [];
  bool _copying = false;
  String? _progress;

  OrgSongResult get _song => widget.source;

  @override
  void initState() {
    super.initState();
    _loadTarget();
  }

  @override
  void dispose() {
    _prefix.dispose();
    _number.dispose();
    super.dispose();
  }

  OrgSongCopyTarget? get _currentTarget => widget.targets.where((t) => t.libraryId == _targetLibraryId).firstOrNull;

  int? get _numberValue => int.tryParse(_number.text.trim());

  bool get _numberTaken => isSongNumberTaken(_numberValue, _prefix.text, _targetSongs);

  int get _nextFreeNumber => nextFreeSongNumber(_prefix.text, _targetSongs);

  Song? get _existingSong =>
      _mode == _Mode.existing ? _targetSongs.where((s) => s.id == _existingSongId).firstOrNull : null;

  int get _selectedFileCount => _fileOptions.where((f) => f.checked).length;

  bool get _canCopy {
    if (_copying || _loadingTarget) return false;
    if (_mode == _Mode.existing) {
      return _existingSong != null && (_selectedFileCount > 0 || _fieldOptions.any((f) => f.checked));
    }
    return _numberValue != null && !_numberTaken;
  }

  /// Song extra field definitions of the target library.
  List<ExtraField> get _targetFieldDefs =>
      widget.orgTenants.where((t) => t.id == _targetLibraryId).firstOrNull?.songAdditionalFields ??
      _currentTarget?.tenant.songAdditionalFields ??
      const [];

  Future<void> _loadTarget() async {
    final libraryId = _targetLibraryId;
    setState(() => _loadingTarget = true);
    final repo = ref.read(orgSongRepositoryWithTenantProvider);
    try {
      final results = await Future.wait([repo.getLibrarySongRows(libraryId), repo.getLibraryGroups(libraryId)]);
      if (!mounted || libraryId != _targetLibraryId) return;
      final rows = results[0] as List<Map<String, dynamic>>;
      _targetSongs = rows.map(Song.fromJson).toList();
      _targetRows = {
        for (final r in rows)
          if (r['id'] != null) (r['id'] as num).toInt(): r,
      };
      _targetGroups = results[1] as List<Group>;
    } catch (e) {
      if (!mounted || libraryId != _targetLibraryId) return;
      _targetSongs = const [];
      _targetRows = const {};
      _targetGroups = const [];
      ToastHelper.showError(context, context.l10n.orgSongsTargetLoadFailed(friendlyErrorMessage(e)));
    }
    if (!mounted) return;
    setState(() {
      _loadingTarget = false;
      _duplicates = findSongsWithSameName(_song.name, _targetSongs);
      _mode = _duplicates.isNotEmpty ? _Mode.existing : _Mode.created;
      _existingSongId = _duplicates.firstOrNull?.id;
      _prefix.text = _song.prefix ?? '';
      var number = _song.number;
      if (number != null && isSongNumberTaken(number, _prefix.text, _targetSongs)) {
        number = nextFreeSongNumber(_prefix.text, _targetSongs);
      }
      _number.text = number?.toString() ?? '';
      _buildOptions();
    });
  }

  void _onModeChange(_Mode mode) {
    setState(() {
      _mode = mode;
      if (_mode == _Mode.existing && _existingSongId == null) {
        _existingSongId = _duplicates.firstOrNull?.id;
      }
      _buildOptions();
    });
  }

  static bool _isEmpty(dynamic value) =>
      value == null || value == '' || (value is List && value.isEmpty) || (value is Map && value.isEmpty);

  String _extraValueLabel(dynamic value) {
    if (value == true) return context.l10n.commonYes;
    if (value == false) return context.l10n.commonNo;
    return value == null ? '' : value.toString();
  }

  String _difficultyLabel(int? difficulty) =>
      difficulty == null || difficulty < 1 || difficulty > 3 ? '' : SongUtils.difficultyLabel(difficulty);

  /// Ionic `buildOptions`: fields and files of the source Werk.
  void _buildOptions() {
    final song = _song;
    final existing = _existingSong;
    final existingRow = existing?.id == null ? null : _targetRows[existing!.id!];
    final l10n = context.l10n;
    final options = <_FieldOption>[];
    void add(
      String key,
      String label,
      String value,
      dynamic current,
      String? currentLabel,
      void Function(Map<String, dynamic>) apply,
    ) {
      options.add(
        _FieldOption(
          key: key,
          label: label,
          value: value,
          currentValue: existing != null && !_isEmpty(current) ? currentLabel : null,
          checked: existing != null ? _isEmpty(current) : true,
          apply: apply,
        ),
      );
    }

    final link = song.link;
    if (link != null && link.isNotEmpty) {
      add('link', l10n.songsLink, link, existing?.link, existing?.link, (f) => f['link'] = link);
    }
    final difficulty = song.difficulty;
    if (difficulty != null && difficulty != 0) {
      add(
        'difficulty',
        l10n.orgSongsFieldDifficulty,
        _difficultyLabel(difficulty),
        existing?.difficulty,
        _difficultyLabel(existing?.difficulty),
        (f) => f['difficulty'] = difficulty,
      );
    }
    if (song.withChoir || song.withSolo) {
      options.add(
        _FieldOption(
          key: 'choirSolo',
          label: l10n.orgSongsFieldChoirSolo,
          value: [if (song.withChoir) l10n.orgSongsWithChoir, if (song.withSolo) l10n.orgSongsWithSolo].join(', '),
          checked: true,
          apply: (f) {
            if (song.withChoir) f['withChoir'] = true;
            if (song.withSolo) f['withSolo'] = true;
          },
        ),
      );
    }
    if (song.categoryNames.isNotEmpty) {
      options.add(
        _FieldOption(
          key: 'categories',
          label: l10n.orgSongsFieldCategories,
          value: song.categoryNames.join(', '),
          checked: existing != null ? (existing.categoryIds ?? const []).isEmpty : true,
          // resolved in _copy() because categories may need to be created
          apply: (_) {},
        ),
      );
    }
    for (final mapped in mapExtraFields(song.additionalFields, song.fieldDefs, _targetFieldDefs)) {
      final current = existing?.additionalFields?[mapped.targetField.id];
      add(
        'extra:${mapped.targetField.id}',
        mapped.targetField.name,
        _extraValueLabel(mapped.value),
        current,
        _extraValueLabel(current),
        (f) {
          f['additional_fields'] = {
            ...((f['additional_fields'] as Map<String, dynamic>?) ?? const {}),
            mapped.targetField.id: mapped.value,
          };
        },
      );
    }
    final beamer = song.beamerFile;
    if (beamer != null) {
      final current = existingRow?['beamer_file'];
      add(
        'beamer',
        l10n.orgSongsFieldBeamer,
        (beamer['name'] ?? '').toString(),
        current,
        current is Map ? (current['name'] ?? '').toString() : null,
        (f) => f['beamer_file'] = beamer,
      );
    }
    _fieldOptions = options;

    final existingNames = {for (final f in existing?.files ?? const <SongFile>[]) f.fileName.toLowerCase()};
    _fileOptions = [
      for (final file in song.files)
        () {
          final exists = existingNames.contains(file.fileName.toLowerCase());
          return _FileOption(
            file: file,
            existsInTarget: exists,
            checked: !exists,
            instrumentId: mapGroupByName(file.instrumentId, file.groupName, file.groupSynonyms, _targetGroups),
          );
        }(),
    ];
  }

  String _sourceGroupLabel(OrgSongFile file) {
    if (file.instrumentId == 1) return context.l10n.songsRecording;
    if (file.instrumentId == 2) return context.l10n.songsLyrics;
    return file.groupName ?? file.note ?? context.l10n.songsOther;
  }

  Future<void> _copy() async {
    final target = _currentTarget;
    if (target == null || !_canCopy) return;
    if (DemoGuard.blocked()) return; // DEMO_GUARD
    final l10n = context.l10n;
    final repo = ref.read(orgSongRepositoryWithTenantProvider);

    if (_mode == _Mode.existing) {
      final overwrites = _fieldOptions.where((f) => f.checked && f.currentValue != null).toList();
      if (overwrites.isNotEmpty) {
        final ok = await DialogHelper.showConfirmation(
          context,
          title: l10n.orgSongsOverwriteHeader,
          message: l10n.orgSongsOverwriteMessage(overwrites.map((f) => f.label).join(', ')),
          confirmText: l10n.orgSongsOverwriteConfirm,
        );
        if (!ok || !mounted) return;
      }
    }

    setState(() {
      _copying = true;
      _progress = l10n.songsCopying;
    });
    final existing = _existingSong;
    final mode = _mode;
    try {
      final fields = <String, dynamic>{};
      for (final option in _fieldOptions.where((f) => f.checked)) {
        option.apply(fields);
      }
      if (_fieldOptions.any((f) => f.key == 'categories' && f.checked)) {
        final ids = await repo.ensureSongCategories(target.libraryId, _song.categoryNames);
        fields['category_ids'] = {...?existing?.categoryIds, ...ids}.toList();
      }
      if (mode == _Mode.created) {
        fields['number'] = _numberValue;
        final prefix = _prefix.text.trim();
        fields['prefix'] = prefix.isEmpty ? null : prefix;
      }
      await repo.copyOrgSong(
        OrgSongCopyRequest(
          source: _song,
          targetLibraryId: target.libraryId,
          existingSongId: mode == _Mode.existing ? _existingSongId : null,
          fields: fields,
          files: [
            for (final f in _fileOptions)
              if (f.checked) (file: f.file, instrumentId: f.instrumentId),
          ],
          mainGroupId: _targetGroups.where((g) => g.maingroup == true).firstOrNull?.id,
        ),
        onProgress: (current, total) {
          if (mounted) setState(() => _progress = l10n.songsCopyingFile(current, total));
        },
      );
      if (!mounted) return;
      // The copy may land in the own (or synced) library: reload the Werke.
      ref.invalidate(songsProvider);
      widget.onCopied?.call(target.libraryId);
      final tenantName = target.libraryName ?? target.tenant.shortName;
      ToastHelper.showSuccess(
        context,
        mode == _Mode.existing
            ? l10n.orgSongsMergedInto(_song.name, tenantName)
            : l10n.orgSongsCopiedTo(_song.name, tenantName),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) ToastHelper.showError(context, l10n.songsCopyFailed(friendlyErrorMessage(e)));
    } finally {
      if (mounted) {
        setState(() {
          _copying = false;
          _progress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final target = _currentTarget;
    return PopScope(
      canPop: !_copying,
      child: Column(
        children: [
          IonSheetHeader(
            title: l10n.songsCopySong,
            start: [
              TextButton(onPressed: _copying ? null : () => Navigator.pop(context), child: Text(l10n.commonCancel)),
            ],
            end: [
              TextButton(
                onPressed: _canCopy ? _copy : null,
                child: Text(l10n.songsCopy, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          if (_copying) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  IonInsetList(
                    children: [
                      IonItem(
                        title: Text(orgSongLabel(_song.prefix, _song.number, _song.name)),
                        subtitle: Text(l10n.orgSongsFromTenant(_song.tenantName)),
                      ),
                    ],
                  ),
                  // Target
                  IonListHeader(l10n.orgSongsTarget),
                  IonInsetList(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: AppDropdownFormField<int>(
                          iosInterface: AppSelectInterface.actionSheet,
                          value: _targetLibraryId,
                          decoration: InputDecoration(labelText: l10n.personTargetInstance),
                          isExpanded: true,
                          items: [
                            for (final t in widget.targets)
                              DropdownMenuItem(value: t.libraryId, child: Text(t.tenant.shortName)),
                          ],
                          onChanged:
                              _copying
                                  ? null
                                  : (v) {
                                    if (v == null || v == _targetLibraryId) return;
                                    setState(() => _targetLibraryId = v);
                                    _loadTarget();
                                  },
                        ),
                      ),
                      if (target?.libraryName != null)
                        IonItem(
                          leading: const Icon(Icons.sync, color: AppColors.medium),
                          title: Text(
                            l10n.orgSongsSyncedTarget(target!.tenant.shortName, target.libraryName!),
                            style: const TextStyle(fontSize: 14, color: AppColors.medium),
                          ),
                        ),
                    ],
                  ),
                  if (_loadingTarget)
                    const Padding(padding: EdgeInsets.all(16), child: Center(child: AppSpinner()))
                  else
                    ..._buildTargetDetails(context),
                  if (_progress != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Text(_progress!, style: const TextStyle(fontSize: 13, color: AppColors.medium)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTargetDetails(BuildContext context) {
    final l10n = context.l10n;
    return [
      // Duplicate handling
      if (_duplicates.isNotEmpty)
        IonInsetList(
          children: [
            Container(
              color: AppColors.warning,
              child: ListTile(
                leading: const Icon(Icons.warning_amber_rounded, color: Colors.black),
                title: Text(
                  l10n.orgSongsDuplicateWarning(_duplicates.length),
                  style: const TextStyle(color: Colors.black),
                ),
              ),
            ),
            RadioListTile<_Mode>(
              value: _Mode.existing,
              groupValue: _mode,
              title: Text(l10n.orgSongsModeExisting),
              onChanged: _copying ? null : (v) => _onModeChange(v!),
            ),
            if (_mode == _Mode.existing && _duplicates.length > 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: AppDropdownFormField<int>(
                  iosInterface: AppSelectInterface.actionSheet,
                  value: _existingSongId,
                  decoration: InputDecoration(labelText: l10n.orgSongsExistingSong),
                  isExpanded: true,
                  items: [
                    for (final d in _duplicates)
                      if (d.id != null)
                        DropdownMenuItem(value: d.id, child: Text(orgSongLabel(d.prefix, d.number, d.name))),
                  ],
                  onChanged:
                      (v) => setState(() {
                        _existingSongId = v;
                        _buildOptions();
                      }),
                ),
              ),
            RadioListTile<_Mode>(
              value: _Mode.created,
              groupValue: _mode,
              title: Text(l10n.orgSongsModeNew),
              onChanged: _copying ? null : (v) => _onModeChange(v!),
            ),
          ],
        ),
      // Number (new Werk)
      if (_mode == _Mode.created) ...[
        IonListHeader(l10n.orgSongsNumber),
        IonInsetList(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _prefix,
                maxLength: 5,
                decoration: InputDecoration(labelText: l10n.orgSongsPrefix, counterText: ''),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _number,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.orgSongsNumber),
                style: _numberTaken ? const TextStyle(color: AppColors.danger) : null,
                onChanged: (_) => setState(() {}),
              ),
            ),
            if (_numberTaken)
              IonItem(
                leading: const Icon(Icons.error_outline, color: AppColors.danger),
                title: Text(l10n.orgSongsNumberTaken, style: const TextStyle(color: AppColors.danger)),
                subtitle: Text(l10n.orgSongsUseNextFree('${_prefix.text}$_nextFreeNumber')),
                onTap: () => setState(() => _number.text = '$_nextFreeNumber'),
              ),
          ],
        ),
      ],
      // Fields
      if (_fieldOptions.isNotEmpty) ...[
        IonListHeader(l10n.orgSongsFields),
        IonInsetList(
          children: [
            for (final option in _fieldOptions)
              CheckboxListTile(
                controlAffinity: ListTileControlAffinity.leading,
                value: option.checked,
                title: Text(option.label),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(option.value),
                    if (option.currentValue != null)
                      Text(
                        l10n.orgSongsCurrentValue(option.currentValue!),
                        style: const TextStyle(color: AppColors.warning),
                      ),
                  ],
                ),
                onChanged: _copying ? null : (v) => setState(() => option.checked = v ?? false),
              ),
          ],
        ),
      ],
      // Files
      if (_fileOptions.isNotEmpty) ...[
        IonListHeader(
          l10n.orgSongsFiles(_selectedFileCount, _fileOptions.length),
          trailing: [
            TextButton(
              onPressed:
                  _copying
                      ? null
                      : () => setState(() {
                        final all = _selectedFileCount < _fileOptions.length;
                        for (final f in _fileOptions) {
                          f.checked = all;
                        }
                      }),
              child: Text(_selectedFileCount < _fileOptions.length ? l10n.orgSongsSelectAll : l10n.orgSongsSelectNone),
            ),
          ],
        ),
        IonInsetList(children: [for (final option in _fileOptions) _buildFileRow(context, option)]),
      ],
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Text(l10n.orgSongsCopyHint, style: const TextStyle(fontSize: 13, color: AppColors.medium)),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: _canCopy ? _copy : null,
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
          child: Text(_mode == _Mode.existing ? l10n.orgSongsCopyIntoExisting : l10n.orgSongsCopyAsNew),
        ),
      ),
    ];
  }

  Widget _buildFileRow(BuildContext context, _FileOption option) {
    final l10n = context.l10n;
    final groups = _targetGroups.where((g) => g.id != null && !reservedFileGroupIds.contains(g.id)).toList();
    final values = <int?>{null, 1, 2, for (final g in groups) g.id};
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          Checkbox(
            value: option.checked,
            onChanged: _copying ? null : (v) => setState(() => option.checked = v ?? false),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(option.file.fileName, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(
                  l10n.orgSongsSourceGroup(_sourceGroupLabel(option.file)),
                  style: const TextStyle(fontSize: 13, color: AppColors.medium),
                ),
                if (option.existsInTarget)
                  Text(l10n.orgSongsFileExists, style: const TextStyle(fontSize: 13, color: AppColors.warning)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: DropdownButtonHideUnderline(
              child: AppDropdownButton<int?>(
                iosInterface: AppSelectInterface.actionSheet,
                isExpanded: true,
                value: values.contains(option.instrumentId) ? option.instrumentId : null,
                hint: Text(l10n.orgSongsTargetGroup),
                items: [
                  DropdownMenuItem(value: null, child: Text(l10n.songsOther)),
                  DropdownMenuItem(value: 1, child: Text(l10n.songsRecording)),
                  DropdownMenuItem(value: 2, child: Text(l10n.songsLyrics)),
                  for (final g in groups) DropdownMenuItem(value: g.id, child: Text(g.name)),
                ],
                onChanged: !option.checked || _copying ? null : (v) => setState(() => option.instrumentId = v),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
