/// Reads Excel (.xlsx) and CSV files into header/row maps for imports.
///
/// Port of Ionic `spreadsheet-reader.ts`: CSV bytes are decoded as UTF-8
/// first (a BOM is stripped) and, when that fails because of invalid byte
/// sequences, as Windows-1252 (CSV exported from older Excel versions). This
/// keeps umlauts like "Müller" intact instead of turning them into "MÃ¼ller".
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import '../../l10n/l10n.dart';

/// Parsed first sheet of a spreadsheet: header names and one map per row.
class SpreadsheetData {
  const SpreadsheetData({required this.headers, required this.rows});

  final List<String> headers;

  /// Each row maps header -> cell value (String, num, bool or DateTime).
  /// Missing cells are ''.
  final List<Map<String, dynamic>> rows;
}

/// Thrown when a file cannot be parsed.
class SpreadsheetReadException implements Exception {
  SpreadsheetReadException(this.message);
  final String message;
  @override
  String toString() => message;
}

bool isCsvFileName(String fileName) =>
    RegExp(r'\.(csv|txt)$', caseSensitive: false).hasMatch(fileName);

/// Parse [bytes] of a file called [fileName] (.xlsx, .csv or .txt).
SpreadsheetData readSpreadsheet(Uint8List bytes, String fileName) {
  final List<List<dynamic>> table;
  if (isCsvFileName(fileName)) {
    table = parseCsv(decodeCsvBytes(bytes));
  } else {
    if (RegExp(r'\.xls$', caseSensitive: false).hasMatch(fileName)) {
      throw SpreadsheetReadException(
        l10nWithoutContext.coreFlutterXlsUnsupported,
      );
    }
    table = _readXlsx(bytes);
  }
  return tableToRows(table);
}

/// Decode CSV bytes: strict UTF-8 first (BOM removed), Windows-1252 fallback.
String decodeCsvBytes(List<int> bytes) {
  var data = bytes;
  if (data.length >= 3 && data[0] == 0xEF && data[1] == 0xBB && data[2] == 0xBF) {
    data = data.sublist(3);
  }
  try {
    return const Utf8Decoder(allowMalformed: false).convert(data);
  } on FormatException {
    return decodeWindows1252(data);
  }
}

/// Windows-1252 code points for bytes 0x80..0x9F (0 = undefined -> U+FFFD).
const List<int> _cp1252High = [
  0x20AC, 0, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, //
  0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0, 0x017D, 0, //
  0, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, //
  0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0, 0x017E, 0x0178,
];

String decodeWindows1252(List<int> bytes) {
  final buffer = StringBuffer();
  for (final b in bytes) {
    if (b >= 0x80 && b <= 0x9F) {
      final cp = _cp1252High[b - 0x80];
      buffer.writeCharCode(cp == 0 ? 0xFFFD : cp);
    } else {
      buffer.writeCharCode(b);
    }
  }
  return buffer.toString();
}

/// Detect the delimiter from the first line (outside of quotes).
String detectCsvDelimiter(String text) {
  final counts = {',': 0, ';': 0, '\t': 0};
  var inQuotes = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (c == '"') {
      inQuotes = !inQuotes;
    } else if (!inQuotes && (c == '\n' || c == '\r')) {
      break;
    } else if (!inQuotes && counts.containsKey(c)) {
      counts[c] = counts[c]! + 1;
    }
  }
  var best = ',';
  for (final entry in counts.entries) {
    if (entry.value > counts[best]!) best = entry.key;
  }
  return best;
}

/// RFC-4180-ish CSV parser (quoted fields, "" escapes, CR/LF line endings).
List<List<dynamic>> parseCsv(String text, {String? delimiter}) {
  final sep = delimiter ?? detectCsvDelimiter(text);
  final rows = <List<dynamic>>[];
  var row = <dynamic>[];
  final field = StringBuffer();
  var inQuotes = false;
  var i = 0;
  while (i < text.length) {
    final c = text[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i += 2;
          continue;
        }
        inQuotes = false;
      } else {
        field.write(c);
      }
      i++;
      continue;
    }
    if (c == '"') {
      inQuotes = true;
    } else if (c == sep) {
      row.add(field.toString());
      field.clear();
    } else if (c == '\r' || c == '\n') {
      row.add(field.toString());
      field.clear();
      rows.add(row);
      row = <dynamic>[];
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
    } else {
      field.write(c);
    }
    i++;
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows;
}

