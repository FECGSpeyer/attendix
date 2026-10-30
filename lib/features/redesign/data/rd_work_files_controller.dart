import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/song_providers.dart';
import '../../../core/services/song_file_service.dart';
import '../../../core/utils/error_message.dart';
import '../../../data/models/song/song.dart';
import 'rd_work_files_logic.dart';

/// How long a delete can be taken back before it is stored.
const Duration rdFileUndoDelay = Duration(seconds: 6);

/// REDESIGN: file writes of one Werk (key: song id) for the desktop file
/// workspace: the upload queue, deletes with "Rückgängig", category and
/// name changes.
///
/// Every write of the service reads `songs.files`, changes it and writes it
/// back, so they run one after the other ([_serial]); two uploads at once
/// would drop one of the files. While writes are waiting or a delete can
/// still be undone the controller stays alive, also when the page is left.
class RdWorkFilesController extends AutoDisposeFamilyNotifier<RdWorkFilesState, int> {
  Future<void> _tail = Future<void>.value();
  int _running = 0;
  int _nextId = 0;
  KeepAliveLink? _keep;
  int? _mainGroupId;
  Timer? _deleteTimer;
  Timer? _noticeTimer;
  List<SongFile> _toDelete = const [];

  int get _songId => arg;

  @override
  RdWorkFilesState build(int songId) {
    ref.onDispose(() {
      _deleteTimer?.cancel();
      _noticeTimer?.cancel();
    });
    return const RdWorkFilesState();
  }

  Future<T> _serial<T>(Future<T> Function(SongFileService service) task) {
    _running++;
    _keep ??= ref.keepAlive();
    final result = _tail.then((_) async => task(await ref.read(readySongFileServiceProvider.future)));
    _tail = result.then<void>((_) {}, onError: (_) {}).whenComplete(() {
      _running--;
      _release();
    });
    return result;
  }

  void _release() {
    if (_running == 0 && _toDelete.isEmpty) {
      _keep?.close();
      _keep = null;
    }
  }

  void _refresh() {
    ref.invalidate(songDetailDataProvider);
    // Only what is loaded (invalidating builds a provider that is not).
    if (ref.exists(songByIdProvider(_songId))) ref.invalidate(songByIdProvider(_songId));
    if (ref.exists(songsProvider)) ref.invalidate(songsProvider);
  }

  void _setUpload(int id, RdUpload Function(RdUpload u) change) {
    state = state.copyWith(uploads: [
      for (final u in state.uploads) u.id == id ? change(u) : u,
    ]);
  }

  /// Queues [files] (already sorted into categories, see
  /// `rdUploadConflicts` for [replace]).
  void enqueue(
    Iterable<({PlatformFile file, int? instrumentId, String? note, List<SongFile> replace})> files, {
    int? mainGroupId,
  }) {
    _mainGroupId = mainGroupId;
    final added = [
      for (final f in files)
        RdUpload(
          id: _nextId++,
          file: f.file,
          instrumentId: f.instrumentId,
          note: f.instrumentId == null ? f.note : null,
          replace: f.replace,
        ),
    ];
    if (added.isEmpty) return;
    // Finished rows of an earlier batch make room for the new one.
    state = state.copyWith(uploads: [
      ...state.uploads.where((u) => u.status != RdUploadStatus.done),
      ...added,
    ]);
    for (final u in added) {
      _serial((service) => _upload(service, u.id));
    }
  }

  Future<void> _upload(SongFileService service, int id) async {
    final upload = state.uploads.where((u) => u.id == id).firstOrNull;
    if (upload == null || upload.status != RdUploadStatus.waiting) return;
    _setUpload(id, (u) => u.copyWith(status: RdUploadStatus.uploading));
    try {
      for (final old in upload.replace) {
        await service.deleteFile(
          songId: _songId,
          url: old.url,
          storageName: old.storageName,
          fileName: old.fileName,
          mainGroupId: _mainGroupId,
        );
      }
      await service.uploadFile(
        songId: _songId,
        file: upload.file,
        instrumentId: upload.instrumentId,
        note: upload.note,
        mainGroupId: _mainGroupId,
      );
      _setUpload(id, (u) => u.copyWith(status: RdUploadStatus.done));
    } catch (e) {
      _setUpload(id, (u) => u.copyWith(status: RdUploadStatus.failed, error: friendlyErrorMessage(e)));
    }
    _refresh();
  }

