import 'dart:convert';
import 'dart:typed_data';

import 'package:attendix/core/utils/import_mapper.dart';
import 'package:attendix/core/utils/spreadsheet_reader.dart';
import 'package:attendix/data/models/instrument/instrument.dart';
import 'package:attendix/data/models/song/song.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const groups = [
    Group(id: 1, name: 'Dirigent', maingroup: true),
    Group(id: 2, name: 'Trompete'),
  ];
  const ctx = PersonMapContext(groups: groups, mainGroupId: 1);

  group('CSV decoding (UTF-8 umlauts)', () {
    test('UTF-8 with BOM keeps umlauts', () {
      final bytes = Uint8List.fromList(
          [0xEF, 0xBB, 0xBF, ...utf8.encode('Vorname;Nachname\nJürgen;Müller\n')]);
      final data = readSpreadsheet(bytes, 'personen.csv');
      expect(data.headers, ['Vorname', 'Nachname']);
      expect(data.rows.single['Nachname'], 'Müller');
      expect(data.rows.single['Vorname'], 'Jürgen');
    });

    test('Windows-1252 fallback for invalid UTF-8', () {
      // "Müller" in cp1252: ü = 0xFC
      final bytes = Uint8List.fromList(
          [...latin1.encode('Name,Gruppe\n'), 0x4D, 0xFC, 0x6C, 0x6C, 0x65, 0x72, ...latin1.encode(',Trompete\n')]);
      final data = readSpreadsheet(bytes, 'x.CSV');
      expect(data.rows.single['Name'], 'Müller');
    });

    test('quoted fields and delimiter detection', () {
      final rows = parseCsv('a;b\n"x;y";"he said ""hi"""\r\n');
      expect(rows[1], ['x;y', 'he said "hi"']);
    });
  });

  group('Person mapping', () {
    test('auto maps German headers and aliases', () {
      final mapping =
          autoMapPersonHeaders(['Vorname', 'NACHNAME', 'email', 'Instrument', 'Foo'], ctx);
      expect(mapping['Vorname'], 'Vorname');
      expect(mapping['NACHNAME'], 'Nachname');
      expect(mapping['email'], 'E-Mail');
      expect(mapping['Instrument'], 'Gruppe');
      expect(mapping['Foo'], isNull);
      expect(mappingHasName(mapping), isTrue);
    });

    test('splitFullName handles comma and multi-part names', () {
      expect(splitFullName('Müller, Anna').firstName, 'Anna');
      expect(splitFullName('Müller, Anna').lastName, 'Müller');
      expect(splitFullName('Anna Maria Müller').firstName, 'Anna Maria');
      expect(splitFullName('Anna').lastName, '');
    });

    test('parseGermanDate accepts supported formats', () {
      expect(parseGermanDate('15.03.1990'), '1990-03-15T00:00:00.000Z');
      expect(parseGermanDate('1990-03-15'), '1990-03-15T00:00:00.000Z');
      expect(parseGermanDate('5.3.1990'), '1990-03-05T00:00:00.000Z');
      expect(parseGermanDate('31.02.1990'), isNull);
      expect(parseGermanDate(32947), '1990-03-15T00:00:00.000Z');
    });

    test('unknown group falls back to main group and is unresolved', () {
      final mapping = {'Name': 'Name', 'Gruppe': 'Gruppe', 'Mail': 'E-Mail'};
      final rows = mapPersonRows([
        {'Name': 'Anna Müller', 'Gruppe': 'Posaune', 'Mail': 'A@x.de'},
        {'Name': 'Ben Bauer', 'Gruppe': 'trompete', 'Mail': 'a@x.de'},
        {'Name': '', 'Gruppe': '', 'Mail': ''},
      ], mapping, ctx);
      expect(rows, hasLength(2));
      expect(rows[0].instrument, 1);
      expect(rows[0].groupResolved, isFalse);
      expect(rows[0].email, 'a@x.de');
      expect(rows[1].instrument, 2);
      expect(rows[1].isDuplicate, isTrue); // same email in file
    });

    test('missing last name is an error; existing email is duplicate', () {
      final mapping = {'V': 'Vorname', 'N': 'Nachname', 'E': 'E-Mail'};
      final rows = detectPersonDuplicates(
        mapPersonRows([
          {'V': 'Anna', 'N': '', 'E': ''},
          {'V': 'Ben', 'N': 'Bauer', 'E': 'ben@x.de'},
        ], mapping, ctx),
        {'ben@x.de'},
      );
      expect(rows[0].status, 'error');
      expect(rows[1].status, 'duplicate');
      expect(rows[1].data['birthday'], isNull);
    });
  });

  group('Song mapping', () {
    const songCtx = SongMapContext(
      songCategories: [SongCategory(id: 'c1', name: 'Weihnachten')],
    );

    test('maps a complete row', () {
      final mapping = autoMapSongHeaders(kSongImportHeaders, songCtx);
      expect(mappingSongHasRequired(mapping), isTrue);
      final row = mapSongRow({
        'Nummer': '42',
        'Präfix': 'W',
        'Name': 'Stille Nacht',
        'Chor & Orchester': 'ja',
        'Mit Solo': 'nein',
        'Link': '',
        'Schwierigkeit': '2',
        'Kategorien': 'Weihnachten, Ostern',
      }, mapping, songCtx, 0);
      expect(row.errors, isEmpty);
      expect(row.data['number'], 42);
      expect(row.data['prefix'], 'W');
      expect(row.data['withChoir'], isTrue);
      expect(row.data['withSolo'], isFalse);
      expect(row.data['difficulty'], 2);
      expect(row.data['category_ids'], ['c1']);
      expect(row.warnings, contains('Kategorie "Ostern" nicht gefunden'));
      expect(row.compositeKey, 'W42');
    });

    test('duplicates within file and tenant are flagged', () {
      final mapping = {'Nr': 'Nummer', 'Titel': 'Name'};
      final rows = detectSongDuplicates(
        mapSongRows([
          {'Nr': '1', 'Titel': 'A'},
          {'Nr': '1', 'Titel': 'B'},
          {'Nr': '2', 'Titel': 'C'},
          {'Nr': 'x', 'Titel': 'D'},
        ], mapping, songCtx),
        {'2'},
      );
      expect(rows[0].status, 'ok');
      expect(rows[1].status, 'duplicate');
      expect(rows[2].status, 'duplicate');
      expect(rows[3].status, 'error');
    });
  });
}
