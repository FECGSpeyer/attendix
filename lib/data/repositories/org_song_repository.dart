import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/song_file_service.dart' show SongFileService, songFileJson;
import '../../core/utils/song_copy.dart';
import '../../l10n/l10n.dart';
import '../models/instrument/instrument.dart';
import '../models/song/org_song.dart';
import '../models/song/song.dart';
import 'base_repository.dart';

final orgSongRepositoryProvider = Provider<OrgSongRepository>((ref) {
  return OrgSongRepository(ref);
});

/// Organisation-wide Werk search and copy (Ionic 4.17.13, `SongService`
/// `searchOrgSongs` / `copyOrgSong` / `ensureSongCategories`).
///
/// Scoping:
/// - The search reads only via the `search_org_songs` RPC with the current
///   tenant (the RPC checks admin/responsible and the organisation).
/// - Organisation instances are read via `tenant_group_tenants` of the
///   current tenant's organisation.
/// - Every read/write of the target library filters by that library's
///   `tenantId` (the instance whose Werkbibliothek is used, like Ionic), and
///   copies are only allowed into libraries of the current organisation.
class OrgSongRepository extends BaseRepository with TenantAwareRepository {
  OrgSongRepository(super.ref);

  static const String _bucket = 'songs';
  static const String _publicPrefix = '/storage/v1/object/public/songs/';
  static const int _pageSize = 1000;

  /// Ionic `searchOrgSongs`: Werke of the other instances of the organisation.
  Future<List<OrgSongResult>> searchOrgSongs(
    String query, {
    List<int>? tenantIds,
    bool onlyWithFiles = false,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final data = await supabase.rpc(
        'search_org_songs',
        params: {
          'p_tenant_id': currentTenantId,
          'p_query': query,
          'p_tenant_ids': (tenantIds == null || tenantIds.isEmpty) ? null : tenantIds,
          'p_only_with_files': onlyWithFiles,
          'p_limit': limit,
          'p_offset': offset,
        },
      );
      return ((data as List?) ?? const [])
          .map((e) => OrgSongResult.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'searchOrgSongs');
      rethrow;
    }
  }

  /// All instances of the current tenant's organisation (incl. the current
  /// one) with their Werk library settings.
  Future<List<OrgSongTenant>> getOrgTenants() async {
    try {
      final link =
          await supabase
              .from('tenant_group_tenants')
              .select('tenant_group')
              .eq('tenant_id', currentTenantId)
              .limit(1)
              .maybeSingle();
      final orgId = link?['tenant_group'] as int?;
      if (orgId == null) return const [];
      final response = await supabase
          .from('tenant_group_tenants')
          .select('tenant:tenant_id(id, shortName, longName, song_source_tenant_id, song_additional_fields)')
          .eq('tenant_group', orgId);
      return (response as List)
          .where((e) => e['tenant'] != null)
          .map((e) => OrgSongTenant.fromJson(Map<String, dynamic>.from(e['tenant'] as Map)))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getOrgTenants');
      rethrow;
    }
  }

  /// Raw `songs` rows of a target library (Ionic `songSvc.getSongs(libraryId)`);
  /// raw so columns without a [Song] field (e.g. `beamer_file`) stay visible.
  Future<List<Map<String, dynamic>>> getLibrarySongRows(int libraryId) async {
    try {
      final songs = <Map<String, dynamic>>[];
      for (var from = 0; ; from += _pageSize) {
        final page = await supabase
            .from('songs')
            .select('*')
            .eq('tenantId', libraryId)
            .order('number')
            .order('id')
            .range(from, from + _pageSize - 1);
        final rows = page as List;
        songs.addAll(rows.map((e) => Map<String, dynamic>.from(e as Map)));
        if (rows.length < _pageSize) break;
      }
      return songs;
    } catch (e, stack) {
      handleError(e, stack, 'getLibrarySongRows');
      rethrow;
    }
  }

