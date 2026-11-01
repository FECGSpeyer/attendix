import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/services/song_file_service.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/instrument_matcher.dart';
import '../../../../data/models/song/song.dart';
import '../../../../data/repositories/song_repository.dart';
import '../../../../l10n/l10n.dart';
import 'rd_import_ai.dart';
import 'rd_import_drive.dart';
import 'rd_import_logic.dart';
import 'rd_import_source.dart';

/// REDESIGN: "Noten importieren": steps of the assistant, reading the ZIP or
/// the shared Drive folder and the upload. The rules are in
/// [rdBuildImportPlan] and friends.

enum RdImportStep { source, reading, questions, review, uploading, done }

/// A file that could not be uploaded.
class RdImportFailure {
  const RdImportFailure({required this.path, required this.work, required this.error});

  final String path;
  final String work;
  final String error;
}

/// Progress and result of the upload.
class RdImportUpload {
  const RdImportUpload({
    required this.total,
    this.done = 0,
    this.succeeded = 0,
    this.current,
    this.failures = const [],
    this.newWorks = 0,
    this.newGroups = 0,
    this.learned = 0,
    this.finished = false,
    this.learnFailed = false,
    this.aborted = false,
  });

  final int total;
  final int done;

  /// Files that are in Attendix now.
  final int succeeded;

  /// File being uploaded ("120 Wie wunderbar · Viola.pdf").
  final String? current;
  final List<RdImportFailure> failures;
  final int newWorks;
  final int newGroups;

  /// Part names saved as terms of a group.
  final int learned;
  final bool finished;
  final bool learnFailed;

  /// Stopped because the group was switched meanwhile.
  final bool aborted;

  RdImportUpload copyWith({
    int? done,
    int? succeeded,
    String? current,
    List<RdImportFailure>? failures,
    int? newWorks,
    int? newGroups,
    int? learned,
    bool? finished,
    bool? learnFailed,
    bool? aborted,
  }) =>
      RdImportUpload(
        total: total,
        done: done ?? this.done,
        succeeded: succeeded ?? this.succeeded,
        current: current ?? this.current,
        failures: failures ?? this.failures,
        newWorks: newWorks ?? this.newWorks,
        newGroups: newGroups ?? this.newGroups,
        learned: learned ?? this.learned,
        finished: finished ?? this.finished,
        learnFailed: learnFailed ?? this.learnFailed,
        aborted: aborted ?? this.aborted,
      );
}

class RdImportState {
  const RdImportState({
    this.step = RdImportStep.source,
    this.sourceName,
    this.progress = 0,
    this.plan,
    this.decisions = const RdImportDecisions(),
    this.upload,
    this.error,
    this.fileCount = 0,
    this.driveFolder,
    this.useAi = true,
    this.aiStatus = RdImportAiStatus.off,
    this.ai = const {},
    this.aiFilled = const {},
    this.readingDates = false,
  });

  final RdImportStep step;

  /// Name of the ZIP or the Drive folder ("Noten (Speyer)").
  final String? sourceName;

  /// The shared Drive folder read (to stop sharing it afterwards).
  final RdDriveRef? driveFolder;

  /// Reading progress 0–1.
  final double progress;

  /// Files found in the ZIP (without system files).
  final int fileCount;
  final RdImportPlan? plan;
  final RdImportDecisions decisions;
  final RdImportUpload? upload;

  /// Reading failed (no ZIP, empty ZIP, nothing loaded).
  final String? error;

  /// Suggestions of the KI for the questions (switch "Vorschläge der KI").
  final bool useAi;
  final RdImportAiStatus aiStatus;

  /// The KI's guess by question key.
  final Map<String, RdImportAiAnswer> ai;

  /// Questions whose answer the KI filled in and nobody confirmed or
  /// changed since. They must be confirmed before the review
  /// ([RdImportController.confirmAi]): only then are they used and learned.
  final Set<String> aiFilled;

  /// Dates of Fassungen that only showed after a decision are being read:
  /// "Passt so" and the upload wait.
  final bool readingDates;

