import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../providers/song_providers.dart';
import '../providers/tenant_providers.dart';
import '../utils/demo_guard.dart'; // DEMO_GUARD
import '../../l10n/l10n.dart';
import '../utils/file_mime.dart';
import 'error_reporter.dart';

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

/// Service for managing song file uploads to Supabase Storage
class SongFileService {
  final SupabaseClient _supabase;
  final int? _tenantId;

  SongFileService(this._supabase, this._tenantId);

  static const String _bucketName = 'songs';

  /// Pick a file (PDF, PNG, JPG)
  Future<PlatformFile?> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      withData: kIsWeb, // For web, we need bytes
    );

    if (result == null || result.files.isEmpty) return null;
    // BL-013: Use firstOrNull for explicit null-safety
    return result.files.firstOrNull;
  }

  /// Generate a safe filename (`name_<suffix>.ext`, Ionic format)
  @visibleForTesting
  static String encodeFilename(String filename, Object suffix) {
    final ext = filename.split('.').last;
    String name = filename.substring(0, filename.length - ext.length - 1);

    // Sanitize the filename
    name = name
        .replaceAll(RegExp(r'[\u0300-\u036f]'), '') // Remove diacritics
        .replaceAll(RegExp(r'[^\w\s-]'), '-') // Replace non-word chars
        .replaceAll(RegExp(r'\s+'), '-') // Replace spaces
        .replaceAll(RegExp(r'-+'), '-') // Multiple hyphens to single
        .replaceAll(RegExp(r'^-+|-+$'), ''); // Trim hyphens

    return '${name}_$suffix.$ext';
  }

  static final _random = Random();

  /// A storage name for [fileName] not in [taken]: first a random number
  /// 100–999 (as Ionic), then every other one of them, then longer numbers.
  /// Never returns a taken name.
  static String freeStorageName(String fileName, Set<Object?> taken, [Random? random]) {
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

  /// A storage name for [fileName] that no file of the song uses yet. The
  /// upload overwrites (`upsert`), so an equal name would replace that
  /// file's object, and deleting the old entry afterwards ("Ersetzen")
  /// would remove both. Old files without storageName are stored under
  /// their fileName, so those count as taken too.
  Future<String> _freeFileId(int tenantId, int songId, String fileName) async {
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
    return freeStorageName(fileName, taken);
  }

  /// Writes of one song's `files` list read it, change it and write it back,
  /// so two at once would drop a change. They wait for each other here,
  /// across every service instance and page (old song page, upload sheets,
  /// the redesign workspace).
  static final Map<String, Future<void>> _songLocks = {};

  static Future<T> _locked<T>(int? tenantId, int songId, Future<T> Function() task) {
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

  @visibleForTesting
  static Future<T> lockedForTest<T>(int? tenantId, int songId, Future<T> Function() task) =>
      _locked(tenantId, songId, task);

  /// Upload a file to Supabase Storage and add it to the song.
  /// Returns the public URL of the uploaded file. The song's
  /// `instrument_ids` are derived from its files (Ionic); [keepBesetzung]
  /// keeps the groups it had besides them (import of a whole folder).
  Future<String> uploadFile({
    required int songId,
    required PlatformFile file,
    int? instrumentId,
    String? note,
    int? mainGroupId,
    bool keepBesetzung = false,
  }) =>
      _locked(_tenantId, songId, () => _uploadFile(
            songId: songId,
            file: file,
            instrumentId: instrumentId,
            note: note,
            mainGroupId: mainGroupId,
            keepBesetzung: keepBesetzung,
          ));

  /// Like [uploadFile], but the content is stored by [store] (the
  /// `werke-import` function copies it straight from Google Drive): it gets
  /// the tenant, a storage name no file of the song uses and the content type
  /// and returns the storage path it wrote. The entry is then added to the
  /// song as by [uploadFile].
  Future<String> uploadFileVia({
    required int songId,
    required String fileName,
    required Future<String> Function(int tenantId, String storageName, String contentType) store,
    int? instrumentId,
    String? note,
    int? mainGroupId,
    bool keepBesetzung = false,
  }) =>
      _locked(_tenantId, songId, () async {
        DemoGuard.checkCurrent('uploadSongFile'); // DEMO_GUARD
        final tenantId = _tenantId;
        if (tenantId == null) {
          throw Exception(l10nWithoutContext.coreFlutterNoTenantSelected);
        }
        final extension = PlatformFile(name: fileName, size: 0).extension ?? '';
        final fileId = await _freeFileId(tenantId, songId, fileName);
        final storagePath = 'songs/$tenantId/$songId/$fileId';
        final stored = await store(tenantId, fileId, _getContentType(extension));
        if (stored != storagePath) throw StateError('stored at $stored, not $storagePath');
        return _addToSong(
          tenantId: tenantId,
          songId: songId,
          storagePath: storagePath,
          fileId: fileId,
          fileName: fileName,
          extension: extension,
          instrumentId: instrumentId,
          note: note,
          mainGroupId: mainGroupId,
          keepBesetzung: keepBesetzung,
        );
      });

  /// Delete a file from storage and song's files array.
  Future<void> deleteFile({
    required int songId,
    required String url,
    String? storageName,
    String? fileName,
    int? mainGroupId,
  }) =>
      _locked(_tenantId, songId, () => _deleteFile(
            songId: songId,
            url: url,
            storageName: storageName,
            fileName: fileName,
            mainGroupId: mainGroupId,
          ));

  /// Delete all files from a song
  Future<void> deleteAllFiles({required int songId}) =>
      _locked(_tenantId, songId, () => _deleteAllFiles(songId: songId));

  /// Update file category (instrumentId and note)
  Future<void> updateFileCategory({
    required int songId,
    required String url,
    String? storageName,
    int? instrumentId,
    String? note,
    int? mainGroupId,
  }) =>
      _locked(_tenantId, songId, () => _updateFileCategory(
            songId: songId,
            url: url,
            storageName: storageName,
            instrumentId: instrumentId,
            note: note,
            mainGroupId: mainGroupId,
          ));

  /// Rename a file (display name only, see [_renameFile]).
  Future<void> renameFile({
    required int songId,
    required String url,
    required String storageName,
    required String fileName,
  }) =>
      _locked(_tenantId, songId, () => _renameFile(
            songId: songId,
            url: url,
            storageName: storageName,
            fileName: fileName,
          ));

  /// Upload file from bytes (for copying between tenants)
  Future<String> uploadFileBytes({
    required int songId,
    required int tenantId,
    required String fileName,
    required String fileType,
    required Uint8List bytes,
    int? instrumentId,
    String? note,
  }) =>
      _locked(tenantId, songId, () => _uploadFileBytes(
            songId: songId,
            tenantId: tenantId,
            fileName: fileName,
            fileType: fileType,
            bytes: bytes,
            instrumentId: instrumentId,
            note: note,
          ));

  /// Upload a file to Supabase Storage
  /// Returns the public URL of the uploaded file
  Future<String> _uploadFile({
    required int songId,
    required PlatformFile file,
    int? instrumentId,
    String? note,
    int? mainGroupId,
    bool keepBesetzung = false,
  }) async {
    DemoGuard.checkCurrent('uploadSongFile'); // DEMO_GUARD
    if (_tenantId == null) {
      throw Exception(l10nWithoutContext.coreFlutterNoTenantSelected);
    }

    // Generate unique storage path
    final fileId = await _freeFileId(_tenantId, songId, file.name);
    final storagePath = 'songs/$_tenantId/$songId/$fileId';

    // Get file bytes (dropped files, web and desktop apps, already carry them)
    Uint8List fileBytes;
    if (file.bytes != null) {
      fileBytes = file.bytes!;
    } else if (kIsWeb) {
      throw Exception(l10nWithoutContext.coreFlutterFileBytesUnavailable);
    } else {
      if (file.path == null) {
        throw Exception(l10nWithoutContext.coreFlutterFilePathUnavailable);
      }
      fileBytes = await File(file.path!).readAsBytes();
    }

    // Upload to storage
    await _supabase.storage.from(_bucketName).uploadBinary(
          storagePath,
          fileBytes,
          fileOptions: FileOptions(
            contentType: _getContentType(file.extension ?? ''),
            upsert: true,
          ),
        );

    return _addToSong(
      tenantId: _tenantId,
      songId: songId,
      storagePath: storagePath,
      fileId: fileId,
      fileName: file.name,
      extension: file.extension ?? '',
      instrumentId: instrumentId,
      note: note,
      mainGroupId: mainGroupId,
      keepBesetzung: keepBesetzung,
    );
  }

  /// Adds the file stored at [storagePath] to the song's files (removes it
  /// again when the song is gone). Returns its public URL.
  Future<String> _addToSong({
    required int tenantId,
    required int songId,
    required String storagePath,
    required String fileId,
    required String fileName,
    required String extension,
    int? instrumentId,
    String? note,
    int? mainGroupId,
    bool keepBesetzung = false,
  }) async {
    // Get public URL
    final url = _supabase.storage.from(_bucketName).getPublicUrl(storagePath);

    // RT-009: Use maybeSingle() to handle deleted songs gracefully
    final songResponse = await _supabase
        .from('songs')
        .select(keepBesetzung ? 'files, instrument_ids' : 'files')
        .eq('id', songId)
        .eq('tenantId', tenantId)
        .maybeSingle();

    if (songResponse == null) {
      // Cleanup: remove uploaded file
      try {
        await _supabase.storage.from(_bucketName).remove([storagePath]);
      } catch (e, st) {
        ErrorReporter.report(e, st, where: 'song_file_service');
      }
      throw Exception(l10nWithoutContext.coreFlutterSongNotFound);
    }

    // Build new files array
    final existingFiles = (songResponse['files'] as List?) ?? [];
    // Like Ionic: fileType is the browser MIME type (`file.type`), which
    // is empty for types the browser does not know.
    final newFile = {
      'storageName': fileId,
      'fileName': fileName,
      'fileType': songFileMimeType(extension) ?? '',
      'url': url,
      'instrumentId': instrumentId,
      if (note != null) 'note': note,
    };

    // PARITY_B (D14): Ionic rewrites every file entry with exactly these keys
    final updatedFiles = [...existingFiles, newFile].map(songFileJson).toList();

    // Update song with new files array and derived instrument_ids (Ionic)
    var instrumentIds = instrumentIdsFromFiles(updatedFiles, mainGroupId: mainGroupId);
    if (keepBesetzung) {
      // Read and written under the song's lock, with the files.
      final before = [
        for (final id in (songResponse['instrument_ids'] as List?) ?? const [])
          if (id is num) id.toInt(),
      ];
      instrumentIds = [...before, ...instrumentIds.where((id) => !before.contains(id))];
    }
    await _supabase.from('songs').update({
      'files': updatedFiles,
      'instrument_ids': instrumentIds,
    }).eq('id', songId).eq('tenantId', tenantId);

    return url;
  }

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

  static bool _sameFile(dynamic f, String url, String? storageName) {
    if (f is! Map) return false;
    if (url.isNotEmpty && f['url'] == url) return true;
    return storageName != null &&
        storageName.isNotEmpty &&
        f['storageName'] == storageName;
  }

  /// Delete a file from storage and song's files array.
  /// Files are identified by URL (old files have no storageName).
  Future<void> _deleteFile({
    required int songId,
    required String url,
    String? storageName,
    String? fileName,
    int? mainGroupId,
  }) async {
    DemoGuard.checkCurrent('deleteSongFile'); // DEMO_GUARD
    if (_tenantId == null) {
      throw Exception(l10nWithoutContext.coreFlutterNoTenantSelected);
    }

    // Delete from storage
    final objectName = (storageName?.isNotEmpty ?? false) ? storageName : fileName;
    if (objectName != null && objectName.isNotEmpty) {
      final storagePath = 'songs/$_tenantId/$songId/$objectName';
      try {
        await _supabase.storage.from(_bucketName).remove([storagePath]);
      } catch (e) {
        // File might not exist in storage, continue anyway
      }
    }

    // RT-009: Use maybeSingle() - song may have been deleted
    final songResponse = await _supabase
        .from('songs')
        .select('files')
        .eq('id', songId)
        .eq('tenantId', _tenantId)
        .maybeSingle();

    // Song doesn't exist - file is effectively deleted
    if (songResponse == null) {
      return;
    }

    final existingFiles = (songResponse['files'] as List?) ?? [];

    // Remove the file from the array
    final updatedFiles = existingFiles
        .where((f) => !_sameFile(f, url, storageName))
        .toList();

    // Update song
    await _supabase.from('songs').update({
      'files': updatedFiles,
      'instrument_ids': instrumentIdsFromFiles(updatedFiles, mainGroupId: mainGroupId),
    }).eq('id', songId).eq('tenantId', _tenantId);
  }

  /// Delete all files from a song
  Future<void> _deleteAllFiles({required int songId}) async {
    DemoGuard.checkCurrent('deleteSongFile'); // DEMO_GUARD
    if (_tenantId == null) {
      throw Exception(l10nWithoutContext.coreFlutterNoTenantSelected);
    }

    // RT-009: Use maybeSingle() - song may have been deleted
    final songResponse = await _supabase
        .from('songs')
        .select('files')
        .eq('id', songId)
        .eq('tenantId', _tenantId)
        .maybeSingle();

    // Song doesn't exist - nothing to do
    if (songResponse == null) {
      return;
    }

    final existingFiles = (songResponse['files'] as List?) ?? [];

    // Delete each file from storage
    for (final file in existingFiles) {
      final storageName =
          (file['storageName'] as String?) ?? (file['fileName'] as String?);
      if (storageName != null) {
        final storagePath = 'songs/$_tenantId/$songId/$storageName';
        try {
          await _supabase.storage.from(_bucketName).remove([storagePath]);
        } catch (e) {
          // File might not exist in storage, continue anyway
        }
      }
    }

    // Clear files array
    await _supabase.from('songs').update({
      'files': [],
    }).eq('id', songId).eq('tenantId', _tenantId);
  }

  /// Update file category (instrumentId and note)
  Future<void> _updateFileCategory({
    required int songId,
    required String url,
    String? storageName,
    int? instrumentId,
    String? note,
    int? mainGroupId,
  }) async {
    DemoGuard.checkCurrent('updateSongFile'); // DEMO_GUARD
    if (_tenantId == null) {
      throw Exception(l10nWithoutContext.coreFlutterNoTenantSelected);
    }

    // RT-009: Use maybeSingle() - song may have been deleted
    final songResponse = await _supabase
        .from('songs')
        .select('files')
        .eq('id', songId)
        .eq('tenantId', _tenantId)
        .maybeSingle();

    if (songResponse == null) {
      throw Exception(l10nWithoutContext.coreFlutterSongNotFound);
    }

    final existingFiles = List<Map<String, dynamic>>.from(
      (songResponse['files'] as List?) ?? [],
    );

    // Update the matching file
    for (var i = 0; i < existingFiles.length; i++) {
      if (_sameFile(existingFiles[i], url, storageName)) {
        existingFiles[i] = {
          ...existingFiles[i],
          'instrumentId': instrumentId,
          'note': note,
        };
        break;
      }
    }

    // Update song (Ionic saveFileChange also refreshes instrument_ids)
    await _supabase.from('songs').update({
      'files': existingFiles,
      'instrument_ids': instrumentIdsFromFiles(
        existingFiles,
        mainGroupId: mainGroupId,
        excludeLyrics: true,
      ),
    }).eq('id', songId).eq('tenantId', _tenantId);
  }

  /// Rename a file: only its display name (`fileName`) changes; the storage
  /// object keeps its `storageName`. Files without a storageName (very old
  /// uploads) are stored under their fileName, so they are not renamed.
  Future<void> _renameFile({
    required int songId,
    required String url,
    required String storageName,
    required String fileName,
  }) async {
    DemoGuard.checkCurrent('updateSongFile'); // DEMO_GUARD
    if (_tenantId == null) {
      throw Exception(l10nWithoutContext.coreFlutterNoTenantSelected);
    }
    if (storageName.isEmpty || fileName.trim().isEmpty) return;

    // RT-009: Use maybeSingle() - song may have been deleted
    final songResponse = await _supabase
        .from('songs')
        .select('files')
        .eq('id', songId)
        .eq('tenantId', _tenantId)
        .maybeSingle();

    if (songResponse == null) {
      throw Exception(l10nWithoutContext.coreFlutterSongNotFound);
    }

    final existingFiles = List<Map<String, dynamic>>.from(
      (songResponse['files'] as List?) ?? [],
    );
    for (var i = 0; i < existingFiles.length; i++) {
      if (_sameFile(existingFiles[i], url, storageName)) {
        existingFiles[i] = {...existingFiles[i], 'fileName': fileName.trim()};
        break;
      }
    }

    await _supabase.from('songs').update({
      'files': existingFiles,
    }).eq('id', songId).eq('tenantId', _tenantId);
  }

  /// Pick multiple files
  Future<List<PlatformFile>?> pickMultipleFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: true,
      withData: kIsWeb,
    );

    if (result == null || result.files.isEmpty) return null;
    return result.files;
  }

  /// Download a file's bytes (for saving locally)
  Future<Uint8List?> downloadFileBytes(String url) async {
    try {
      // Extract storage path from URL
      // URL format: https://xxx.supabase.co/storage/v1/object/public/songs/...
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;

      // Find 'songs' in path and get everything after
      final songsIndex = pathSegments.indexOf('songs');
      if (songsIndex == -1 || songsIndex >= pathSegments.length - 1) {
        return null;
      }

      final storagePath = pathSegments.sublist(songsIndex).join('/');
      return await _supabase.storage.from(_bucketName).download(
        storagePath.replaceFirst('songs/', ''),
      );
    } catch (e, stack) {
      debugPrint('Error downloading file: $e\n$stack');
      return null;
    }
  }

  /// Upload file from bytes (for copying between tenants)
  Future<String> _uploadFileBytes({
    required int songId,
    required int tenantId,
    required String fileName,
    required String fileType,
    required Uint8List bytes,
    int? instrumentId,
    String? note,
  }) async {
    DemoGuard.checkCurrent('uploadSongFile'); // DEMO_GUARD
    // Generate unique storage path
    final fileId = await _freeFileId(tenantId, songId, fileName);
    final storagePath = 'songs/$tenantId/$songId/$fileId';

    // Upload to storage
    await _supabase.storage.from(_bucketName).uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(
            contentType: _getContentType(fileType),
            upsert: true,
          ),
        );

    // Get public URL
    final url = _supabase.storage.from(_bucketName).getPublicUrl(storagePath);

    // RT-009: Use maybeSingle() - song may have been deleted
    final songResponse = await _supabase
        .from('songs')
        .select('files')
        .eq('id', songId)
        .eq('tenantId', tenantId)
        .maybeSingle();

    if (songResponse == null) {
      // Cleanup: remove uploaded file
      try {
        await _supabase.storage.from(_bucketName).remove([storagePath]);
      } catch (e, st) {
        ErrorReporter.report(e, st, where: 'song_file_service');
      }
      throw Exception(l10nWithoutContext.coreFlutterSongNotFound);
    }

    // Build new files array
    final existingFiles = (songResponse['files'] as List?) ?? [];
    final newFile = {
      'storageName': fileId,
      'fileName': fileName,
      // Ionic uploadSongFileToTenant: keep the source file's type as is.
      'fileType': fileType,
      'url': url,
      'instrumentId': instrumentId,
      if (note != null) 'note': note,
    };

    // PARITY_B (D14): Ionic rewrites every file entry with exactly these keys
    final updatedFiles = [...existingFiles, newFile].map(songFileJson).toList();

    // Update song with new files array
    await _supabase.from('songs').update({
      'files': updatedFiles,
    }).eq('id', songId).eq('tenantId', tenantId);

    return url;
  }

  /// Storage content type for an upload: the MIME type, or
  /// `application/octet-stream` when unknown.
  String _getContentType(String extensionOrMime) {
    if (extensionOrMime.contains('/')) return extensionOrMime;
    return songFileMimeType(extensionOrMime) ?? 'application/octet-stream';
  }

}

/// Provider for SongFileService
/// Uses the effective song tenant (Werk-Synchronisierung: song source tenant)
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