List<List<dynamic>> _readXlsx(Uint8List bytes) {
  final Excel excel;
  try {
    excel = Excel.decodeBytes(bytes);
  } catch (e) {
    throw SpreadsheetReadException(l10nWithoutContext.peopleFileUnreadable);
  }
  if (excel.tables.isEmpty) return [];
  final sheetName = excel.getDefaultSheet() ?? excel.tables.keys.first;
  final sheet = excel.tables[sheetName] ?? excel.tables.values.first;
  return sheet.rows
      .map((r) => r.map((cell) => cellToDart(cell?.value)).toList())
      .toList();
}

/// Convert an `excel` cell value to a plain Dart value.
dynamic cellToDart(CellValue? value) {
  return switch (value) {
    null => '',
    TextCellValue() => value.value.toString(),
    IntCellValue() => value.value,
    // Whole-number doubles (e.g. phone numbers, song numbers) -> int.
    DoubleCellValue() => value.value == value.value.truncateToDouble() &&
            value.value.abs() < 1e15
        ? value.value.toInt()
        : value.value,
    BoolCellValue() => value.value,
    DateCellValue() => DateTime(value.year, value.month, value.day),
    DateTimeCellValue() =>
      DateTime(value.year, value.month, value.day, value.hour, value.minute),
    TimeCellValue() => value.toString(),
    FormulaCellValue() => value.formula,
  };
}

/// Turn a raw table (first row = headers) into header-keyed row maps, like
/// SheetJS `sheet_to_json(sheet, { defval: '' })`.
SpreadsheetData tableToRows(List<List<dynamic>> table) {
  if (table.isEmpty) return const SpreadsheetData(headers: [], rows: []);

  final headerRow = table.first;
  final dataRows = table.skip(1).toList();
  final width = [headerRow.length, ...dataRows.map((r) => r.length)]
      .reduce((a, b) => a > b ? a : b);

  final headers = <String>[];
  final columnIndexes = <int>[];
  final used = <String, int>{};
  for (var col = 0; col < width; col++) {
    var name = col < headerRow.length
        ? (headerRow[col] ?? '').toString().trim()
        : '';
    if (name.isEmpty) {
      final hasData = dataRows.any((r) =>
          col < r.length && (r[col] ?? '').toString().trim().isNotEmpty);
      if (!hasData) continue;
      name = '__EMPTY';
    }
    if (used.containsKey(name)) {
      final n = used[name]!;
      used[name] = n + 1;
      name = '${name}_$n';
    } else {
      used[name] = 1;
    }
    headers.add(name);
    columnIndexes.add(col);
  }

  final rows = <Map<String, dynamic>>[];
  for (final r in dataRows) {
    final map = <String, dynamic>{};
    var hasValue = false;
    for (var i = 0; i < headers.length; i++) {
      final col = columnIndexes[i];
      final v = col < r.length ? (r[col] ?? '') : '';
      if (v.toString().trim().isNotEmpty) hasValue = true;
      map[headers[i]] = v;
    }
    // SheetJS skips fully blank rows (blankrows: false).
    if (hasValue) rows.add(map);
  }
  return SpreadsheetData(headers: headers, rows: rows);
}

/// Build an .xlsx template with a header row and one example row.
List<int>? buildTemplateXlsx(List<String> headers, List<String> example) {
  final excel = Excel.createExcel();
  final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
  excel.rename(defaultSheet, 'Import');
  final sheet = excel['Import'];
  sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
  final padded = [...example];
  while (padded.length < headers.length) {
    padded.add('');
  }
  sheet.appendRow(padded.map((v) => TextCellValue(v)).toList());
  return excel.save();
}