  RdImportState copyWith({
    RdImportStep? step,
    String? sourceName,
    double? progress,
    RdImportPlan? plan,
    RdImportDecisions? decisions,
    RdImportUpload? upload,
    String? error,
    bool clearError = false,
    int? fileCount,
    RdDriveRef? driveFolder,
    bool? useAi,
    RdImportAiStatus? aiStatus,
    Map<String, RdImportAiAnswer>? ai,
    Set<String>? aiFilled,
    bool? readingDates,
  }) =>
      RdImportState(
        step: step ?? this.step,
        sourceName: sourceName ?? this.sourceName,
        progress: progress ?? this.progress,
        plan: plan ?? this.plan,
        decisions: decisions ?? this.decisions,
        upload: upload ?? this.upload,
        error: clearError ? null : (error ?? this.error),
        fileCount: fileCount ?? this.fileCount,
        driveFolder: driveFolder ?? this.driveFolder,
        useAi: useAi ?? this.useAi,
        aiStatus: aiStatus ?? this.aiStatus,
        ai: ai ?? this.ai,
        aiFilled: aiFilled ?? this.aiFilled,
        readingDates: readingDates ?? this.readingDates,
      );
}

/// ZIPs read in the browser are held in memory: more than this together
/// is refused there (the Drive link or the app can take it).
const int rdImportMaxWebBytes = 1024 * 1024 * 1024;

/// Why reading stopped.
enum RdImportReadError {
  notZip,
  empty,
  noData,

  /// Too large to hold in the browser's memory ([rdImportMaxWebBytes]).
  tooLargeWeb,

  /// No link to a folder.
  badLink,

  /// A Drive link to a file or document, not a folder.
  notFolder,

  /// Dropbox links are not read yet (ZIP instead).
  dropbox,

  /// Folder not found or not shared with "Anyone with the link".
  notFound,

  /// The link import is not set up on the server yet.
  notSetUp,

  /// More files than one import can take.
  tooMany,

  /// The day's budget is used up, or Google is busy.
  limit,
  forbidden,
  failed,
}

RdImportReadError _readErrorOf(RdDriveError error) => switch (error) {
      RdDriveError.notSetUp => RdImportReadError.notSetUp,
      RdDriveError.notFound => RdImportReadError.notFound,
      RdDriveError.notFolder => RdImportReadError.notFolder,
      RdDriveError.limit || RdDriveError.busy => RdImportReadError.limit,
      RdDriveError.tooMany => RdImportReadError.tooMany,
      RdDriveError.forbidden => RdImportReadError.forbidden,
      RdDriveError.exists || RdDriveError.failed => RdImportReadError.failed,
    };

/// A checked Drive link: the folder and its name, or why not.
class RdLinkCheck {
  const RdLinkCheck({this.folder, this.name, this.error});

  final RdDriveRef? folder;
  final String? name;
  final RdImportReadError? error;
}

/// Text of a failed upload.
String _uploadError(Object e) {
  if (e is RdDriveException) {
    final l10n = l10nWithoutContext;
    return switch (e.error) {
      RdDriveError.notFound => l10n.redesignImportDriveFileGone,
      RdDriveError.limit || RdDriveError.busy => l10n.redesignImportErrorLimit,
      RdDriveError.notSetUp => l10n.redesignImportErrorNotSetUp,
      _ => l10n.commonUnknownError,
    };
  }
  if (e is FormatException) return l10nWithoutContext.redesignImportFileBroken;
  return friendlyErrorMessage(e);
}

class RdImportController extends AutoDisposeNotifier<RdImportState> {
  RdImportFiles? _source;
  KeepAliveLink? _keep;
  bool _disposed = false;
  int? _tenantId;
  int? _mainGroupId;

  /// Werke created by an earlier run (a retry does not create them again).
  final Map<String, int> _created = {};

  /// Groups created by an earlier run.
  final Map<String, int> _createdGroups = {};

