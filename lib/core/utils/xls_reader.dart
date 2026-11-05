/// Minimal reader for legacy Excel files (.xls, BIFF8 in an OLE2 compound
/// file) – first worksheet only, cell values only.
///
/// Ionic reads .xls with SheetJS (`read(buffer, { cellDates: true })`); the
/// `excel` package only understands .xlsx. This reader covers what the
/// person and song imports need: text (shared strings and inline labels),
/// numbers (NUMBER, RK, MULRK), booleans, formula results (cached values,
/// like SheetJS) and date-formatted numbers as [DateTime].
library;

import 'dart:typed_data';

/// Thrown when the bytes are not a readable BIFF8 workbook.
class XlsFormatException implements Exception {
  XlsFormatException(this.message);
  final String message;
  @override
  String toString() => 'XlsFormatException: $message';
}

/// Whether [bytes] start with the OLE2 compound file signature.
bool isOle2File(List<int> bytes) =>
    bytes.length >= 8 &&
    bytes[0] == 0xD0 &&
    bytes[1] == 0xCF &&
    bytes[2] == 0x11 &&
    bytes[3] == 0xE0 &&
    bytes[4] == 0xA1 &&
    bytes[5] == 0xB1 &&
    bytes[6] == 0x1A &&
    bytes[7] == 0xE1;

/// Reads the first worksheet of an .xls file as a table (rows of cells;
/// empty cells are '').
List<List<dynamic>> readXlsTable(Uint8List bytes) {
  final stream = _Cfb(bytes).readStream(const ['Workbook', 'Book']);
  return _Biff8(stream).firstSheet();
}

// ---------------------------------------------------------------------------
// OLE2 compound file

class _Cfb {
  _Cfb(this.bytes) {
    if (!isOle2File(bytes) || bytes.length < 512) {
      throw XlsFormatException('no compound file');
    }
    _data = ByteData.sublistView(bytes);
    _sectorSize = 1 << _u16(0x1E);
    _miniSectorSize = 1 << _u16(0x20);
    _miniCutoff = _u32(0x38);
    _buildFat();
  }

  final Uint8List bytes;
  late final ByteData _data;
  late final int _sectorSize;
  late final int _miniSectorSize;
  late final int _miniCutoff;
  final List<int> _fat = [];

  static const _endOfChain = 0xFFFFFFFE;
  static const _freeSect = 0xFFFFFFFF;

  int _u16(int o) => _data.getUint16(o, Endian.little);
  int _u32(int o) => _data.getUint32(o, Endian.little);

  int _sectorOffset(int sector) => (sector + 1) * _sectorSize;

  void _buildFat() {
    final fatSectors = <int>[];
    final numFat = _u32(0x2C);
    for (var i = 0; i < 109 && fatSectors.length < numFat; i++) {
      final s = _u32(0x4C + i * 4);
      if (s != _freeSect) fatSectors.add(s);
    }
    var difat = _u32(0x44);
    var guard = 0;
    while (difat != _endOfChain && difat != _freeSect && fatSectors.length < numFat) {
      if (++guard > 100000) throw XlsFormatException('DIFAT loop');
      final base = _sectorOffset(difat);
      final perSector = _sectorSize ~/ 4 - 1;
      for (var i = 0; i < perSector && fatSectors.length < numFat; i++) {
        final s = _u32(base + i * 4);
        if (s != _freeSect) fatSectors.add(s);
      }
      difat = _u32(base + perSector * 4);
    }
    for (final s in fatSectors) {
      final base = _sectorOffset(s);
      if (base + _sectorSize > bytes.length) break;
      for (var i = 0; i < _sectorSize ~/ 4; i++) {
        _fat.add(_u32(base + i * 4));
      }
    }
  }

  List<int> _chain(int start, List<int> table) {
    final out = <int>[];
    var s = start;
    while (s != _endOfChain && s != _freeSect && s >= 0 && s < table.length) {
      if (out.length > table.length) throw XlsFormatException('sector loop');
      out.add(s);
      s = table[s];
    }
    return out;
  }

  Uint8List _readChain(int start, int size) {
    final out = BytesBuilder(copy: false);
    for (final s in _chain(start, _fat)) {
      final o = _sectorOffset(s);
      final end = (o + _sectorSize).clamp(0, bytes.length);
      if (o >= bytes.length) break;
      out.add(Uint8List.sublistView(bytes, o, end));
    }
    final all = out.takeBytes();
    return size >= 0 && size < all.length ? Uint8List.sublistView(all, 0, size) : all;
  }

