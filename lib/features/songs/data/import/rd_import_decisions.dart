part of 'rd_import_logic.dart';

// Evaluating user/AI decisions: target numbering, file/work state, summary, uploads, and learned terms.

/// Proposed target of [work] with the decisions [d]: the Werk found, or a
/// new Werk. Into the Repertoire (or a Sammlung without Kürzel) it keeps the
/// folder's number when that is still free. Into a Sammlung with a Kürzel
/// new Werke are numbered on from its highest number, whatever the folders
/// say (Leon, 09.11.2026: "02 Ohne Gott" into a new Sammlung is T1, not T2).
RdWorkTarget rdDefaultTarget(RdImportPlan plan, RdImportWork work, [RdImportDecisions d = const RdImportDecisions()]) {
  final id = work.match.songId;
  if (id != null) return RdWorkTarget.song(id);
  if (work.key == 'loose') return const RdWorkTarget.skip();
  return rdNewWorkTarget(plan, work, d);
}

/// [work] as a new Werk (also one found in Attendix but chosen "Als neues
/// Werk anlegen"): its number from [_numbersOf]; in a Sammlung its Kürzel.
RdWorkTarget rdNewWorkTarget(RdImportPlan plan, RdImportWork work, [RdImportDecisions d = const RdImportDecisions()]) {
  // A Werk found in Attendix has its name as title: a new one is named after the folder.
  final parsed = rdParseWorkName(work.folderName).title;
  final name = work.match.songId == null && work.title.isNotEmpty
      ? work.title
      : (parsed.isEmpty ? work.folderName : parsed);
  // Its own number typed by hand is not in the way of its proposal.
  final own = d.targets[work.key];
  final number = _numbersOf(plan, own != null && own.isNew ? d.copyWith(targets: {...d.targets}..remove(work.key)) : d)[work.key];
  return RdWorkTarget.create(name: name, number: number, prefix: number == null ? plan.newPrefix : plan.newPrefix ?? work.prefix);
}

/// Numbers in use in the group and those the other Werke of the import take
/// as new Werke with [d] ([rdImportNumberKey]); [exceptKey]'s own left out.
Set<String> rdImportUsedNumbers(RdImportPlan plan, RdImportDecisions d, {String? exceptKey}) => {
      ..._groupNumbers(plan),
      for (final w in plan.works)
        if (w.key != exceptKey)
          if (rdTargetOf(plan, d, w) case RdWorkTarget(isNew: true, :final int number, :final prefix))
            rdImportNumberKey(prefix ?? plan.newPrefix, number),
    };

/// Numbers in use anywhere in the group.
Set<String> _groupNumbers(RdImportPlan plan) => {
      ...plan.takenNumbers,
      for (final s in plan.songs.values)
        if (s.number != null) rdImportNumberKey(s.prefix, s.number!),
    };

/// The number after the highest one with [prefix] in [used].
int rdImportNextNumber(Set<String> used, String prefix) {
  final head = '${prefix.trim().toUpperCase()}|';
  return used.where((k) => k.startsWith(head)).fold<int>(0, (m, k) => math.max(m, int.tryParse(k.substring(head.length)) ?? 0)) + 1;
}

/// Why [input] cannot be the number of [work] as a new Werk with Kürzel
/// [prefix] and the decisions [d], or null when it can (also empty: no
/// number, except in a Sammlung with a Kürzel). A number another Werk of
/// the import has now is taken too: it would lose it without notice.
RdImportNumberProblem? rdImportNumberProblem(RdImportPlan plan, RdImportDecisions d, RdImportWork work, String input, {String? prefix}) {
  final text = _withoutKuerzel(input, prefix);
  if (text.isEmpty) return (plan.newPrefix?.trim() ?? '').isEmpty ? null : RdImportNumberProblem.required;
  final n = int.tryParse(text);
  if (n == null || n < 1) return RdImportNumberProblem.invalid;
  final used = rdImportUsedNumbers(plan, d, exceptKey: work.key);
  return used.contains(rdImportNumberKey(prefix, n)) ? RdImportNumberProblem.taken : null;
}

