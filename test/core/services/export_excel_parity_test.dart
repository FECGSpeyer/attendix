import 'package:attendix/core/services/export_service.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../factories/test_factories.dart';

/// Ionic export.page writes one sheet "Anwesenheit" (book_new +
/// book_append_sheet); Excel.createExcel() starts with an empty "Sheet1".
void main() {
  test('player list Excel has exactly one sheet, header starts empty', () async {
    final bytes = await ExportService().exportPlayerListExcel(
      players: TestFactories.createPersonList(3, tenantId: 1),
      fields: const ['Vorname', 'Nachname'],
      tenantName: 'MVB',
    );
    final excel = Excel.decodeBytes(bytes);
    expect(excel.tables.keys, ['Anwesenheit']);
    final header = excel.tables['Anwesenheit']!.rows.first;
    expect(header.map((c) => c?.value?.toString() ?? ''), ['', 'Vorname', 'Nachname']);
  });
}
