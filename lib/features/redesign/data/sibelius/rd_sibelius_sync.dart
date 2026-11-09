import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/connectivity_provider.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/services/song_file_service.dart';
import '../../../../data/models/song/song.dart';
import '../../../../l10n/l10n.dart';
import 'rd_sibelius_logic.dart';

/// "In Sibelius bearbeiten" exists only in the Mac app (Sibelius runs on the
/// Mac, the app may open files in other apps and see their saves).
bool get rdSibeliusSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

/// How often the copies are compared while any is open.
const Duration rdSibeliusPollInterval = Duration(seconds: 3);

/// How long a save must stay unchanged before it is uploaded (Sibelius
/// writes it in several steps), and how long no part may be added before the
/// parts are offered (Sibelius exports one part after the other).
const Duration rdSibeliusSaveSettle = Duration(seconds: 3);
const Duration rdSibeliusPartsSettle = Duration(seconds: 6);

const String _prefsKey = 'rd_sibelius_state_v1';

/// What happened with a save in Sibelius (shown as a toast).
sealed class RdSibeliusEvent {
  const RdSibeliusEvent(this.fileName);
  final String fileName;
}

/// The new content replaced the file in Attendix; [afterRetry]: only now, after
/// tries that failed (offline).
class RdSibeliusSaved extends RdSibeliusEvent {
  const RdSibeliusSaved(super.fileName, {this.afterRetry = false});
  final bool afterRetry;
}

/// The file changed in Attendix meanwhile: the save was added as [copyName].
class RdSibeliusSavedAsCopy extends RdSibeliusEvent {
  const RdSibeliusSavedAsCopy(super.fileName, this.copyName);
  final String copyName;
}

/// The upload failed: the save is on the Mac only and is uploaded by itself
/// later (shown once, not for every further try).
class RdSibeliusSaveFailed extends RdSibeliusEvent {
  const RdSibeliusSaveFailed(super.fileName, this.error);
  final Object error;
}

/// The Werk was deleted in Attendix: the copy is not kept in step any more
/// (it stays in Downloads › Attendix).
class RdSibeliusWorkGone extends RdSibeliusEvent {
  const RdSibeliusWorkGone(super.fileName);
}

class RdSibeliusState {
  const RdSibeliusState({this.parts = const {}, this.waiting = const []});

  /// Exported parts per parts folder, waiting for their Werk page.
  final Map<String, RdSibeliusParts> parts;

  /// Copies whose last save is only on the Mac so far (upload failed, tried
  /// again by itself).
  final List<RdSibeliusCheckout> waiting;

  bool isWaiting(int tenantId, int songId, SongFile file) => waiting.any((c) => c.matches(tenantId, songId, file));

  RdSibeliusState copyWith({Map<String, RdSibeliusParts>? parts, List<RdSibeliusCheckout>? waiting}) =>
      RdSibeliusState(parts: parts ?? this.parts, waiting: waiting ?? this.waiting);

  RdSibeliusParts? partsFor(int tenantId, int songId) {
    for (final p in parts.values) {
      if (p.tenantId == tenantId && p.songId == songId) return p;
    }
    return null;
  }
}

/// Result of [RdSibeliusSync.edit].
enum RdSibeliusOpen { opened, noFolder, notOpened }

/// REDESIGN (Mac app): keeps the scores opened with "In Sibelius bearbeiten"
/// in step with Attendix (see rd_sibelius_logic.dart).
///
/// While any copy is open the copies are compared every
/// [rdSibeliusPollInterval]; a save is uploaded once its file stayed the
/// same for one interval (Sibelius writes it in several steps). New part
/// PDFs of a work folder wait in [RdSibeliusState.parts] until the Werk page
/// is shown, which offers them as the new Stimmen.
class RdSibeliusSync extends Notifier<RdSibeliusState> {
  /// Test seams.
  @visibleForTesting
  static Future<Directory?> Function() downloadsDirectory = getDownloadsDirectory;
  @visibleForTesting
  static Future<bool> Function(Uri uri) openFile = (uri) => launchUrl(uri);

  final StreamController<RdSibeliusEvent> _events = StreamController.broadcast();

  /// Saves to show (the Werk page or the app shows them as toasts).
  Stream<RdSibeliusEvent> get events => _events.stream;

  List<RdSibeliusCheckout> _checkouts = [];
  Map<String, int> _partsSince = {};
  Future<void>? _loading;
  Timer? _timer;
  AppLifecycleListener? _lifecycle;
  Future<void> _scanning = Future<void>.value();
  bool _busy = false;

  /// Saves not yet settled: path → (modified, size, first seen).
  final Map<String, (int, int, int)> _pending = {};

