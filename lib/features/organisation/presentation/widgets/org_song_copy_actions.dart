part of 'org_song_copy_sheet.dart';

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
  _FileOption({
    required this.file,
    required this.checked,
    required this.instrumentId,
    required this.existsInTarget,
  });

  final OrgSongFile file;
  bool checked;
  int? instrumentId;
  final bool existsInTarget;
}

enum _Mode { existing, created }

extension _OrgSongCopyActions on _OrgSongCopySheetState {
  Future<void> _loadTarget() async {
    final libraryId = _targetLibraryId;
    _update(() => _loadingTarget = true);
    final repo = ref.read(orgSongRepositoryWithTenantProvider);
    try {
      final results = await Future.wait([
        repo.getLibrarySongRows(libraryId),
        repo.getLibraryGroups(libraryId),
      ]);
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
      ToastHelper.showError(
        context,
        context.l10n.orgSongsTargetLoadFailed(friendlyErrorMessage(e)),
      );
    }
    if (!mounted) return;
    _update(() {
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
    _update(() {
      _mode = mode;
      if (_mode == _Mode.existing && _existingSongId == null) {
        _existingSongId = _duplicates.firstOrNull?.id;
      }
      _buildOptions();
    });
  }

  String _extraValueLabel(dynamic value) {
    if (value == true) return context.l10n.commonYes;
    if (value == false) return context.l10n.commonNo;
    return value == null ? '' : value.toString();
  }

  String _difficultyLabel(int? difficulty) =>
      difficulty == null || difficulty < 1 || difficulty > 3
          ? ''
          : SongUtils.difficultyLabel(difficulty);

  /// Collects copyable metadata fields and files for the selected target mode.
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
          currentValue: existing != null && !_OrgSongCopySheetState._isEmpty(current) ? currentLabel : null,
          checked: existing != null ? _OrgSongCopySheetState._isEmpty(current) : true,
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
          value: [
            if (song.withChoir) l10n.orgSongsWithChoir,
            if (song.withSolo) l10n.orgSongsWithSolo,
          ].join(', '),
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
          // Resolved in _copy() because missing categories are created on demand.
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

    final existingNames = {
      for (final f in existing?.files ?? const <SongFile>[]) f.fileName.toLowerCase(),
    };
    _fileOptions = [
      for (final file in song.files)
        () {
          final exists = existingNames.contains(file.fileName.toLowerCase());
          return _FileOption(
            file: file,
            existsInTarget: exists,
            checked: !exists,
            instrumentId: mapGroupByName(
              file.instrumentId,
              file.groupName,
              file.groupSynonyms,
              _targetGroups,
            ),
          );
        }(),
    ];
  }

  String _sourceGroupLabel(OrgSongFile file) {
    if (file.instrumentId == 1) return context.l10n.songsRecording;
    if (file.instrumentId == 2) return context.l10n.songsLyrics;
    return file.groupName ?? file.note ?? context.l10n.songsOther;
  }

  String _targetGroupLabel(int? instrumentId, AppLocalizations l10n) {
    if (instrumentId == null) return l10n.songsOther;
    if (instrumentId == 1) return l10n.songsRecording;
    if (instrumentId == 2) return l10n.songsLyrics;
    return _availableTargetGroups.where((g) => g.id == instrumentId).firstOrNull?.name ?? l10n.songsOther;
  }

  Future<void> _pickTarget() async {
    final choice = await showAppActionSheet<int>(
      context,
      title: context.l10n.personTargetInstance,
      actions: [
        for (final t in widget.targets)
          AppActionSheetAction<int>(
            value: t.libraryId,
            label: t.tenant.shortName,
            selected: t.libraryId == _targetLibraryId,
          ),
      ],
    );
    if (!mounted || choice == null || choice == _targetLibraryId) return;
    _update(() => _targetLibraryId = choice);
    await _loadTarget();
  }

  Future<void> _pickExistingSong() async {
    final choice = await showAppActionSheet<int>(
      context,
      title: context.l10n.orgSongsExistingSong,
      actions: [
        for (final d in _duplicates)
          if (d.id != null)
            AppActionSheetAction<int>(
              value: d.id!,
              label: orgSongLabel(d.prefix, d.number, d.name),
              selected: d.id == _existingSongId,
            ),
      ],
    );
    if (!mounted || choice == null) return;
    _update(() {
      _existingSongId = choice;
      _buildOptions();
    });
  }

  Future<void> _pickFileGroup(_FileOption option) async {
    final l10n = context.l10n;
    final groups = _availableTargetGroups;
    final current = _validTargetGroupId(option.instrumentId, groups);
    final choice = await showAppActionSheet<({int? id})>(
      context,
      title: l10n.orgSongsTargetGroup,
      actions: [
        AppActionSheetAction<({int? id})>(
          value: (id: null),
          label: l10n.songsOther,
          selected: current == null,
        ),
        AppActionSheetAction<({int? id})>(
          value: const (id: 1),
          label: l10n.songsRecording,
          selected: current == 1,
        ),
        AppActionSheetAction<({int? id})>(
          value: const (id: 2),
          label: l10n.songsLyrics,
          selected: current == 2,
        ),
        for (final g in groups)
          AppActionSheetAction<({int? id})>(
            value: (id: g.id),
            label: g.name,
            selected: current == g.id,
          ),
      ],
    );
    if (!mounted || choice == null) return;
    _update(() => option.instrumentId = choice.id);
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

    _update(() {
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
          if (mounted) _update(() => _progress = l10n.songsCopyingFile(current, total));
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
        _update(() {
          _copying = false;
          _progress = null;
        });
      }
    }
  }
}
