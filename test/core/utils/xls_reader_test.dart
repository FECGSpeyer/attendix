import 'dart:io';

import 'package:attendix/core/utils/spreadsheet_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('.xls (BIFF8) is read like SheetJS: text, dates, numbers, formula results', () {
    final bytes = File('test/fixtures/import_sample.xls').readAsBytesSync();
    // The content decides, not the extension (SheetJS `read()`).
    final data = readSpreadsheet(bytes, 'Mitglieder.xls');
    expect(data.headers, ['Vorname', 'Nachname', 'Geburtsdatum', 'Nummer', 'Doppelt', 'Gruß', 'Aktiv']);
    expect(data.rows[0], {
      'Vorname': 'Jürgen',
      'Nachname': 'Müller',
      'Geburtsdatum': DateTime(1990, 3, 4),
      'Nummer': 7,
      'Doppelt': 14,
      'Gruß': 'Jürgen Ж',
      'Aktiv': true,
    });
    expect(data.rows[1]['Vorname'], 'Ольга');
    expect(data.rows[1]['Geburtsdatum'], '');
    expect(data.rows[1]['Doppelt'], 5);
    expect(data.rows[1]['Aktiv'], false);
  });

  test('headers below empty rows stay the headers (SheetJS !ref)', () {
    final data = tableToRows([
      ['', ''],
      ['Vorname', 'Nachname'],
      ['Anna', 'Muster'],
    ]);
    expect(data.headers, ['Vorname', 'Nachname']);
    expect(data.rows.single['Vorname'], 'Anna');
  });
}