  /// What the plan is built from (built again when parts are decided).
  ({
    List<RdImportEntry> entries,
    List<RdImportSong> songs,
    List<InstrumentInfo> instruments,
    bool isChoir,
    Map<String, String> hashes,
    Map<String, DateTime> dates,
    int junk,
  })? _input;

  @override
  RdImportState build() {
    ref.onDispose(() {
      _disposed = true;
      _source?.close();
    });
    return const RdImportState();
  }

  /// Back to the start (another ZIP).
  void restart() {
    _aiRun++;
    _dated.clear();
    _source?.close();
    _source = null;
    _input = null;
    _created.clear();
    _createdGroups.clear();
    state = const RdImportState();
  }

  /// Reads [zips], compares duplicate candidates and the dates of Werke
  /// with Fassungen and builds the plan.
  /// ZIPs picked in the browser come as a stream: their size is checked
  /// before they are read into memory.
  Future<RdImportReadError?> read(List<PlatformFile> zips) async {
    if (zips.isEmpty) return null;
    final streamed = zips.where(rdIsStreamed);
    if (streamed.fold<int>(0, (n, z) => n + z.size) > rdImportMaxWebBytes) return RdImportReadError.tooLargeWeb;
    final data = await _data();
    if (_disposed) return null;
    if (data == null) return RdImportReadError.noData;
    state = state.copyWith(step: RdImportStep.reading, progress: 0, clearError: true);
    await _pause();
    if (streamed.isNotEmpty) {
      try {
        zips = [for (final z in zips) rdIsStreamed(z) ? await _collect(z) : z];
      } catch (_) {
        if (!_disposed) state = state.copyWith(step: RdImportStep.source);
        return RdImportReadError.notZip;
      }
      if (_disposed) return null;
    }

    final RdImportSource source;
    try {
      source = RdImportSource.open(zips);
    } on FormatException {
      state = state.copyWith(step: RdImportStep.source);
      return RdImportReadError.notZip;
    }
    return _readFrom(source, data);
  }

  /// Checks a pasted Google Drive link: the folder's name, or why not.
  Future<RdLinkCheck> checkLink(String text) async {
    final folder = rdParseDriveLink(text);
    if (folder == null) {
      return RdLinkCheck(
        error: rdIsDropboxLink(text)
            ? RdImportReadError.dropbox
            : rdIsDriveLink(text)
                ? RdImportReadError.notFolder
                : RdImportReadError.badLink,
      );
    }
    final tenantId = ref.read(currentTenantIdProvider);
    if (tenantId == null) return const RdLinkCheck(error: RdImportReadError.noData);
    try {
      final name = await ref.read(rdDriveApiProvider).folderName(tenantId, folder);
      return RdLinkCheck(folder: folder, name: name);
    } on RdDriveException catch (e) {
      return RdLinkCheck(error: _readErrorOf(e.error));
    } catch (_) {
      return const RdLinkCheck(error: RdImportReadError.failed);
    }
  }

  /// Reads the shared Drive [folder] (named [name]) level by level, then
  /// as [read].
  Future<RdImportReadError?> readLink(RdDriveRef folder, String name) async {
    final data = await _data();
    if (_disposed) return null;
    final tenantId = _tenantId;
    if (data == null || tenantId == null) return RdImportReadError.noData;
    state = state.copyWith(step: RdImportStep.reading, progress: 0, sourceName: name, fileCount: 0, clearError: true);
    final RdDriveSource source;
    try {
      source = await RdDriveSource.load(
        ref.read(rdDriveApiProvider),
        tenantId,
        folder,
        name,
        onProgress: (files) {
          if (!_disposed) state = state.copyWith(fileCount: files);
        },
        cancelled: () => _disposed || ref.read(currentTenantIdProvider) != tenantId,
      );
    } catch (e) {
      if (_disposed) return null;
      state = state.copyWith(step: RdImportStep.source);
      return e is RdDriveException ? _readErrorOf(e.error) : RdImportReadError.failed;
    }
    if (_disposed) return null;
    state = state.copyWith(driveFolder: folder);
    return _readFrom(source, data);
  }

