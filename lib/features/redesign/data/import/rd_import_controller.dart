import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/services/part_vision_service.dart';
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
  const RdImportFailure({required this.path, required this.work, required this.error, this.cancelled = false});

  final String path;
  final String work;
  final String error;

  /// Not uploaded because the import was cancelled (no error).
  final bool cancelled;
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
    this.cancelled = false,
    this.filesSince,
    this.filesFrom = 0,
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

  /// Cancelled by hand ("Abbrechen"): the files being uploaded still
  /// arrive, the others are not uploaded.
  final bool cancelled;

  /// When the files started (after new groups and Werke) and how many were
  /// [done] then: for the time left ([rdImportTimeLeft]).
  final DateTime? filesSince;
  final int filesFrom;

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
    bool? cancelled,
    DateTime? filesSince,
    int? filesFrom,
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
        cancelled: cancelled ?? this.cancelled,
        filesSince: filesSince ?? this.filesSince,
        filesFrom: filesFrom ?? this.filesFrom,
      );

}

/// About how long the upload still takes at [now], from the pace of the
/// files so far; null until a few files are done (the first ones say
/// little).
Duration? rdImportTimeLeft(RdImportUpload upload, DateTime now) {
  final since = upload.filesSince;
  final done = upload.done - upload.filesFrom;
  if (since == null || upload.finished || done < 3) return null;
  final elapsed = now.difference(since);
  if (elapsed < const Duration(seconds: 5)) return null;
  final left = upload.total - upload.done;
  if (left <= 0) return Duration.zero;
  return elapsed * (left / done);
}

/// The upload of the Noten-Import while it runs, and its result until it
/// was seen: the bar in the shell shows it on every other page (the upload
/// goes on when the import page is left). Written by [RdImportController].
final rdImportRunProvider = StateProvider<RdImportUpload?>((ref) => null);

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
    this.collectionId,
    this.pages = const (done: 0, total: 0, limit: false),
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

  /// Sammlung the Noten go into (null: Repertoire): Werke are compared
  /// with its Werke, new ones are created in it with its Kürzel.
  final int? collectionId;

  /// First pages the KI reads in the review: done of total, and whether
  /// the day's budget ran out.
  final ({int done, int total, bool limit}) pages;

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
    int? collectionId,
    bool toRepertoire = false,
    ({int done, int total, bool limit})? pages,
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
        collectionId: toRepertoire ? null : (collectionId ?? this.collectionId),
        pages: pages ?? this.pages,
      );
}

/// First pages the KI reads at most in one import.
const int rdImportMaxPageReads = 300;

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

  /// The group shows the Werke of another one ([rdImportOwnLibraryProvider]).
  otherLibrary,

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

