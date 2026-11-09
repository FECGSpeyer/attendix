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

const String _prefsKey = 'rd_sibelius_state_v1';

/// What happened with a save in Sibelius (shown as a toast).
sealed class RdSibeliusEvent {
  const RdSibeliusEvent(this.fileName);
  final String fileName;
}

/// The new content replaced the file in Attendix.
class RdSibeliusSaved extends RdSibeliusEvent {
  const RdSibeliusSaved(super.fileName);
}

/// The file changed in Attendix meanwhile: the save was added as [copyName].
class RdSibeliusSavedAsCopy extends RdSibeliusEvent {
  const RdSibeliusSavedAsCopy(super.fileName, this.copyName);
  final String copyName;
}

/// The upload failed (retried after the next save or when the app returns).
class RdSibeliusSaveFailed extends RdSibeliusEvent {
  const RdSibeliusSaveFailed(super.fileName, this.error);
  final Object error;
}

class RdSibeliusState {
  const RdSibeliusState({this.parts = const {}});

  /// Exported parts per parts folder, waiting for their Werk page.
  final Map<String, RdSibeliusParts> parts;

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

  /// Seen on the last tick and not yet stable: path → (modified, size).
  final Map<String, (int, int)> _pending = {};

  /// Parts folders seen on the last tick: folder → (count, newest).
  final Map<String, (int, int)> _pendingParts = {};

  @override
  RdSibeliusState build() {
    ref.onDispose(() {
      _timer?.cancel();
      _lifecycle?.dispose();
      _events.close();
    });
    return const RdSibeliusState();
  }