  Uint8List readStream(List<String> names) {
    final dir = _readChain(_u32(0x30), -1);
    final dd = ByteData.sublistView(dir);
    Uint8List? root;
    for (var o = 0; o + 128 <= dir.length; o += 128) {
      final nameLen = dd.getUint16(o + 0x40, Endian.little);
      final type = dir[o + 0x42];
      if (type == 0 || nameLen < 2) continue;
      final units = <int>[
        for (var i = 0; i < (nameLen ~/ 2) - 1; i++) dd.getUint16(o + i * 2, Endian.little),
      ];
      final name = String.fromCharCodes(units);
      final start = dd.getUint32(o + 0x74, Endian.little);
      final size = dd.getUint32(o + 0x78, Endian.little);
      if (type == 5) {
        root = _readChain(start, size);
        continue;
      }
      if (type == 2 && names.contains(name)) {
        if (size >= _miniCutoff) return _readChain(start, size);
        return _readMini(start, size, root ?? _rootStream(dir));
      }
    }
    throw XlsFormatException('no Workbook stream');
  }

  Uint8List _rootStream(Uint8List dir) {
    final dd = ByteData.sublistView(dir);
    return _readChain(dd.getUint32(0x74, Endian.little), dd.getUint32(0x78, Endian.little));
  }

  Uint8List _readMini(int start, int size, Uint8List ministream) {
    final miniFat = <int>[];
    final mfBytes = _readChain(_u32(0x3C), -1);
    final md = ByteData.sublistView(mfBytes);
    for (var i = 0; i + 4 <= mfBytes.length; i += 4) {
      miniFat.add(md.getUint32(i, Endian.little));
    }
    final out = BytesBuilder(copy: false);
    for (final s in _chain(start, miniFat)) {
      final o = s * _miniSectorSize;
      if (o >= ministream.length) break;
      out.add(Uint8List.sublistView(
          ministream, o, (o + _miniSectorSize).clamp(0, ministream.length)));
    }
    final all = out.takeBytes();
    return size < all.length ? Uint8List.sublistView(all, 0, size) : all;
  }
}

// ---------------------------------------------------------------------------
// BIFF8 workbook stream

class _Record {
  _Record(this.type, this.data);
  final int type;
  final Uint8List data;
}

class _Biff8 {
  _Biff8(this.stream);

  final Uint8List stream;
  final List<String> _sst = [];
  final List<int> _xfFormat = [];
  final Map<int, String> _formats = {};
  bool _date1904 = false;

  static const _bof = 0x0809;
  static const _eof = 0x000A;
  static const _continue = 0x003C;

  List<_Record> _records(int offset) {
    final out = <_Record>[];
    final d = ByteData.sublistView(stream);
    var o = offset;
    while (o + 4 <= stream.length) {
      final type = d.getUint16(o, Endian.little);
      final len = d.getUint16(o + 2, Endian.little);
      final end = (o + 4 + len).clamp(0, stream.length);
      out.add(_Record(type, Uint8List.sublistView(stream, o + 4, end)));
      o = end;
    }
    return out;
  }

  List<List<dynamic>> firstSheet() {
    final globals = _records(0);
    if (globals.isEmpty || globals.first.type != _bof) {
      throw XlsFormatException('no BIFF stream');
    }
    final bofVersion = ByteData.sublistView(globals.first.data).getUint16(0, Endian.little);
    if (bofVersion != 0x0600) throw XlsFormatException('not BIFF8');

    int? sheetOffset;
    for (var i = 0; i < globals.length; i++) {
      final r = globals[i];
      final d = ByteData.sublistView(r.data);
      switch (r.type) {
        case 0x0022: // DATEMODE
          _date1904 = r.data.length >= 2 && d.getUint16(0, Endian.little) == 1;
        case 0x041E: // FORMAT
          final id = d.getUint16(0, Endian.little);
          _formats[id] = _Reader([r.data]).skip(2).unicodeString16();
        case 0x00E0: // XF
          _xfFormat.add(r.data.length >= 4 ? d.getUint16(2, Endian.little) : 0);
        case 0x0085: // BOUNDSHEET8: first worksheet (type 0)
          final type = r.data.length >= 6 ? r.data[5] : 0;
          if (sheetOffset == null && type == 0) {
            sheetOffset = d.getUint32(0, Endian.little);
          }
        case 0x00FC: // SST (+ CONTINUE)
          final parts = <Uint8List>[r.data];
          while (i + 1 < globals.length && globals[i + 1].type == _continue) {
            parts.add(globals[++i].data);
          }
          _readSst(parts);
        case _eof:
          i = globals.length;
      }
    }
    if (sheetOffset == null) return [];
    return _readSheet(_records(sheetOffset));
  }

