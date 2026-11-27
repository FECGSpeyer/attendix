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

part 'rd_import_controller_state.dart';
part 'rd_import_controller_ai.dart';
part 'rd_import_controller_review.dart';
part 'rd_import_controller_upload.dart';

class RdImportController extends AutoDisposeNotifier<RdImportState> {
  RdImportState get _state => state;
  set _state(RdImportState value) => state = value;

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

  /// The Werke the KI named for folders the comparison is not sure about,
  /// by folder name ([rdBuildImportPlan] `aiWorks`).
  Map<String, int> _aiWorks = const {};

  /// Counts the Werk requests: an answer of an older one is dropped.
  int _worksRun = 0;

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

  /// Uploads the files of the ready Werke: new groups first, then the files
  /// (three Werke at a time, a new Werk created before its first file; each
  /// upload keeps the Besetzung of its Werk) and saves the part names chosen
  /// by hand as terms of the groups. [only] = paths of an earlier run that
  /// failed or was cancelled (retry). [cancelUpload] stops it.
  Future<void> upload({Set<String>? only}) => _runUpload(only: only);

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
