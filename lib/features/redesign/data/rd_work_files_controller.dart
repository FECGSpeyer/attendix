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

/// How long the upload queue stays after everything was uploaded.
const Duration rdUploadQueueHideDelay = Duration(seconds: 3);

/// REDESIGN: file writes of one Werk (key: song id) for the desktop file
/// workspace: the upload queue, deletes with "Rückgängig", category and
/// name changes.
///
/// Every write of the service reads `songs.files`, changes it and writes it
/// back, so they run one after the other ([_serial]; the service also locks
/// each song across all pages); two uploads at once would drop one of the
/// files. The service (and with it the tenant) is taken when a write is
/// queued, so a tenant switch meanwhile never sends it to another tenant.
/// While writes are waiting or a delete can still be undone the controller
/// stays alive, also when the page is left.
class RdWorkFilesController extends AutoDisposeFamilyNotifier<RdWorkFilesState, int> {
  Future<void> _tail = Future<void>.value();
  int _running = 0;
  int _nextId = 0;
  KeepAliveLink? _keep;
  int? _mainGroupId;
  Timer? _deleteTimer;
  Timer? _noticeTimer;
  Timer? _hideTimer;
  List<SongFile> _toDelete = const [];
  Future<SongFileService>? _deleteService;

  /// Service of each queued upload, taken when it was queued.
  final Map<int, Future<SongFileService>> _uploadServices = {};

  int get _songId => arg;

  @override
  RdWorkFilesState build(int songId) {
    ref.onDispose(() {
      _deleteTimer?.cancel();
      _noticeTimer?.cancel();
      _hideTimer?.cancel();
    });
    return const RdWorkFilesState();
  }

  /// The service for writes queued now (bound to the current tenant).
  Future<SongFileService> _service() => ref.read(readySongFileServiceProvider.future);

  Future<T> _serial<T>(Future<SongFileService> service, Future<T> Function(SongFileService service) task) {
    _running++;
    _keep ??= ref.keepAlive();
    final result = _tail.then((_) async => task(await service));
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
    _hideTimer?.cancel();
    // Finished rows of an earlier batch make room for the new one.
    state = state.copyWith(uploads: [
      ...state.uploads.where((u) => u.status != RdUploadStatus.done),
      ...added,
    ]);
    final service = _service();
    for (final u in added) {
      _uploadServices[u.id] = service;
      _serial(service, (s) => _upload(s, u.id));
    }
  }

  Future<void> _upload(SongFileService service, int id) async {
    final upload = state.uploads.where((u) => u.id == id).firstOrNull;
    if (upload == null || upload.status != RdUploadStatus.waiting) return;
    _setUpload(id, (u) => u.copyWith(status: RdUploadStatus.uploading));
    try {
      // "Ersetzen": the new file first, the old ones only once it is
      // stored, so a failed upload never loses them.
      if (!upload.stored) {
        final url = await service.uploadFile(
          songId: _songId,
          file: upload.file,
          instrumentId: upload.instrumentId,
          note: upload.note,
          mainGroupId: _mainGroupId,
        );
        _setUpload(id, (u) => u.copyWith(stored: true, storedUrl: url));
      }
      final storedUrl = state.uploads.where((u) => u.id == id).firstOrNull?.storedUrl;
      for (final old in upload.replace) {
        if (old.url == storedUrl) continue; // never the file just stored
        await service.deleteFile(
          songId: _songId,
          url: old.url,
          storageName: old.storageName,
          fileName: old.fileName,
          mainGroupId: _mainGroupId,
        );
      }
      _setUpload(id, (u) => u.copyWith(status: RdUploadStatus.done));
      _uploadServices.remove(id);
    } catch (e) {
      _setUpload(id, (u) => u.copyWith(status: RdUploadStatus.failed, error: friendlyErrorMessage(e)));
    }
    _refresh();
    _hideWhenAllDone();
  }

  /// All uploads stored: the queue goes away by itself after a moment.
  /// With a failed upload it stays, for "Erneut versuchen".
  void _hideWhenAllDone() {
    _hideTimer?.cancel();
    if (state.busy || state.failedCount > 0 || state.uploads.isEmpty) return;
    _hideTimer = Timer(rdUploadQueueHideDelay, () {
      if (!state.busy && state.failedCount == 0) dismissFinished();
    });
  }

  /// "Erneut versuchen" of a failed upload.
  void retry(int id) {
    final upload = state.uploads.where((u) => u.id == id).firstOrNull;
    if (upload == null || upload.status != RdUploadStatus.failed) return;
    _hideTimer?.cancel();
    _setUpload(id, (u) => u.copyWith(status: RdUploadStatus.waiting));
    final service = _uploadServices[id] ??= _service();
    _serial(service, (s) => _upload(s, id));
  }

  /// Removes the finished and failed rows of the queue.
  void dismissFinished() {
    _hideTimer?.cancel();
    final keep = [
      for (final u in state.uploads)
        if (u.status == RdUploadStatus.waiting || u.status == RdUploadStatus.uploading) u,
    ];
    _uploadServices.removeWhere((id, _) => !keep.any((u) => u.id == id));
    state = state.copyWith(uploads: keep);
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
    _deleteService = _service();
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
    _deleteService = null;
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
    final service = _deleteService ?? _service();
    _deleteService = null;
    for (final file in batch) {
      _serial(
        service,
        (s) => s.deleteFile(
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
    _serial(service, (_) async => _refresh());
  }

  /// Moves a file to another part / category.
  Future<void> setCategory(SongFile file, int? instrumentId, String? note, {int? mainGroupId}) async {
    await _serial(
      _service(),
      (s) => s.updateFileCategory(
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
      _service(),
      (s) => s.renameFile(
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
