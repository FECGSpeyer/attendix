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
    final streamed = zips.where((z) => z.bytes == null && z.path == null && z.readStream != null);
    if (streamed.fold<int>(0, (n, z) => n + z.size) > rdImportMaxWebBytes) return RdImportReadError.tooLargeWeb;
    final data = await _data();
    if (_disposed) return null;
    if (data == null) return RdImportReadError.noData;
    state = state.copyWith(step: RdImportStep.reading, progress: 0, clearError: true);
    await _pause();
    if (streamed.isNotEmpty) {
      try {
        zips = [for (final z in zips) z.bytes == null && z.path == null && z.readStream != null ? await _collect(z) : z];
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
    // A few at a time (a Drive folder answers each over the network).
    Future<void> inspect(
      List<String> paths, {
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

    await inspect(work, hash: hashing.contains, date: dating.contains, share: 0.9);
    if (_disposed) return null;
    // Dates of Werke that only show Fassungen once duplicates are known.
    var plan = rdBuildImportPlan(source.entries,
        songs: songs, instruments: instruments, isChoir: isChoir, hashes: hashes, dates: dates, junk: source.junk);
    final missing = rdImportPathsToDate(plan).where((p) => !dates.containsKey(p) && !work.contains(p)).toList();
    if (missing.isNotEmpty) {
      await inspect(missing, hash: (_) => false, date: (_) => true);
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
    state = state.copyWith(step: RdImportStep.questions, progress: 1, plan: plan, decisions: const RdImportDecisions());
    return null;
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

  void goTo(RdImportStep step) {
    if (step == RdImportStep.review && state.step == RdImportStep.questions) _replan();
    state = state.copyWith(step: step);
  }

  void _decide(RdImportDecisions Function(RdImportDecisions d) change) =>
      state = state.copyWith(decisions: change(state.decisions));

  void answer(String questionKey, RdImportCategory? answer) => _decide((d) {
        final answers = {...d.answers};
        answer == null ? answers.remove(questionKey) : answers[questionKey] = answer;
        return d.copyWith(answers: answers);
      });

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
  }

  void confirm(String workKey, {bool value = true}) => _decide((d) {
        final confirmed = {...d.confirmed};
        value ? confirmed.add(workKey) : confirmed.remove(workKey);
        return d.copyWith(confirmed: confirmed);
      });

  /// Uploads the files of the ready Werke: new groups and Werke first, then
  /// the files (three Werke at a time; each upload keeps the Besetzung of
  /// its Werk) and saves the part names chosen by hand as terms of the
  /// groups. [only] = paths of an earlier run that failed (retry).
  Future<void> upload({Set<String>? only}) async {
    final plan = state.plan;
    final source = _source;
    if (plan == null || source == null) return;
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
            progress = progress.copyWith(current: '${item.work.title} · ${item.file.name}', succeeded: succeeded.length);
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
