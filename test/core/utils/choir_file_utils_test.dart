import 'package:attendix/core/providers/song_providers.dart';
import 'package:attendix/core/utils/choir_file_utils.dart';
import 'package:attendix/data/models/instrument/instrument.dart';
import 'package:attendix/data/models/song/song.dart';
import 'package:attendix/features/self_service/presentation/widgets/upcoming_songs_sheet.dart';
import 'package:attendix/features/songs/presentation/utils/song_utils.dart';
import 'package:flutter_test/flutter_test.dart';

SongFile _file(String name, {int? instrumentId, String? note}) => SongFile(
      fileName: name,
      fileType: 'application/pdf',
      url: 'https://x/$name',
      instrumentId: instrumentId,
      note: note,
    );

void main() {
  group('isChoirAllFile (Ionic Utils.isChoirAllFile)', () {
    test('detects note "Chor" tolerating case and spaces', () {
      expect(isChoirAllFile(note: 'Chor'), isTrue);
      expect(isChoirAllFile(note: ' chor '), isTrue);
      expect(isChoirAllFile(note: 'CHOR'), isTrue);
    });

    test('needs no group and the exact word', () {
      expect(isChoirAllFile(instrumentId: 5, note: 'Chor'), isFalse);
      expect(isChoirAllFile(note: 'Chorsatz'), isFalse);
      expect(isChoirAllFile(note: null), isFalse);
      expect(isChoirAllFile(note: ''), isFalse);
    });

    test('stored note stays "Chor"', () {
      expect(kChoirAllNote, 'Chor');
    });
  });

  group('category picker values', () {
    test('choir files map to the "Chor (alle)" option only in choirs', () {
      expect(fileCategoryOptionValue(null, 'Chor', isChoir: true), kChoirAllOptionValue);
      expect(fileCategoryOptionValue(null, 'Chor', isChoir: false), isNull);
      expect(fileCategoryOptionValue(null, 'Partitur', isChoir: true), isNull);
      expect(fileCategoryOptionValue(7, null, isChoir: true), 7);
    });

    test('resolves options to the stored category', () {
      expect(resolveFileCategoryOption(kChoirAllOptionValue, 'x'),
          (instrumentId: null, note: 'Chor'));
      expect(resolveFileCategoryOption(null, 'Partitur'),
          (instrumentId: null, note: 'Partitur'));
      // Switching from "Chor (alle)" to free text clears the note.
      expect(resolveFileCategoryOption(null, 'chor'), (instrumentId: null, note: ''));
      expect(resolveFileCategoryOption(4, 'Partitur'), (instrumentId: 4, note: null));
    });
  });

  group('songs feature', () {
    test('label "Chor (alle)" in choirs, badge and sort tolerant', () {
      final f = _file('a.pdf', note: ' chor');
      expect(SongUtils.fileLabel(f, const [], isChoir: true), 'Chor (alle)');
      expect(SongUtils.fileLabel(f, const []), ' chor');
      expect(SongUtils.fileBadgeColor(f), SongUtils.fileBadgeColor(_file('b.pdf', note: 'Chor')));
      final sorted = SongUtils.sortedFiles(
        [_file('other.pdf', note: 'Sonstiges'), f, _file('lyrics.pdf', instrumentId: 2)],
        const [],
      );
      expect(sorted.map((e) => e.fileName), ['lyrics.pdf', 'a.pdf', 'other.pdf']);
    });

    test('group directory has a virtual "Chor (alle)" group in choirs', () {
      final songs = [
        Song(id: 1, name: 'A', files: [_file('a.pdf', note: 'chor'), _file('s.pdf', instrumentId: 10)]),
        Song(id: 2, name: 'B', files: [_file('p.pdf', note: 'Partitur')]),
      ];
      const groups = [Group(id: 10, name: 'Sopran')];
      final choir = buildGroupsWithFiles(songs, groups,
          conductorsLabel: 'Dirigenten', isChoir: true, choirAllLabel: 'Chor (alle)');
      expect(choir.map((g) => g.id), [songConductorGroupId, songChoirAllGroupId, 10]);
      expect(filesForGroup(songs, songChoirAllGroupId).map((e) => e.file.fileName), ['a.pdf']);

      final orchestra = buildGroupsWithFiles(songs, groups, conductorsLabel: 'Dirigenten');
      expect(orchestra.map((g) => g.id), [songConductorGroupId, 10]);
    });
  });

  group('self service', () {
    test('choir members see notes when a "Chor (alle)" file exists', () {
      final song = Song(name: 'A', instrumentIds: const [], files: [_file('a.pdf', note: ' Chor ')]);
      expect(hasSongNotesForPlayer(song, 9, isChoir: true), isTrue);
      expect(hasSongNotesForPlayer(song, 9, isChoir: false), isFalse);
    });
  });
}
