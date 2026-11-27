import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config/supabase_config.dart';
import '../providers/song_providers.dart';
import '../providers/tenant_providers.dart';
import '../utils/demo_guard.dart'; // DEMO_GUARD
import '../../l10n/l10n.dart';
import '../utils/file_mime.dart';
import '../../data/models/song/song.dart';
import 'error_reporter.dart';

part 'song_file_sibelius.dart';
part 'song_file_upload.dart';

/// PARITY_B (D14): Ionic `filesJson` mapping of a `songs.files[]` entry —
/// storageName, fileName, fileType, url, instrumentId (null if missing) and
/// note (omitted when undefined). No `created_at`.
Map<String, dynamic> songFileJson(dynamic f) {
  final m = Map<String, dynamic>.from(f as Map);
  return {
    'storageName': m['storageName'],
    'fileName': m['fileName'],
    'fileType': m['fileType'],
    'url': m['url'],
    'instrumentId': m['instrumentId'],
    if (m['note'] != null) 'note': m['note'],
  };
}

/// The song is not there any more (deleted meanwhile).
class SongNotFoundException implements Exception {
  const SongNotFoundException();

  @override
  String toString() => l10nWithoutContext.coreFlutterSongNotFound;
}

/// Shared state, locking, and storage helpers for [SongFileService] mixins.
abstract class _SongFileServiceCore {
  _SongFileServiceCore(this._supabase, this._tenantId);

  final SupabaseClient _supabase;
  final int? _tenantId;

  static const String _bucketName = 'songs';
  static final Map<String, Future<void>> _songLocks = {};

  /// Tenant whose songs this service writes (the song source tenant).
  int? get tenantId => _tenantId;

  static Future<T> _locked<T>(
    int? tenantId,
    int songId,
    Future<T> Function() task,
  ) {
    final key = '$tenantId/$songId';
    final before = _songLocks[key] ?? Future<void>.value();
    final result = before.then((_) => task());
    late final Future<void> tail;
    tail = result.then<void>((_) {}, onError: (_) {}).whenComplete(() {
      if (identical(_songLocks[key], tail)) _songLocks.remove(key);
    });
    _songLocks[key] = tail;
    return result;
  }

  /// A fresh storage name that no file of the song uses yet. Old files without
  /// storageName are stored under their fileName, so those count as taken too.
  /// Only the existing Drive importer needs [legacyNumericName].
  Future<String> _freeFileId(
    int tenantId,
    int songId,
    String fileName, {
    bool legacyNumericName = false,
  }) async {
    final song = await _supabase
        .from('songs')
        .select('files')
        .eq('id', songId)
        .eq('tenantId', tenantId)
        .maybeSingle();
    final taken = <Object?>{
      for (final f in (song?['files'] as List?) ?? const [])
        if (f is Map) ...[f['storageName'], f['fileName']],
    };
    return legacyNumericName
        ? SongFileService.freeStorageName(fileName, taken)
        : SongFileService.freshStorageName(fileName, taken);
  }

  static bool _sameFile(dynamic f, String url, String? storageName) {
    if (f is! Map) return false;
    if (url.isNotEmpty && f['url'] == url) return true;
    return storageName != null &&
        storageName.isNotEmpty &&
        f['storageName'] == storageName;
  }

  /// Storage content type for an upload: the MIME type, or
  /// `application/octet-stream` when unknown.
  String _getContentType(String extensionOrMime) {
    if (extensionOrMime.contains('/')) return extensionOrMime;
    return songFileMimeType(extensionOrMime) ?? 'application/octet-stream';
  }
}

