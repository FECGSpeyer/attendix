import 'package:attendix/data/models/instrument/instrument.dart';
import 'package:attendix/features/songs/presentation/utils/song_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const strings = GroupCategory(id: 1, name: 'Streicher');
  const winds = GroupCategory(id: 2, name: 'Holzbläser');
  const groups = [
    Group(id: 1, name: 'Dirigent', maingroup: true),
    Group(id: 10, name: 'Violine 1', categoryId: 1),
    Group(id: 11, name: 'Violine 3', categoryId: 1),
    Group(id: 20, name: 'Flöte', categoryId: 2),
    Group(id: 21, name: 'Saxophon', categoryId: 2),
    Group(id: 30, name: 'Celesta'),
  ];

  String text(List<int> ids, {Map<int, int>? counts}) =>
      SongUtils.missingInstrumentsText(ids, groups, [strings, winds], playerCounts: counts);

  group('"Ohne …" with active players', () {
    test('without counts every group counts (Ionic)', () {
      expect(text([10, 20]), contains('Saxophon'));
      expect(text([10, 20]), contains('Sonstige')); // Celesta, a category of its own
    });

    test('groups nobody plays are not missing', () {
      final counts = {10: 8, 20: 3};
      expect(text([10, 20], counts: counts), isEmpty);
      expect(text([10], counts: counts), contains('Flöte'));
      expect(text([10], counts: counts), isNot(contains('Saxophon')));
    });

    test('a whole category is named by the played groups only', () {
      // Flöte is the only played wind group: missing it means "Ohne Flöte".
      final counts = {10: 8, 11: 0, 20: 3};
      expect(text([10], counts: counts), contains('Flöte'));
      expect(text([10], counts: counts), isNot(contains('Violine 3')));
    });

    test('empty counts (not loaded) fall back to every group', () {
      expect(text([10, 20], counts: const {}), contains('Saxophon'));
    });
  });
}