  /// The Werke and groups; binds the import to the current group.
  Future<SongsListData?> _data() async {
    final data = await ref.read(songsListDataProvider(null).future);
    if (_disposed || data == null) return data;
    _tenantId = ref.read(currentTenantIdProvider);
    _mainGroupId = data.groups.where((g) => g.maingroup == true).firstOrNull?.id;
    return data;
  }

  Future<RdImportReadError?> _readFrom(RdImportFiles source, SongsListData data) async {
    if (_disposed) {
      await source.close();
      return null;
    }
    if (source.entries.isEmpty) {
      await source.close();
      state = state.copyWith(step: RdImportStep.source);
      return RdImportReadError.empty;
    }
    _source?.close();
    _source = source;
    state = state.copyWith(sourceName: source.name, fileCount: source.entries.length);

    final songs = [
      for (final s in data.songs)
        if (s.id != null) RdImportSong(id: s.id!, name: s.name, number: s.number, prefix: s.prefix, files: s.files ?? const []),
    ];
    final instruments = [
      for (final g in data.instruments)
        if (g.id != null) InstrumentInfo(id: g.id!, name: g.name, synonyms: g.synonyms),
    ];
    final isChoir = data.tenantType == 'choir';

    // Duplicates (same size) and the dates in the PDFs of Werke with
    // Fassungen are read from the content.
    final toHash = rdImportPathsToHash(source.entries).toList();
    final hashes = <String, String>{};
    final dates = <String, DateTime>{};
    final toDate = rdImportPathsToDate(rdBuildImportPlan(source.entries, songs: songs, instruments: instruments, isChoir: isChoir));
    final hashing = toHash.toSet();
    final dating = toDate.toSet();
    final work = {...hashing, ...dating}.toList()..sort();
    _dated
      ..clear()
      ..addAll(dating);
    await _inspect(source, work, hashes, dates, hash: hashing.contains, date: dating.contains, share: 0.9);
    if (_disposed) return null;
    // Dates of Werke that only show Fassungen once duplicates are known.
    var plan = rdBuildImportPlan(source.entries,
        songs: songs, instruments: instruments, isChoir: isChoir, hashes: hashes, dates: dates, junk: source.junk);
    final missing = rdImportPathsToDate(plan).where((p) => !dates.containsKey(p) && !_dated.contains(p)).toList();
    if (missing.isNotEmpty) {
      _dated.addAll(missing);
      await _inspect(source, missing, hashes, dates, hash: (_) => false, date: (_) => true);
      if (_disposed) return null;
      plan = rdBuildImportPlan(source.entries,
          songs: songs, instruments: instruments, isChoir: isChoir, hashes: hashes, dates: dates, junk: source.junk);
    }
    if (_disposed) return null;
    _input = (
      entries: source.entries,
      songs: songs,
      instruments: instruments,
      isChoir: isChoir,
      hashes: hashes,
      dates: dates,
      junk: source.junk,
    );
    state = state.copyWith(
      step: RdImportStep.questions,
      progress: 1,
      plan: plan,
      decisions: const RdImportDecisions(),
      ai: const {},
      aiFilled: const {},
      aiStatus: RdImportAiStatus.off,
    );
    unawaited(_suggest());
    return null;
  }

  /// Paths whose date was read (or tried): not read again.
  final Set<String> _dated = {};

  /// Reads [paths] of [source] a few at a time (a Drive folder answers each
  /// over the network): the hash and/or the date inside, as [hash] and
  /// [date] say. [share] of the progress bar is used.
  Future<void> _inspect(
    RdImportFiles source,
    List<String> paths,
    Map<String, String> hashes,
    Map<String, DateTime> dates, {
    required bool Function(String) hash,
    required bool Function(String) date,
    double share = 1,
  }) async {
    var next = 0;
    var done = 0;
    Future<void> worker() async {
      while (next < paths.length && !_disposed) {
        final path = paths[next++];
        try {
          final r = await source.inspect(path, hash: hash(path), date: date(path));
          if (r.hash != null) hashes[path] = r.hash!;
          if (r.date != null) dates[path] = r.date!;
        } catch (_) {
          // Unreadable: no duplicate check, date of the listing.
        }
        done++;
        if (done % 8 == 0 && !_disposed) {
          state = state.copyWith(progress: share * done / (paths.length + 1));
          await _pause();
        }
      }
    }

    await Future.wait([for (var i = 0; i < 4; i++) worker()]);
  }

