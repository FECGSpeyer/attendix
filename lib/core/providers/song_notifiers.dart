part of 'song_providers.dart';

// ============================================================================
// Mutations
// ============================================================================

/// Notifier for song mutations (CRUD operations)
class SongNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  SongRepository get _repo => ref.read(songRepositoryWithTenantProvider);

  Future<Song?> createSong(Song song) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repo.createSong(song);
      state = const AsyncValue.data(null);
      ref.invalidate(songsProvider);
      return result;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  Future<Song?> updateSong(int id, Map<String, dynamic> updates) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repo.updateSong(id, updates);
      state = const AsyncValue.data(null);
      ref.invalidate(songsProvider);
      ref.invalidate(songByIdProvider(id));
      return result;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  Future<bool> deleteSong(int id) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deleteSong(id);
      state = const AsyncValue.data(null);
      ref.invalidate(songsProvider);
      ref.invalidate(currentSongsProvider);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<SongHistory?> addSongHistory({
    required int songId,
    required String date,
    String? conductorName,
    int? attendanceId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repo.addSongHistory(
        songId: songId,
        date: date,
        conductorName: conductorName,
        attendanceId: attendanceId,
      );
      state = const AsyncValue.data(null);
      ref.invalidate(songHistoryProvider(songId));
      ref.invalidate(songHistoryProvider(null));
      ref.invalidate(songsProvider);
      return result;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }
}

final songNotifierProvider =
    NotifierProvider<SongNotifier, AsyncValue<void>>(() {
  return SongNotifier();
});