  void _readSst(List<Uint8List> parts) {
    final r = _Reader(parts);
    r.skip(4);
    final unique = r.u32();
    for (var i = 0; i < unique && !r.atEnd; i++) {
      _sst.add(r.richString16());
    }
  }

  List<List<dynamic>> _readSheet(List<_Record> records) {
    final cells = <int, Map<int, dynamic>>{};
    var maxCol = -1;
    void put(int row, int col, dynamic v) {
      (cells[row] ??= {})[col] = v;
      if (col > maxCol) maxCol = col;
    }

    int? pendingRow;
    int? pendingCol;
    for (var i = 0; i < records.length; i++) {
      final r = records[i];
      if (i > 0 && r.type == _bof) {
        // embedded substream (chart) – skip to its EOF
        var depth = 1;
        while (depth > 0 && ++i < records.length) {
          if (records[i].type == _bof) depth++;
          if (records[i].type == _eof) depth--;
        }
        continue;
      }
      if (r.type == _eof) break;
      final d = ByteData.sublistView(r.data);
      if (r.data.length < 6 && r.type != 0x0207) continue;
      switch (r.type) {
        case 0x00FD: // LABELSST
          final idx = d.getUint32(6, Endian.little);
          put(_row(d), _col(d), idx < _sst.length ? _sst[idx] : '');
        case 0x0204: // LABEL
          put(_row(d), _col(d), _Reader([r.data]).skip(6).unicodeString16());
        case 0x0203: // NUMBER
          put(_row(d), _col(d), _number(d.getFloat64(6, Endian.little), d.getUint16(4, Endian.little)));
        case 0x027E: // RK
          put(_row(d), _col(d), _number(_rk(d.getUint32(6, Endian.little)), d.getUint16(4, Endian.little)));
        case 0x00BD: // MULRK
          final row = _row(d);
          final first = _col(d);
          final count = (r.data.length - 6) ~/ 6;
          for (var k = 0; k < count; k++) {
            final xf = d.getUint16(4 + k * 6, Endian.little);
            final rk = d.getUint32(6 + k * 6, Endian.little);
            put(row, first + k, _number(_rk(rk), xf));
          }
        case 0x0205: // BOOLERR
          final isError = r.data.length > 7 && r.data[7] == 1;
          put(_row(d), _col(d), isError ? '' : r.data[6] != 0);
        case 0x0006: // FORMULA: cached result
          final row = _row(d);
          final col = _col(d);
          if (d.getUint16(12, Endian.little) == 0xFFFF) {
            switch (r.data[6]) {
              case 0: // string in the following STRING record
                pendingRow = row;
                pendingCol = col;
              case 1:
                put(row, col, r.data[8] != 0);
              default:
                put(row, col, '');
            }
          } else {
            put(row, col, _number(d.getFloat64(6, Endian.little), d.getUint16(4, Endian.little)));
          }
        case 0x0207: // STRING (formula text result)
          if (pendingRow != null && pendingCol != null) {
            final parts = <Uint8List>[r.data];
            while (i + 1 < records.length && records[i + 1].type == _continue) {
              parts.add(records[++i].data);
            }
            put(pendingRow, pendingCol, _Reader(parts).unicodeString16());
          }
          pendingRow = null;
          pendingCol = null;
      }
    }
    if (cells.isEmpty) return [];
    final lastRow = cells.keys.reduce((a, b) => a > b ? a : b);
    return [
      for (var row = 0; row <= lastRow; row++)
        [for (var col = 0; col <= maxCol; col++) cells[row]?[col] ?? ''],
    ];
  }