/// Service for managing song file uploads to Supabase Storage.
class SongFileService extends _SongFileServiceCore
    with _SongFileUploadMixin, _SongFileSibeliusMixin {
  SongFileService(super.supabase, super.tenantId);

  static final _random = Random();

  /// Generate a safe filename (`name_<suffix>.ext`).
  @visibleForTesting
  static String encodeFilename(String filename, Object suffix) {
    final dot = filename.lastIndexOf('.');
    final hasExtension = dot > 0 && dot < filename.length - 1;
    final ext = hasExtension ? filename.substring(dot) : '';
    String name = hasExtension ? filename.substring(0, dot) : filename;

    // Sanitize the filename
    name = name
        .replaceAll(RegExp(r'[\u0300-\u036f]'), '') // Remove diacritics
        .replaceAll(RegExp(r'[^\w\s-]'), '-') // Replace non-word chars
        .replaceAll(RegExp(r'\s+'), '-') // Replace spaces
        .replaceAll(RegExp(r'-+'), '-') // Multiple hyphens to single
        .replaceAll(RegExp(r'^-+|-+$'), ''); // Trim hyphens

    return '${name}_$suffix$ext';
  }

  /// A storage name for [fileName] not in [taken]: first a random number
  /// 100–999 (as Ionic), then every other one of them, then longer numbers.
  /// The numeric contract of `werke-import`; the upload must reject existing
  /// objects because removed names may still be awaiting cleanup.
  static String freeStorageName(
    String fileName,
    Set<Object?> taken, [
    Random? random,
  ]) {
    final first = 100 + (random ?? _random).nextInt(900);
    for (var i = 0; i < 900; i++) {
      final id = encodeFilename(fileName, 100 + (first - 100 + i) % 900);
      if (!taken.contains(id)) return id;
    }
    for (var n = 1000;; n++) {
      final id = encodeFilename(fileName, n);
      if (!taken.contains(id)) return id;
    }
  }

  /// A fresh object identity for each upload, including separate app sessions.
  /// Removed references can still have pending storage cleanup, so names must
  /// not be chosen from a reusable numeric pool. Uploads also reject overwrite.
  static String freshStorageName(String fileName, Set<Object?> taken) {
    for (;;) {
      final id = encodeFilename(fileName, const Uuid().v4());
      if (!taken.contains(id)) return id;
    }
  }

  @visibleForTesting
  static Future<T> lockedForTest<T>(
    int? tenantId,
    int songId,
    Future<T> Function() task,
  ) =>
      _SongFileServiceCore._locked(tenantId, songId, task);

  /// Ionic: instrument_ids = distinct file instrumentIds except null,
  /// 1 (Aufnahme) and the main group ([excludeLyrics] also drops 2).
  static List<int> instrumentIdsFromFiles(
    List<dynamic> files, {
    int? mainGroupId,
    bool excludeLyrics = false,
  }) {
    final ids = <int>{};
    for (final f in files) {
      final id = (f is Map ? f['instrumentId'] : null) as num?;
      if (id == null) continue;
      final value = id.toInt();
      if (value == 1 || value == mainGroupId) continue;
      if (excludeLyrics && value == 2) continue;
      ids.add(value);
    }
    return ids.toList();
  }

  /// [fileName] ending in the extension of the stored object [storedName]
  /// (unchanged when it already does or the object has none).
  static String withStoredExtension(String fileName, String storedName) {
    final dot = storedName.lastIndexOf('.');
    if (dot <= 0 || dot == storedName.length - 1) return fileName;
    final ext = storedName.substring(dot);
    return fileName.toLowerCase().endsWith(ext.toLowerCase())
        ? fileName
        : '$fileName$ext';
  }
}

/// Provider for SongFileService.
/// Uses the effective song tenant (Werk-Synchronisierung: song source tenant).
final songFileServiceProvider = Provider<SongFileService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final tenant = ref.watch(currentTenantProvider);
  final sourceId =
      ref.watch(songTenantSettingsProvider).valueOrNull?.songSourceTenantId;
  return SongFileService(supabase, sourceId ?? tenant?.id);
});

/// [songFileServiceProvider] once the song source tenant is known, so a first
/// upload/delete on a cold start never targets the own tenant of a synced
/// instance (`songs/<own>/…` → "Song nicht gefunden").
final readySongFileServiceProvider = FutureProvider<SongFileService>((ref) async {
  await ref.watch(songTenantSettingsProvider.future);
  return ref.watch(songFileServiceProvider);
});