  /// Parts folders not yet settled: folder → (count, newest, first seen).
  final Map<String, (int, int, int)> _pendingParts = {};

  @override
  RdSibeliusState build() {
    ref.onDispose(() {
      _timer?.cancel();
      _lifecycle?.dispose();
      _events.close();
    });
    if (rdSibeliusSupported) {
      // Back online: saves that are only on the Mac go up right away.
      ref.listen<AsyncValue<bool>>(connectivityProvider, (previous, next) {
        if (next.valueOrNull == true && previous?.valueOrNull != true) _retryNow();
      });
    }
    return const RdSibeliusState();
  }

  /// Picks up copies of an earlier start (called once the app is up).
  Future<void> start() async {
    if (!rdSibeliusSupported) return;
    await _load();
    if (_lifecycle == null) {
      // Back in the app: failed uploads get another try right away.
      _lifecycle = AppLifecycleListener(onResume: _retryNow);
      _retryNow();
      return;
    }
    _schedule();
  }

  /// Tries failed uploads again now instead of after their pause.
  void _retryNow() {
    _checkouts = [for (final c in _checkouts) c.failedModified == null ? c : c.copyWith(failedAt: 0)];
    _schedule();
    unawaited(_scan());
  }

  /// Reads the stored copies once (every caller waits for the same read).
  Future<void> _load() => _loading ??= _read();

