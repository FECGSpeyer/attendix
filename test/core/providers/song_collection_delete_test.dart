import 'package:attendix/core/providers/song_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
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

  @override
  Future<List<Song>> getSongs() async => const [
        Song(id: 1, name: 'Eins', collectionId: 3),
        Song(id: 2, name: 'Zwei', collectionId: 3),
        Song(id: 3, name: 'Drei', collectionId: 4),
        Song(id: 4, name: 'Vier'),
        Song(id: 5, name: 'Fünf', collectionId: 3),
      ];

  @override
  Future<void> deleteSong(int id) async {
    if (failing.contains(id)) throw Exception('offline');
    deletedSongs.add(id);
  }

  @override
  Future<void> deleteSongCollection(int id) async => deletedCollections.add(id);
}

void main() {
  test('a Sammlung with its Werke: only its own; kept while one Werk is left', () async {
    late _FakeSongRepo repo;
    final container = ProviderContainer(overrides: [
      currentTenantIdProvider.overrideWithValue(7),
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

    repo.failing.clear();
    final done = await notifier.deleteWithWorks(3);
    expect(done.ok, isTrue);
    expect(repo.deletedSongs, {1, 2, 5});
    expect(repo.deletedCollections, [3]);
  });
}