  /// PDF dates the plan needs and nobody read yet (Fassungen that only
  /// show once a part is decided).
  List<String> _missingDates() {
    final plan = state.plan;
    final input = _input;
    if (plan == null || input == null) return const [];
    return rdImportPathsToDate(plan).where((p) => !input.dates.containsKey(p) && !_dated.contains(p)).toList();
  }

  /// Reads the [_missingDates] and plans again; false when the import
  /// changed meanwhile.
  /// While they are read, [RdImportState.readingDates] holds "Passt so" and
  /// the upload; a Werk whose suggested Fassung changes by the new dates
  /// has to be checked again.
  Future<bool> _completeDates() async {
    final input = _input;
    final source = _source;
    final missing = _missingDates();
    if (input == null || source == null || missing.isEmpty) return true;
    _dated.addAll(missing);
    _datesRunning++;
    state = state.copyWith(readingDates: true);
    try {
      await _inspect(source, missing, input.hashes, input.dates, hash: (_) => false, date: (_) => true);
    } finally {
      _datesRunning--;
      if (!_disposed && _datesRunning == 0) state = state.copyWith(readingDates: false);
    }
    if (_disposed || !identical(_input, input)) return false;
    final before = {for (final w in state.plan?.works ?? const <RdImportWork>[]) w.key: rdFassungOf(state.decisions, w)};
    _replan();
    final changed = {
      for (final w in state.plan?.works ?? const <RdImportWork>[])
        if (before.containsKey(w.key) && before[w.key] != rdFassungOf(state.decisions, w)) w.key,
    };
    if (changed.any(state.decisions.confirmed.contains)) {
      _decide((d) => d.copyWith(confirmed: {...d.confirmed}..removeAll(changed)));
    }
    return true;
  }

  /// Date reads running ([_completeDates]).
  int _datesRunning = 0;

  /// Counts the KI requests: an answer of an older one is dropped.
  int _aiRun = 0;

  /// Asks the KI about the questions (one request for all).
  Future<void> _suggest() async {
    final plan = state.plan;
    final tenantId = _tenantId;
    if (plan == null || tenantId == null || !state.useAi || plan.questions.isEmpty) return;
    final run = ++_aiRun;
    state = state.copyWith(aiStatus: RdImportAiStatus.loading);
    ({Map<String, RdImportAiAnswer> answers, RdImportAiStatus status}) result;
    try {
      result = await ref.read(rdImportAiProvider).suggest(
        tenantId,
        plan.questions,
        groups: {for (final g in plan.instruments) g.id},
        isChoir: plan.isChoir,
      );
    } catch (_) {
      result = (answers: const {}, status: RdImportAiStatus.failed);
    }
    if (_disposed || run != _aiRun || !state.useAi) return;
    state = state.copyWith(ai: result.answers, aiStatus: result.status);
    // Filled in only while the questions are shown: after them the plan is
    // made and checked with the answers given.
    if (state.step == RdImportStep.questions) _applyAi();
  }

  /// The person takes the answers the KI filled in: from now on they count
  /// like their own (used for the files and learned as terms).
  void confirmAi() {
    if (state.aiFilled.isNotEmpty) state = state.copyWith(aiFilled: const {});
  }

  /// Fills in the sure guesses of questions nobody answered yet.
  void _applyAi() {
    final answers = {...state.decisions.answers};
    final filled = {...state.aiFilled};
    for (final e in state.ai.entries) {
      if (!e.value.sure || answers.containsKey(e.key)) continue;
      answers[e.key] = e.value.category;
      filled.add(e.key);
    }
    state = state.copyWith(decisions: state.decisions.copyWith(answers: answers), aiFilled: filled);
  }

