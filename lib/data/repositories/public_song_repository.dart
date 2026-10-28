import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/instrument/instrument.dart';
import '../models/song/song.dart';
import '../models/song/song_additional_field.dart';
import '../models/tenant/tenant.dart';
import 'base_repository.dart';
import 'song_repository.dart';

/// Provider for the public (no login) song share repository
final publicSongRepositoryProvider = Provider<PublicSongRepository>((ref) {
  return PublicSongRepository(ref);
});

/// Tenant resolved from a public song sharing link.
class SharedSongTenant {
  const SharedSongTenant({
    required this.tenant,
    this.additionalFields = const [],
  });

  final Tenant tenant;
  final List<SongAdditionalField> additionalFields;

  int get id => tenant.id!;
}

/// Read-only access for the public song share pages
/// (`https://attendix.de/<song_sharing_id>[/<songId>]`, Ionic `:songSharingId`).
///
/// There is no logged-in tenant here, so this repository is not
/// [TenantAwareRepository]. Every query is restricted to the tenant id that
/// was resolved from the (unguessable) `song_sharing_id`.
class PublicSongRepository extends BaseRepository {
  PublicSongRepository(super.ref);

  /// Resolve the tenant of a sharing id (`tenants` has no tenantId column,
  /// it is selected by its `song_sharing_id`).
  Future<SharedSongTenant?> getTenantBySongSharingId(String sharingId) async {
    if (sharingId.isEmpty) return null;
    try {
      final response = await supabase
          .from('tenants')
          .select('*')
          .eq('song_sharing_id', sharingId)
          .maybeSingle();
      if (response == null) return null;
      return SharedSongTenant(
        tenant: Tenant.fromJson(response),
        additionalFields: SongAdditionalField.listFromJson(
          response['song_additional_fields'],
        ),
      );
    } catch (e, stack) {
      handleError(e, stack, 'getTenantBySongSharingId');
      rethrow;
    }
  }

  /// All songs of the shared tenant (paginated like [SongRepository.getSongs]).
  Future<List<Song>> getSongs(int tenantId) async {
    try {
      const pageSize = 1000;
      final songs = <Song>[];
      for (var from = 0;; from += pageSize) {
        final response = await supabase
            .from('songs')
            .select('*')
            .eq('tenantId', tenantId)
            .order('number', ascending: true)
            .order('id', ascending: true)
            .range(from, from + pageSize - 1);
        final page = (response as List)
            .map((e) => Song.fromJson(e as Map<String, dynamic>))
            .toList();
        songs.addAll(page);
        if (page.length < pageSize) break;
      }
      return songs;
    } catch (e, stack) {
      handleError(e, stack, 'getSongs');
      rethrow;
    }
  }

  /// One song of the shared tenant
  Future<Song?> getSong(int songId, int tenantId) async {
    try {
      final response = await supabase
          .from('songs')
          .select('*')
          .eq('id', songId)
          .eq('tenantId', tenantId)
          .maybeSingle();
      if (response == null) return null;
      return sortSongFiles(Song.fromJson(response));
    } catch (e, stack) {
      handleError(e, stack, 'getSong');
      rethrow;
    }
  }

  /// Song categories of the shared tenant
  Future<List<SongCategory>> getSongCategories(int tenantId) async {
    try {
      final response = await supabase
          .from('song_categories')
          .select('*')
          .eq('tenant_id', tenantId)
          .order('index');
      return (response as List)
          .map((e) => SongCategory.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getSongCategories');
      rethrow;
    }
  }

  /// Groups (instruments) of the shared tenant
  Future<List<Group>> getGroups(int tenantId) async {
    try {
      final response = await supabase
          .from('instruments')
          .select('*')
          .eq('tenantId', tenantId)
          .order('category')
          .order('name');
      return (response as List)
          .map((e) => Group.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getGroups');
      rethrow;
    }
  }

  /// Group categories of the shared tenant
  Future<List<GroupCategory>> getGroupCategories(int tenantId) async {
    try {
      final response = await supabase
          .from('group_categories')
          .select('*')
          .eq('tenant_id', tenantId)
          .order('name');
      return (response as List)
          .map((e) => GroupCategory.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getGroupCategories');
      rethrow;
    }
  }

  /// Current (upcoming) songs of the shared tenant
  Future<List<CurrentSongsGroup>> getCurrentSongs(int tenantId) async {
    try {
      return await loadCurrentSongsForTenant(supabase, tenantId);
    } catch (e, stack) {
      handleError(e, stack, 'getCurrentSongs');
      rethrow;
    }
  }
}