/// The number in [input] once [rdImportNumberProblem] found none; null = none.
int? rdImportParseNumber(String input, {String? prefix}) => int.tryParse(_withoutKuerzel(input, prefix));

/// [input] without the Kürzel typed with it ("T3" → "3").
String _withoutKuerzel(String input, String? prefix) {
  final text = input.trim();
  final kuerzel = (prefix ?? '').trim();
  return kuerzel.isNotEmpty && text.toUpperCase().startsWith(kuerzel.toUpperCase()) ? text.substring(kuerzel.length).trim() : text;
}

/// Numbers of new Werke with the decisions [d]. Numbers chosen for a new
/// Werk (by hand, or kept when the plan changed with the KI) are kept free;
/// those Werke are not numbered again. Into a Sammlung with a Kürzel: on
/// from its highest number, in the order of the Werke (folder numbers only
/// sort them). Otherwise the folder numbers still free (the first keeps a
/// number twice in the folders); the others stay without. Werke found in
/// Attendix and the files without a Werk folder come after all new ones (a
/// number for when one is made new by hand). Cached per plan and chosen
/// numbers.
final _numbers = Expando<Map<String, Map<String, int?>>>();

/// The last numbers per targets map: every Werk of one build asks with the same.
final _numbersByTargets = Expando<(RdImportPlan, Map<String, int?>)>();

Map<String, int?> _numbersOf(RdImportPlan plan, RdImportDecisions d) {
  final last = _numbersByTargets[d.targets];
  if (last != null && identical(last.$1, plan)) return last.$2;
  final chosen = <String, String>{
    for (final e in d.targets.entries)
      if (e.value case RdWorkTarget(isNew: true, :final int number, :final prefix))
        if (plan.work(e.key) != null) e.key: rdImportNumberKey(prefix ?? plan.newPrefix, number),
  };
  final cache = _numbers[plan] ??= {};
  final signature = (chosen.entries.map((e) => '${e.key}=${e.value}').toList()..sort()).join('\n');
  final hit = cache[signature];
  if (hit != null) {
    _numbersByTargets[d.targets] = (plan, hit);
    return hit;
  }

  final group = _groupNumbers(plan);
  final used = {...group, ...chosen.values};
  final numbers = <String, int?>{};
  final without = <RdImportWork>[];
  final prefix = plan.newPrefix?.trim() ?? '';
  final works = [
    for (final w in plan.works)
      if (w.key != 'loose' && !chosen.containsKey(w.key) && w.match.songId == null) w,
    for (final w in plan.works)
      if (w.key != 'loose' && !chosen.containsKey(w.key) && w.match.songId != null) w,
    // Files without a Werk folder, when made a new Werk by hand.
    for (final w in plan.works)
      if (w.key == 'loose' && !chosen.containsKey(w.key)) w,
  ];
  for (final w in works) {
    final n = prefix.isEmpty ? w.number : null;
    if (n != null && used.add(rdImportNumberKey(plan.newPrefix ?? w.prefix, n))) {
      numbers[w.key] = n;
    } else {
      without.add(w);
    }
  }
  if (prefix.isNotEmpty) {
    var next = rdImportNextNumber(group, prefix);
    for (final w in without) {
      while (!used.add(rdImportNumberKey(prefix, next))) {
        next++;
      }
      numbers[w.key] = next++;
    }
  }
  if (cache.length >= 32) cache.clear();
  _numbersByTargets[d.targets] = (plan, numbers);
  return cache[signature] = numbers;
}

RdWorkTarget rdTargetOf(RdImportPlan plan, RdImportDecisions d, RdImportWork work) =>
    d.targets[work.key] ?? rdDefaultTarget(plan, work, d);

/// Chosen Fassung of [work]; null = all files.
String? rdFassungOf(RdImportDecisions d, RdImportWork work) {
  if (work.fassungen.length < 2) return null;
  if (d.fassungen.containsKey(work.key)) return d.fassungen[work.key];
  return d.proposeFassung ? work.defaultFassung : null;
}

