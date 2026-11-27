part of 'rd_work_files.dart';

/// File actions, selection state, and keyboard shortcuts for [RdWorkFiles].
extension _RdWorkFilesActions on _RdWorkFilesState {
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
    _update(() => _busy = true);
    try {
      await task();
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, e is ZipDownloadException ? e.message(context.l10n) : friendlyErrorMessage(e));
      }
    } finally {
      if (mounted) _update(() => _busy = false);
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
    _update(() {
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
    _update(() {
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
    _update(() => _renaming = null);
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
      _update(() {
        _cursor = file.url;
        _anchor = file.url;
      });
      _focus.requestFocus();
      _open(file);
      return;
    }
    _update(() {
      _selecting = true;
      if (shift && _anchor != null) {
        _selected = rdRangeSelection(order, _anchor!, file.url);
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
    _update(() {
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
    _update(() {
      _selecting = false;
      _selected = {};
    });
    _focus.requestFocus();
  }

  void _toggle(SongFile file, bool? value) {
    _update(() {
      _selecting = true;
      _selected = {..._selected};
      value == true ? _selected.add(file.url) : _selected.remove(file.url);
      _anchor = file.url;
      _cursor = file.url;
    });
    _focus.requestFocus();
  }

  void _selectAll(List<SongFile> files, bool all) {
    _update(() {
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
    if (_modPressed) return _onModKey(key, files);

    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp) {
      if (order.isEmpty) return KeyEventResult.handled;
      final current = _cursor == null ? null : order.indexOf(_cursor!);
      final next =
          order[rdNextIndex(
            current == -1 ? null : current,
            key == LogicalKeyboardKey.arrowDown ? 1 : -1,
            order.length,
          )];
      _update(() {
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

  KeyEventResult _onModKey(LogicalKeyboardKey key, List<SongFile> files) {
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
}
