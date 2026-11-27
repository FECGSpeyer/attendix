part of 'rd_import_controller.dart';

// Private upload pipeline (new groups, 3-way parallel Werk upload, synonym
// learning, cancellation & tenant-switch safety) for [RdImportController].
extension _RdImportControllerUpload on RdImportController {
  Future<void> _runUpload({Set<String>? only}) async {
    final plan = _state.plan;
    final source = _source;
    if (plan == null || source == null) return;
    // Unconfirmed KI answers and dates still being read are not uploaded.
    if (_state.aiFilled.isNotEmpty || _state.readingDates) return;
    _dropStaleConfirmations();
    // Bound before the first await (tenant switch safety).
    final tenantId = _tenantId;
    if (tenantId == null || ref.read(currentTenantIdProvider) != tenantId) return;
    final SongRepository songs = ref.read(songRepositoryWithTenantProvider);
    final groupNotifier = ref.read(groupNotifierProvider.notifier);
    final decisions = _state.decisions;
    var items = rdImportUploads(plan, decisions);
    if (only != null) items = items.where((i) => only.contains(i.file.path)).toList();
    if (items.isEmpty) return;

    // Pages still being read do not change what is uploaded.
    _pagesRun++;
    _keep ??= ref.keepAlive();
    _cancel = false;
    var progress = RdImportUpload(total: items.length);
    _show(progress, step: RdImportStep.uploading);
    final failures = <RdImportFailure>[];
    final succeeded = <String>{};
    bool tenantChanged() => _disposed || ref.read(currentTenantIdProvider) != tenantId;

    try {
      final service = await ref.read(readySongFileServiceProvider.future);

      // 1. New groups.
      final existingGroups = await ref.read(groupsProvider.future);
      for (final name in rdImportNewGroups(items)) {
        if (_createdGroups.containsKey(name)) continue;
        if (tenantChanged()) return;
        if (_cancel) break;
        final same = existingGroups.where((g) => g.name.trim().toLowerCase() == name.trim().toLowerCase() && g.id != null);
        if (same.isNotEmpty) {
          _createdGroups[name] = same.first.id!;
          continue;
        }
        final group = await groupNotifier.createGroup({'name': name, 'maingroup': false});
        if (group?.id == null) {
          for (final i in items.where((i) => i.stores.any((c) => c.newGroup == name))) {
            failures.add(RdImportFailure(path: i.file.path, work: i.work.title, error: name));
          }
          continue;
        }
        _createdGroups[name] = group!.id!;
        progress = progress.copyWith(newGroups: progress.newGroups + 1);
      }

      // 2. The files, three Werke at a time, each Werk file by file; a new
      // Werk is created right before its first file (a cancel leaves no
      // empty Werke).
      final failed = {for (final f in failures) f.path};
      final byWork = <String, List<RdUploadItem>>{};
      for (final i in items) {
        if (failed.contains(i.file.path)) continue;
        byWork.putIfAbsent(i.work.key, () => []).add(i);
      }
      final queue = byWork.values.toList();
      var done = failures.length;
      progress = progress.copyWith(filesSince: DateTime.now(), filesFrom: done);
      _show(progress.copyWith(done: done, failures: [...failures], cancelled: _cancel));

      /// The Werk of [list]: found, created before, or created now ([fresh]);
      /// null when that failed (then its files failed too).
      Future<({int id, bool fresh})?> songOf(List<RdUploadItem> list) async {
        final work = list.first.work;
        final target = rdTargetOf(plan, decisions, work);
        if (target.songId != null) return (id: target.songId!, fresh: false);
        final created = _created[work.key];
        if (created != null) return (id: created, fresh: false);
        try {
          final song = await songs.createSong(
              // A new Werk chosen by hand gets the Sammlung's Kürzel too.
              Song(name: target.name!, number: target.number, prefix: target.prefix ?? plan.newPrefix, collectionId: _state.collectionId));
          if (song.id == null) throw StateError('no id');
          progress = progress.copyWith(newWorks: progress.newWorks + 1);
          return (id: _created[work.key] = song.id!, fresh: true);
        } catch (e) {
          for (final i in list) {
            failures.add(RdImportFailure(path: i.file.path, work: work.title, error: friendlyErrorMessage(e)));
          }
          done += list.length;
          return null;
        }
      }

      Future<void> worker() async {
        while (queue.isNotEmpty) {
          if (tenantChanged() || _cancel) return;
          final list = queue.removeAt(0);
          final song = await songOf(list);
          if (song == null) continue;
          final songId = song.id;
          for (final item in list) {
            if (tenantChanged()) return;
            // A Werk created just now still gets its first file (no empty
            // Werk when "Abbrechen" came meanwhile).
            if (_cancel && !(song.fresh && item == list.first)) return;
            progress = progress.copyWith(current: '${item.file.name} · ${item.work.title}', succeeded: succeeded.length);
            _show(progress.copyWith(done: done, failures: [...failures], cancelled: _cancel));
            try {
              // A part for several groups is stored once per group.
              final several = item.stores.length > 1;
              for (final c in item.stores) {
                final instrumentId = c.newGroup != null ? _createdGroups[c.newGroup] : c.instrumentId;
                final part = '${item.file.path}|$instrumentId';
                if (several && _storedParts.contains(part)) continue;
                if (tenantChanged()) return;
                await source.upload(
                  service,
                  songId: songId,
                  path: item.file.path,
                  fileName: item.file.name,
                  instrumentId: instrumentId,
                  note: c.note,
                  mainGroupId: _mainGroupId,
                );
                if (several) _storedParts.add(part);
              }
              succeeded.add(item.file.path);
            } catch (e) {
              failures.add(RdImportFailure(path: item.file.path, work: item.work.title, error: _uploadError(e)));
            }
            done++;
          }
        }
      }

      await Future.wait([worker(), worker(), worker()]);
      if (tenantChanged()) {
        progress = progress.copyWith(done: done, failures: [...failures], aborted: true);
        return;
      }
      // Cancelled: what was not uploaded can be uploaded later ("Restliche
      // Dateien hochladen").
      if (_cancel) {
        final failed = {for (final f in failures) f.path};
        for (final i in items) {
          if (!succeeded.contains(i.file.path) && !failed.contains(i.file.path)) {
            failures.add(RdImportFailure(path: i.file.path, work: i.work.title, error: '', cancelled: true));
          }
        }
      }

      // 3. Part names chosen by hand become terms of their groups.
      final uploaded = items.where((i) => succeeded.contains(i.file.path)).toList();
      final groups = await ref.read(groupsProvider.future).catchError((_) => existingGroups);
      final instruments = [
        for (final g in groups)
          if (g.id != null && g.maingroup != true) InstrumentInfo(id: g.id!, name: g.name, synonyms: g.synonyms),
        for (final e in _createdGroups.entries)
          if (!groups.any((g) => g.id == e.value)) InstrumentInfo(id: e.value, name: e.key),
      ];
      final terms = rdImportLearnedTerms(plan, decisions, uploaded, instruments: instruments, groupIds: _createdGroups);
      var learnFailed = false;
      if (terms.isNotEmpty && !tenantChanged()) {
        learnFailed = !await groupNotifier.addSynonyms(terms);
      }
      progress = progress.copyWith(
        done: items.length,
        failures: [...failures],
        learned: learnFailed ? 0 : terms.values.fold<int>(0, (n, list) => n + list.length),
        learnFailed: learnFailed,
        finished: true,
        cancelled: _cancel,
      );
    } catch (e) {
      // Every file not uploaded yet can be tried again.
      final error = friendlyErrorMessage(e);
      final failed = {for (final f in failures) f.path};
      progress = progress.copyWith(
        failures: [
          ...failures,
          for (final i in items)
            if (!succeeded.contains(i.file.path) && !failed.contains(i.file.path))
              RdImportFailure(path: i.file.path, work: i.work.title, error: error),
        ],
        finished: true,
      );
    } finally {
      if (!_disposed) {
        ref.invalidate(songsProvider);
        ref.invalidate(songsListDataProvider);
        ref.invalidate(groupsProvider);
        final switched = ref.read(currentTenantIdProvider) != tenantId;
        // Kept until the result was seen (the page may have been left),
        // not into another group.
        _show(
          progress.copyWith(succeeded: succeeded.length, finished: true, aborted: progress.aborted || switched),
          step: RdImportStep.done,
        );
        if (switched) resultSeen();
      }
    }
  }
}
