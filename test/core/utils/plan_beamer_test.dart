import 'package:attendix/core/utils/plan_beamer.dart';
import 'package:attendix/core/utils/plan_utils.dart';
import 'package:attendix/data/models/organisation/organisation.dart';
import 'package:attendix/data/models/plan/plan.dart';
import 'package:attendix/data/models/song/song.dart';
import 'package:flutter_test/flutter_test.dart';

/// Port of Ionic `utilities/plan-beamer.spec.ts` (4.17.10) plus the
/// Werk fallback (4.17.11) and the model round trip.
void main() {
  PlanField f(String name, {bool? needsBeamer, String? uid, BeamerFile? beamerFile, bool isGroup = false, int? songId}) =>
      PlanField(
        id: 'fld-$name',
        name: name,
        time: '5',
        needsBeamer: needsBeamer,
        uid: uid,
        beamerFile: beamerFile,
        isGroup: isGroup,
        songId: songId,
      );
  Organisation org({bool linked = true, bool enabled = true}) =>
      Organisation(name: 'FECG Speyer', fecgLinkEnabled: linked, beamerFilesEnabled: enabled);

  test('is active only for linked orgs with the setting on and an ORG plan', () {
    expect(PlanBeamer.active(org(), true), isTrue);
    expect(PlanBeamer.active(org(), false), isFalse);
    expect(PlanBeamer.active(org(enabled: false), true), isFalse);
    expect(PlanBeamer.active(org(linked: false), true), isFalse);
    expect(PlanBeamer.active(null, true), isFalse);
  });

  test('switches on for Werke and titles with Lied or Gedicht', () {
    expect(PlanBeamer.autoNeedsBeamer(name: 'Herr, reich mir die Hände', songId: 47), isTrue);
    expect(PlanBeamer.autoNeedsBeamer(name: 'Gemeindelied'), isTrue);
    expect(PlanBeamer.autoNeedsBeamer(name: 'gedicht: Dank'), isTrue);
    expect(PlanBeamer.autoNeedsBeamer(name: 'Predigt'), isFalse);
  });

  test('keeps a value set by hand', () {
    expect(PlanBeamer.needsBeamer(f('Lied', needsBeamer: false)), isFalse);
    expect(PlanBeamer.needsBeamer(f('Predigt', needsBeamer: true)), isTrue);
  });

  test('never needs a file for notes, block heads and the agenda marker', () {
    expect(PlanBeamer.needsBeamer(const PlanField(id: 'noteFld Lied', name: 'Lied', time: '0', needsBeamer: true)),
        isFalse);
    expect(PlanBeamer.needsBeamer(f('Lieder', isGroup: true)), isFalse);
    expect(PlanBeamer.needsBeamer(const PlanField(id: PlanUtils.agendaPlaceholderId, name: 'Lied', time: '0')),
        isFalse);
  });

  test('autoReason names the Werk or the word found in the title', () {
    expect(PlanBeamer.autoReason(name: 'x', songId: 1), (song: true, word: null));
    expect(PlanBeamer.autoReason(name: 'Gedicht'), (song: false, word: 'Gedicht'));
    expect(PlanBeamer.autoReason(name: 'Lied und Gedicht'), (song: false, word: 'Lied'));
    expect(PlanBeamer.autoReason(name: 'Lied', manual: true), isNull);
    expect(PlanBeamer.autoReason(name: 'Predigt'), isNull);
  });

  test('gives each row a unique uid and drops the file of copied rows', () {
    const file = BeamerFile(name: 'a.sng', path: 'Songs/a.sng');
    var n = 0;
    final fields = PlanBeamer.ensureFieldUids(
      [f('a', uid: 'u1', beamerFile: file), f('b'), f('c', uid: 'u1', beamerFile: file)],
      newUid: () => 'new${n++}',
    );
    expect(fields[0].uid, 'u1');
    expect(fields[0].beamerFile, file);
    expect(fields[1].uid, isNotEmpty);
    expect(fields[2].uid, isNot('u1'));
    expect(fields[2].beamerFile, isNull);
    expect(fields.map((x) => x.uid).toSet().length, 3);
  });

  test('ensureFieldUids returns the same list when every row has its own uid', () {
    final fields = [f('a', uid: 'u1'), f('b', uid: 'u2')];
    expect(identical(PlanBeamer.ensureFieldUids(fields), fields), isTrue);
  });

  test('a copied block gets no uid and no file', () {
    const file = BeamerFile(name: 'a.sng', path: 'Songs/a.sng');
    final head = PlanUtils.newGroupHead('Block');
    final clone = PlanUtils.cloneBlock([
      head,
      PlanField(id: 'fld-x', name: 'Lied', time: '5', groupId: head.id, uid: 'u1', beamerFile: file),
    ]);
    expect(clone[1].uid, isNull);
    expect(clone[1].beamerFile, isNull);
  });

  test('fileOf prefers the row file, then the Werk file', () {
    const rowFile = BeamerFile(name: 'row.sng', path: 'r');
    const songFile = BeamerFile(name: 'song.sng', path: 's');
    BeamerFile? lookup(int id) => id == 7 ? songFile : null;
    expect(PlanBeamer.fileOf(f('x', songId: 7, beamerFile: rowFile), lookup), rowFile);
    expect(PlanBeamer.fileOf(f('x', songId: 7), lookup), songFile);
    expect(PlanBeamer.fileOf(f('x'), lookup), isNull);
  });

  test('plan rows keep uid, needsBeamer and beamerFile through JSON', () {
    final json = {
      'id': '47',
      'name': 'Lied',
      'time': '5',
      'songId': 47,
      'uid': 'u-1',
      'needsBeamer': false,
      'beamerFile': {'name': 'a.sng', 'path': 'Songs/a.sng', 'linkedAt': '2026-10-30'},
    };
    final field = PlanField.fromJson(json);
    expect(field.uid, 'u-1');
    expect(field.needsBeamer, isFalse);
    expect(field.beamerFile?.name, 'a.sng');
    final out = field.toJson();
    expect(out['uid'], 'u-1');
    expect(out['needsBeamer'], false);
    expect(out['beamerFile'], {'name': 'a.sng', 'path': 'Songs/a.sng', 'linkedAt': '2026-10-30'});
    // Untouched rows write none of the new keys.
    final plain = const PlanField(id: 'a', name: 'a').toJson();
    expect(plain.containsKey('uid') || plain.containsKey('needsBeamer') || plain.containsKey('beamerFile'), isFalse);
  });

  test('a malformed beamer file is ignored', () {
    expect(PlanField.fromJson({'id': 'a', 'name': 'a', 'beamerFile': 'x'}).beamerFile, isNull);
    expect(PlanField.fromJson({'id': 'a', 'name': 'a', 'beamerFile': {'path': 'p'}}).beamerFile, isNull);
  });

  test('song reads beamer_file but never writes it', () {
    final song = Song.fromJson({
      'name': 'X',
      'beamer_file': {'name': 'x.sng', 'path': 'p'},
    });
    expect(song.beamerFile?.name, 'x.sng');
    expect(song.toJson().containsKey('beamer_file'), isFalse);
  });

  test('organisation reads the Gemeinde App columns', () {
    final o = Organisation.fromJson({
      'name': 'FECG',
      'fecg_link_enabled': true,
      'beamer_files_enabled': null,
      'gemeinde_app_key_hash': 'h',
      'gemeinde_app_key_hint': 'abcd',
    });
    expect(o.fecgLinkEnabled, isTrue);
    expect(o.beamerFilesEnabled, isFalse);
    expect(o.gemeindeAppKeyHint, 'abcd');
  });

  test('new Gemeinde App key: atx_ + 48 hex, SHA-256 hash and last 4 chars', () {
    final k = PlanBeamer.newGemeindeAppKey();
    expect(k.key, matches(RegExp(r'^atx_[0-9a-f]{48}$')));
    expect(k.hint, k.key.substring(k.key.length - 4));
    expect(k.hash, PlanBeamer.gemeindeAppKeyHash(k.key));
    // Known SHA-256 vector.
    expect(PlanBeamer.gemeindeAppKeyHash('abc'),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
  });
}