  /// Switches the KI suggestions; off takes back the answers it filled in.
  void setUseAi(bool value) {
    if (value == state.useAi) return;
    if (!value) {
      _aiRun++;
      final filled = state.aiFilled;
      final answers = {...state.decisions.answers}..removeWhere((key, _) => filled.contains(key));
      state = state.copyWith(
        useAi: false,
        aiStatus: RdImportAiStatus.off,
        aiFilled: const {},
        decisions: state.decisions.copyWith(answers: answers),
      );
      return;
    }
    state = state.copyWith(useAi: true);
    if (state.ai.isNotEmpty) {
      state = state.copyWith(aiStatus: RdImportAiStatus.done);
      if (state.step == RdImportStep.questions) _applyAi();
    } else {
      unawaited(_suggest());
    }
  }

  /// The plan again with the parts decided so far: two folders with the
  /// same part only after an answer are Fassungen too.
  void _replan() {
    final input = _input;
    if (input == null || state.plan == null) return;
    final d = state.decisions;
    state = state.copyWith(
      plan: rdBuildImportPlan(
        input.entries,
        songs: input.songs,
        instruments: input.instruments,
        isChoir: input.isChoir,
        hashes: input.hashes,
        dates: input.dates,
        junk: input.junk,
        answers: d.answers,
        categories: d.categories,
      ),
    );
  }

  Future<void> _pause() => Future<void>.delayed(Duration.zero);

