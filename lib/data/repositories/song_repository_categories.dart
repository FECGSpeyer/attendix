part of 'song_repository.dart';

/// Song categories and collections (Sammlungen) operations for [SongRepository].
mixin _SongCategoriesMixin on _SongRepositoryCore {
  // ==========================================================================
  // Song Categories
  // ==========================================================================

  /// Get song categories of the effective song tenant
  Future<List<SongCategory>> getSongCategories() async {
    try {
      final response = await supabase
          .from('song_categories')
          .select('*')
          .eq('tenant_id', songTenantId)
          .order('index', ascending: true);

      return (response as List)
          .map((e) => SongCategory.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getSongCategories');
      rethrow;
    }
  }

  /// Create a new song category
  Future<SongCategory> addSongCategory({
    required String name,
    required int index,
  }) async {
    ensureNotDemo('addSongCategory'); // DEMO_GUARD
    try {
      final response = await supabase
          .from('song_categories')
          .insert({
            'tenant_id': songTenantId,
            'name': name,
            'index': index,
          })
          .select()
          .single();

      return SongCategory.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'addSongCategory');
      rethrow;
    }
  }

  /// Update a song category
  Future<void> updateSongCategory(String id, Map<String, dynamic> updates) async {
    ensureNotDemo('updateSongCategory'); // DEMO_GUARD
    try {
      await supabase
          .from('song_categories')
          .update(updates)
          .eq('id', id)
          .eq('tenant_id', songTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'updateSongCategory');
      rethrow;
    }
  }

  /// Delete a song category (Ionic removeSongCategory: delete only).
  /// PARITY_B (D8): the remaining categories are NOT renumbered.
  Future<void> deleteSongCategory(String id) async {
    ensureNotDemo('deleteSongCategory'); // DEMO_GUARD
    try {
      await supabase
          .from('song_categories')
          .delete()
          .eq('id', id)
          .eq('tenant_id', songTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'deleteSongCategory');
      rethrow;
    }
  }

  // ==========================================================================
  // Sammlungen (song_collections, supabase/sql/song_collections.sql)
  // ==========================================================================

  /// Sammlungen of the effective song tenant in their order; null when the
  /// database has none yet (then the app works without Sammlungen).
  Future<List<SongCollection>?> getSongCollections() async {
    try {
      final response = await supabase
          .from('song_collections')
          .select('*')
          .eq('tenant_id', songTenantId)
          .order('index', ascending: true)
          .order('id', ascending: true);

      return (response as List)
          .map((e) => SongCollection.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      if (SongRepository.isMissingCollectionsSchema(e)) return null;
      handleError(e, stack, 'getSongCollections');
      rethrow;
    }
  }

  /// Creates a Sammlung in the effective song tenant.
  Future<SongCollection> addSongCollection(SongCollection collection) async {
    ensureNotDemo('addSongCollection'); // DEMO_GUARD
    try {
      final response = await supabase
          .from('song_collections')
          .insert({
            'tenant_id': songTenantId,
            'name': collection.name,
            'prefix': collection.prefix,
            'visibility': collection.visibility,
            'group_ids': collection.groupIds,
            'plannable': collection.plannable,
            'public_link': collection.publicLink,
            'index': collection.index,
          })
          .select()
          .single();
      return SongCollection.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'addSongCollection');
      rethrow;
    }
  }

  /// Changes columns of a Sammlung (name, prefix, visibility, group_ids,
  /// plannable, public_link, index).
  Future<void> updateSongCollection(int id, Map<String, dynamic> updates) async {
    ensureNotDemo('updateSongCollection'); // DEMO_GUARD
    try {
      await supabase
          .from('song_collections')
          .update(updates)
          .eq('id', id)
          .eq('tenant_id', songTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'updateSongCollection');
      rethrow;
    }
  }

  /// Changes the prefix of Sammlung [id] and of its Werke that still carry
  /// the old one, in one transaction (function `rename_song_collection_prefix`
  /// in song_collections.sql, checks the tenant). Throws a
  /// [RepositoryException] with code 23505 when a number would be taken
  /// twice; then nothing changed.
  Future<void> renameSongCollectionPrefix(int id, String prefix) async {
    ensureNotDemo('renameSongCollectionPrefix'); // DEMO_GUARD
    try {
      await supabase.rpc('rename_song_collection_prefix', params: {
        'p_collection_id': id,
        'p_tenant_id': songTenantId,
        'p_prefix': prefix,
      });
    } catch (e, stack) {
      handleError(e, stack, 'renameSongCollectionPrefix');
      rethrow;
    }
  }

  /// Ids of the Werke in Sammlung [collectionId], from the server only (no
  /// offline copy): a failed load throws. For deleting a Sammlung.
  Future<List<int>> getSongIdsInCollection(int collectionId) async {
    final tenantId = songTenantId;
    try {
      final ids = <int>[];
      for (var from = 0;; from += _SongRepositoryCore._pageSize) {
        final rows = await supabase
            .from('songs')
            .select('id')
            .eq('tenantId', tenantId)
            .eq('collection_id', collectionId)
            .order('id', ascending: true)
            .range(from, from + _SongRepositoryCore._pageSize - 1) as List;
        ids.addAll(rows.map((r) => (r as Map<String, dynamic>)['id'] as int));
        if (rows.length < _SongRepositoryCore._pageSize) break;
      }
      return ids;
    } catch (e, stack) {
      handleError(e, stack, 'getSongIdsInCollection');
      rethrow;
    }
  }

  /// Deletes a Sammlung; its Werke fall back to "Repertoire" (on delete
  /// set null).
  Future<void> deleteSongCollection(int id) async {
    ensureNotDemo('deleteSongCollection'); // DEMO_GUARD
    try {
      await supabase
          .from('song_collections')
          .delete()
          .eq('id', id)
          .eq('tenant_id', songTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'deleteSongCollection');
      rethrow;
    }
  }

  /// Puts Werk [id] into Sammlung [collectionId] (null = Repertoire),
  /// with a new [prefix] and [number] when given.
  Future<void> moveSongToCollection(
    int id,
    int? collectionId, {
    String? prefix,
    int? number,
  }) async {
    ensureNotDemo('moveSongToCollection'); // DEMO_GUARD
    try {
      await supabase
          .from('songs')
          .update({
            'collection_id': collectionId,
            if (prefix != null) 'prefix': prefix,
            if (number != null) 'number': number,
          })
          .eq('id', id)
          .eq('tenantId', songTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'moveSongToCollection');
      rethrow;
    }
  }
}
