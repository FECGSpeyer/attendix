part of 'song_file_service.dart';

/// File rename and Sibelius content-replacement operations for [SongFileService].
mixin _SongFileSibeliusMixin on _SongFileServiceCore {
  /// Rename a file: only its display name (`fileName`) changes; the storage
  /// object keeps its `storageName`. Files without a storageName (very old
  /// uploads) are stored under their fileName, so they are not renamed.
  Future<void> renameFile({
    required int songId,
    required String url,
    required String storageName,
    required String fileName,
  }) =>
      _SongFileServiceCore._locked(
        _tenantId,
        songId,
        () => _renameFile(
          songId: songId,
          url: url,
          storageName: storageName,
          fileName: fileName,
        ),
      );

  /// Replace the content of a file (REDESIGN: a score saved in Sibelius).
  /// See [_replaceFileContent].
  Future<SongFile?> replaceFileContent({
    required int songId,
    required String url,
    String? storageName,
    Set<String> earlierNames = const {},
    String? newStorageName,
    required Uint8List bytes,
  }) =>
      _SongFileServiceCore._locked(
        _tenantId,
        songId,
        () => _replaceFileContent(
          songId: songId,
          url: url,
          storageName: storageName,
          earlierNames: earlierNames,
          newStorageName: newStorageName,
          bytes: bytes,
        ),
      );

  /// The new content gets a storage name no file of the song uses (a new
  /// URL, so no cached copy of the old content is shown); the entry keeps its
  /// place, name, part and note; the old object is removed afterwards.
  /// Returns the new entry, or null when the song has no such file any more
  /// (it was replaced or deleted meanwhile, nothing is written then).
  ///
  /// A try whose answer got lost (connection gone) may have gone through:
  /// [earlierNames] are the storage names such tries used, so the file is
  /// found under them too; [newStorageName] is the name for this try (a
  /// free one is taken when it is in use).
  Future<SongFile?> _replaceFileContent({
    required int songId,
    required String url,
    String? storageName,
    Set<String> earlierNames = const {},
    String? newStorageName,
    required Uint8List bytes,
  }) async {
    DemoGuard.checkCurrent('uploadSongFile'); // DEMO_GUARD
    final tenantId = _tenantId;
    if (tenantId == null) {
      throw Exception(l10nWithoutContext.coreFlutterNoTenantSelected);
    }

    final songResponse = await _supabase
        .from('songs')
        .select('files')
        .eq('id', songId)
        .eq('tenantId', tenantId)
        .maybeSingle();
    if (songResponse == null) throw const SongNotFoundException();

    final files = [
      for (final f in (songResponse['files'] as List?) ?? const [])
        songFileJson(f),
    ];
    final index = files.indexWhere(
      (f) =>
          _SongFileServiceCore._sameFile(f, url, storageName) ||
          earlierNames.contains(f['storageName']),
    );
    if (index < 0) return null;
    final old = files[index];
    final fileName = (old['fileName'] as String?) ?? '';
    final oldObject = ((old['storageName'] as String?)?.isNotEmpty ?? false)
        ? old['storageName'] as String
        : fileName;

    final taken = <Object?>{
      for (final f in files) ...[f['storageName'], f['fileName']],
    };
    // Type of the stored object: the display name may have been renamed
    // without its extension ("Ablauf v1.2").
    final typedName = SongFileService.withStoredExtension(fileName, oldObject);
    final fileId = newStorageName != null &&
            newStorageName.isNotEmpty &&
            !taken.contains(newStorageName)
        ? newStorageName
        : SongFileService.freshStorageName(typedName, taken);
    final storagePath = 'songs/$tenantId/$songId/$fileId';
    final dot = typedName.lastIndexOf('.');
    final extension = dot > 0 ? typedName.substring(dot + 1).toLowerCase() : '';

    await _supabase.storage
        .from(_SongFileServiceCore._bucketName)
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(
            contentType: _getContentType(extension),
            upsert: false,
          ),
        );

    final newUrl = _supabase.storage
        .from(_SongFileServiceCore._bucketName)
        .getPublicUrl(storagePath);
    files[index] = {...old, 'storageName': fileId, 'url': newUrl};
    try {
      // Same parts as before, so instrument_ids stay as they are.
      await _supabase.from('songs').update({
        'files': files,
      }).eq('id', songId).eq('tenantId', tenantId);
    } catch (_) {
      // The answer may have got lost although the list was written: the new
      // object is removed only when no entry points to it (when that cannot
      // be checked, e.g. offline, it stays; an unused object is harmless).
      try {
        final check = await _supabase
            .from('songs')
            .select('files')
            .eq('id', songId)
            .eq('tenantId', tenantId)
            .maybeSingle();
        final used = ((check?['files'] as List?) ?? const [])
            .any((f) => f is Map && f['storageName'] == fileId);
        if (!used) {
          await _supabase.storage
              .from(_SongFileServiceCore._bucketName)
              .remove([storagePath]);
        }
      } catch (e) {
        debugPrint('[SongFileService] new object kept: $e');
      }
      rethrow;
    }

    if (oldObject.isNotEmpty) {
      try {
        await _supabase.storage
            .from(_SongFileServiceCore._bucketName)
            .remove(['songs/$tenantId/$songId/$oldObject']);
      } catch (_) {
        // The entry already points to the new content; a leftover object
        // is harmless.
      }
    }
    return SongFile(
      storageName: fileId,
      fileName: fileName,
      fileType: (old['fileType'] as String?) ?? '',
      url: newUrl,
      instrumentId: (old['instrumentId'] as num?)?.toInt(),
      note: old['note'] as String?,
    );
  }

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
        existingFiles[i] = {...existingFiles[i], 'fileName': fileName.trim()};
        break;
      }
    }

    await _supabase.from('songs').update({
      'files': existingFiles,
    }).eq('id', songId).eq('tenantId', _tenantId);
  }
}