/// Whether the current group's Werke are its own. A group that shows the
/// Werke of another one (Werk-Synchronisierung) imports nothing: the Noten
/// would go to the other group's Werke.
final rdImportOwnLibraryProvider = FutureProvider<bool>((ref) async {
  final tenantId = ref.watch(currentTenantIdProvider);
  final source = (await ref.watch(songTenantSettingsProvider.future)).songSourceTenantId;
  return source == null || source == tenantId;
});

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
  /// Held from the start of an upload until its result was seen
  /// ([resultSeen]): the upload goes on when the page is left.
  KeepAliveLink? _keep;
  bool _disposed = false;

  /// "Abbrechen" was tapped during the upload.
  bool _cancel = false;
  int? _tenantId;
  bool _otherLibrary = false;
  int? _mainGroupId;

  /// Werke created by an earlier run (a retry does not create them again).
  final Map<String, int> _created = {};

  /// Groups a file for several groups was already stored for ("path|group"):
  /// a retry stores it only for the others.
  final Set<String> _storedParts = {};

  /// Groups created by an earlier run.
  final Map<String, int> _createdGroups = {};

  /// What the plan is built from (built again when parts are decided).
  ({
    List<RdImportEntry> entries,
    List<Song> allSongs,
    List<RdImportSong> songs,
    String? newPrefix,
    Set<String> takenNumbers,
    List<InstrumentInfo> instruments,
    bool isChoir,
    Map<String, String> hashes,
    Map<String, DateTime> dates,
    int junk,
    RdImportPlanCache cache,
  })? _input;

  @override
  RdImportState build() {
    ref.onDispose(() {
      _disposed = true;
      _source?.close();
    });
    // The result of an import does not go along into another group.
    ref.listen(currentTenantIdProvider, (previous, next) {
      if (previous == next) return;
      Future.microtask(() {
        if (!_disposed && state.step == RdImportStep.done) resultSeen();
      });
    });
    return const RdImportState();
  }

  /// Back to the start (another ZIP).
  void restart() {
    resultSeen();
    _aiRun++;
    _clearPages();
    _dated.clear();
    _confirmedAs.clear();
    _source?.close();
    _source = null;
    _input = null;
    _created.clear();
    _createdGroups.clear();
    _storedParts.clear();
    state = RdImportState(collectionId: state.collectionId);
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
    if (data == null) return _otherLibrary ? RdImportReadError.otherLibrary : RdImportReadError.noData;
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
    if (data == null || tenantId == null) return _otherLibrary ? RdImportReadError.otherLibrary : RdImportReadError.noData;
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

  /// The Werke and groups; binds the import to the current group. Null
  /// when they cannot be loaded or are another group's
  /// ([RdImportReadError.otherLibrary]).
  Future<SongsListData?> _data() async {
    _otherLibrary = !await ref.read(rdImportOwnLibraryProvider.future).catchError((_) => false);
    if (_otherLibrary) return null;
    final data = await ref.read(songsListDataProvider(null).future);
    if (_disposed || data == null) return data;
    _tenantId = ref.read(currentTenantIdProvider);
    _mainGroupId = data.groups.where((g) => g.maingroup == true).firstOrNull?.id;
    return data;
  }

  /// The Werke of the chosen Sammlung (Repertoire: those without one), its
  /// Kürzel for new Werke and the numbers in use in the whole group.
  ({List<RdImportSong> songs, String? newPrefix, Set<String> takenNumbers}) _target(List<Song> all) {
    final id = state.collectionId;
    final collection = id == null ? null : ref.read(songCollectionsProvider).valueOrNull?.where((c) => c.id == id).firstOrNull;
    return (
      songs: [
        for (final s in all)
          if (s.id != null && s.collectionId == id)
            RdImportSong(id: s.id!, name: s.name, number: s.number, prefix: s.prefix, files: s.files ?? const []),
      ],
      newPrefix: collection?.prefix.trim(),
      takenNumbers: {
        for (final s in all)
          if (s.number != null) rdImportNumberKey(s.prefix, s.number!),
      },
    );
  }

  /// Chooses the Sammlung the Noten go into (null: Repertoire). After
  /// reading, the Werke are compared again with its Werke; what was decided
  /// about Werke starts over, the parts stay.
  void setCollection(int? id) {
    if (id == state.collectionId) return;
    state = id == null ? state.copyWith(toRepertoire: true) : state.copyWith(collectionId: id);
    final input = _input;
    if (input == null || state.plan == null) return;
    final target = _target(input.allSongs);
    _input = (
      entries: input.entries,
      allSongs: input.allSongs,
      songs: target.songs,
      newPrefix: target.newPrefix,
      takenNumbers: target.takenNumbers,
      instruments: input.instruments,
      isChoir: input.isChoir,
      hashes: input.hashes,
      dates: input.dates,
      junk: input.junk,
      cache: RdImportPlanCache(),
    );
    _confirmedAs.clear();
    _aiWorks = const {};
    _worksRun++;
    state = state.copyWith(
      decisions: state.decisions.copyWith(targets: const {}, fassungen: const {}, confirmed: const {}, recheck: const {}),
    );
    _replan();
    unawaited(_matchWorks());
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
    _clearPages();
    state = state.copyWith(sourceName: source.name, fileCount: source.entries.length);

    final target = _target(data.songs);
    final songs = target.songs;
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
    final cache = RdImportPlanCache();
    final toDate =
        rdImportPathsToDate(rdBuildImportPlan(source.entries,
            songs: songs,
            instruments: instruments,
            isChoir: isChoir,
            cache: cache,
            newPrefix: target.newPrefix,
            takenNumbers: target.takenNumbers));
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
        songs: songs, instruments: instruments, isChoir: isChoir, hashes: hashes, dates: dates, junk: source.junk, cache: cache, newPrefix: target.newPrefix, takenNumbers: target.takenNumbers);
    final missing = rdImportPathsToDate(plan).where((p) => !dates.containsKey(p) && !_dated.contains(p)).toList();
    if (missing.isNotEmpty) {
      _dated.addAll(missing);
      await _inspect(source, missing, hashes, dates, hash: (_) => false, date: (_) => true);
      if (_disposed) return null;
      plan = rdBuildImportPlan(source.entries,
          songs: songs, instruments: instruments, isChoir: isChoir, hashes: hashes, dates: dates, junk: source.junk, cache: cache, newPrefix: target.newPrefix, takenNumbers: target.takenNumbers);
    }
    if (_disposed) return null;
    _input = (
      entries: source.entries,
      allSongs: data.songs,
      songs: songs,
      newPrefix: target.newPrefix,
      takenNumbers: target.takenNumbers,
      instruments: instruments,
      isChoir: isChoir,
      hashes: hashes,
      dates: dates,
      junk: source.junk,
      cache: cache,
    );
    _confirmedAs.clear();
    state = state.copyWith(
      step: RdImportStep.questions,
      progress: 1,
      plan: plan,
      decisions: const RdImportDecisions(),
      ai: const {},
      aiFilled: const {},
      aiStatus: RdImportAiStatus.off,
      pages: const (done: 0, total: 0, limit: false),
    );
    _aiWorks = const {};
    _worksRun++;
    unawaited(_suggest());
    unawaited(_matchWorks());
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
  /// has to be checked again ([_dropStaleConfirmations]).
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
    // A Sammlung chosen meanwhile keeps the files and their dates (the
    // same map): the plan is made anew with them.
    if (_disposed || _input == null || !identical(_input!.dates, input.dates)) return false;
    _replan();
    return true;
  }

  /// The selection each "Passt so" was given for ([rdWorkSelection]), by
  /// Werk.
  final Map<String, String> _confirmedAs = {};

  /// Takes back every "Passt so" whose Werk no longer shows what was
  /// confirmed; the Werk waits for another look ([RdImportDecisions.recheck]),
  /// even when nothing is flagged any more. Runs after each change of the
  /// plan or the decisions.
  void _dropStaleConfirmations() {
    final plan = state.plan;
    final d = state.decisions;
    if (plan == null || d.confirmed.isEmpty) return;
    final works = {for (final w in plan.works) w.key: w};
    final stale = <String>{
      for (final key in d.confirmed)
        if (works[key] == null || _confirmedAs[key] != rdWorkSelection(plan, d, works[key]!)) key,
    };
    if (stale.isEmpty) return;
    _confirmedAs.removeWhere((key, _) => stale.contains(key));
    state = state.copyWith(
      decisions: d.copyWith(confirmed: {...d.confirmed}..removeAll(stale), recheck: {...d.recheck, ...stale}),
    );
  }

  /// Date reads running ([_completeDates]).
  int _datesRunning = 0;

  /// Counts the KI requests: an answer of an older one is dropped.
  int _aiRun = 0;

  /// Asks the KI about the questions (one request for all).
  Future<void> _suggest() async {
    final plan = state.plan;
    final tenantId = _tenantId;
    // A part for several groups ("Posaune und Tuba") goes to all of them:
    // the KI would name only one.
    final questions = plan?.questions.where((q) => q.several.isEmpty).toList() ?? const <RdImportQuestion>[];
    if (plan == null || tenantId == null || !state.useAi || questions.isEmpty) return;
    final run = ++_aiRun;
    state = state.copyWith(aiStatus: RdImportAiStatus.loading);
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
    if (_disposed || run != _aiRun || !state.useAi) return;
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
    state = state.copyWith(ai: ai, aiStatus: result.status);
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
      // Also when the known instrument proposes the same new group: the
      // answer shows as the KI's (✦) and is confirmed like the others.
      if (!e.value.sure || answers.containsKey(e.key)) continue;
      answers[e.key] = e.value.category;
      filled.add(e.key);
    }
    state = state.copyWith(decisions: state.decisions.copyWith(answers: answers), aiFilled: filled);
    _dropStaleConfirmations();
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
      _dropStaleConfirmations();
      _worksRun++;
      _pagesRun++;
      if (_aiWorks.isNotEmpty || _pageReads.isNotEmpty) {
        _aiWorks = const {};
        _replan();
      }
      return;
    }
    state = state.copyWith(useAi: true);
    if (_pageReads.isNotEmpty) _replan();
    if (state.step == RdImportStep.review) unawaited(_readPages());
    if (state.ai.isNotEmpty) {
      state = state.copyWith(aiStatus: RdImportAiStatus.done);
      if (state.step == RdImportStep.questions) _applyAi();
    } else {
      unawaited(_suggest());
    }
    unawaited(_matchWorks());
  }

  /// The Werke the KI named for folders the comparison is not sure about,
  /// by folder name ([rdBuildImportPlan] `aiWorks`).
  Map<String, int> _aiWorks = const {};

  /// Counts the Werk requests: an answer of an older one is dropped.
  int _worksRun = 0;

  /// Asks the KI which Werk in Attendix the folders are that the comparison
  /// is not sure about (other spelling, translation, typo). Its sure answers
  /// become Werke "zu prüfen"; nothing is taken unseen.
  Future<void> _matchWorks() async {
    final plan = state.plan;
    final tenantId = _tenantId;
    final input = _input;
    if (plan == null || tenantId == null || input == null || !state.useAi) return;
    final folders = rdImportWorksToAsk(plan);
    if (folders.isEmpty) return;
    final run = ++_worksRun;
    final found = await ref.read(rdImportAiProvider).matchWorks(tenantId, folders, songs: plan.songs.keys.toSet());
    if (_disposed || run != _worksRun || !state.useAi || !identical(_input, input) || found.isEmpty) return;
    // Only while the questions are shown: in the review the Werke may have
    // been decided about already.
    if (state.step != RdImportStep.questions) return;
    _aiWorks = found;
    _replan();
  }

  /// The plan again with the parts decided so far: two folders with the
  /// same part only after an answer are Fassungen too.
  void _replan() {
    final input = _input;
    final before = state.plan;
    if (input == null || before == null) return;
    var d = state.decisions;
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
      pageReads: state.useAi ? _pageReads : const {},
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
    state = state.copyWith(plan: plan, decisions: d);
    _dropStaleConfirmations();
  }

  Future<void> _pause() => Future<void>.delayed(Duration.zero);

  /// What the KI read on page 1, by path ([rdBuildImportPlan] `pageReads`).
  Map<String, RdImportPageRead> _pageReads = const {};

  /// Paths whose first page was read (or could not be): not read again.
  final Set<String> _pagesTried = {};

  /// First pages rendered, the last [_keptPages] (the preview opens at once).
  final Map<String, Uint8List> _pageImages = {};
  static const _keptPages = 40;

  /// Counts the page reads: a new import, the KI switched off or the upload
  /// ends the running one; its late answers are dropped.
  int _pagesRun = 0;

  /// The run whose loop is going ([_readPages]); null when none is.
  int? _pagesLoop;

  /// The Werk open in the review ([readFirst]): its pages are read next.
  String? _readFirst;

  /// The Werk [workKey] is opened in the review: the KI reads its unclear
  /// pages before those of the other Werke.
  void readFirst(String workKey) => _readFirst = workKey;

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
        state.useAi &&
        state.step == RdImportStep.review;
    bool stopped() => !current() || state.pages.limit;
    final vision = ref.read(partVisionServiceProvider);
    var done = 0;
    var total = 0;
    void show({bool? limit}) => state = state.copyWith(pages: (done: done, total: total, limit: limit ?? state.pages.limit));
    _pagesLoop = run;
    try {
      while (!stopped()) {
        final plan = state.plan;
        if (plan == null) return;
        final paths = [
          for (final p in rdImportPagesToRead(plan, state.decisions))
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
    final plan = state.plan;
    if (plan == null) return false;
    final work = plan.works.where((w) => w.files.any((f) => f.path == path)).firstOrNull;
    return work != null && state.decisions.confirmed.contains(work.key);
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
    while (_pageImages.length > _keptPages) {
      _pageImages.remove(_pageImages.keys.first);
    }
    return image;
  }

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
  /// lesen"): a PDF among them (photos outside the browser).
  bool canReadPages(RdImportQuestion q) => q.examples.any((e) => PartVisionService.supports(e.file.name));

  /// Where the file at [path] opens outside the app (Drive); null for ZIPs.
  Uri? viewLink(String path) => _source?.viewLink(path);

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
  /// ([confirmAi]); until then the questions stay. Back to the questions
  /// while those dates are read keeps them there.
  Future<void> goTo(RdImportStep step) async {
    if (step == RdImportStep.review && state.step == RdImportStep.questions) {
      if (state.aiFilled.isNotEmpty) return;
      _replan();
      if (_missingDates().isNotEmpty) {
        state = state.copyWith(step: RdImportStep.reading, progress: 0);
        if (!await _completeDates()) return;
        if (state.step != RdImportStep.reading) return;
      }
    }
    state = state.copyWith(step: step);
    if (step == RdImportStep.review) unawaited(_readPages());
  }

  void _decide(RdImportDecisions Function(RdImportDecisions d) change) {
    state = state.copyWith(decisions: change(state.decisions));
    _dropStaleConfirmations();
  }

  void answer(String questionKey, RdImportCategory? answer) {
    if (state.aiFilled.contains(questionKey)) state = state.copyWith(aiFilled: {...state.aiFilled}..remove(questionKey));
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
    final filled = state.aiFilled.difference(answers.keys.toSet());
    if (filled.length != state.aiFilled.length) state = state.copyWith(aiFilled: filled);
    _decide((d) => d.copyWith(answers: {...d.answers, ...answers}));
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
  /// Fassung may still change). It holds for the selection shown now; when
  /// that changes later, or the person takes it back ([value] false), the
  /// Werk is open again until the next "Passt so".
  void confirm(String workKey, {bool value = true}) {
    if (value && state.readingDates) return;
    final plan = state.plan;
    final work = plan?.works.where((w) => w.key == workKey).firstOrNull;
    if (value && (plan == null || work == null)) return;
    if (value) {
      _confirmedAs[workKey] = rdWorkSelection(plan!, state.decisions, work!);
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

  /// Uploads the files of the ready Werke: new groups first, then the files
  /// (three Werke at a time, a new Werk created before its first file; each
  /// upload keeps the Besetzung of its Werk) and saves the part names chosen
  /// by hand as terms of the groups. [only] = paths of an earlier run that
  /// failed or was cancelled (retry). [cancelUpload] stops it.
  Future<void> upload({Set<String>? only}) async {
    final plan = state.plan;
    final source = _source;
    if (plan == null || source == null) return;
    // Unconfirmed KI answers and dates still being read are not uploaded.
    if (state.aiFilled.isNotEmpty || state.readingDates) return;
    _dropStaleConfirmations();
    // Bound before the first await (tenant switch safety).
    final tenantId = _tenantId;
    if (tenantId == null || ref.read(currentTenantIdProvider) != tenantId) return;
    final SongRepository songs = ref.read(songRepositoryWithTenantProvider);
    final groupNotifier = ref.read(groupNotifierProvider.notifier);
    final decisions = state.decisions;
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
              Song(name: target.name!, number: target.number, prefix: target.prefix ?? plan.newPrefix, collectionId: state.collectionId));
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

  /// The upload for the page and for the bar in the shell.
  void _show(RdImportUpload upload, {RdImportStep? step}) {
    state = state.copyWith(step: step, upload: upload);
    ref.read(rdImportRunProvider.notifier).state = upload;
  }

  /// "Abbrechen" during the upload: the files being uploaded still arrive,
  /// no other one starts; the part names of those uploaded are learned.
  void cancelUpload() {
    final upload = state.upload;
    if (state.step != RdImportStep.uploading || upload == null || _cancel) return;
    _cancel = true;
    _show(upload.copyWith(cancelled: true));
  }

  /// The result was seen (on the page, or its bar was closed): the import
  /// goes once no page shows it any more.
  void resultSeen() {
    if (state.step == RdImportStep.uploading) return;
    if (ref.read(rdImportRunProvider) != null) ref.read(rdImportRunProvider.notifier).state = null;
    _keep?.close();
    _keep = null;
  }
}

final rdImportProvider = AutoDisposeNotifierProvider<RdImportController, RdImportState>(RdImportController.new);
