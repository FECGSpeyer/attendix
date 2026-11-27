part of 'rd_import_logic.dart';

// Import plan assembly: grouping folders, deduplication, Fassungen, and open questions.

/// Files of the same size whose content must be compared (hash) to find
/// duplicates.
Set<String> rdImportPathsToHash(List<RdImportEntry> entries) {
  final bySize = <int, List<String>>{};
  for (final e in entries) {
    // Files that are never uploaded are never read.
    if (!rdImportExtensions.contains(e.extension) || e.size > rdMaxUploadBytes) continue;
    bySize.putIfAbsent(e.size, () => []).add(e.path);
  }
  return {for (final list in bySize.values) if (list.length > 1) ...list};
}

/// Files whose date inside the file decides the Fassung (PDFs of Werke with
/// several Fassungen).
Set<String> rdImportPathsToDate(RdImportPlan plan) => {
      for (final w in plan.works)
        if (w.fassungen.length > 1)
          for (final f in w.files)
            if (f.hardSkip == null && f.entry.extension == 'pdf') f.path,
    };

/// Builds the plan: Werk folders, the Werk in Attendix, categories,
/// duplicates (by [hashes]), Fassungen (newest by [dates], the date inside
/// a PDF) and the questions.
/// What [rdBuildImportPlan] reads from the names alone. Kept while files,
/// Werke and groups stay the same: an answer or a change by hand only
/// changes the rest, so the plan is made again in a moment.
class RdImportPlanCache {
  Map<String, String?>? _folders;
  final Map<String, RdWorkMatch> _matches = {};
  final Map<String, ({FileCategoryGuess guess, String? newGroup, List<RdImportCategory> several})> _files = {};
}