  /// Picks up copies of an earlier start (called once the app is up).
  Future<void> start() async {
    if (!rdSibeliusSupported) return;
    await _load();
    _lifecycle ??= AppLifecycleListener(onResume: () {
      // Failed uploads get another try when the app comes back.
      _checkouts = [for (final c in _checkouts) c.copyWith(clearFailed: true)];
      unawaited(_scan());
    });
    _schedule();
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
    _timer ??= Timer.periodic(rdSibeliusPollInterval, (_) => unawaited(_scan()));
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

    var checkout = _checkouts.where((c) => c.matches(tenantId, songId, file)).firstOrNull;
    final local = checkout == null ? null : File(checkout.path);
    var localChanged = false;
    if (checkout != null && local != null && await local.exists()) {
      final hash = sha256.convert(await local.readAsBytes()).toString();
      localChanged = hash != checkout.hash;
      // A save whose upload failed gets another try.
      if (localChanged) _replace(checkout = checkout.copyWith(clearFailed: true));
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
        final dir = Directory(
          '${root.path}/${rdSafePathSegment(groupName, fallback: 'Gruppe')}/'
          '${rdSibeliusWorkFolder(number: songNumber, name: songName)}',
        );
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
      _checkouts = [for (final c in _checkouts) if (c.path != path) c, next];
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

  /// [name] in [dir], with " (2)" … when another open copy has that path.
  String _freePath(String dir, String name) {
    final taken = {for (final c in _checkouts) c.path};
    var path = '$dir/$name';
    final dot = name.lastIndexOf('.');
    for (var n = 2; taken.contains(path); n++) {
      path = dot > 0
          ? '$dir/${name.substring(0, dot)} ($n)${name.substring(dot)}'
          : '$dir/$name ($n)';
    }
    return path;
  }

  /// One comparison at a time.
  Future<void> _scan() => _scanning = _scanning.then((_) => _scanOnce()).catchError((Object e) {
        debugPrint('[RdSibeliusSync] scan failed: $e');
      });

  @visibleForTesting
  Future<void> scanNow() => _scan();

  Future<void> _scanOnce() async {
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    var changed = false;
    final gone = <String>{};
    for (final checkout in List.of(_checkouts)) {
      final file = File(checkout.path);
      if (!await file.exists()) {
        // Moved or deleted in the Finder: nothing to keep in step any more.
        if (!await file.parent.exists()) gone.add(checkout.path);
        continue;
      }
      final stat = await file.stat();
      final modified = stat.modified.millisecondsSinceEpoch;
      if (modified == checkout.modified || modified == checkout.failedModified) {
        _pending.remove(checkout.path);
        continue;
      }
      // Wait until the save is complete (same time and size twice).
      final seen = (modified, stat.size);
      if (_pending[checkout.path] != seen) {
        _pending[checkout.path] = seen;
        continue;
      }
      _pending.remove(checkout.path);
      if (checkout.userId != userId) continue;
      final bytes = await file.readAsBytes();
      final hash = sha256.convert(bytes).toString();
      if (hash == checkout.hash) {
        _replace(checkout.copyWith(modified: modified, clearFailed: true));
        changed = true;
        continue;
      }
      await _upload(checkout, bytes, hash, modified);
      changed = true;
    }
    if (gone.isNotEmpty) {
      _checkouts = [for (final c in _checkouts) if (!gone.contains(c.path)) c];
      changed = true;
    }
    await _scanParts();
    if (changed) await _save();
    _schedule();
  }

  void _replace(RdSibeliusCheckout next) {
    _checkouts = [for (final c in _checkouts) c.path == next.path ? next : c];
  }

  Future<void> _upload(RdSibeliusCheckout checkout, Uint8List bytes, String hash, int modified) async {
    final service = SongFileService(ref.read(supabaseClientProvider), checkout.tenantId);
    try {
      final replaced = await service.replaceFileContent(
        songId: checkout.songId,
        url: checkout.url,
        storageName: checkout.storageName,
        bytes: bytes,
      );
      if (replaced != null) {
        _replace(checkout.copyWith(
          url: replaced.url,
          storageName: replaced.storageName,
          hash: hash,
          modified: modified,
          clearFailed: true,
        ));
        _events.add(RdSibeliusSaved(checkout.fileName));
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
        _replace(checkout.copyWith(
          url: url,
          storageName: segments.isEmpty ? null : Uri.decodeComponent(segments.last),
          fileName: copyName,
          hash: hash,
          modified: modified,
          clearFailed: true,
        ));
        _events.add(RdSibeliusSavedAsCopy(checkout.fileName, copyName));
      }
      _refresh(checkout.songId);
    } catch (e) {
      debugPrint('[RdSibeliusSync] upload failed: $e');
      _replace(checkout.copyWith(failedModified: modified));
      _events.add(RdSibeliusSaveFailed(checkout.fileName, e));
    }
  }

  void _refresh(int songId) {
    ref.invalidate(songDetailDataProvider);
    if (ref.exists(songByIdProvider(songId))) ref.invalidate(songByIdProvider(songId));
    if (ref.exists(songsProvider)) ref.invalidate(songsProvider);
  }

  /// New PDFs in the parts folders (kept in [state] until taken).
  Future<void> _scanParts() async {
    final next = <String, RdSibeliusParts>{};
    final folders = <String, RdSibeliusCheckout>{
      for (final c in _checkouts) '${File(c.path).parent.path}/$rdSibeliusPartsFolder': c,
    };
    for (final entry in folders.entries) {
      final dir = Directory(entry.key);
      if (!await dir.exists()) continue;
      final pdfs = <String, int>{};
      try {
        await for (final f in dir.list(followLinks: false)) {
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
      // Sibelius writes one part after the other: wait until none is added.
      final newest = paths.map((p) => pdfs[p]!).reduce((a, b) => a > b ? a : b);
      final seen = (paths.length, newest);
      if (_pendingParts[entry.key] != seen) {
        _pendingParts[entry.key] = seen;
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
    if (!mapEquals(_partsKeys(next), _partsKeys(state.parts))) state = RdSibeliusState(parts: next);
  }

  static Map<String, String> _partsKeys(Map<String, RdSibeliusParts> parts) => {
    for (final e in parts.entries) e.key: e.value.paths.join('\n'),
  };

  /// Reads the waiting parts of [folder] (as upload files) and marks them
  /// as taken; null when there are none any more.
  Future<List<PlatformFile>?> takeParts(String folder) async {
    final parts = state.parts[folder];
    if (parts == null) return null;
    await _markPartsTaken(parts);
    final files = <PlatformFile>[];
    for (final path in parts.paths) {
      try {
        final bytes = await File(path).readAsBytes();
        files.add(PlatformFile(name: path.split('/').last, size: bytes.length, bytes: bytes, path: path));
      } catch (e) {
        debugPrint('[RdSibeliusSync] part not readable: $e');
      }
    }
    return files;
  }

  Future<void> _markPartsTaken(RdSibeliusParts parts) async {
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
    state = RdSibeliusState(parts: {...state.parts}..remove(parts.folder));
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
