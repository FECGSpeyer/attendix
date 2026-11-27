part of 'import_controller.dart';

/// Review, AI toggle, replanning, page previews, and user decision actions
/// for [RdImportController].
extension RdImportControllerReview on RdImportController {
  /// The person takes the answers the KI filled in: from now on they count
  /// like their own (used for the files and learned as terms).
  void confirmAi() {
    if (_state.aiFilled.isNotEmpty) _state = _state.copyWith(aiFilled: const {});
  }

  /// Switches the KI suggestions; off takes back the answers it filled in.
  void setUseAi(bool value) {
    if (value == _state.useAi) return;
    if (!value) {
      _aiRun++;
      final filled = _state.aiFilled;
      final answers = {..._state.decisions.answers}..removeWhere((key, _) => filled.contains(key));
      _state = _state.copyWith(
        useAi: false,
        aiStatus: RdImportAiStatus.off,
        aiFilled: const {},
        decisions: _state.decisions.copyWith(answers: answers),
      );
      _dropStaleConfirmations();
      _worksRun++;
      _pagesRun++;
      if (_aiWorks.isNotEmpty || _pageReads.isNotEmpty) {
        _aiWorks = const {};
        _replan();
      }
      return;
    }
    _state = _state.copyWith(useAi: true);
    if (_pageReads.isNotEmpty) _replan();
    if (_state.step == RdImportStep.review) unawaited(_readPages());
    if (_state.ai.isNotEmpty) {
      _state = _state.copyWith(aiStatus: RdImportAiStatus.done);
      if (_state.step == RdImportStep.questions) _applyAi();
    } else {
      unawaited(_suggest());
    }
    unawaited(_matchWorks());
  }

  /// The plan again with the parts decided so far: two folders with the
  /// same part only after an answer are Fassungen too.
  void _replan() {
    final input = _input;
    final before = _state.plan;
    if (input == null || before == null) return;
    var d = _state.decisions;
    final plan = rdBuildImportPlan(
      input.entries,
      songs: input.songs,
      instruments: input.instruments,
      isChoir: input.isChoir,
      hashes: input.hashes,
      dates: input.dates,
      junk: input.junk,
      answers: d.answers,
      categories: d.categories,
      aiWorks: _aiWorks,
      cache: input.cache,
      newPrefix: input.newPrefix,
      takenNumbers: input.takenNumbers,
      pageReads: _state.useAi ? _pageReads : const {},
    );
    // A Werk whose key changed (KI hint came or went) keeps what the person
    // decided about it: target, skip, Fassung, "Passt so".
    final moved = rdImportMovedWorks(before, plan);
    if (moved.isNotEmpty) {
      String to(String key) => moved[key] ?? key;
      d = d.copyWith(
        targets: {for (final e in d.targets.entries) to(e.key): e.value},
        fassungen: {for (final e in d.fassungen.entries) to(e.key): e.value},
        confirmed: {for (final k in d.confirmed) to(k)},
        recheck: {for (final k in d.recheck) to(k)},
      );
      for (final e in moved.entries) {
        final selection = _confirmedAs.remove(e.key);
        if (selection != null) _confirmedAs[e.value] = selection;
      }
    }
    _state = _state.copyWith(plan: plan, decisions: d);
    _dropStaleConfirmations();
  }

  /// The Werk [workKey] is opened in the review: the KI reads its unclear
  /// pages before those of the other Werke.
  void readFirst(String workKey) => _readFirst = workKey;