  Future<void> _read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = rdSibeliusStateFromJson(prefs.getString(_prefsKey));
      _checkouts = [...stored.checkouts, ..._checkouts];
      _partsSince = {...stored.partsSince, ..._partsSince};
    } catch (e) {
      debugPrint('[RdSibeliusSync] load failed: $e');
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, rdSibeliusStateJson(_checkouts, _partsSince));
    } catch (e) {
      debugPrint('[RdSibeliusSync] save failed: $e');
    }
  }

  void _schedule() {
    if (_checkouts.isEmpty) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    // A tick is skipped while a comparison (e.g. a slow upload) still runs.
    _timer ??= Timer.periodic(rdSibeliusPollInterval, (_) {
      if (!_busy) unawaited(_scan());
    });
  }

  /// Real path of Downloads › Attendix (the sandbox reaches Downloads
  /// through a link in its container; Sibelius gets the real path).
  Future<Directory?> _root() async {
    final downloads = await downloadsDirectory();
    if (downloads == null) return null;
    var path = downloads.path;
    try {
      path = await Directory(path).resolveSymbolicLinks();
    } catch (_) {
      // Keep the path as it is.
    }
    return Directory('$path/$rdSibeliusRootFolder');
  }

  /// Home folder of the user (for the Sibelius plug-ins folder).
  Future<String?> home() async {
    final root = await _root();
    return root == null ? null : rdRealHome(root.path);
  }

  /// Copies [file] of the Werk into its work folder (unless a copy with
  /// changes not yet in Attendix is there) and opens it in Sibelius.
  Future<RdSibeliusOpen> edit({
    required SongFileService service,
    required int songId,
    required String songName,
    int? songNumber,
    required String groupName,
    int? mainGroupId,
    required SongFile file,
  }) async {
    await start();
    final tenantId = service.tenantId;
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (tenantId == null || userId == null) return RdSibeliusOpen.notOpened;

    final root = await _root();
    if (root == null) return RdSibeliusOpen.noFolder;

    // Only an own copy is reused: saves of a copy of another account (switched
    // accounts) are uploaded only when that account is back.
    var checkout = _checkouts.where((c) => c.userId == userId && c.matches(tenantId, songId, file)).firstOrNull;
    final local = checkout == null ? null : File(checkout.path);
    var localChanged = false;
    if (checkout != null && local != null && await local.exists()) {
      final hash = sha256.convert(await local.readAsBytes()).toString();
      localChanged = hash != checkout.hash;
      // A save whose upload failed gets another try now.
      if (localChanged && checkout.failedModified != null) _replace(checkout = checkout.copyWith(failedAt: 0));
    } else {
      checkout = null;
    }

    if (checkout == null || (!localChanged && checkout.url != file.url)) {
      // New copy, or the copy is unchanged and Attendix has a newer one.
      final bytes = await service.downloadFileBytes(file.url);
      if (bytes == null) return RdSibeliusOpen.notOpened;
      final String path;
      if (checkout != null) {
        path = checkout.path;
      } else {
        var folder =
            '${root.path}/${rdSafePathSegment(groupName, fallback: 'Gruppe')}/'
            '${rdSibeliusWorkFolder(number: songNumber, name: songName)}';
        // Another Werk with the same name and number has its own folder (its
        // Stimmen folder must not be offered here).
        if (_checkouts.any(
          (c) => File(c.path).parent.path == folder && (c.tenantId != tenantId || c.songId != songId),
        )) {
          folder = '$folder ($songId)';
        }
        final dir = Directory(folder);
        try {
          await dir.create(recursive: true);
        } catch (e) {
          debugPrint('[RdSibeliusSync] no work folder: $e');
          return RdSibeliusOpen.noFolder;
        }
        path = _freePath(dir.path, rdSafePathSegment(file.fileName, fallback: 'Partitur.sib'));
      }
      final target = File(path);
      try {
        await target.writeAsBytes(bytes, flush: true);
      } catch (e) {
        debugPrint('[RdSibeliusSync] write failed: $e');
        return RdSibeliusOpen.noFolder;
      }
      final stat = await target.stat();
      final next = RdSibeliusCheckout(
        path: path,
        tenantId: tenantId,
        songId: songId,
        userId: userId,
        url: file.url,
        storageName: file.storageName,
        fileName: file.fileName,
        instrumentId: file.instrumentId,
        note: file.note,
        mainGroupId: mainGroupId,
        hash: sha256.convert(bytes).toString(),
        modified: stat.modified.millisecondsSinceEpoch,
      );
      _checkouts = [
        for (final c in _checkouts)
          if (c.path != path) c,
        next,
      ];
      final parts = '${target.parent.path}/$rdSibeliusPartsFolder';
      // Parts exported before (an earlier copy) are not offered again.
      _partsSince.putIfAbsent(parts, () => DateTime.now().millisecondsSinceEpoch);
      checkout = next;
      await _save();
    }
    _schedule();

    final opened = await openFile(Uri.file(checkout.path));
    return opened ? RdSibeliusOpen.opened : RdSibeliusOpen.notOpened;
  }

  /// [name] in [dir], with " (2)" … when another copy or file has that path.
  String _freePath(String dir, String name) {
    final taken = {for (final c in _checkouts) c.path};
    bool used(String path) => taken.contains(path) || File(path).existsSync();
    var path = '$dir/$name';
    final dot = name.lastIndexOf('.');
    for (var n = 2; used(path); n++) {
      path = dot > 0 ? '$dir/${name.substring(0, dot)} ($n)${name.substring(dot)}' : '$dir/$name ($n)';
    }
    return path;
  }

  /// One comparison at a time.
  Future<void> _scan() =>
      _scanning = _scanning
          .then((_) async {
            _busy = true;
            try {
              await _scanOnce();
            } finally {
              _busy = false;
            }
          })
          .catchError((Object e) {
            debugPrint('[RdSibeliusSync] scan failed: $e');
          });

  @visibleForTesting
  Future<void> scanNow() => _scan();

  Future<void> _scanOnce() async {
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    final now = DateTime.now().millisecondsSinceEpoch;
    var changed = false;
    final gone = <String>{};
    for (final checkout in List.of(_checkouts)) {
      try {
        final result = await _scanCheckout(checkout, userId, now);
        if (result == null) {
          gone.add(checkout.path);
        } else if (result) {
          changed = true;
        }
      } catch (e) {
        // One unreadable copy does not stop the others.
        debugPrint('[RdSibeliusSync] ${checkout.path}: $e');
      }
    }
    if (gone.isNotEmpty) {
      _checkouts = [
        for (final c in _checkouts)
          if (!gone.contains(c.path)) c,
      ];
      changed = true;
    }
    await _scanParts(now);
    if (changed) await _save();
    _publishWaiting();
    _schedule();
  }

  /// Compares one copy: whether its record changed, null when it is not
  /// kept in step any more.
  Future<bool?> _scanCheckout(RdSibeliusCheckout checkout, String? userId, int now) async {
    final file = File(checkout.path);
    if (!await file.exists()) {
      // Moved or deleted in the Finder: nothing to keep in step any more.
      return await file.parent.exists() ? false : null;
    }
    final stat = await file.stat();
    final modified = stat.modified.millisecondsSinceEpoch;
    if (modified == checkout.modified) {
      _pending.remove(checkout.path);
      return false;
    }
    if (modified == checkout.failedModified) {
      // Its upload failed (offline?): tried again after a pause.
      _pending.remove(checkout.path);
      final due = (checkout.failedAt ?? 0) + rdSibeliusRetryDelay(checkout.failCount).inMilliseconds;
      if (now < due) return false;
    } else {
      // Wait until the save is complete: unchanged for a while.
      final seen = _pending[checkout.path];
      if (seen == null || seen.$1 != modified || seen.$2 != stat.size) {
        _pending[checkout.path] = (modified, stat.size, now);
        return false;
      }
      if (now - seen.$3 < rdSibeliusSaveSettle.inMilliseconds) return false;
      _pending.remove(checkout.path);
    }
    if (checkout.userId != userId) return false;
    final bytes = await file.readAsBytes();
    final hash = sha256.convert(bytes).toString();
    if (hash == checkout.hash) {
      _replace(checkout.copyWith(modified: modified, clearFailed: true));
      return true;
    }
    return await _upload(checkout, bytes, hash, modified) ? true : null;
  }

  void _publishWaiting() {
    final waiting = [
      for (final c in _checkouts)
        if (c.failedModified != null) c,
    ];
    String key(List<RdSibeliusCheckout> list) => [for (final c in list) '${c.path}|${c.url}'].join('\n');
    if (key(waiting) != key(state.waiting)) state = state.copyWith(waiting: waiting);
  }

  void _replace(RdSibeliusCheckout next) {
    _checkouts = [for (final c in _checkouts) c.path == next.path ? next : c];
  }

  /// Uploads a save; false when the Werk is gone (the copy is let go).
  Future<bool> _upload(RdSibeliusCheckout checkout, Uint8List bytes, String hash, int modified) async {
    final service = SongFileService(ref.read(supabaseClientProvider), checkout.tenantId);
    // The name of this try is kept before it starts: if the connection drops
    // after Attendix took it but before the answer came, the next try finds
    // the file under it (instead of thinking it was deleted).
    final attempt = rdSibeliusAttemptName(
      checkout.storageName ?? checkout.fileName,
      DateTime.now().millisecondsSinceEpoch,
    );
    final attempts = [...checkout.attempts, attempt];
    _replace(checkout = checkout.copyWith(attempts: attempts.sublist(attempts.length > 20 ? attempts.length - 20 : 0)));
    await _save();
    try {
      final replaced = await service.replaceFileContent(
        songId: checkout.songId,
        url: checkout.url,
        storageName: checkout.storageName,
        earlierNames: checkout.attempts.toSet(),
        newStorageName: attempt,
        bytes: bytes,
      );
      if (replaced != null) {
        _replace(
          checkout.copyWith(
            url: replaced.url,
            storageName: replaced.storageName,
            hash: hash,
            modified: modified,
            attempts: const [],
            clearFailed: true,
          ),
        );
        _events.add(RdSibeliusSaved(checkout.fileName, afterRetry: checkout.failCount > 0));
      } else {
        // Replaced or deleted in Attendix meanwhile: keep both versions.
        final copyName = rdSibeliusCopyName(checkout.fileName, l10nWithoutContext.redesignFilesSibeliusCopySuffix);
        final url = await service.uploadFile(
          songId: checkout.songId,
          file: PlatformFile(name: copyName, size: bytes.length, bytes: bytes),
          instrumentId: checkout.instrumentId,
          note: checkout.note,
          mainGroupId: checkout.mainGroupId,
        );
        final segments = Uri.tryParse(url)?.pathSegments ?? const <String>[];
        _replace(
          checkout.copyWith(
            url: url,
            storageName: segments.isEmpty ? null : Uri.decodeComponent(segments.last),
            fileName: copyName,
            hash: hash,
            modified: modified,
            attempts: const [],
            clearFailed: true,
          ),
        );
        _events.add(RdSibeliusSavedAsCopy(checkout.fileName, copyName));
      }
      _refresh(checkout.songId);
    } on SongNotFoundException {
      _events.add(RdSibeliusWorkGone(checkout.fileName));
      return false;
    } catch (e) {
      debugPrint('[RdSibeliusSync] upload failed: $e');
      // The save stays on the Mac and goes up by itself later; the hint is
      // shown once, not for every further try.
      _replace(
        checkout.copyWith(
          failedModified: modified,
          failedAt: DateTime.now().millisecondsSinceEpoch,
          failCount: checkout.failCount + 1,
        ),
      );
      if (checkout.failCount == 0) _events.add(RdSibeliusSaveFailed(checkout.fileName, e));
    }
    return true;
  }

  void _refresh(int songId) {
    ref.invalidate(songDetailDataProvider);
    if (ref.exists(songByIdProvider(songId))) ref.invalidate(songByIdProvider(songId));
    if (ref.exists(songsProvider)) ref.invalidate(songsProvider);
  }

  /// New PDFs in the parts folders (kept in [state] until taken).
  Future<void> _scanParts(int now) async {
    final next = <String, RdSibeliusParts>{};
    final folders = <String, RdSibeliusCheckout>{
      for (final c in _checkouts) '${File(c.path).parent.path}/$rdSibeliusPartsFolder': c,
    };
    for (final entry in folders.entries) {
      final dir = Directory(entry.key);
      final pdfs = <String, int>{};
      try {
        if (!await dir.exists()) continue;
        // Also below: a "/" in a part name may become a subfolder.
        await for (final f in dir.list(recursive: true, followLinks: false)) {
          if (f is! File) continue;
          pdfs[f.path] = (await f.stat()).modified.millisecondsSinceEpoch;
        }
      } catch (e) {
        debugPrint('[RdSibeliusSync] parts folder: $e');
        continue;
      }
      final since = _partsSince[entry.key] ?? 0;
      final paths = rdNewPartPdfs(pdfs, since);
      if (paths.isEmpty) {
        _pendingParts.remove(entry.key);
        continue;
      }
      // Sibelius writes one part after the other: offered once none was
      // added for a while.
      final newest = paths.map((p) => pdfs[p]!).reduce((a, b) => a > b ? a : b);
      final seen = _pendingParts[entry.key];
      final settled =
          seen != null &&
          seen.$1 == paths.length &&
          seen.$2 == newest &&
          now - seen.$3 >= rdSibeliusPartsSettle.inMilliseconds;
      if (seen == null || seen.$1 != paths.length || seen.$2 != newest) {
        _pendingParts[entry.key] = (paths.length, newest, now);
      }
      if (!settled) {
        final waiting = state.parts[entry.key];
        if (waiting != null) next[entry.key] = waiting;
        continue;
      }
      next[entry.key] = RdSibeliusParts(
        folder: entry.key,
        tenantId: entry.value.tenantId,
        songId: entry.value.songId,
        paths: paths,
      );
    }
    if (!mapEquals(_partsKeys(next), _partsKeys(state.parts))) state = state.copyWith(parts: next);
  }

  static Map<String, String> _partsKeys(Map<String, RdSibeliusParts> parts) => {
    for (final e in parts.entries) e.key: e.value.paths.join('\n'),
  };

  /// Reads the waiting parts of [folder] as upload files; null when there
  /// are none any more. They stay waiting until [partsAnswered].
  Future<({RdSibeliusParts parts, List<PlatformFile> files})?> takeParts(String folder) async {
    final parts = state.parts[folder];
    if (parts == null) return null;
    final files = <PlatformFile>[];
    for (final path in parts.paths) {
      try {
        final bytes = await File(path).readAsBytes();
        files.add(PlatformFile(name: path.split('/').last, size: bytes.length, bytes: bytes, path: path));
      } catch (e) {
        debugPrint('[RdSibeliusSync] part not readable: $e');
      }
    }
    return (parts: parts, files: files);
  }

  /// The user took over or turned down [parts]: not offered again (only
  /// parts exported later are).
  Future<void> partsAnswered(RdSibeliusParts parts) async {
    var newest = _partsSince[parts.folder] ?? 0;
    for (final path in parts.paths) {
      try {
        final modified = (await File(path).stat()).modified.millisecondsSinceEpoch;
        if (modified > newest) newest = modified;
      } catch (_) {
        // Gone meanwhile.
      }
    }
    _partsSince[parts.folder] = newest;
    _pendingParts.remove(parts.folder);
    state = state.copyWith(parts: {...state.parts}..remove(parts.folder));
    await _save();
  }
}

final rdSibeliusSyncProvider = NotifierProvider<RdSibeliusSync, RdSibeliusState>(RdSibeliusSync.new);

/// Whether the Werk page shows the hint "Stimmen direkt aus Sibelius" (Mac
/// app): until the plug-in was installed from here or the hint was closed.
class RdSibeliusPluginHint extends AsyncNotifier<bool> {
  static const _installedKey = 'rd_sibelius_plugin_installed';
  static const _dismissedKey = 'rd_sibelius_plugin_hint_dismissed';

  @override
  Future<bool> build() async {
    if (!rdSibeliusSupported) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      return !(prefs.getBool(_installedKey) ?? false) && !(prefs.getBool(_dismissedKey) ?? false);
    } catch (_) {
      return false;
    }
  }

  Future<void> markInstalled() => _set(_installedKey);

  Future<void> dismiss() => _set(_dismissedKey);

  Future<void> _set(String key) async {
    state = const AsyncData(false);
    try {
      await (await SharedPreferences.getInstance()).setBool(key, true);
    } catch (_) {
      // Shown again after the next start.
    }
  }
}

final rdSibeliusPluginHintProvider = AsyncNotifierProvider<RdSibeliusPluginHint, bool>(RdSibeliusPluginHint.new);