/// The question of [f] has an answer that decides its part ("Von Seite 1
/// lesen" leaves it open).
bool _answeredByHand(RdImportDecisions d, RdImportFile f) {
  final key = f.questionKey;
  final answer = key == null ? null : d.answers[key];
  return answer != null && !answer.fromPage;
}

/// The question of [f] is answered "Von Seite 1 lesen".
bool _answeredFromPage(RdImportDecisions d, RdImportFile f) {
  final key = f.questionKey;
  return key != null && (d.answers[key]?.fromPage ?? false);
}

RdImportCategory _categoryOf(RdImportPlan plan, RdImportDecisions d, RdImportFile f, RdImportWork work) =>
    _decided(f, d.categories, d.answers, plan.instruments, work.title, plan.pageReads, plan.isChoir);

/// The part of [f]: chosen by hand, else the answer to its question (with
/// the file's own part number), else what the KI read on page 1, else the
/// guess. "Von Seite 1 lesen" as the answer leaves it to page 1.
RdImportCategory _decided(
  RdImportFile f,
  Map<String, RdImportCategory> categories,
  Map<String, RdImportCategory> answers,
  List<InstrumentInfo> instruments,
  String workTitle,
  Map<String, RdImportPageRead> pageReads,
  bool isChoir,
) {
  final own = categories[f.path];
  if (own != null) return own;
  final answer = f.questionKey == null ? null : answers[f.questionKey];
  if (answer != null && !answer.fromPage) {
    return rdImportAnswerFor(answer, f, instruments: instruments, isChoir: isChoir, workTitle: workTitle);
  }
  return pageReads[f.path]?.category ?? f.guessed;
}

/// The part [answer] (to the question of [f]) gives [f]: a group with the
/// file's own part number ("фл → Flöte 1" puts "фл2.pdf" to Flöte 2), a
/// part for several groups with the file's own groups.
RdImportCategory rdImportAnswerFor(
  RdImportCategory answer,
  RdImportFile f, {
  required List<InstrumentInfo> instruments,
  required bool isChoir,
  required String workTitle,
}) {
  final id = answer.instrumentId;
  if (id != null && id > InstrumentMatcher.lyricsId) {
    return RdImportCategory(instrumentId: rdImportSiblingGroup(id, f.name, instruments, workName: workTitle));
  }
  if (answer.isSeveral) return _severalOf(answer, f, instruments, isChoir, workTitle);
  return answer;
}

/// An answer for several groups as file [f] has it: one answer is given for
/// "Posaune 1 und Tuba" and "Posaune 2 und Tuba", so a group of the same
/// instrument that the file's own name gives for sure ("Posaune 2", "Violine
/// 2 (neu)") takes the place of the answer's.
RdImportCategory _severalOf(
  RdImportCategory answer,
  RdImportFile f,
  List<InstrumentInfo> instruments,
  bool isChoir,
  String workTitle,
) {
  var own = f.several;
  if (own.isEmpty) {
    final named = rdImportNamedGroups(rdImportWithoutWorkName(f.name, workTitle), instruments, isChoir: isChoir);
    if (named.sure) own = named.groups;
  }
  if (own.isEmpty) return answer;
  String? instrument(RdImportCategory c) {
    final name = c.newGroup ?? instruments.where((g) => g.id == c.instrumentId).firstOrNull?.name;
    final known = name == null ? const <String>[] : InstrumentMatcher.knownGroups(name, isChoir: isChoir);
    return known.length == 1 ? known.single : null;
  }

  final mine = <String, RdImportCategory>{
    for (final c in own)
      if (instrument(c) case final k?) k: c,
  };
  final groups = <RdImportCategory>[];
  for (final c in answer.groups) {
    final k = instrument(c);
    final g = (k == null ? null : mine[k]) ?? c;
    if (!groups.contains(g)) groups.add(g);
  }
  return groups.length > 1 ? RdImportCategory.several(groups) : groups.single;
}