  int _row(ByteData d) => d.getUint16(0, Endian.little);
  int _col(ByteData d) => d.getUint16(2, Endian.little);

  static double _rk(int rk) {
    double v;
    if (rk & 0x02 != 0) {
      v = (rk >> 2).toSigned(30).toDouble();
    } else {
      final b = ByteData(8)..setUint32(4, rk & 0xFFFFFFFC, Endian.little);
      v = b.getFloat64(0, Endian.little);
    }
    return rk & 0x01 != 0 ? v / 100 : v;
  }

  /// Number cell → DateTime for date formats (SheetJS cellDates), whole
  /// numbers as int (like the .xlsx path), else double.
  dynamic _number(double v, int xf) {
    final fmt = xf < _xfFormat.length ? _xfFormat[xf] : 0;
    if (isDateFormat(fmt, _formats[fmt])) return excelSerialToDate(v, date1904: _date1904);
    if (v == v.truncateToDouble() && v.abs() < 1e15) return v.toInt();
    return v;
  }
}

/// Built-in date/time number formats and custom formats with date/time
/// tokens (outside quotes, escapes and brackets).
bool isDateFormat(int id, String? custom) {
  if ((id >= 14 && id <= 22) || (id >= 27 && id <= 36) || (id >= 45 && id <= 47) || (id >= 50 && id <= 58)) {
    return true;
  }
  if (custom == null) return false;
  final stripped = custom
      .replaceAll(RegExp(r'"[^"]*"'), '')
      .replaceAll(RegExp(r'\\.'), '')
      .replaceAll(RegExp(r'\[[^\]]*\]'), '')
      .toLowerCase();
  if (stripped.contains('general')) return false;
  return RegExp('[dmyhs]').hasMatch(stripped);
}

/// Excel serial date → DateTime (date only when there is no time part).
DateTime excelSerialToDate(double serial, {bool date1904 = false}) {
  final base = date1904 ? DateTime(1904, 1, 1) : DateTime(1899, 12, 30);
  final days = serial.floor();
  final ms = ((serial - days) * Duration.millisecondsPerDay).round();
  final day = DateTime(base.year, base.month, base.day + days);
  if (ms == 0) return day;
  final t = Duration(milliseconds: ms);
  return DateTime(day.year, day.month, day.day, t.inHours, t.inMinutes % 60);
}

/// Reads across a record and its CONTINUE records (BIFF8 strings restart
/// their compression flag at each CONTINUE boundary).
class _Reader {
  _Reader(this.parts);

  final List<Uint8List> parts;
  int _part = 0;
  int _pos = 0;

  bool get atEnd => _part >= parts.length || (_part == parts.length - 1 && _pos >= parts[_part].length);

  void _normalize() {
    while (_part < parts.length && _pos >= parts[_part].length) {
      _part++;
      _pos = 0;
    }
  }

  int u8() {
    _normalize();
    if (_part >= parts.length) throw XlsFormatException('unexpected end');
    return parts[_part][_pos++];
  }

  int u16() => u8() | (u8() << 8);
  int u32() => u16() | (u16() << 16);

  _Reader skip(int n) {
    for (var i = 0; i < n; i++) {
      u8();
    }
    return this;
  }

  String _chars(int count, bool wide) {
    final units = <int>[];
    var isWide = wide;
    for (var i = 0; i < count; i++) {
      if (_part < parts.length && _pos >= parts[_part].length && _part + 1 < parts.length) {
        // continued string: new compression flag at the boundary
        _part++;
        _pos = 0;
        isWide = (u8() & 0x01) != 0;
      }
      units.add(isWide ? u16() : u8());
    }
    // Compressed characters are the low bytes of UTF-16 (Latin-1).
    return String.fromCharCodes(units);
  }

  /// XLUnicodeString with a 16-bit length (LABEL, FORMAT, STRING).
  String unicodeString16() {
    final count = u16();
    final flags = u8();
    return _chars(count, flags & 0x01 != 0);
  }

  /// XLUnicodeRichExtendedString (SST entries).
  String richString16() {
    final count = u16();
    final flags = u8();
    final runs = flags & 0x08 != 0 ? u16() : 0;
    final ext = flags & 0x04 != 0 ? u32() : 0;
    final text = _chars(count, flags & 0x01 != 0);
    skip(runs * 4 + ext);
    return text;
  }
}
