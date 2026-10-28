import 'package:attendix/core/providers/song_filter_providers.dart';
import 'package:attendix/core/providers/song_providers.dart';
import 'package:attendix/data/models/song/song.dart';
import 'package:attendix/data/models/song/song_additional_field.dart';
import 'package:attendix/data/models/song/song_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('enrichSongsWithHistory', () {
    final now = DateTime(2026, 5, 10, 12);
    final songs = [
      const Song(id: 1, name: 'A'),
      const Song(id: 2, name: 'B'),
      const Song(id: 3, name: 'C'),
    ];

    test('"Zuletzt gesungen" ignores future attendances', () {
      final history = [
        const SongHistory(songId: 1, date: '2026-06-01T10:00:00', conductorName: 'Future'),
        const SongHistory(songId: 1, date: '2026-05-20T10:00:00', conductorName: 'Soon'),
        const SongHistory(songId: 1, date: '2026-04-01T10:00:00', conductorName: 'Past'),
        const SongHistory(songId: 1, date: '2026-01-01T10:00:00', conductorName: 'Old'),
      ];
      final result = enrichSongsWithHistory(songs, history, now: now);
      final a = result.firstWhere((s) => s.id == 1);
      expect(a.lastSung, '2026-04-01T10:00:00');
      expect(a.conductor, 'Past');
      expect(a.nextPlanned, '2026-05-20T10:00:00');
    });

    test('today counts as sung, order of history does not matter', () {
      final history = [
        const SongHistory(songId: 2, date: '2026-03-01T10:00:00'),
        const SongHistory(songId: 2, date: '2026-05-10T18:00:00', otherConductor: 'Gast'),
      ];
      final b = enrichSongsWithHistory(songs, history, now: now)
          .firstWhere((s) => s.id == 2);
      expect(b.lastSung, '2026-05-10T18:00:00');
      expect(b.conductor, 'Gast');
      expect(b.nextPlanned, isNull);
    });

    test('only future entries: not sung yet but planned', () {
      final history = [const SongHistory(songId: 3, date: '2026-07-01T10:00:00')];
      final c = enrichSongsWithHistory(songs, history, now: now)
          .firstWhere((s) => s.id == 3);
      expect(c.lastSung, isNull);
      expect(c.conductor, isNull);
      expect(c.nextPlanned, '2026-07-01T10:00:00');
    });
  });

  group('applySongFilter', () {
    final songs = [
      const Song(id: 1, name: 'Halleluja', number: 3, withChoir: true, categoryIds: ['x']),
      const Song(id: 2, name: 'Marsch', number: 1, instrumentIds: [5], additionalFields: {'f': true}),
      const Song(id: 3, name: 'Choral', number: 2, withChoir: true, withSolo: true, instrumentIds: [6]),
    ];

    test('category segment and multi category filter use category_ids', () {
      expect(applySongFilter(songs, const SongFilter(category: 'x')).map((s) => s.id), [1]);
      expect(applySongFilter(songs, const SongFilter(categoryIds: ['y'])), isEmpty);
    });

    test('choir / solo toggles', () {
      expect(applySongFilter(songs, const SongFilter(withChoir: true)).map((s) => s.id), [3, 1]);
      expect(
        applySongFilter(songs, const SongFilter(withChoir: true, withSolo: true)).map((s) => s.id),
        [3],
      );
    });

    test('group and additional field filters', () {
      expect(applySongFilter(songs, const SongFilter(instrumentIds: [6])).map((s) => s.id), [3]);
      final fields = SongAdditionalField.listFromJson([
        {'id': 'f', 'name': 'Feld', 'type': 'boolean'},
      ]);
      expect(
        applySongFilter(songs, const SongFilter(fieldFilters: {'f': 'true'}), additionalFields: fields)
            .map((s) => s.id),
        [2],
      );
    });

    test('search matches name and number', () {
      expect(applySongFilter(songs, const SongFilter(), search: 'marsch').map((s) => s.id), [2]);
      expect(applySongFilter(songs, const SongFilter(), search: '3').map((s) => s.id), [1]);
    });
  });

  group('sortSongs', () {
    final songs = [
      const Song(id: 1, name: 'b', number: 2, lastSung: '2026-01-01'),
      const Song(id: 2, name: 'a', number: 1),
      const Song(id: 3, name: 'c', number: 3, lastSung: '2026-03-01'),
    ];

    test('number and name', () {
      expect(sortSongs(songs, SongSortOption.numberAsc).map((s) => s.id), [2, 1, 3]);
      expect(sortSongs(songs, SongSortOption.nameDesc).map((s) => s.id), [3, 1, 2]);
    });

    test('last sung puts never sung songs last in both directions', () {
      expect(sortSongs(songs, SongSortOption.lastSungDesc).map((s) => s.id), [3, 1, 2]);
      expect(sortSongs(songs, SongSortOption.lastSungAsc).map((s) => s.id), [1, 3, 2]);
    });
  });
}
