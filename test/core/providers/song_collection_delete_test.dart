import 'package:attendix/core/providers/song_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/services/offline_queue_service.dart';
import 'package:attendix/data/models/song/song.dart';
import 'package:attendix/data/repositories/song_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the deletes instead of calling Supabase.
class _FakeSongRepo extends SongRepository {
  _FakeSongRepo(super.ref) {
    setTenantId(7);
  }

  final deletedSongs = <int>{};
  final deletedCollections = <int>[];
  final failing = <int>{};
  final songs = [
    const Song(id: 1, name: 'Eins', collectionId: 3),
    const Song(id: 2, name: 'Zwei', collectionId: 3),
    const Song(id: 3, name: 'Drei', collectionId: 4),
    const Song(id: 4, name: 'Vier'),
    const Song(id: 5, name: 'Fünf', collectionId: 3),
  ];

  /// Added to the Sammlung on the next delete (an import meanwhile).
  Song? addedMeanwhile;

  @override
  Future<List<Song>> getSongs() async => [for (final s in songs) if (!deletedSongs.contains(s.id)) s];

  @override
  Future<void> deleteSong(int id) async {
    if (failing.contains(id)) throw Exception('offline');
    deletedSongs.add(id);
    if (addedMeanwhile case final song?) {
      songs.add(song);
      addedMeanwhile = null;
    }
  }

  @override
  Future<void> deleteSongCollection(int id) async => deletedCollections.add(id);
}

void main() {
  test('a Sammlung with its Werke: only its own; kept while one Werk is left', () async {
    late _FakeSongRepo repo;
    final container = ProviderContainer(overrides: [
      currentTenantIdProvider.overrideWithValue(7),
      connectivityCheckProvider.overrideWithValue(() async => true),
      songRepositoryWithTenantProvider.overrideWith((ref) => repo = _FakeSongRepo(ref)),
    ]);
    addTearDown(container.dispose);
    final notifier = container.read(songCollectionNotifierProvider.notifier);
    container.read(songRepositoryWithTenantProvider);

    repo.failing.add(2);
    final progress = <(int, int)>[];
    final failed = await notifier.deleteWithWorks(3, onProgress: (done, total) => progress.add((done, total)));
    expect((failed.ok, failed.deleted, failed.failed), (false, 2, 1));
    expect(repo.deletedSongs, {1, 5});
    expect(repo.deletedCollections, isEmpty);
    expect(progress.last, (3, 3));

    // A Werk added meanwhile goes too, before the Sammlung.
    repo.failing.clear();
    repo.addedMeanwhile = const Song(id: 6, name: 'Sechs', collectionId: 3);
    final done = await notifier.deleteWithWorks(3);
    expect(done.ok, isTrue);
    expect(repo.deletedSongs, {1, 2, 5, 6});
    expect(repo.deletedCollections, [3]);
  });
}
