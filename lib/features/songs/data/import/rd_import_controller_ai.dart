part of 'rd_import_controller.dart';

// Private AI suggestion, work-matching, and page-1 vision helpers for
// [RdImportController].
extension _RdImportControllerAi on RdImportController {
  /// Asks the KI about the questions (one request for all).
  Future<void> _suggest() async {
    final plan = _state.plan;
    final tenantId = _tenantId;
    // A part for several groups ("Posaune und Tuba") goes to all of them:
    // the KI would name only one.
    final questions = plan?.questions.where((q) => q.several.isEmpty).toList() ?? const <RdImportQuestion>[];
    if (plan == null || tenantId == null || !_state.useAi || questions.isEmpty) return;
    final run = ++_aiRun;
    _state = _state.copyWith(aiStatus: RdImportAiStatus.loading);
    ({Map<String, RdImportAiAnswer> answers, RdImportAiStatus status}) result;
    try {
      result = await ref.read(rdImportAiProvider).suggest(
        tenantId,
        questions,
        groups: {for (final g in plan.instruments) g.id},
        isChoir: plan.isChoir,
      );
    } catch (_) {
      result = (answers: const {}, status: RdImportAiStatus.failed);
    }
    if (_disposed || run != _aiRun || !_state.useAi) return;
    // A name alone ("Solo", "Parts") often says nothing where page 1 names
    // the part: the KI's "Ohne Zuordnung" becomes "Von Seite 1 lesen" when
    // there is a page to read (Leon, 08.11.2026).
    final readable = {for (final q in questions) if (canReadPages(q)) q.key};
    final ai = {
      for (final e in result.answers.entries)
        e.key: e.value.category == RdImportCategory.other && readable.contains(e.key)
            ? RdImportAiAnswer(const RdImportCategory.fromPage(), sure: e.value.sure)
            : e.value,
    };
    _state = _state.copyWith(ai: ai, aiStatus: result.status);
    // Filled in only while the questions are shown: after them the plan is
    // made and checked with the answers given.
    if (_state.step == RdImportStep.questions) _applyAi();
  }


  /// Fills in the sure guesses of questions nobody answered yet.
  void _applyAi() {
    final answers = {..._state.decisions.answers};
    final filled = {..._state.aiFilled};
    for (final e in _state.ai.entries) {
      // Also when the known instrument proposes the same new group: the
      // answer shows as the KI's (✦) and is confirmed like the others.
      if (!e.value.sure || answers.containsKey(e.key)) continue;
      answers[e.key] = e.value.category;
      filled.add(e.key);
    }
    _state = _state.copyWith(decisions: _state.decisions.copyWith(answers: answers), aiFilled: filled);
    _dropStaleConfirmations();
  }

  /// Asks the KI which Werk in Attendix the folders are that the comparison
  /// is not sure about (other spelling, translation, typo). Its sure answers
  /// become Werke "zu prüfen"; nothing is taken unseen.
  Future<void> _matchWorks() async {
    final plan = _state.plan;
    final tenantId = _tenantId;
    final input = _input;
    if (plan == null || tenantId == null || input == null || !_state.useAi) return;
    final folders = rdImportWorksToAsk(plan);
    if (folders.isEmpty) return;
    final run = ++_worksRun;
    final found = await ref.read(rdImportAiProvider).matchWorks(tenantId, folders, songs: plan.songs.keys.toSet());
    if (_disposed || run != _worksRun || !_state.useAi || !identical(_input, input) || found.isEmpty) return;
    // Only while the questions are shown: in the review the Werke may have
    // been decided about already.
    if (_state.step != RdImportStep.questions) return;
    _aiWorks = found;
    _replan();
  }

  void _clearPages() {
    _readFirst = null;
    _pagesRun++;
    _pageReads = const {};
    _pagesTried.clear();
    _pageImages.clear();
  }