RdFileState rdFileState(RdImportPlan plan, RdImportDecisions d, RdImportWork work, RdImportFile f) {
  final category = _categoryOf(plan, d, f, work);
  final byHand = d.categories.containsKey(f.path) || _answeredByHand(d, f);
  if (f.hardSkip != null) return RdFileState(take: false, category: category, reason: f.hardSkip, canToggle: false);
  final target = rdTargetOf(plan, d, work);
  if (target.skip) return RdFileState(take: false, category: category, reason: RdSkipReason.workSkipped, canToggle: false);

  RdSkipReason? reason;
  final fassung = rdFassungOf(d, work);
  final song = target.songId == null ? null : plan.songs[target.songId];
  final otherFassung = fassung != null &&
      f.fassungKey != fassung &&
      work.fassungen.any((x) => x.key == f.fassungKey) &&
      // Lyrics fit every Fassung: kept while the chosen one has none.
      (category.instrumentId != InstrumentMatcher.lyricsId ||
          work.files.any((x) =>
              x.fassungKey == fassung &&
              x.hardSkip == null &&
              _categoryOf(plan, d, x, work).instrumentId == InstrumentMatcher.lyricsId));
  if (otherFassung) {
    reason = RdSkipReason.otherFassung;
  } else if (song != null && _sameName(song, f.name, category)) {
    reason = RdSkipReason.sameName;
  } else if (d.skipWordBesidePdf && f.besidePdf) {
    reason = RdSkipReason.wordNextToPdf;
  } else if (song != null && category.each.every((c) => _atSong(song, c))) {
    // A part for several groups is left out only when every group has it.
    reason = RdSkipReason.partExists;
  }
  final manual = d.take[f.path];
  final take = manual ?? reason == null;
  final pageRead = byHand ? null : plan.pageReads[f.path];
  // "Von Seite 1 lesen": open until page 1 is read for sure, whatever the
  // name proposes ("Oboe" as a new group).
  final unclear = take &&
      !byHand &&
      !(pageRead?.sure ?? false) &&
      (_answeredFromPage(d, f) ||
          (f.guess.confidence != MatchConfidence.sure && f.newGroup == null && f.several.isEmpty));
  return RdFileState(
    take: take,
    category: category,
    reason: take ? null : (manual == false ? RdSkipReason.byHand : reason),
    unclear: unclear,
    byHand: byHand,
    pageRead: pageRead,
  );
}

RdWorkState rdWorkState(RdImportPlan plan, RdImportDecisions d, RdImportWork work) {
  final target = rdTargetOf(plan, d, work);
  final files = {for (final f in work.files) f.path: rdFileState(plan, d, work, f)};
  final flags = <RdWorkFlag>{
    if (!d.targets.containsKey(work.key) && work.match.kind != RdMatchKind.sure && work.match.songId != null) RdWorkFlag.unsureMatch,
    if (work.fassungen.length > 1) RdWorkFlag.fassungen,
    if (files.values.any((f) => f.reason == RdSkipReason.partExists)) RdWorkFlag.partExists,
    if (files.values.any((f) => f.unclear && !f.proposedByAi)) RdWorkFlag.unclear,
    if (files.values.any((f) => f.proposedByAi)) RdWorkFlag.aiProposal,
  };
  return RdWorkState(
    target: target,
    files: files,
    flags: flags,
    confirmed: d.confirmed.contains(work.key),
    recheck: d.recheck.contains(work.key),
  );
}

/// What a Werk shows and will upload, as one text: target, Fassung, flags
/// and every file taken with its part. "Passt so" holds for this selection
/// only; when it changes (an answer, a category, a Fassung that shows only
/// then, dates read later) the Werk has to be checked again.
String rdWorkSelection(RdImportPlan plan, RdImportDecisions d, RdImportWork work) {
  final s = rdWorkState(plan, d, work);
  final t = s.target;
  String category(RdImportCategory c) =>
      c.isSeveral ? '[${c.groups.map(category).join(',')}]' : '${c.instrumentId}|${c.note}|${c.newGroup}';
  return [
    'target ${t.skip}|${t.songId}|${t.prefix}|${t.number}|${t.name}',
    'fassung ${rdFassungOf(d, work)}',
    'flags ${(s.flags.map((f) => f.name).toList()..sort()).join(',')}',
    for (final f in work.files)
      if (s.files[f.path]!.take) 'file ${f.path} ${category(s.files[f.path]!.category)}',
  ].join('\n');
}