RdImportPlan rdBuildImportPlan(
  List<RdImportEntry> entries, {
  required List<RdImportSong> songs,
  required List<InstrumentInfo> instruments,
  required bool isChoir,
  Map<String, String> hashes = const {},
  Map<String, DateTime> dates = const {},
  int junk = 0,
  Map<String, RdImportCategory> answers = const {},
  Map<String, RdImportCategory> categories = const {},
  Map<String, int> aiWorks = const {},
  RdImportPlanCache? cache,
  String? newPrefix,
  Set<String> takenNumbers = const {},
  Map<String, RdImportPageRead> pageReads = const {},
}) {
  final folderOf = cache == null
      ? rdFindWorkFolders(entries, songs: songs, instruments: instruments)
      : cache._folders ??= rdFindWorkFolders(entries, songs: songs, instruments: instruments);
  final groupNames = {for (final g in instruments) g.name.trim().toLowerCase()};

  // Werk folders → Werke (folders of the same Werk in Attendix, or new ones
  // with the same title, are one Werk).
  final byFolder = <String, List<RdImportEntry>>{};
  for (final e in entries) {
    byFolder.putIfAbsent(folderOf[e.path] ?? '', () => []).add(e);
  }
  final groups = <String, ({List<String> folders, RdWorkMatch match, ({String? prefix, int? number, String title}) parsed})>{};
  for (final folder in byFolder.keys) {
    final name = folder.isEmpty ? '' : folder.split('/').last;
    var match = folder.isEmpty
        ? RdWorkMatch.none
        : cache == null
            ? rdMatchWork(name, songs)
            : cache._matches.putIfAbsent(name, () => rdMatchWork(name, songs));
    // The Werk the KI named when the comparison is not sure.
    final hint = aiWorks[name];
    if (hint != null && match.kind != RdMatchKind.sure && songs.any((s) => s.id == hint)) {
      match = RdWorkMatch(RdMatchKind.byAi, hint);
    }
    final parsed = rdParseWorkName(name);
    // Only sure folders of the same Werk are put together; an unsure one
    // ("120 Anderes Lied" next to "120 Wie wunderbar") stays a Werk of its
    // own, to be checked.
    final key = match.songId != null
        ? (match.kind == RdMatchKind.sure ? 'song:${match.songId}' : 'song:${match.songId}~${_folded(name)}')
        : folder.isEmpty
            ? 'loose'
            : 'new:${_folded(parsed.title.isEmpty ? name : parsed.title)}';
    final existing = groups[key];
    if (existing == null) {
      groups[key] = (folders: [folder], match: match, parsed: parsed);
    } else {
      existing.folders.add(folder);
    }
  }

  final works = <RdImportWork>[];
  final questionFiles = <String, List<({RdImportFile file, String work, String? label})>>{};
  for (final entry in groups.entries) {
    final g = entry.value;
    // An unsure Werk shows the folder's name; the target names the Werk.
    final song = g.match.songId == null || g.match.kind != RdMatchKind.sure
        ? null
        : songs.firstWhere((s) => s.id == g.match.songId);
    final title = song?.name ?? (g.parsed.title.isEmpty ? (g.folders.first.split('/').last) : g.parsed.title);
    final parents = {for (final f in g.folders) f.contains('/') ? f.substring(0, f.lastIndexOf('/')) : ''};
    final werkEntries = [for (final f in g.folders) ...byFolder[f]!];

    String fassungKeyOf(RdImportEntry e) {
      final folder = folderOf[e.path] ?? '';
      final depth = folder.isEmpty ? 0 : folder.split('/').length;
      final rel = e.folders.sublist(depth.clamp(0, e.folders.length)).where((s) => !_formatFoldersN.contains(_folded(s))).join('/');
      final parent = folder.contains('/') ? folder.substring(0, folder.lastIndexOf('/')) : '';
      return parents.length > 1 ? '$parent|$rel' : rel;
    }

    String labelOf(String key) {
      final parts = key.split('|');
      final rel = parts.last;
      if (parts.length == 1) return rel;
      final parent = parts.first.isEmpty ? '' : parts.first.split('/').last;
      return [parent, rel].where((s) => s.isNotEmpty).join(' › ');
    }

    // "Alt" is the choir voice, not an old version, only next to other
    // voice folders (Sopran, Tenor …) in the same folder. A lone "Alt"
    // folder stays an old version, also in a choir: when in doubt the Werk
    // is checked.
    Iterable<(String, String)> levels(String key) sync* {
      var start = 0;
      for (final m in RegExp(r'[|/]').allMatches('$key/')) {
        if (m.start > start) yield (key.substring(0, start), key.substring(start, m.start));
        start = m.end;
      }
    }

    final siblings = <String, Set<String>>{};
    for (final e in werkEntries) {
      for (final (parent, name) in levels(fassungKeyOf(e))) {
        siblings.putIfAbsent(parent, () => {}).add(_folded(name));
      }
    }
    bool isVoice(String s) => _voiceFoldersN.contains(s) || _voiceFoldersN.contains(s.split(' ').first);
    bool isOldKey(String key) => levels(key).any(
          (l) => rdImportIsOldFolder(l.$2) && !(_isAltVoice(l.$2) && (siblings[l.$1] ?? const {}).any(isVoice)),
        );

    // Categories and hard reasons.
    final workName = g.parsed.title.isEmpty ? title : g.parsed.title;
    final raw = <RdImportFile>[];
    for (final e in werkEntries) {
      RdSkipReason? hard;
      if (!rdImportExtensions.contains(e.extension)) {
        hard = RdSkipReason.unsupported;
      } else if (e.size > rdMaxUploadBytes) {
        hard = RdSkipReason.tooLarge;
      }
      final read = cache?._files[e.path] ?? _readName(e, folderOf[e.path] ?? '', instruments, isChoir, groupNames, workName);
      cache?._files[e.path] = read;
      raw.add(RdImportFile(
        entry: e,
        fassungKey: fassungKeyOf(e),
        guess: read.guess,
        hardSkip: hard,
        newGroup: hard == null ? read.newGroup : null,
        several: hard == null ? read.several : const [],
      ));
    }

    // Duplicates: same size and content; the copy outside "Alt" folders and
    // with the shorter path is kept.
    final keep = <String, RdImportFile>{};
    final duplicates = <String>{};
    final ordered = [...raw]..sort((a, b) {
        final old = (isOldKey(a.fassungKey) ? 1 : 0) - (isOldKey(b.fassungKey) ? 1 : 0);
        if (old != 0) return old;
        final len = a.path.length - b.path.length;
        return len != 0 ? len : a.path.compareTo(b.path);
      });
    for (final f in ordered) {
      if (f.hardSkip != null) continue;
      final hash = hashes[f.path];
      if (hash == null) continue;
      final id = '${f.entry.size}:$hash';
      if (keep.containsKey(id)) {
        duplicates.add(f.path);
      } else {
        keep[id] = f;
      }
    }

    // Word next to a PDF of the same name.
    String stem(String name) {
      final dot = name.lastIndexOf('.');
      return (dot > 0 ? name.substring(0, dot) : name).toLowerCase();
    }

    final pdfStems = {for (final f in raw) if (f.entry.extension == 'pdf') '${f.entry.folders.join('/')}/${stem(f.name)}'};

    final files = <RdImportFile>[
      for (final f in raw)
        RdImportFile(
          entry: f.entry,
          fassungKey: f.fassungKey,
          guess: f.guess,
          newGroup: f.newGroup,
          several: f.several,
          hardSkip: f.hardSkip ?? (duplicates.contains(f.path) ? RdSkipReason.duplicate : null),
          besidePdf: _textExtensions.contains(f.entry.extension) &&
              pdfStems.contains('${f.entry.folders.join('/')}/${stem(f.name)}'),
          questionKey: f.hardSkip == null &&
                  !duplicates.contains(f.path) &&
                  // A part for several groups is asked about only when it
                  // makes a new group.
                  (f.several.isEmpty
                      ? f.guess.confidence != MatchConfidence.sure
                      : f.several.any((c) => c.newGroup != null)) &&
                  f.entry.extension != 'sib'
              ? rdImportQuestionKey(f.name, workName: workName)
              : null,
        ),
    ];
    files.sort((a, b) => a.path.compareTo(b.path));

    // Fassungen: sub-folders with the same part, or an "Alt" folder next to
    // others. The newest by date is proposed, "Alt" folders never.
    // The parts as decided so far (answers, changes by hand) count.
    final live = files.where((f) => f.hardSkip == null).toList();
    final keys = <String, Set<String>>{};
    for (final f in live) {
      keys.putIfAbsent(f.fassungKey, () => <String>{});
      // A part for several groups counts for each of them.
      for (final c in _decided(f, categories, answers, instruments, title, pageReads, isChoir).each) {
        final clash = rdImportClashKey(c);
        if (clash != null) keys[f.fassungKey]!.add(clash);
      }
    }
    final competing = <String>{};
    final keyList = keys.keys.toList();
    for (var i = 0; i < keyList.length; i++) {
      for (var j = i + 1; j < keyList.length; j++) {
        if (keys[keyList[i]]!.intersection(keys[keyList[j]]!).isNotEmpty) {
          competing
            ..add(keyList[i])
            ..add(keyList[j]);
        }
      }
    }
    if (keyList.length > 1) {
      competing.addAll(keyList.where(isOldKey));
      if (competing.isNotEmpty && competing.every(isOldKey)) {
        // Only "Alt" folders compete: the files outside them are the other side.
        competing.addAll(keyList.where((k) => !isOldKey(k)));
      }
    }
    var fassungen = <RdImportFassung>[];
    String? chosen;
    if (competing.length > 1) {
      DateTime? newest(Iterable<DateTime?> list) =>
          list.whereType<DateTime>().fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
      DateTime? inFiles(String k) => newest(live.where((f) => f.fassungKey == k).map((f) => dates[f.path]));
      DateTime? inZip(String k) => newest(live.where((f) => f.fassungKey == k).map((f) => f.entry.modified));
      // The dates inside the files when every Fassung has one; the ZIP's
      // dates (upload to Drive) are not comparable with them.
      final byFiles = competing.every((k) => inFiles(k) != null);
      fassungen = [
        for (final k in competing)
          RdImportFassung(
            key: k,
            label: labelOf(k),
            fileCount: live.where((f) => f.fassungKey == k).length,
            newest: byFiles ? inFiles(k) : inZip(k),
            isOld: isOldKey(k),
          ),
      ]..sort((a, b) {
          final old = (a.isOld ? 1 : 0) - (b.isOld ? 1 : 0);
          if (old != 0) return old;
          final da = a.newest;
          final db = b.newest;
          if (da != null && db != null && da != db) return db.compareTo(da);
          if ((da == null) != (db == null)) return da == null ? 1 : -1;
          final count = b.fileCount - a.fileCount;
          return count != 0 ? count : a.label.compareTo(b.label);
        });
      chosen = fassungen.first.key;
    }

    final work = RdImportWork(
      key: entry.key,
      title: title,
      number: song?.number ?? g.parsed.number,
      prefix: song?.prefix ?? g.parsed.prefix,
      folders: g.folders..sort(),
      match: g.match,
      files: files,
      fassungen: fassungen,
      defaultFassung: chosen,
    );
    works.add(work);
    for (final f in files) {
      final key = f.questionKey;
      if (key == null) continue;
      questionFiles.putIfAbsent(key, () => []).add((file: f, work: work.title, label: _questionLabel(f.name, workName: workName)));
    }
  }

  works.sort((a, b) {
    final na = a.number ?? 1 << 30;
    final nb = b.number ?? 1 << 30;
    return na != nb ? na.compareTo(nb) : a.title.toLowerCase().compareTo(b.title.toLowerCase());
  });

  // Questions: names that come up in two or more files, and every known
  // instrument that would become a new group. Other single unknown files
  // are decided in the review of their Werk.
  final questions = <RdImportQuestion>[];
  for (final entry in questionFiles.entries) {
    final list = entry.value;
    final labels = <String, int>{};
    final suggestions = <int, int>{};
    final newGroups = <String, int>{};
    final severals = <RdImportCategory, int>{};
    for (final q in list) {
      final label = q.label;
      if (label != null) labels[label] = (labels[label] ?? 0) + 1;
      final id = q.file.guess.instrumentId;
      if (id != null) suggestions[id] = (suggestions[id] ?? 0) + 1;
      final group = q.file.newGroup;
      if (group != null) newGroups[group] = (newGroups[group] ?? 0) + 1;
      if (q.file.several.isNotEmpty) {
        final c = RdImportCategory.several(q.file.several);
        severals[c] = (severals[c] ?? 0) + 1;
      }
    }
    // A new group is asked about even for one file: it is created on upload.
    if (list.length < 2 && newGroups.isEmpty && severals.isEmpty) continue;
    String top(Map<String, int> counts) => (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
    final suggestion = suggestions.isEmpty ? null : (suggestions.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
    // A part for several groups is the answer only when at least half of
    // the files are one (in any numbers: "Posaune 1 und Tuba" … "Posaune 3
    // und Tuba"): a single "Klavier - Oboe" does not decide for 96 files
    // "Oboe".
    final severalFiles = list.where((q) => q.file.several.isNotEmpty).length;
    final several = severals.isEmpty ? null : (severals.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first;
    questions.add(RdImportQuestion(
      key: entry.key,
      label: labels.isEmpty ? entry.key : top(labels),
      fileCount: list.length,
      works: {for (final q in list) q.work}.take(2).toList(),
      files: {for (final q in list) q.file.name}.take(3).toList(),
      // PDFs first (the KI reads them everywhere), then photos, then the rest.
      examples: [
        for (final q in [
          ...list.where((q) => q.file.entry.extension == 'pdf'),
          ...list.where((q) => q.file.entry.extension != 'pdf' && rdImportPreviewable(q.file)),
          ...list.where((q) => !rdImportPreviewable(q.file)),
        ].take(3))
          (file: q.file, work: q.work),
      ],
      suggestion: suggestion,
      newGroup: newGroups.isEmpty ? null : top(newGroups),
      several: several == null || severalFiles * 2 < list.length ? const [] : several.key.groups,
    ));
  }
  questions.sort((a, b) => b.fileCount != a.fileCount ? b.fileCount.compareTo(a.fileCount) : a.label.compareTo(b.label));

  return RdImportPlan(
    works: works,
    questions: questions,
    songs: {for (final s in songs) s.id: s},
    instruments: instruments,
    isChoir: isChoir,
    junk: junk,
    newPrefix: newPrefix,
    takenNumbers: takenNumbers,
    pageReads: pageReads,
  );
}