  /// Page 1 of the file at [path] to look at in the review (photos as they
  /// are); null when there is none.
  Future<Uint8List?> pagePreview(String path) async {
    final source = _source;
    if (source == null) return null;
    final lower = path.toLowerCase();
    if (lower.endsWith('.pdf')) return _pageImage(source, path);
    if (lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return source.content(path);
    return null;
  }

  /// Whether the KI can read the first page of files of [q] ("Von Seite 1
  /// lesen"): a PDF among them (photos outside the browser). A PDF is
  /// always among the examples when the question has one.
  bool canReadPages(RdImportQuestion q) => q.examples.any((e) => PartVisionService.supports(e.file.name));

  /// Where the file at [path] opens outside the app (Drive); null for ZIPs.
  Uri? viewLink(String path) => _source?.viewLink(path);

  /// Goes to [step]. From the questions to the review the plan is made
  /// again with the answers, and dates of Fassungen that only show now are
  /// read first. Answers the KI filled in have to be confirmed before
  /// ([confirmAi]); until then the questions stay. Back to the questions
  /// while those dates are read keeps them there.
  Future<void> goTo(RdImportStep step) async {
    if (step == RdImportStep.review && _state.step == RdImportStep.questions) {
      if (_state.aiFilled.isNotEmpty) return;
      _replan();
      if (_missingDates().isNotEmpty) {
        _state = _state.copyWith(step: RdImportStep.reading, progress: 0);
        if (!await _completeDates()) return;
        if (_state.step != RdImportStep.reading) return;
      }
    }
    _state = _state.copyWith(step: step);
    if (step == RdImportStep.review) unawaited(_readPages());
  }

  void _decide(RdImportDecisions Function(RdImportDecisions d) change) {
    _state = _state.copyWith(decisions: change(_state.decisions));
    _dropStaleConfirmations();
  }

  void answer(String questionKey, RdImportCategory? answer) {
    if (_state.aiFilled.contains(questionKey)) {
      _state = _state.copyWith(aiFilled: {..._state.aiFilled}..remove(questionKey));
    }
    _decide((d) {
      final answers = {...d.answers};
      answer == null ? answers.remove(questionKey) : answers[questionKey] = answer;
      return d.copyWith(answers: answers);
    });
  }

  /// Gives every question in [answers] its answer at once ("Alle als
  /// Trompete"); the KI's answers among them count as taken.
  void answerAll(Map<String, RdImportCategory> answers) {
    if (answers.isEmpty) return;
    final filled = _state.aiFilled.difference(answers.keys.toSet());
    if (filled.length != _state.aiFilled.length) _state = _state.copyWith(aiFilled: filled);
    _decide((d) => d.copyWith(answers: {...d.answers, ...answers}));
  }

  void setSkipWordBesidePdf(bool value) => _decide((d) => d.copyWith(skipWordBesidePdf: value));

  void setProposeFassung(bool value) => _decide((d) => d.copyWith(proposeFassung: value));

  void setTarget(String workKey, RdWorkTarget target) =>
      _decide((d) => d.copyWith(targets: {...d.targets, workKey: target}));

  /// [fassungKey] null = all Fassungen.
  void setFassung(String workKey, String? fassungKey) =>
      _decide((d) => d.copyWith(fassungen: {...d.fassungen, workKey: fassungKey}));

  void setTake(String path, bool take) => _decide((d) => d.copyWith(take: {...d.take, path: take}));

  void setCategory(String path, RdImportCategory category) {
    _decide((d) => d.copyWith(categories: {...d.categories, path: category}));
    _replan();
    unawaited(_completeDates());
  }

  /// "Passt so" (not while dates of Fassungen are read: the suggested
  /// Fassung may still change). It holds for the selection shown now; when
  /// that changes later, or the person takes it back ([value] false), the
  /// Werk is open again until the next "Passt so".
  void confirm(String workKey, {bool value = true}) {
    if (value && _state.readingDates) return;
    final plan = _state.plan;
    final work = plan?.works.where((w) => w.key == workKey).firstOrNull;
    if (value && (plan == null || work == null)) return;
    if (value) {
      _confirmedAs[workKey] = rdWorkSelection(plan!, _state.decisions, work!);
    } else {
      _confirmedAs.remove(workKey);
    }
    _decide((d) {
      final confirmed = {...d.confirmed};
      value ? confirmed.add(workKey) : confirmed.remove(workKey);
      // Taken back by hand, the Werk waits for another look too.
      final recheck = {...d.recheck};
      value ? recheck.remove(workKey) : recheck.add(workKey);
      return d.copyWith(confirmed: confirmed, recheck: recheck);
    });
  }
}