  /// Lets the KI read page 1 of the files whose part nobody knows (four at
  /// a time, at most [rdImportMaxPageReads] per import) while the review is
  /// shown; Werke with "Passt so" are left alone. A sure read of a group
  /// takes the file out of "Stimme unklar" (✦ Seite 1); other reads are
  /// proposed, and the file stays to be checked. A file whose read was cut
  /// off is read another time.
  Future<void> _readPages() async {
    final source = _source;
    final tenantId = _tenantId;
    final run = _pagesRun;
    if (_pagesLoop == run || source == null || tenantId == null) return;
    bool current() =>
        !_disposed &&
        run == _pagesRun &&
        identical(_source, source) &&
        _state.useAi &&
        _state.step == RdImportStep.review;
    bool stopped() => !current() || _state.pages.limit;
    final vision = ref.read(partVisionServiceProvider);
    var done = 0;
    var total = 0;
    void show({bool? limit}) => _state = _state.copyWith(pages: (done: done, total: total, limit: limit ?? _state.pages.limit));
    _pagesLoop = run;
    try {
      while (!stopped()) {
        final plan = _state.plan;
        if (plan == null) return;
        final paths = [
          for (final p in rdImportPagesToRead(plan, _state.decisions))
            if (!_pagesTried.contains(p) && PartVisionService.supports(p)) p,
        ];
        // The budget is spent on what is taken, so a Werk opened later is
        // read too when its pages lie beyond the first ones.
        var left = rdImportMaxPageReads - _pagesTried.length;
        if (paths.isEmpty || left <= 0) return;
        total += paths.length < left ? paths.length : left;
        show();
        final pending = [...paths];
        final workOf = {
          for (final w in plan.works)
            for (final f in w.files) f.path: w.key,
        };
        // The Werk open now first, then in the order of the Werke.
        String? take() {
          if (pending.isEmpty || left <= 0) return null;
          left--;
          final first = _readFirst;
          final i = first == null ? -1 : pending.indexWhere((p) => workOf[p] == first);
          return pending.removeAt(i < 0 ? 0 : i);
        }

        Future<void> worker() async {
          while (!stopped()) {
            final path = take();
            if (path == null) return;
            RdImportPageRead? read;
            var limit = false;
            try {
              final image = await _pageImage(source, path);
              final work = plan.work(workOf[path] ?? '');
              final found = image == null || stopped()
                  ? null
                  : await vision.readImage(
                      image,
                      tenantId: tenantId,
                      fileName: path.split('/').last,
                      others: [
                        for (final f in work?.files ?? const <RdImportFile>[])
                          if (f.path != path) f.name,
                      ],
                    );
              if (found != null) {
                read = rdImportPageRead(
                  groupId: found.groupId,
                  label: found.label,
                  sure: found.sure,
                  kind: found.kind,
                  instruments: plan.instruments,
                  isChoir: plan.isChoir,
                );
              }
            } on PartVisionLimit {
              limit = true;
            }
            // Late (upload begun, KI off, other import): dropped, read again
            // another time.
            if (!current()) return;
            if (limit) {
              show(limit: true);
              return;
            }
            _pagesTried.add(path);
            done++;
            show();
            if (read != null && !_confirmedNow(path)) {
              _pageReads = {..._pageReads, path: read};
              _replan();
              // A part found can make Fassungen whose dates are not read yet.
              unawaited(_completeDates());
            }
          }
        }

        await Future.wait([for (var i = 0; i < 4; i++) worker()]);
      }
    } finally {
      if (_pagesLoop == run) _pagesLoop = null;
      // Nothing is being read any more: the count goes.
      if (run == _pagesRun && !_disposed) {
        done = total = 0;
        show();
      }
    }
  }

  /// The Werk of [path] got its "Passt so" (what was confirmed stays).
  bool _confirmedNow(String path) {
    final plan = _state.plan;
    if (plan == null) return false;
    final work = plan.works.where((w) => w.files.any((f) => f.path == path)).firstOrNull;
    return work != null && _state.decisions.confirmed.contains(work.key);
  }

  /// Page 1 of the file at [path] as a picture; null when it cannot be had.
  Future<Uint8List?> _pageImage(RdImportFiles source, String path) async {
    final kept = _pageImages.remove(path);
    if (kept != null) return _pageImages[path] = kept;
    final bytes = await source.content(path);
    if (bytes == null) return null;
    final image = await PartVisionService.firstPage(bytes, path.split('/').last);
    if (image == null || !identical(_source, source)) return image;
    _pageImages[path] = image;
    while (_pageImages.length > RdImportController._keptPages) {
      _pageImages.remove(_pageImages.keys.first);
    }
    return image;
  }
}
