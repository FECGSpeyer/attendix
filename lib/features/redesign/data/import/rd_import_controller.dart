import 'dart:async';

import 'package:crypto/crypto.dart';
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
import 'rd_import_logic.dart';
import 'rd_import_source.dart';

/// REDESIGN: "Noten importieren": steps of the assistant, reading the ZIP
/// and the upload. The rules are in [rdBuildImportPlan] and friends.

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
  });

  final RdImportStep step;

  /// Name of the ZIP ("Noten (Speyer)").
  final String? sourceName;

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
      );
}

/// Why reading stopped.
enum RdImportReadError { notZip, empty, noData }

class RdImportController extends AutoDisposeNotifier<RdImportState> {
  RdImportSource? _source;
  KeepAliveLink? _keep;
  bool _disposed = false;
  int? _tenantId;
  int? _mainGroupId;

  /// Werke created by an earlier run (a retry does not create them again).
  final Map<String, int> _created = {};

  /// Groups created by an earlier run.
  final Map<String, int> _createdGroups = {};

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
    _created.clear();
    _createdGroups.clear();
    state = const RdImportState();
  }

  /// Reads [zips], compares duplicate candidates and the dates of Werke
  /// with Fassungen and builds the plan.
  Future<RdImportReadError?> read(List<PlatformFile> zips) async {
    if (zips.isEmpty) return null;
    final data = await ref.read(songsListDataProvider(null).future);
    if (_disposed) return null;
    if (data == null) return RdImportReadError.noData;
    _tenantId = ref.read(currentTenantIdProvider);
    _mainGroupId = data.groups.where((g) => g.maingroup == true).firstOrNull?.id;
    state = state.copyWith(step: RdImportStep.reading, progress: 0, clearError: true);
    await _pause();

    final RdImportSource source;
    try {
      source = RdImportSource.open(zips);
    } on FormatException {
      state = state.copyWith(step: RdImportStep.source);
      return RdImportReadError.notZip;
    }
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
    final work = {...hashing, ...toDate}.toList()..sort();
    for (var i = 0; i < work.length; i++) {
      if (_disposed) return null;
      final path = work[i];
      try {
        final bytes = source.read(path);
        if (hashing.contains(path)) hashes[path] = sha1.convert(bytes).toString();
        if (path.toLowerCase().endsWith('.pdf')) {
          final date = rdPdfDate(bytes);
          if (date != null) dates[path] = date;
        }
      } catch (_) {
        // Unreadable: no duplicate check, ZIP date.
      }
      if (i % 8 == 0) {
        state = state.copyWith(progress: (i + 1) / (work.length + 1));
        await _pause();
      }
    }
    // Dates of Werke that only show Fassungen once duplicates are known.
    var plan = rdBuildImportPlan(source.entries,
        songs: songs, instruments: instruments, isChoir: isChoir, hashes: hashes, dates: dates, junk: source.junk);
    final missing = rdImportPathsToDate(plan).where((p) => !dates.containsKey(p)).toList();
    if (missing.any((p) => !work.contains(p))) {
      for (final path in missing) {
        if (_disposed) return null;
        try {
          final date = rdPdfDate(source.read(path));
          if (date != null) dates[path] = date;
        } catch (_) {}
      }
      plan = rdBuildImportPlan(source.entries,
          songs: songs, instruments: instruments, isChoir: isChoir, hashes: hashes, dates: dates, junk: source.junk);
    }
    if (_disposed) return null;
    state = state.copyWith(step: RdImportStep.questions, progress: 1, plan: plan, decisions: const RdImportDecisions());
    return null;
  }

  Future<void> _pause() => Future<void>.delayed(Duration.zero);

  void goTo(RdImportStep step) => state = state.copyWith(step: step);

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

  void setCategory(String path, RdImportCategory category) =>
      _decide((d) => d.copyWith(categories: {...d.categories, path: category}));

  void confirm(String workKey, {bool value = true}) => _decide((d) {
        final confirmed = {...d.confirmed};
        value ? confirmed.add(workKey) : confirmed.remove(workKey);
        return d.copyWith(confirmed: confirmed);
      });

  /// Uploads the files of the ready Werke: new groups and Werke first, then
  /// the files (three Werke at a time), keeps the Besetzung of existing
  /// Werke and saves the part names chosen by hand as terms of the groups.
  /// [only] = paths of an earlier run that failed (retry).
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

      // 3. Besetzung of existing Werke before the upload (the upload
      //    recomputes it from the files and would drop groups without files).
      final before = <int, List<int>>{};
      for (final id in {for (final i in items) if (!(_created.containsValue(songIds[i.work.key]))) songIds[i.work.key]}.whereType<int>()) {
        if (tenantChanged()) return;
        try {
          final song = await songs.getSongById(id);
          final ids = song?.instrumentIds ?? const <int>[];
          if (ids.isNotEmpty) before[id] = ids;
        } catch (_) {}
      }

      // 4. The files, three Werke at a time, each Werk file by file.
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
            progress = progress.copyWith(current: '${item.work.title} · ${item.file.name}');
            state = state.copyWith(upload: progress.copyWith(done: done, failures: [...failures]));
            try {
              final bytes = await Future(() => source.read(item.file.path));
              final c = item.category;
              await service.uploadFile(
                songId: songId,
                file: PlatformFile(name: item.file.name, size: bytes.length, bytes: bytes),
                instrumentId: c.newGroup != null ? _createdGroups[c.newGroup] : c.instrumentId,
                note: c.note,
                mainGroupId: _mainGroupId,
              );
            } catch (e) {
              failures.add(RdImportFailure(path: item.file.path, work: item.work.title, error: friendlyErrorMessage(e)));
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

      // 5. Keep groups of the old Besetzung that have no files.
      for (final entry in before.entries) {
        try {
          final song = await songs.getSongById(entry.key);
          if (song == null) continue;
          final now = song.instrumentIds ?? const <int>[];
          final missing = entry.value.where((id) => !now.contains(id)).toList();
          if (missing.isNotEmpty) await songs.updateSong(entry.key, {'instrument_ids': [...now, ...missing]});
        } catch (_) {}
      }

      // 6. Part names chosen by hand become terms of their groups.
      final uploaded = items.where((i) => !failures.any((f) => f.path == i.file.path)).toList();
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
      progress = progress.copyWith(
        failures: [
          ...failures,
          RdImportFailure(path: '', work: '', error: friendlyErrorMessage(e)),
        ],
        finished: true,
      );
    } finally {
      if (!_disposed) {
        ref.invalidate(songsProvider);
        ref.invalidate(songsListDataProvider);
        ref.invalidate(groupsProvider);
        final switched = ref.read(currentTenantIdProvider) != tenantId;
        state = state.copyWith(step: RdImportStep.done, upload: progress.copyWith(finished: true, aborted: progress.aborted || switched));
      }
      _keep?.close();
      _keep = null;
    }
  }
}

final rdImportProvider = AutoDisposeNotifierProvider<RdImportController, RdImportState>(RdImportController.new);