  /// The bytes of a picked file that came as a stream.
  Future<PlatformFile> _collect(PlatformFile zip) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in zip.readStream!) {
      if (_disposed) break;
      builder.add(chunk);
      if (builder.length > rdImportMaxWebBytes) throw const FormatException('too large');
    }
    return PlatformFile(name: zip.name, size: builder.length, bytes: builder.takeBytes());
  }

  /// Goes to [step]. From the questions to the review the plan is made
  /// again with the answers, and dates of Fassungen that only show now are
  /// read first. Answers the KI filled in have to be confirmed before
  /// ([confirmAi]); until then the questions stay.
  Future<void> goTo(RdImportStep step) async {
    if (step == RdImportStep.review && state.step == RdImportStep.questions) {
      if (state.aiFilled.isNotEmpty) return;
      _replan();
      if (_missingDates().isNotEmpty) {
        state = state.copyWith(step: RdImportStep.reading, progress: 0);
        if (!await _completeDates()) return;
      }
    }
    state = state.copyWith(step: step);
  }

  void _decide(RdImportDecisions Function(RdImportDecisions d) change) =>
      state = state.copyWith(decisions: change(state.decisions));

  void answer(String questionKey, RdImportCategory? answer) {
    if (state.aiFilled.contains(questionKey)) state = state.copyWith(aiFilled: {...state.aiFilled}..remove(questionKey));
    _decide((d) {
      final answers = {...d.answers};
      answer == null ? answers.remove(questionKey) : answers[questionKey] = answer;
      return d.copyWith(answers: answers);
    });
  }

  void setSkipWordBesidePdf(bool value) => _decide((d) => d.copyWith(skipWordBesidePdf: value));

  void setProposeFassung(bool value) => _decide((d) => d.copyWith(proposeFassung: value));

  void setTarget(String workKey, RdWorkTarget target) => _decide((d) => d.copyWith(targets: {...d.targets, workKey: target}));

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
  /// Fassung may still change).
  void confirm(String workKey, {bool value = true}) {
    if (value && state.readingDates) return;
    _decide((d) {
      final confirmed = {...d.confirmed};
      value ? confirmed.add(workKey) : confirmed.remove(workKey);
      return d.copyWith(confirmed: confirmed);
    });
  }

  /// Uploads the files of the ready Werke: new groups and Werke first, then
  /// the files (three Werke at a time; each upload keeps the Besetzung of
  /// its Werk) and saves the part names chosen by hand as terms of the
  /// groups. [only] = paths of an earlier run that failed (retry).
  Future<void> upload({Set<String>? only}) async {
    final plan = state.plan;
    final source = _source;
    if (plan == null || source == null) return;
    // Unconfirmed KI answers and dates still being read are not uploaded.
    if (state.aiFilled.isNotEmpty || state.readingDates) return;
    // Bound before the first await (tenant switch safety).
    final tenantId = _tenantId;
    if (tenantId == null || ref.read(currentTenantIdProvider) != tenantId) return;
    final SongRepository songs = ref.read(songRepositoryWithTenantProvider);
    final groupNotifier = ref.read(groupNotifierProvider.notifier);
    final decisions = state.decisions;
    var items = rdImportUploads(plan, decisions);
    if (only != null) items = items.where((i) => only.contains(i.file.path)).toList();
    if (items.isEmpty) return;

    _keep ??= ref.keepAlive();
    var progress = RdImportUpload(total: items.length);
    state = state.copyWith(step: RdImportStep.uploading, upload: progress);
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
        final same = existingGroups.where((g) => g.name.trim().toLowerCase() == name.trim().toLowerCase() && g.id != null);
        if (same.isNotEmpty) {
          _createdGroups[name] = same.first.id!;
          continue;
        }
        final group = await groupNotifier.createGroup({'name': name, 'maingroup': false});
        if (group?.id == null) {
          for (final i in items.where((i) => i.category.newGroup == name)) {
            failures.add(RdImportFailure(path: i.file.path, work: i.work.title, error: name));
          }
          continue;
        }
        _createdGroups[name] = group!.id!;
        progress = progress.copyWith(newGroups: progress.newGroups + 1);
      }

      // 2. New Werke.
      final songIds = <String, int>{};
      for (final work in {for (final i in items) i.work}) {
        final target = rdTargetOf(plan, decisions, work);
        if (target.songId != null) {
          songIds[work.key] = target.songId!;
          continue;
        }
        final created = _created[work.key];
        if (created != null) {
          songIds[work.key] = created;
          continue;
        }
        if (tenantChanged()) return;
        try {
          final song = await songs.createSong(Song(name: target.name!, number: target.number, prefix: target.prefix));
          if (song.id == null) throw StateError('no id');
          _created[work.key] = songIds[work.key] = song.id!;
          progress = progress.copyWith(newWorks: progress.newWorks + 1);
        } catch (e) {
          for (final i in items.where((i) => i.work == work)) {
            failures.add(RdImportFailure(path: i.file.path, work: work.title, error: friendlyErrorMessage(e)));
          }
        }
      }
      state = state.copyWith(upload: progress.copyWith(failures: [...failures]));

      // 3. The files, three Werke at a time, each Werk file by file.
      final failed = {for (final f in failures) f.path};
      final byWork = <String, List<RdUploadItem>>{};
      for (final i in items) {
        if (failed.contains(i.file.path) || songIds[i.work.key] == null) continue;
        byWork.putIfAbsent(i.work.key, () => []).add(i);
      }
      final queue = byWork.values.toList();
      var done = failures.length;
      Future<void> worker() async {
        while (queue.isNotEmpty) {
          final list = queue.removeAt(0);
          for (final item in list) {
            if (tenantChanged()) return;
            final songId = songIds[item.work.key]!;
            progress = progress.copyWith(current: '${item.file.name} · ${item.work.title}', succeeded: succeeded.length);
            state = state.copyWith(upload: progress.copyWith(done: done, failures: [...failures]));
            try {
              final c = item.category;
              await source.upload(
                service,
                songId: songId,
                path: item.file.path,
                fileName: item.file.name,
                instrumentId: c.newGroup != null ? _createdGroups[c.newGroup] : c.instrumentId,
                note: c.note,
                mainGroupId: _mainGroupId,
              );
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

      // 4. Part names chosen by hand become terms of their groups.
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
        state = state.copyWith(
          step: RdImportStep.done,
          upload: progress.copyWith(succeeded: succeeded.length, finished: true, aborted: progress.aborted || switched),
        );
      }
      _keep?.close();
      _keep = null;
    }
  }
}

final rdImportProvider = AutoDisposeNotifierProvider<RdImportController, RdImportState>(RdImportController.new);