  /// Groups of a target library (Ionic `db.getGroups(libraryId)`).
  Future<List<Group>> getLibraryGroups(int libraryId) async {
    try {
      final response = await supabase.from('instruments').select('*').eq('tenantId', libraryId).order('name');
      return (response as List).map((e) => Group.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e, stack) {
      handleError(e, stack, 'getLibraryGroups');
      rethrow;
    }
  }

  /// Ionic `ensureSongCategories`: ids of the categories with these names in
  /// the library; missing ones are created.
  Future<List<String>> ensureSongCategories(int libraryId, List<String> names) async {
    ensureNotDemo('ensureSongCategories'); // DEMO_GUARD
    try {
      await _ensureOrgLibrary(libraryId);
      final response = await supabase.from('song_categories').select('*').eq('tenant_id', libraryId).order('index');
      final existing = (response as List).map((e) => SongCategory.fromJson(e as Map<String, dynamic>)).toList();
      var nextIndex = existing.fold<int>(-1, (m, c) => c.index > m ? c.index : m) + 1;
      final ids = <String>[];
      for (final name in names) {
        final match = existing.where((c) => c.name.trim().toLowerCase() == name.trim().toLowerCase()).firstOrNull;
        if (match?.id != null) {
          ids.add(match!.id!);
          continue;
        }
        final created = SongCategory.fromJson(
          await supabase
              .from('song_categories')
              .insert({'name': name, 'index': nextIndex++, 'tenant_id': libraryId})
              .select()
              .single(),
        );
        existing.add(created);
        ids.add(created.id!);
      }
      return ids;
    } catch (e, stack) {
      handleError(e, stack, 'ensureSongCategories');
      rethrow;
    }
  }

  /// Ionic `copyOrgSong`: copies a Werk found in another instance into the
  /// target library, as a new Werk or into an existing one. Only the given
  /// fields and files are taken over. If copying the files fails, everything
  /// uploaded in this run is removed again, and a newly created Werk too.
  Future<Song> copyOrgSong(OrgSongCopyRequest request, {void Function(int current, int total)? onProgress}) async {
    ensureNotDemo('copyOrgSong'); // DEMO_GUARD
    final libraryId = request.targetLibraryId;
    final source = request.source;
    await _ensureOrgLibrary(libraryId);
    final copiedFrom = copiedFromOf(source, DateTime.now()).toJson();

    Song song;
    Map<String, dynamic>? songRow;
    if (request.existingSongId != null) {
      final row =
          await supabase
              .from('songs')
              .select('*')
              .eq('id', request.existingSongId!)
              .eq('tenantId', libraryId)
              .maybeSingle();
      if (row == null) throw Exception(l10nWithoutContext.orgSongsTargetMissing);
      songRow = row;
      final update = <String, dynamic>{...request.fields};
      final extra = request.fields['additional_fields'];
      if (extra is Map) {
        update['additional_fields'] = {
          ...Map<String, dynamic>.from((row['additional_fields'] as Map?) ?? const {}),
          ...Map<String, dynamic>.from(extra),
        };
      }
      if (row['copied_from'] == null) update['copied_from'] = copiedFrom;
      if (update.isNotEmpty) {
        songRow =
            await supabase
                .from('songs')
                .update(update)
                .eq('id', request.existingSongId!)
                .eq('tenantId', libraryId)
                .select()
                .single();
      }
      song = Song.fromJson(songRow);
    } else {
      songRow =
          await supabase
              .from('songs')
              .insert({
                'name': source.name,
                'number': source.number,
                'prefix': source.prefix,
                'withChoir': false,
                'withSolo': false,
                'instrument_ids': <int>[],
                'category': null,
                'category_ids': <String>[],
                ...request.fields,
                'copied_from': copiedFrom,
                'tenantId': libraryId,
              })
              .select()
              .single();
      song = Song.fromJson(songRow);
    }

    if (request.files.isEmpty) return song;

    final songId = song.id!;
    final uploadedPaths = <String>[];
    final newFiles = <Map<String, dynamic>>[];
    final existingFiles = ((songRow['files'] as List?) ?? const []);
    final taken = <Object?>{
      for (final f in existingFiles)
        if (f is Map) ...[f['storageName'], f['fileName']],
    };
    try {
      for (var i = 0; i < request.files.length; i++) {
        onProgress?.call(i + 1, request.files.length);
        final entry = request.files[i];
        final file = entry.file;
        final sourcePath = storagePathFromPublicUrl(file.url);
        if (sourcePath == null) {
          throw Exception(l10nWithoutContext.songsFlutterFileDownloadFailed(file.fileName));
        }
        final bytes = await supabase.storage.from(_bucket).download(sourcePath);
        final fileId = SongFileService.freeStorageName(file.fileName, taken);
        taken.add(fileId);
        final filePath = 'songs/$libraryId/$songId/$fileId';
        await supabase.storage
            .from(_bucket)
            .uploadBinary(
              filePath,
              bytes,
              fileOptions: FileOptions(upsert: true, contentType: file.fileType.isEmpty ? null : file.fileType),
            );
        uploadedPaths.add(filePath);
        newFiles.add({
          'storageName': fileId,
          'fileName': file.fileName,
          'fileType': file.fileType,
          'url': supabase.storage.from(_bucket).getPublicUrl(filePath),
          'instrumentId': entry.instrumentId,
          if (file.note != null) 'note': file.note,
        });
      }

      final allFiles = [...existingFiles, ...newFiles].map(songFileJson).toList();
      final instrumentIds = instrumentIdsFromCopiedFiles(
        allFiles.map((f) => (f['instrumentId'] as num?)?.toInt()),
        mainGroupId: request.mainGroupId,
      );
      final updated =
          await supabase
              .from('songs')
              .update({'files': allFiles, 'instrument_ids': instrumentIds})
              .eq('id', songId)
              .eq('tenantId', libraryId)
              .select()
              .single();
      return Song.fromJson(updated);
    } catch (e, stack) {
      if (uploadedPaths.isNotEmpty) {
        try {
          await supabase.storage.from(_bucket).remove(uploadedPaths);
        } catch (_) {}
      }
      if (request.existingSongId == null) {
        try {
          await supabase.from('songs').delete().eq('id', songId).eq('tenantId', libraryId);
        } catch (_) {}
      }
      handleError(e, stack, 'copyOrgSong');
      rethrow;
    }
  }

  /// Copies only go into Werk libraries of the current organisation.
  Future<void> _ensureOrgLibrary(int libraryId) async {
    final tenants = await getOrgTenants();
    final allowed = tenants.map((t) => t.libraryId).toSet();
    if (!allowed.contains(libraryId)) {
      throw RepositoryException(message: 'Target library is not part of the organisation', operation: 'copyOrgSong');
    }
  }

  /// Object path in the `songs` bucket of a public file URL (Ionic
  /// `file.url.split('/storage/v1/object/public/songs/')[1]`).
  static String? storagePathFromPublicUrl(String url) {
    final idx = url.indexOf(_publicPrefix);
    if (idx < 0) return null;
    final path = url.substring(idx + _publicPrefix.length).split('?').first;
    return path.isEmpty ? null : Uri.decodeComponent(path);
  }
}