RdImportSummary rdImportSummary(RdImportPlan plan, RdImportDecisions d) {
  var open = 0, ready = 0, newWorks = 0, skippedWorks = 0, take = 0, skip = 0;
  for (final w in plan.works) {
    final s = rdWorkState(plan, d, w);
    if (s.target.skip) {
      skippedWorks++;
      skip += s.files.length;
    } else if (s.open) {
      open++;
    } else {
      if (s.takeCount > 0) {
        ready++;
        if (s.target.isNew) newWorks++;
      }
      take += s.takeCount;
      skip += s.skipCount;
    }
  }
  return RdImportSummary(
    works: plan.works.length,
    open: open,
    ready: ready,
    newWorks: newWorks,
    skippedWorks: skippedWorks,
    take: take,
    skip: skip,
    openQuestions: plan.questions.where((q) => !d.answers.containsKey(q.key)).length,
  );
}

/// Files of the ready Werke, Werk by Werk.
List<RdUploadItem> rdImportUploads(RdImportPlan plan, RdImportDecisions d) => [
      for (final w in plan.works)
        for (final s in [rdWorkState(plan, d, w)])
          if (s.ready)
            for (final f in w.files)
              if (s.files[f.path]!.take)
                RdUploadItem(
                  work: w,
                  file: f,
                  category: s.files[f.path]!.category,
                  stores: _toStore(s.files[f.path]!.category, plan.songs[s.target.songId]),
                ),
    ];

/// The groups a part for several groups still lacks at [song]; all of them
/// when it lacks none (taken by hand) or the Werk is new.
List<RdImportCategory> _toStore(RdImportCategory c, RdImportSong? song) {
  if (!c.isSeveral || song == null) return c.each;
  final missing = [for (final g in c.groups) if (!_atSong(song, g)) g];
  return missing.isEmpty ? c.groups : missing;
}

/// Group names to create (answers and choices "Neue Gruppe anlegen") used by
/// [items].
List<String> rdImportNewGroups(List<RdUploadItem> items) => {
      for (final i in items)
        for (final c in i.stores)
          if (c.newGroup != null) c.newGroup!,
    }.toList();

/// The folder names of Werke the comparison is not sure about (new, only
/// the number fits, several fit), to ask the KI about ([rdBuildImportPlan]
/// `aiWorks`).
List<String> rdImportWorksToAsk(RdImportPlan plan) => {
      for (final w in plan.works)
        if (w.match.kind != RdMatchKind.sure && w.match.kind != RdMatchKind.byAi && plan.songs.isNotEmpty)
          for (final f in w.folders)
            if (f.isNotEmpty) f.split('/').last,
    }.toList();

/// Werke whose key changed from [before] to [after], old key → new key: the
/// KI's hint came or went, so "new:…" became "song:…~…" or back. What the
/// person decided about such a Werk stays with its folder.
Map<String, String> rdImportMovedWorks(RdImportPlan before, RdImportPlan after) {
  final oldKeyOf = {
    for (final w in before.works)
      for (final f in w.folders) f: w.key,
  };
  final oldKeys = {for (final w in before.works) w.key};
  final newKeys = {for (final w in after.works) w.key};
  final moved = <String, String>{};
  final split = <String>{};
  for (final w in after.works) {
    if (oldKeys.contains(w.key)) continue;
    final olds = {
      for (final f in w.folders)
        if (oldKeyOf[f] case final k? when !newKeys.contains(k)) k,
    };
    if (olds.length != 1) continue;
    // One old Werk now in two: nothing is carried over.
    if (moved.containsKey(olds.single)) split.add(olds.single);
    moved[olds.single] = w.key;
  }
  return moved..removeWhere((k, _) => split.contains(k));
}