  /// "Erneut versuchen" of a failed upload.
  void retry(int id) {
    final upload = state.uploads.where((u) => u.id == id).firstOrNull;
    if (upload == null || upload.status != RdUploadStatus.failed) return;
    _setUpload(id, (u) => u.copyWith(status: RdUploadStatus.waiting));
    _serial((service) => _upload(service, id));
  }

  /// Removes the finished and failed rows of the queue.
  void dismissFinished() {
    state = state.copyWith(uploads: [
      for (final u in state.uploads)
        if (u.status == RdUploadStatus.waiting || u.status == RdUploadStatus.uploading) u,
    ]);
  }

  /// Shows [text] at the bottom for [rdFileUndoDelay].
  void showNotice(String text) {
    _noticeTimer?.cancel();
    state = state.copyWith(notice: text);
    _noticeTimer = Timer(rdFileUndoDelay, () => state = state.copyWith(clearNotice: true));
  }

  /// Hides [files] at once and deletes them after [rdFileUndoDelay] unless
  /// [undoDelete] comes first. An earlier delete is stored right away.
  void delete(List<SongFile> files, {int? mainGroupId, String? notice}) {
    if (files.isEmpty) return;
    _commitDeletes();
    _mainGroupId = mainGroupId ?? _mainGroupId;
    _toDelete = files;
    _keep ??= ref.keepAlive();
    state = state.copyWith(hidden: {...state.hidden, for (final f in files) f.url});
    _deleteTimer = Timer(rdFileUndoDelay, _commitDeletes);
    if (notice != null) showNotice(notice);
  }

  /// Whether a delete can still be taken back.
  bool get canUndoDelete => _toDelete.isNotEmpty;

  /// Brings the files of the last delete back (nothing was stored yet).
  bool undoDelete({String? notice}) {
    if (_toDelete.isEmpty) return false;
    _deleteTimer?.cancel();
    final urls = {for (final f in _toDelete) f.url};
    _toDelete = const [];
    state = state.copyWith(hidden: {...state.hidden}..removeAll(urls));
    if (notice != null) showNotice(notice);
    _release();
    return true;
  }

  /// Stores the pending delete now (also used when the page closes).
  void _commitDeletes() {
    _deleteTimer?.cancel();
    final batch = _toDelete;
    if (batch.isEmpty) return;
    _toDelete = const [];
    final mainGroupId = _mainGroupId;
    for (final file in batch) {
      _serial(
        (service) => service.deleteFile(
          songId: _songId,
          url: file.url,
          storageName: file.storageName,
          fileName: file.fileName,
          mainGroupId: mainGroupId,
        ),
      ).catchError((Object e) {
        state = state.copyWith(hidden: {...state.hidden}..remove(file.url));
        showNotice(friendlyErrorMessage(e));
      });
    }
    _serial((_) async => _refresh());
  }

  /// Moves a file to another part / category.
  Future<void> setCategory(SongFile file, int? instrumentId, String? note, {int? mainGroupId}) async {
    await _serial(
      (service) => service.updateFileCategory(
        songId: _songId,
        url: file.url,
        storageName: file.storageName,
        instrumentId: instrumentId,
        note: instrumentId == null ? note : null,
        mainGroupId: mainGroupId,
      ),
    );
    _refresh();
  }

  /// Renames a file (see [rdRenamedFileName], [rdCanRename]).
  Future<void> rename(SongFile file, String fileName) async {
    if (!rdCanRename(file)) return;
    await _serial(
      (service) => service.renameFile(
        songId: _songId,
        url: file.url,
        storageName: file.storageName!,
        fileName: fileName,
      ),
    );
    _refresh();
  }
}

final rdWorkFilesProvider =
    NotifierProvider.autoDispose.family<RdWorkFilesController, RdWorkFilesState, int>(RdWorkFilesController.new);
