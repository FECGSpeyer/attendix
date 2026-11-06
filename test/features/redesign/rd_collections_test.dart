import 'package:attendix/data/models/song/song.dart';
import 'package:attendix/features/redesign/data/rd_collections_logic.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../factories/test_factories.dart';

/// REDESIGN: Sammlungen (canvas "Noten-Bereich neu gedacht"): who sees
/// which one, the numbers on a move, what may be planned.
void main() {
  final violine = TestFactories.createGroup(id: 1, name: 'Violine 1');
  final floete = TestFactories.createGroup(id: 2, name: 'Flöte');
  final groups = [violine, floete];
  const einspielen = SongCollection(id: 10, name: 'Einspielen', prefix: 'E', plannable: false);
  const leitung = SongCollection(id: 11, name: 'In Vorbereitung', visibility: 'leads');
  const streicher = SongCollection(id: 12, name: 'Streicher', visibility: 'groups', groupIds: [1]);
  const all = [einspielen, leitung, streicher];

  test('leads see every Sammlung, members those for all and of their group', () {
    expect(rdVisibleCollections(all, lead: true, ownGroup: null, groups: groups), all);
    expect(rdVisibleCollections(all, lead: false, ownGroup: violine, groups: groups), [einspielen, streicher]);
    expect(rdVisibleCollections(all, lead: false, ownGroup: floete, groups: groups), [einspielen]);

    const songs = [
      Song(id: 1, name: 'A'),
      Song(id: 2, name: 'B', collectionId: 11),
      Song(id: 3, name: 'C', collectionId: 10),
    ];
    expect(rdVisibleWorks(songs, [einspielen]).map((s) => s.id), [1, 3]);
    expect(rdWorksIn(songs, null).map((s) => s.id), [1]);
  });

  test('a move takes the prefix and next number of the Sammlung, back drops it', () {
    const songs = [
      Song(id: 1, name: 'A', number: 12),
      Song(id: 2, name: 'B', prefix: 'E', number: 1, collectionId: 10),
      Song(id: 3, name: 'C', number: 40, collectionId: 11),
    ];
    // Repertoire → Einspielen: E2.
    expect(rdMoveNumbering(songs[0], einspielen, all, songs), (prefix: 'E', number: 2));
    // Einspielen → Repertoire: the prefix goes, the next free number.
    expect(rdMoveNumbering(songs[1], null, all, songs), (prefix: '', number: 41));
    // Into a Sammlung without prefix: the number stays.
    expect(rdMoveNumbering(songs[2], null, all, songs), isNull);
  });

  test('Werke of a Sammlung that is not planbar stay out of programmes', () {
    const songs = [
      Song(id: 1, name: 'A'),
      Song(id: 2, name: 'B', collectionId: 10),
      Song(id: 3, name: 'C', collectionId: 11),
    ];
    expect(rdPlannableWorks(songs, all).map((s) => s.id), [1, 3]);
    expect(rdPlannableWorks(songs, null), songs);
  });
}