/// Files whose part nobody knows yet and the KI did not read: their first
/// page is read ([RdImportPageRead]), in the order of the Werke. Werke with
/// "Passt so" stay as they were confirmed.
List<String> rdImportPagesToRead(RdImportPlan plan, RdImportDecisions d) => [
      for (final w in plan.works)
        if (!d.confirmed.contains(w.key))
          for (final e in rdWorkState(plan, d, w).files.entries)
            if (e.value.unclear && e.value.pageRead == null && !plan.pageReads.containsKey(e.key)) e.key,
    ];

/// The new groups the files go to as decided so far, to pick them for other
/// files too before they exist ("Neue Gruppe: Oboe").
List<String> rdImportPendingGroups(RdImportPlan plan, RdImportDecisions d) {
  final existing = {for (final g in plan.instruments) g.name.trim().toLowerCase()};
  final names = <String, String>{};
  for (final work in plan.works) {
    for (final f in work.files) {
      if (f.hardSkip != null) continue;
      for (final c in _decided(f, d.categories, d.answers, plan.instruments, work.title, plan.pageReads, plan.isChoir).each) {
        final name = c.newGroup;
        if (name == null || existing.contains(name.trim().toLowerCase())) continue;
        names.putIfAbsent(name.trim().toLowerCase(), () => name);
      }
    }
  }
  return names.values.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}

/// Terms to remember as synonyms: the part names of files whose group was
/// chosen by hand or by an answer ("künftig so erkennen"). [groupIds] maps
/// new group names to their ids; [instruments] includes the new groups.
Map<int, List<String>> rdImportLearnedTerms(
  RdImportPlan plan,
  RdImportDecisions d,
  List<RdUploadItem> items, {
  required List<InstrumentInfo> instruments,
  Map<String, int> groupIds = const {},
}) {
  final terms = <int, Set<String>>{};
  for (final i in items) {
    final byHand = d.categories.containsKey(i.file.path) || _answeredByHand(d, i.file);
    if (!byHand) continue;
    // "Posaune und Tuba" is never a term of one group.
    if (InstrumentMatcher.knownGroups(i.file.name, isChoir: plan.isChoir).length > 1) continue;
    final id = i.category.newGroup != null ? groupIds[i.category.newGroup] : i.category.instrumentId;
    if (id == null) continue;
    final term = learnableTerm(i.file.name, chosenId: id, instruments: instruments, workName: i.work.title);
    if (term == null) continue;
    terms.putIfAbsent(id, () => <String>{}).add(term);
  }
  return {for (final e in terms.entries) e.key: e.value.toList()..sort()};
}

/// [questions] by what they most likely mean: the answer given ([answers],
/// also the ones the KI filled in), the KI's answer ([ai]), the proposed
/// new group, the matcher's guess. The group without a guess comes first,
/// then the ones with the most files. An answered question goes to the
/// group of its answer, so "Alle als …" never takes another one.
List<RdImportQuestionGroup> rdImportQuestionGroups(
  List<RdImportQuestion> questions, {
  Map<String, RdImportCategory> answers = const {},
  Map<String, RdImportCategory> ai = const {},
}) {
  final byCategory = <RdImportCategory?, List<RdImportQuestion>>{};
  for (final q in questions) {
    final guess = answers[q.key] ??
        ai[q.key] ??
        q.proposed ??
        (q.suggestion == null ? null : RdImportCategory(instrumentId: q.suggestion));
    byCategory.putIfAbsent(guess, () => []).add(q);
  }
  final groups = [for (final e in byCategory.entries) RdImportQuestionGroup(e.key, e.value)];
  int rank(RdImportQuestionGroup g) => g.category == null ? 0 : 1;
  groups.sort((a, b) => rank(a) != rank(b) ? rank(a).compareTo(rank(b)) : b.fileCount.compareTo(a.fileCount));
  return groups;
}