/// Notifier for song category mutations (CRUD operations)
class SongCategoryNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  SongRepository get _repo => ref.read(songRepositoryWithTenantProvider);

  /// Add a new song category
  ///
  /// [stillValid] (optional) is asked right before the write; when it says
  /// no (e.g. the group was switched meanwhile) nothing is written.
  Future<SongCategory?> add(String name, {bool Function()? stillValid}) async {
    final repo = _repo; // SOL_FIX4: bind the tenant repository before the first await.
    state = const AsyncValue.loading();
    try {
      final categories = await repo.getSongCategories();
      if (stillValid != null && !stillValid()) {
        state = const AsyncValue.data(null);
        return null;
      }
      final result = await repo.addSongCategory(
        name: name,
        // Sol review: deleting no longer renumbers, so continue after the
        // highest index instead of using the count (avoids duplicates).
        index: categories.fold<int>(
                -1, (m, c) => c.index > m ? c.index : m) +
            1,
      );
      state = const AsyncValue.data(null);
      ref.invalidate(songCategoriesProvider);
      return result;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  /// Update a song category name
  Future<bool> update(String id, String name) async {
    state = const AsyncValue.loading();
    try {
      await _repo.updateSongCategory(id, {'name': name});
      state = const AsyncValue.data(null);
      ref.invalidate(songCategoriesProvider);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  /// Delete a song category
  Future<bool> delete(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deleteSongCategory(id);
      state = const AsyncValue.data(null);
      ref.invalidate(songCategoriesProvider);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  /// Reorder categories
  ///
  /// [stillValid] (optional) is asked once before the first write; when it
  /// says no nothing is written. Once started, all indexes are written
  /// through the repository bound to the origin group, so a group switch
  /// meanwhile never leaves a half-saved order (and writes nothing into
  /// the new group).
  Future<bool> reorder(List<SongCategory> categories, {bool Function()? stillValid}) async {
    state = const AsyncValue.loading();
    // SOL_FIX3: bind the per-tenant repository once for the whole loop.
    final repo = _repo;
    if (stillValid != null && !stillValid()) {
      state = const AsyncValue.data(null);
      return false;
    }
    try {
      for (int i = 0; i < categories.length; i++) {
        final category = categories[i];
        if (category.id != null) {
          await repo.updateSongCategory(category.id!, {'index': i});
        }
      }
      state = const AsyncValue.data(null);
      ref.invalidate(songCategoriesProvider);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }
}

final songCategoryNotifierProvider =
    NotifierProvider<SongCategoryNotifier, AsyncValue<void>>(() {
  return SongCategoryNotifier();
});

/// Mutations of the Sammlungen (song_collections) and of the Sammlung of
/// Werke. Every call binds the tenant repository before its first await.
class SongCollectionNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  SongRepository get _repo => ref.read(songRepositoryWithTenantProvider);

  /// Adds a Sammlung after the last one; null on failure.
  Future<SongCollection?> add(SongCollection collection) async {
    final repo = _repo;
    state = const AsyncValue.loading();
    try {
      final existing = await repo.getSongCollections() ?? const <SongCollection>[];
      final index = existing.fold<int>(-1, (m, c) => c.index > m ? c.index : m) + 1;
      final result = await repo.addSongCollection(collection.copyWith(index: index));
      state = const AsyncValue.data(null);
      ref.invalidate(songCollectionsProvider);
      return result;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  /// Changes columns of Sammlung [id].
  Future<bool> update(int id, Map<String, dynamic> updates) async {
    final repo = _repo;
    state = const AsyncValue.loading();
    try {
      await repo.updateSongCollection(id, updates);
      state = const AsyncValue.data(null);
      ref.invalidate(songCollectionsProvider);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  /// Deletes Sammlung [id]; its Werke go back to "Repertoire".
  Future<bool> delete(int id) async {
    final repo = _repo;
    state = const AsyncValue.loading();
    try {
      await repo.deleteSongCollection(id);
      state = const AsyncValue.data(null);
      ref.invalidate(songCollectionsProvider);
      ref.invalidate(songsProvider);
      ref.read(songCollectionChangesProvider.notifier).state++;
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  /// Deletes Sammlung [id] together with its Werke and their files (after
  /// a test import: hundreds of Werke). The Werke are read from the server, four
  /// deleted at a time; [onProgress] after each. The Sammlung goes only when
  /// a fresh read finds no Werk left in it (one added meanwhile is deleted in
  /// another round): those that failed stay in it. [ok] = the Sammlung is
  /// deleted; [failed] Werke could not be deleted.
  Future<({bool ok, int deleted, int failed})> deleteWithWorks(
    int id, {
    void Function(int done, int total)? onProgress,
  }) async {
    final repo = _repo;
    state = const AsyncValue.loading();
    var deleted = 0;
    var failed = 0;
    final bulk = ref.read(songsBulkDeleteRunningProvider.notifier)..state = true;
    try {
      // From the server only: a cached list would say nothing about what is left.
      Future<List<int>> left() => repo.getSongIdsInCollection(id);
      var total = 0;
      for (var round = 0; round < 3; round++) {
        final queue = await left();
        if (queue.isEmpty) break;
        total += queue.length;
        Future<void> worker() async {
          while (queue.isNotEmpty) {
            final songId = queue.removeLast();
            try {
              await repo.deleteSong(songId);
              deleted++;
            } catch (_) {
              failed++;
            }
            onProgress?.call(deleted + failed, total);
          }
        }

        await Future.wait([for (var i = 0; i < 4; i++) worker()]);
        if (failed > 0) {
          state = const AsyncValue.data(null);
          return (ok: false, deleted: deleted, failed: failed);
        }
      }
      final rest = await left();
      if (rest.isNotEmpty) {
        state = const AsyncValue.data(null);
        return (ok: false, deleted: deleted, failed: rest.length);
      }
      await repo.deleteSongCollection(id);
      state = const AsyncValue.data(null);
      return (ok: true, deleted: deleted, failed: 0);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return (ok: false, deleted: deleted, failed: failed);
    } finally {
      bulk.state = false;
      ref.invalidate(songCollectionsProvider);
      ref.invalidate(songsProvider);
      ref.invalidate(currentSongsProvider);
      ref.read(songCollectionChangesProvider.notifier).state++;
    }
  }

  /// Changes the prefix of Sammlung [id] and of its Werke with the old one,
  /// all or nothing. [clash] when a number would then be taken twice.
  Future<({bool ok, bool clash})> renamePrefix(int id, String prefix) async {
    final repo = _repo;
    state = const AsyncValue.loading();
    try {
      await repo.renameSongCollectionPrefix(id, prefix);
      state = const AsyncValue.data(null);
      return (ok: true, clash: false);
    } on RepositoryException catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return (ok: false, clash: e.code == '23505');
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return (ok: false, clash: false);
    } finally {
      ref.invalidate(songCollectionsProvider);
      ref.invalidate(songsProvider);
      // Every loaded Werk (details, edit forms) takes the new prefix.
      ref.invalidate(songByIdProvider);
      ref.read(songCollectionChangesProvider.notifier).state++;
    }
  }

  /// Stores the order of [collections] (index 0..n).
  Future<bool> reorder(List<SongCollection> collections) async {
    final repo = _repo;
    state = const AsyncValue.loading();
    try {
      for (var i = 0; i < collections.length; i++) {
        final id = collections[i].id;
        if (id != null && collections[i].index != i) {
          await repo.updateSongCollection(id, {'index': i});
        }
      }
      state = const AsyncValue.data(null);
      ref.invalidate(songCollectionsProvider);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      ref.invalidate(songCollectionsProvider);
      return false;
    }
  }

  /// Moves Werke into Sammlung [collectionId] (null = Repertoire), each
  /// with its new prefix and number when it changes ([moves]: song id →
  /// (prefix, number), both null = keep). Returns false when one failed
  /// (the ones before it stay moved).
  Future<bool> move(int? collectionId, Map<int, ({String? prefix, int? number})> moves) async {
    final repo = _repo;
    state = const AsyncValue.loading();
    try {
      for (final entry in moves.entries) {
        await repo.moveSongToCollection(
          entry.key,
          collectionId,
          prefix: entry.value.prefix,
          number: entry.value.number,
        );
      }
      state = const AsyncValue.data(null);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    } finally {
      ref.invalidate(songsProvider);
      for (final id in moves.keys) {
        ref.invalidate(songByIdProvider(id));
      }
      ref.read(songCollectionChangesProvider.notifier).state++;
    }
  }
}

final songCollectionNotifierProvider =
    NotifierProvider<SongCollectionNotifier, AsyncValue<void>>(SongCollectionNotifier.new);
