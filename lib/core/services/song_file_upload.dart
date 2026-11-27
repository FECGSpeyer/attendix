part of 'song_file_service.dart';

/// File picking, upload, download, category update, and delete operations.
mixin _SongFileUploadMixin on _SongFileServiceCore {
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
      // URL format: https://api.attendix.de/storage/v1/object/public/songs/... (or legacy *.supabase.co)
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;

      final songsIndex = pathSegments.indexOf('songs');
      if (songsIndex == -1 || songsIndex >= pathSegments.length - 1) {
        return null;
      }

      final storagePath = pathSegments.sublist(songsIndex).join('/');
      return await _supabase.storage
          .from(_SongFileServiceCore._bucketName)
          .download(storagePath.replaceFirst('songs/', ''));
    } catch (e, stack) {
      debugPrint('Error downloading file: $e\n$stack');
      return null;
    }
  }

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
      _SongFileServiceCore._locked(
        _tenantId,
        songId,
        () => _uploadFile(
          songId: songId,
          file: file,
          instrumentId: instrumentId,
          note: note,
          mainGroupId: mainGroupId,
          keepBesetzung: keepBesetzung,
        ),
      );

  /// Like [uploadFile], but the content is stored by [store] (the
  /// `werke-import` function copies it straight from Google Drive): it gets
  /// the tenant, a storage name no file of the song uses and the content type
  /// and returns the storage path it wrote. The entry is then added to the
  /// song as by [uploadFile]. The importer requires a numeric name and [store]
  /// must reject overwriting an existing object.
  Future<String> uploadFileVia({
    required int songId,
    required String fileName,
    required Future<String> Function(
      int tenantId,
      String storageName,
      String contentType,
    ) store,
    int? instrumentId,
    String? note,
    int? mainGroupId,
    bool keepBesetzung = false,
  }) =>
      _SongFileServiceCore._locked(_tenantId, songId, () async {
        DemoGuard.checkCurrent('uploadSongFile'); // DEMO_GUARD
        final tenantId = _tenantId;
        if (tenantId == null) {
          throw Exception(l10nWithoutContext.coreFlutterNoTenantSelected);
        }
        final extension = PlatformFile(name: fileName, size: 0).extension ?? '';
        final fileId = await _freeFileId(
          tenantId,
          songId,
          fileName,
          legacyNumericName: true,
        );
        final storagePath = 'songs/$tenantId/$songId/$fileId';
        final stored = await store(tenantId, fileId, _getContentType(extension));
        if (stored != storagePath) {
          throw StateError('stored at $stored, not $storagePath');
        }
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
      _SongFileServiceCore._locked(
        _tenantId,
        songId,
        () => _deleteFile(
          songId: songId,
          url: url,
          storageName: storageName,
          fileName: fileName,
          mainGroupId: mainGroupId,
        ),
      );

  /// Delete all files from a song
  Future<void> deleteAllFiles({required int songId}) =>
      _SongFileServiceCore._locked(
        _tenantId,
        songId,
        () => _deleteAllFiles(songId: songId),
      );

  /// Update file category (instrumentId and note)
  Future<void> updateFileCategory({
    required int songId,
    required String url,
    String? storageName,
    int? instrumentId,
    String? note,
    int? mainGroupId,
  }) =>
      _SongFileServiceCore._locked(
        _tenantId,
        songId,
        () => _updateFileCategory(
          songId: songId,
          url: url,
          storageName: storageName,
          instrumentId: instrumentId,
          note: note,
          mainGroupId: mainGroupId,
        ),
      );

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
      _SongFileServiceCore._locked(
        tenantId,
        songId,
        () => _uploadFileBytes(
          songId: songId,
          tenantId: tenantId,
          fileName: fileName,
          fileType: fileType,
          bytes: bytes,
          instrumentId: instrumentId,
          note: note,
        ),
      );

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

    final fileId = await _freeFileId(_tenantId, songId, file.name);
    final storagePath = 'songs/$_tenantId/$songId/$fileId';

    final Uint8List fileBytes;
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

    await _supabase.storage
        .from(_SongFileServiceCore._bucketName)
        .uploadBinary(
          storagePath,
          fileBytes,
          fileOptions: FileOptions(
            contentType: _getContentType(file.extension ?? ''),
            upsert: false,
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
    final url = _supabase.storage
        .from(_SongFileServiceCore._bucketName)
        .getPublicUrl(storagePath);

    // RT-009: Use maybeSingle() to handle deleted songs gracefully
    final songResponse = await _supabase
        .from('songs')
        .select(keepBesetzung ? 'files, instrument_ids' : 'files')
        .eq('id', songId)
        .eq('tenantId', tenantId)
        .maybeSingle();

    if (songResponse == null) {
      try {
        await _supabase.storage
            .from(_SongFileServiceCore._bucketName)
            .remove([storagePath]);
      } catch (e, st) {
        ErrorReporter.report(e, st, where: 'song_file_service');
      }
      throw Exception(l10nWithoutContext.coreFlutterSongNotFound);
    }

    final existingFiles = (songResponse['files'] as List?) ?? [];
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

    var instrumentIds = SongFileService.instrumentIdsFromFiles(
      updatedFiles,
      mainGroupId: mainGroupId,
    );
    if (keepBesetzung) {
      final before = [
        for (final id in (songResponse['instrument_ids'] as List?) ?? const [])
          if (id is num) id.toInt(),
      ];
      instrumentIds = [
        ...before,
        ...instrumentIds.where((id) => !before.contains(id)),
      ];
    }
    await _supabase.from('songs').update({
      'files': updatedFiles,
      'instrument_ids': instrumentIds,
    }).eq('id', songId).eq('tenantId', tenantId);

    return url;
  }

  static String? _storageObjectName(dynamic file) {
    if (file is! Map) return null;
    final storageName = file['storageName'];
    if (storageName is String && storageName.isNotEmpty) return storageName;
    final fileName = file['fileName'];
    return fileName is String && fileName.isNotEmpty ? fileName : null;
  }

  /// Only after the reference update is confirmed. A failed cleanup leaves
  /// an unused object, never a visible entry whose content was removed.
  /// Do not remove objects still used by another entry of the current list.
  Future<void> _cleanupDeletedFiles(
    int tenantId,
    int songId,
    List<dynamic> removed,
    List<dynamic> remaining,
  ) async {
    final used = remaining.map(_storageObjectName).toSet();
    final objects = removed.map(_storageObjectName).whereType<String>().toSet()
      ..removeAll(used);
    for (final object in objects) {
      try {
        await _supabase.storage
            .from(_SongFileServiceCore._bucketName)
            .remove(['songs/$tenantId/$songId/$object']);
      } catch (e, st) {
        ErrorReporter.report(e, st, where: 'SongFileService.deleteFileCleanup');
      }
    }
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

    final songResponse = await _supabase
        .from('songs')
        .select('files')
        .eq('id', songId)
        .eq('tenantId', _tenantId)
        .maybeSingle();

    if (songResponse == null) return;

    final existingFiles = (songResponse['files'] as List?) ?? [];
    final removedFiles = existingFiles
        .where((f) => _SongFileServiceCore._sameFile(f, url, storageName))
        .toList();
    if (removedFiles.isEmpty) return;

    final updatedFiles = existingFiles
        .where((f) => !_SongFileServiceCore._sameFile(f, url, storageName))
        .toList();

    final updated = await _supabase
        .from('songs')
        .update({
          'files': updatedFiles,
          'instrument_ids': SongFileService.instrumentIdsFromFiles(
            updatedFiles,
            mainGroupId: mainGroupId,
          ),
        })
        .eq('id', songId)
        .eq('tenantId', _tenantId)
        .select('id');
    if (updated.isEmpty) throw const SongNotFoundException();

    await _cleanupDeletedFiles(_tenantId, songId, removedFiles, updatedFiles);
  }

  /// Delete all files from a song
  Future<void> _deleteAllFiles({required int songId}) async {
    DemoGuard.checkCurrent('deleteSongFile'); // DEMO_GUARD
    if (_tenantId == null) {
      throw Exception(l10nWithoutContext.coreFlutterNoTenantSelected);
    }

    final songResponse = await _supabase
        .from('songs')
        .select('files')
        .eq('id', songId)
        .eq('tenantId', _tenantId)
        .maybeSingle();

    if (songResponse == null) return;

    final existingFiles = (songResponse['files'] as List?) ?? [];
    if (existingFiles.isEmpty) return;

    final updated = await _supabase
        .from('songs')
        .update({'files': []})
        .eq('id', songId)
        .eq('tenantId', _tenantId)
        .select('id');
    if (updated.isEmpty) throw const SongNotFoundException();

    await _cleanupDeletedFiles(_tenantId, songId, existingFiles, const []);
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
      if (_SongFileServiceCore._sameFile(existingFiles[i], url, storageName)) {
        existingFiles[i] = {
          ...existingFiles[i],
          'instrumentId': instrumentId,
          'note': note,
        };
        break;
      }
    }

    await _supabase.from('songs').update({
      'files': existingFiles,
      'instrument_ids': SongFileService.instrumentIdsFromFiles(
        existingFiles,
        mainGroupId: mainGroupId,
        excludeLyrics: true,
      ),
    }).eq('id', songId).eq('tenantId', _tenantId);
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
    final fileId = await _freeFileId(tenantId, songId, fileName);
    final storagePath = 'songs/$tenantId/$songId/$fileId';

    await _supabase.storage
        .from(_SongFileServiceCore._bucketName)
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(
            contentType: _getContentType(fileType),
            upsert: false,
          ),
        );

    final url = _supabase.storage
        .from(_SongFileServiceCore._bucketName)
        .getPublicUrl(storagePath);

    final songResponse = await _supabase
        .from('songs')
        .select('files')
        .eq('id', songId)
        .eq('tenantId', tenantId)
        .maybeSingle();

    if (songResponse == null) {
      try {
        await _supabase.storage
            .from(_SongFileServiceCore._bucketName)
            .remove([storagePath]);
      } catch (e, st) {
        ErrorReporter.report(e, st, where: 'song_file_service');
      }
      throw Exception(l10nWithoutContext.coreFlutterSongNotFound);
    }

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

    await _supabase.from('songs').update({
      'files': updatedFiles,
    }).eq('id', songId).eq('tenantId', tenantId);

    return url;
  }
}
