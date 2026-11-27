part of 'work_files.dart';

// Upload pipeline: filename parsing, AI/vision part detection, conflict
// resolution, new-group creation, and synonym learning.

/// Sorts [files] into parts (as the old upload sheet), asks once what to do
/// with files that are already there and puts them into the upload queue.
///
/// [fromSibelius]: part PDFs exported by the Attendix plug-in. One list
/// shows each with its part and the PDF it replaces; both can be changed
/// and parts left out.
///
/// Returns false when it stopped without an answer (the page was left).
Future<bool> rdAddWorkFiles(
  BuildContext context,
  WidgetRef ref,
  SongDetailData data,
  List<PlatformFile> files, {
  bool fromSibelius = false,
}) async {
  final l10n = context.l10n;
  final songId = data.song.id;
  if (songId == null || files.isEmpty) return true;
  final controller = ref.read(rdWorkFilesProvider(songId).notifier);
  final existing = rdVisibleFiles(data, ref.read(rdWorkFilesProvider(songId)).hidden);
  final instruments = [
    for (final g in data.partGroups)
      if (g.id != null) InstrumentInfo(id: g.id!, name: g.name, synonyms: g.synonyms),
  ];
  final workName = data.song.name;

  // The names as "Noten importieren" reads them.
  final reads = <({PlatformFile file, RdUploadRead read})>[];
  for (final file in files) {
    if (file.size > rdMaxUploadBytes) {
      ToastHelper.showError(context, l10n.songsFileTooLarge(file.name));
      continue;
    }
    reads.add((
      file: file,
      read: rdUploadRead(file.name, instruments: instruments, isChoir: data.isChoir, workName: workName),
    ));
  }
  if (reads.isEmpty) return true;

  // Sibelius parts carry the part's own name: one list to check them.
  if (fromSibelius) {
    final parts = await showAppDialog<List<_SibeliusPart>>(
      context: context,
      builder:
          (_) => _SibeliusPartsDialog(
            items: [
              for (final r in reads) (file: r.file, instrumentId: r.read.guess.instrumentId, note: r.read.guess.note),
            ],
            existing: existing,
            groups: data.partGroups,
            workName: workName,
            isChoir: data.isChoir,
          ),
    );
    if (parts == null) return context.mounted;
    if (parts.isNotEmpty) {
      controller.enqueue([
        for (final i in parts) (file: i.file, instrumentId: i.instrumentId, note: i.note, replace: i.replace),
      ], mainGroupId: data.mainGroupId);
    }
    return true;
  }

  // What each file to check gets proposed, and why.
  final proposals = <PlatformFile, _Proposal>{
    for (final r in reads)
      if (r.read.review) r.file: _Proposal.fromName(r.read),
  };
  final vision = ref.read(partVisionServiceProvider);
  // The tenant of this drop: after a switch nothing more is sent for it.
  final tenantId = vision.currentTenant();

  // 1. The KI guesses unclear part names (`part-suggest`, one request for
  // all), as in the import.
  final questions = instruments.isEmpty
      ? const <RdImportQuestion>[]
      : rdUploadQuestions([for (final r in reads) if (r.read.review) r.read], workName: workName);
  if (questions.isNotEmpty && tenantId != null) {
    controller.showNotice(l10n.songsFlutterAiReading);
    final result = await ref.read(rdImportAiProvider).suggest(
      tenantId,
      questions,
      groups: {for (final i in instruments) i.id},
      isChoir: data.isChoir,
    );
    if (!context.mounted) return false;
    for (final r in reads) {
      final answer = result.answers[r.read.questionKey];
      if (answer == null) continue;
      final category = rdUploadAiCategory(
        answer,
        r.read,
        instruments: instruments,
        isChoir: data.isChoir,
        workName: workName,
        readable: PartVisionService.supports(r.file.name),
      );
      if (category != null) proposals[r.file] = _Proposal(category, sure: answer.sure, why: _Why.ai);
    }
  }

  // 2. Page 1 (`part-detect`) for what is still open: no sure word of the
  // KI and no known instrument in the name.
  final unclear = [
    for (final r in reads)
      if (instruments.isNotEmpty &&
          r.read.review &&
          !r.read.byKnownName &&
          !(proposals[r.file]!.why == _Why.ai && proposals[r.file]!.sure) &&
          r.read.guess.canAskVision(r.file.name))
        r,
  ];
  if (unclear.isNotEmpty) {
    controller.showNotice(l10n.songsFlutterVisionReading);
    // A minute in all; files not read by then keep what the name or the KI
    // said (and land in the review below).
    final clock = Stopwatch()..start();
    for (final r in unclear) {
      final left = rdVisionBudget - clock.elapsed;
      if (left <= Duration.zero || !context.mounted) break;
      // Each file gets at most what is left of the minute; leaving the page
      // stops it.
      final match = await vision.detect(
        r.file,
        instruments,
        limit: left,
        tenantId: tenantId,
        cancelled: () => !context.mounted,
      );
      if (match != null && match.instrumentId != null) {
        proposals[r.file] = _Proposal(
          RdImportCategory(instrumentId: match.instrumentId),
          sure: match.confidence == MatchConfidence.sure,
          why: _Why.page,
          label: match.term,
        );
      }
    }
    if (!context.mounted) return false;
  }

  // Files whose part is not clear are checked first; terms assigned by hand
  // can be remembered as synonyms of the group.
  final chosen = <PlatformFile, RdImportCategory>{
    for (final r in reads) r.file: proposals[r.file]?.category ?? r.read.category,
  };
  final review = [
    for (final r in reads)
      if (proposals[r.file] case final p?) (file: r.file, read: r.read, proposal: p),
  ];
  var terms = const <int, List<String>>{};
  if (review.isNotEmpty) {
    final result = await showAppDialog<_ReviewResult>(
      context: context,
      builder:
          (_) => _ReviewDialog(
            items: review,
            groups: data.partGroups,
            instruments: instruments,
            isChoir: data.isChoir,
            workName: workName,
          ),
    );
    if (!context.mounted) return false;
    if (result == null) return true;
    chosen.addAll(result.categories);
    terms = result.terms;
  }

  // A part for several groups is uploaded once per group.
  final items = <_UploadItem>[
    for (final r in reads)
      for (final c in chosen[r.file]!.each)
        (
          file: r.file,
          instrumentId: c.instrumentId,
          note: c.note,
          newGroup: c.newGroup,
          conflicts: rdUploadConflicts(r.file.name, c.instrumentId, existing),
        ),
  ];

  var replace = false;
  final clashing = items.where((i) => i.conflicts.isNotEmpty).toList();
  if (clashing.isNotEmpty) {
    final choice = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => _ConflictDialog(items: clashing, groups: data.partGroups),
    );
    if (choice == null) return true;
    replace = choice;
  }

  // New groups ("Oboe" without a group yet) are created only now that the
  // upload really starts, as in the import.
  final groupNotifier = ref.read(groupNotifierProvider.notifier);
  final created = <String, int>{};
  for (final name in rdUploadNewGroups(chosen.values)) {
    final same = data.partGroups.where((g) => g.id != null && g.name.trim().toLowerCase() == name.trim().toLowerCase());
    final id = same.isNotEmpty ? same.first.id : (await groupNotifier.createGroup({'name': name, 'maingroup': false}))?.id;
    if (!context.mounted) return false;
    if (id == null) {
      ToastHelper.showError(context, l10n.rdWordsNewGroupFailed(rdGroupKindOf(context), name));
    } else {
      created[name] = id;
    }
  }

  controller.enqueue([
    for (final i in items)
      // A group that could not be created: the file goes without a part.
      (
        file: i.file,
        instrumentId: i.newGroup != null ? created[i.newGroup] : i.instrumentId,
        note: i.note,
        replace: replace ? i.conflicts : const <SongFile>[],
      ),
  ], mainGroupId: data.mainGroupId);

  // Only once the upload is really started (not on "Abbrechen" in the
  // conflict dialog).
  if (terms.isNotEmpty && context.mounted) {
    final ok = await groupNotifier.addSynonyms(terms);
    if (!ok && context.mounted) ToastHelper.showError(context, l10n.songsFlutterLearnFailed);
  }
  return true;
}

/// A file of the upload with the part it goes to (a group to create:
/// [newGroup]) and the files at the Werk it would replace.
typedef _UploadItem = ({
  PlatformFile file,
  int? instrumentId,
  String? note,
  String? newGroup,
  List<SongFile> conflicts,
});

/// Where a proposal for a file to check comes from.
enum _Why { name, ai, page }

/// What a file to check is proposed: from its name, the KI's guess from the
/// name, or what page 1 shows ([label]: the part as printed).
class _Proposal {
  const _Proposal(this.category, {required this.sure, required this.why, this.label, this.knownName = false});

  factory _Proposal.fromName(RdUploadRead read) => _Proposal(
        read.category,
        sure: read.guess.confidence == MatchConfidence.sure,
        why: _Why.name,
        knownName: read.byKnownName,
      );

  final RdImportCategory category;
  final bool sure;
  final _Why why;
  final String? label;

  /// A known instrument without a group, or a part for several groups.
  final bool knownName;
}

