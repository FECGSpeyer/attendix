import 'dart:convert' show latin1;
import 'dart:typed_data';

import 'package:archive/archive.dart' show ZLibDecoder;

/// Thrown when a PDF cannot be imported as vector pages (damaged, encrypted,
/// unsupported filter, no pages). Callers fall back to rasterising the file.
class PdfMergeException implements Exception {
  PdfMergeException(this.message);

  final String message;

  @override
  String toString() => 'PdfMergeException: $message';
}

/// Merges existing PDF documents page by page into one new PDF without
/// re-rendering them – the counterpart of pdf-lib `copyPages` that Ionic
/// `PrintService.mergeEntries` uses. Pages keep their content streams, fonts,
/// vector graphics and page size (MediaBox/CropBox/Rotate, inherited values
/// resolved).
///
/// Pure Dart (only `archive` for Flate), so the same code runs on iOS,
/// Android, macOS and web.
///
/// Supports classic xref tables, xref streams, object streams, incremental
/// updates and rebuilds the xref by scanning when offsets are broken.
/// Encrypted files throw [PdfMergeException].
class PdfPageMerger {
  /// Object bodies by object number. 0 is unused, 1 = catalog, 2 = page tree.
  final List<Uint8List?> _objects = [null, null, null];
  final List<int> _kids = [];

  /// Pages added so far (all copies).
  int get pageCount => _kids.length;

  /// Appends all pages of [bytes] [copies] times (pages 1..n, 1..n, …).
  /// Returns the number of pages added. Either all pages are added or none
  /// (throws [PdfMergeException] / [FormatException] on failure).
  int addPdf(Uint8List bytes, {int copies = 1}) {
    if (copies <= 0) return 0;
    final reader = _PdfReader(bytes);
    final pages = reader.pages();
    if (pages.isEmpty) throw PdfMergeException('no pages');

    final copier = _Copier(reader, _objects.length);
    final firstCopy = [for (final p in pages) copier.reserve(p.num)];
    final bodies = [for (final p in pages) copier.pageBody(p)];
    for (var i = 0; i < pages.length; i++) {
      copier.out[firstCopy[i]] = bodies[i];
    }
    copier.drain();

    // Further copies share content and resources, only the page dict repeats.
    final kids = [...firstCopy];
    for (var c = 1; c < copies; c++) {
      for (final body in bodies) {
        final n = copier.next++;
        copier.out[n] = body;
        kids.add(n);
      }
    }

    // Commit (nothing above touched the merger state).
    for (var n = _objects.length; n < copier.next; n++) {
      final body = copier.out[n];
      if (body == null) throw PdfMergeException('object $n missing');
      _objects.add(body);
    }
    _kids.addAll(kids);
    return kids.length;
  }

  /// Serialises the merged document (classic xref table, PDF 1.7).
  Uint8List save() {
    if (_kids.isEmpty) throw StateError('no pages');
    _objects[1] = _ascii('<< /Type /Catalog /Pages 2 0 R >>');
    _objects[2] = _ascii(
        '<< /Type /Pages /Kids [${_kids.map((k) => '$k 0 R').join(' ')}] /Count ${_kids.length} >>');

    final out = BytesBuilder(copy: false);
    out.add(_ascii('%PDF-1.7\n'));
    out.add(const [0x25, 0xE2, 0xE3, 0xCF, 0xD3, 0x0A]);
    final offsets = List<int>.filled(_objects.length, 0);
    for (var i = 1; i < _objects.length; i++) {
      offsets[i] = out.length;
      out.add(_ascii('$i 0 obj\n'));
      out.add(_objects[i]!);
      out.add(_ascii('\nendobj\n'));
    }
    final xref = out.length;
    final table = StringBuffer('xref\n0 ${_objects.length}\n0000000000 65535 f\r\n');
    for (var i = 1; i < _objects.length; i++) {
      table.write('${offsets[i].toString().padLeft(10, '0')} 00000 n\r\n');
    }
    table.write('trailer\n<< /Size ${_objects.length} /Root 1 0 R >>\n'
        'startxref\n$xref\n%%EOF\n');
    out.add(_ascii(table.toString()));
    return out.takeBytes();
  }
}

Uint8List _ascii(String s) => latin1.encode(s);

// ---------------------------------------------------------------------------
// Object model
// ---------------------------------------------------------------------------

sealed class _V {
  const _V();
}

final class _Null extends _V {
  const _Null();
}

final class _Bool extends _V {
  const _Bool(this.value);
  final bool value;
}

final class _Num extends _V {
  const _Num(this.raw);
  final String raw;
  int? get asInt => int.tryParse(raw) ?? double.tryParse(raw)?.toInt();
}

/// Name incl. leading slash, raw (escapes kept).
final class _Name extends _V {
  const _Name(this.raw);
  final String raw;
}

/// String token incl. delimiters, copied verbatim.
final class _Str extends _V {
  const _Str(this.raw);
  final Uint8List raw;
}

final class _Arr extends _V {
  const _Arr(this.items);
  final List<_V> items;
}

final class _Dict extends _V {
  const _Dict(this.map);
  final Map<String, _V> map;
  _V? operator [](String key) => map[key];
}

final class _Stream extends _V {
  const _Stream(this.dict, this.data);
  final _Dict dict;
  final Uint8List data;
}

final class _Ref extends _V {
  const _Ref(this.num);
  final int num;
}

/// Writer-only literal.
final class _Raw extends _V {
  const _Raw(this.text);
  final String text;
}

bool _isName(_V? v, String raw) => v is _Name && v.raw == raw;

// ---------------------------------------------------------------------------
// Lexer / parser
// ---------------------------------------------------------------------------

bool _isWs(int c) => c == 0 || c == 9 || c == 10 || c == 12 || c == 13 || c == 32;

bool _isDelim(int c) =>
    c == 0x28 || c == 0x29 || c == 0x3C || c == 0x3E || c == 0x5B || c == 0x5D ||
    c == 0x7B || c == 0x7D || c == 0x2F || c == 0x25;

bool _isRegular(int c) => !_isWs(c) && !_isDelim(c);

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

bool _isNumChar(int c) => _isDigit(c) || c == 0x2B || c == 0x2D || c == 0x2E;

class _Lexer {
  _Lexer(this.b, this.pos);

  final Uint8List b;
  int pos;
  int _depth = 0;

  FormatException _err(String msg) => FormatException(msg, null, pos);

  void skipWs() {
    while (pos < b.length) {
      final c = b[pos];
      if (_isWs(c)) {
        pos++;
      } else if (c == 0x25) {
        while (pos < b.length && b[pos] != 10 && b[pos] != 13) {
          pos++;
        }
      } else {
        break;
      }
    }
  }

  String readToken() {
    skipWs();
    final start = pos;
    while (pos < b.length && _isRegular(b[pos])) {
      pos++;
    }
    if (start == pos) throw _err('token expected');
    return latin1.decode(Uint8List.sublistView(b, start, pos));
  }

  int readInt() {
    final t = readToken();
    return int.tryParse(t) ?? (throw _err('integer expected'));
  }

  /// True if [kw] follows (after whitespace); does not consume it.
  bool peekKeyword(String kw) {
    skipWs();
    if (pos + kw.length > b.length) return false;
    for (var i = 0; i < kw.length; i++) {
      if (b[pos + i] != kw.codeUnitAt(i)) return false;
    }
    final after = pos + kw.length;
    return after >= b.length || !_isRegular(b[after]);
  }

  _V parseValue() {
    skipWs();
    if (pos >= b.length) throw _err('unexpected end');
    final c = b[pos];
    if (c == 0x2F) {
      final start = pos++;
      while (pos < b.length && _isRegular(b[pos])) {
        pos++;
      }
      return _Name(latin1.decode(Uint8List.sublistView(b, start, pos)));
    }
    if (c == 0x28) return _literal();
    if (c == 0x3C) {
      if (pos + 1 < b.length && b[pos + 1] == 0x3C) return _dict();
      final start = pos;
      while (pos < b.length && b[pos] != 0x3E) {
        pos++;
      }
      if (pos >= b.length) throw _err('unterminated hex string');
      pos++;
      return _Str(Uint8List.sublistView(b, start, pos));
    }
    if (c == 0x5B) return _array();
    if (_isNumChar(c)) return _number();
    final save = pos;
    final kw = readToken();
    switch (kw) {
      case 'true':
        return const _Bool(true);
      case 'false':
        return const _Bool(false);
      case 'null':
        return const _Null();
      case 'endobj':
        pos = save; // `n 0 obj endobj` → null object
        return const _Null();
    }
    throw _err('unexpected keyword $kw');
  }

  void _enter() {
    if (++_depth > 256) throw _err('nesting too deep');
  }

  _V _dict() {
    _enter();
    pos += 2;
    final map = <String, _V>{};
    while (true) {
      skipWs();
      if (pos + 1 >= b.length) throw _err('unterminated dict');
      if (b[pos] == 0x3E && b[pos + 1] == 0x3E) {
        pos += 2;
        break;
      }
      final key = parseValue();
      if (key is! _Name) throw _err('dict key expected');
      map[key.raw] = parseValue();
    }
    _depth--;
    return _Dict(map);
  }

  _V _array() {
    _enter();
    pos++;
    final items = <_V>[];
    while (true) {
      skipWs();
      if (pos >= b.length) throw _err('unterminated array');
      if (b[pos] == 0x5D) {
        pos++;
        break;
      }
      items.add(parseValue());
    }
    _depth--;
    return _Arr(items);
  }

  _V _literal() {
    final start = pos;
    var depth = 0;
    while (pos < b.length) {
      final c = b[pos];
      if (c == 0x5C) {
        pos += 2;
        continue;
      }
      if (c == 0x28) {
        depth++;
      } else if (c == 0x29) {
        depth--;
        if (depth == 0) {
          pos++;
          return _Str(Uint8List.sublistView(b, start, pos));
        }
      }
      pos++;
    }
    throw _err('unterminated string');
  }

  _V _number() {
    final start = pos;
    while (pos < b.length && _isNumChar(b[pos])) {
      pos++;
    }
    final raw = latin1.decode(Uint8List.sublistView(b, start, pos));
    final asInt = int.tryParse(raw);
    if (asInt != null && asInt >= 0 && _isDigit(b[start])) {
      // Lookahead for `num gen R`.
      final save = pos;
      skipWs();
      final genStart = pos;
      while (pos < b.length && _isDigit(b[pos])) {
        pos++;
      }
      if (pos > genStart) {
        skipWs();
        if (pos < b.length &&
            b[pos] == 0x52 &&
            (pos + 1 >= b.length || !_isRegular(b[pos + 1]))) {
          pos++;
          return _Ref(asInt);
        }
      }
      pos = save;
    }
    if (double.tryParse(raw) == null && asInt == null) {
      // Malformed number like `--5` or `.`: keep as 0 (viewers do likewise).
      return const _Num('0');
    }
    return _Num(raw);
  }
}

// ---------------------------------------------------------------------------
// Reader
// ---------------------------------------------------------------------------

class _XrefEntry {
  const _XrefEntry.direct(this.offset)
      : stream = null,
        index = 0;
  const _XrefEntry.compressed(int this.stream, this.index) : offset = 0;

  final int offset;
  final int? stream;
  final int index;
}

class _PageInfo {
  const _PageInfo(this.num, this.dict, this.inherited);

  final int num;
  final _Dict dict;
  final Map<String, _V> inherited;
}

const _inheritable = ['/Resources', '/MediaBox', '/CropBox', '/Rotate'];

class _PdfReader {
  _PdfReader(this.b) {
    final head = b.length < 1024 ? b.length : 1024;
    if (_indexOf(b, _ascii('%PDF-'), 0, head) < 0) {
      throw PdfMergeException('not a PDF');
    }
    try {
      _readXref();
    } catch (_) {
      _reconstruct();
    }
    if (_trailer['/Encrypt'] != null && _trailer['/Encrypt'] is! _Null) {
      throw PdfMergeException('encrypted');
    }
  }

  final Uint8List b;
  final Map<int, _XrefEntry> _xref = {};
  _Dict _trailer = const _Dict({});
  bool _reconstructed = false;

  /// While scanning for objects no indirect /Length is resolved.
  bool _scanning = false;
  final Map<int, _V?> _cache = {};
  final Map<int, _ObjStm> _objStms = {};
  final Set<int> _loading = {};

  // --- xref ----------------------------------------------------------------

  void _readXref() {
    final sx = _lastIndexOf(b, _ascii('startxref'));
    if (sx < 0) throw PdfMergeException('no startxref');
    int? offset = _Lexer(b, sx + 9).readInt();
    final visited = <int>{};
    _Dict? first;
    while (offset != null && visited.add(offset)) {
      final trailer = _readXrefSection(offset);
      first ??= trailer;
      final stm = trailer['/XRefStm'];
      if (stm is _Num && stm.asInt != null && visited.add(stm.asInt!)) {
        _readXrefSection(stm.asInt!);
      }
      final prev = trailer['/Prev'];
      offset = prev is _Num ? prev.asInt : null;
    }
    if (first == null || first['/Root'] is! _Ref) {
      throw PdfMergeException('no root');
    }
    _trailer = first;
  }

  _Dict _readXrefSection(int offset) {
    if (offset < 0 || offset >= b.length) throw PdfMergeException('bad xref offset');
    final lx = _Lexer(b, offset);
    if (lx.peekKeyword('xref')) {
      lx.pos += 4;
      while (true) {
        if (lx.peekKeyword('trailer')) {
          lx.pos += 7;
          final t = lx.parseValue();
          if (t is! _Dict) throw PdfMergeException('bad trailer');
          return t;
        }
        final start = lx.readInt();
        final count = lx.readInt();
        for (var i = 0; i < count; i++) {
          final off = lx.readInt();
          lx.readInt(); // generation
          final kind = lx.readToken();
          if (kind == 'n' && off > 0) {
            _xref.putIfAbsent(start + i, () => _XrefEntry.direct(off));
          }
        }
      }
    }

    // Cross-reference stream
    final obj = _parseIndirect(offset, null).value;
    if (obj is! _Stream || !_isName(obj.dict['/Type'], '/XRef')) {
      throw PdfMergeException('no xref');
    }
    final d = obj.dict;
    final w = d['/W'];
    if (w is! _Arr || w.items.length != 3) throw PdfMergeException('bad /W');
    final widths = [for (final x in w.items) x is _Num ? (x.asInt ?? 0) : 0];
    final size = (d['/Size'] as _Num?)?.asInt ?? 0;
    final idx = d['/Index'];
    final ranges = <int>[];
    if (idx is _Arr) {
      for (final x in idx.items) {
        ranges.add(x is _Num ? (x.asInt ?? 0) : 0);
      }
    } else {
      ranges.addAll([0, size]);
    }
    final data = _decode(obj);
    final rowLen = widths[0] + widths[1] + widths[2];
    if (rowLen <= 0) throw PdfMergeException('bad /W');
    var p = 0;
    int field(int width, int def) {
      if (width == 0) return def;
      var v = 0;
      for (var i = 0; i < width; i++) {
        v = v * 256 + data[p++]; // no bit ops: 32-bit on the web
      }
      return v;
    }

    for (var r = 0; r + 1 < ranges.length; r += 2) {
      final start = ranges[r];
      final count = ranges[r + 1];
      for (var i = 0; i < count; i++) {
        if (p + rowLen > data.length) throw PdfMergeException('short xref stream');
        final type = field(widths[0], 1);
        final f2 = field(widths[1], 0);
        final f3 = field(widths[2], 0);
        if (type == 1 && f2 > 0) {
          _xref.putIfAbsent(start + i, () => _XrefEntry.direct(f2));
        } else if (type == 2) {
          _xref.putIfAbsent(start + i, () => _XrefEntry.compressed(f2, f3));
        }
      }
    }
    return d;
  }

  /// Rebuilds the xref by scanning for `n g obj` (damaged files).
  void _reconstruct() {
    _reconstructed = true;
    _scanning = true;
    _xref.clear();
    _cache.clear();
    _objStms.clear();
    final stmNums = <int>[];
    _Dict? xrefTrailer;
    int? catalog;
    try {
      var i = 0;
      while (true) {
        final at = _indexOf(b, _ascii('obj'), i, b.length);
        if (at < 0) break;
        i = at + 3;
        if (at == 0 || !_isWs(b[at - 1])) continue;
        if (at + 3 < b.length && _isRegular(b[at + 3])) continue;
        var j = at - 1;
        while (j >= 0 && _isWs(b[j])) {
          j--;
        }
        final genEnd = j;
        while (j >= 0 && _isDigit(b[j])) {
          j--;
        }
        if (j == genEnd || j < 0 || !_isWs(b[j])) continue;
        while (j >= 0 && _isWs(b[j])) {
          j--;
        }
        final numEnd = j;
        while (j >= 0 && _isDigit(b[j])) {
          j--;
        }
        if (j == numEnd) continue;
        if (j >= 0 && _isRegular(b[j])) continue;
        final start = j + 1;
        try {
          final parsed = _parseIndirect(start, null);
          _xref[parsed.num] = _XrefEntry.direct(start);
          final v = parsed.value;
          final dict = v is _Stream ? v.dict : (v is _Dict ? v : null);
          if (dict != null) {
            if (_isName(dict['/Type'], '/ObjStm')) stmNums.add(parsed.num);
            if (_isName(dict['/Type'], '/XRef')) xrefTrailer = dict;
            if (_isName(dict['/Type'], '/Catalog')) catalog = parsed.num;
          }
          i = parsed.end;
        } catch (_) {
          // not an object header (e.g. inside binary data)
        }
      }
    } finally {
      _scanning = false;
    }

    for (final s in stmNums) {
      try {
        final stm = _objStm(s);
        for (final entry in stm.offsets.entries) {
          _xref.putIfAbsent(entry.key, () => _XrefEntry.compressed(s, 0));
        }
      } catch (_) {
        // damaged object stream: skip
      }
    }

    _Dict? trailer;
    final t = _lastIndexOf(b, _ascii('trailer'));
    if (t >= 0) {
      try {
        final v = _Lexer(b, t + 7).parseValue();
        if (v is _Dict && v['/Root'] is _Ref) trailer = v;
      } catch (_) {}
    }
    if (trailer == null && xrefTrailer != null && xrefTrailer['/Root'] is _Ref) {
      trailer = xrefTrailer;
    }
    if (trailer == null && catalog != null) {
      trailer = _Dict({'/Root': _Ref(catalog)});
    }
    if (trailer == null) throw PdfMergeException('no root');
    _trailer = trailer;
  }

  // --- objects -------------------------------------------------------------

  ({int num, _V value, int end}) _parseIndirect(int offset, int? expectNum) {
    final lx = _Lexer(b, offset);
    final num = lx.readInt();
    lx.readInt();
    if (lx.readToken() != 'obj') throw PdfMergeException('obj expected');
    if (expectNum != null && num != expectNum) {
      throw PdfMergeException('xref points to object $num instead of $expectNum');
    }
    final value = lx.parseValue();
    if (value is _Dict && lx.peekKeyword('stream')) {
      lx.pos += 6;
      if (lx.pos < b.length && b[lx.pos] == 13) lx.pos++;
      if (lx.pos < b.length && b[lx.pos] == 10) lx.pos++;
      final start = lx.pos;
      final len = _streamLength(value);
      int end;
      if (len != null && len >= 0 && start + len <= b.length && _endstreamAt(start + len)) {
        end = start + len;
      } else {
        final es = _indexOf(b, _ascii('endstream'), start, b.length);
        if (es < 0) throw PdfMergeException('endstream missing');
        end = es;
        if (end > start && b[end - 1] == 10) end--;
        if (end > start && b[end - 1] == 13) end--;
      }
      final es = _indexOf(b, _ascii('endstream'), end, b.length);
      return (num: num, value: _Stream(value, Uint8List.sublistView(b, start, end)), end: es + 9);
    }
    return (num: num, value: value, end: lx.pos);
  }

  bool _endstreamAt(int p) {
    final lx = _Lexer(b, p);
    return lx.peekKeyword('endstream');
  }

  int? _streamLength(_Dict dict) {
    final v = dict['/Length'];
    if (v is _Num) return v.asInt;
    if (v is _Ref && !_scanning) {
      try {
        final l = object(v.num);
        if (l is _Num) return l.asInt;
      } catch (_) {}
    }
    return null;
  }

  /// Object [num] or null when it does not exist.
  _V? object(int num) {
    if (_cache.containsKey(num)) return _cache[num];
    if (!_loading.add(num)) throw PdfMergeException('reference cycle at $num');
    try {
      final v = _load(num);
      _cache[num] = v;
      return v;
    } finally {
      _loading.remove(num);
    }
  }

  _V? _load(int num) {
    final e = _xref[num];
    if (e == null) return null;
    try {
      final stream = e.stream;
      if (stream == null) return _parseIndirect(e.offset, num).value;
      return _objStm(stream).get(num, e.index);
    } catch (_) {
      if (_reconstructed) rethrow;
      _reconstruct();
      return _load(num);
    }
  }

  _V? deref(_V? v) => v is _Ref ? object(v.num) : v;

  _ObjStm _objStm(int num) {
    final cached = _objStms[num];
    if (cached != null) return cached;
    final _V? obj;
    if (_scanning) {
      final e = _xref[num];
      obj = e == null ? null : _parseIndirect(e.offset, num).value;
    } else {
      obj = object(num);
    }
    if (obj is! _Stream) throw PdfMergeException('object stream $num missing');
    final n = (obj.dict['/N'] as _Num?)?.asInt ?? 0;
    final first = (obj.dict['/First'] as _Num?)?.asInt ?? 0;
    final data = _decode(obj);
    final lx = _Lexer(data, 0);
    final offsets = <int, int>{};
    final order = <int>[];
    for (var i = 0; i < n; i++) {
      final objNum = lx.readInt();
      final off = lx.readInt();
      offsets.putIfAbsent(objNum, () => first + off);
      order.add(objNum);
    }
    return _objStms[num] = _ObjStm(data, offsets, order);
  }

  Uint8List _decode(_Stream s) {
    final f = s.dict['/Filter'];
    final filters = f is _Arr ? f.items : (f == null ? const <_V>[] : [f]);
    var data = s.data;
    for (final filter in filters) {
      if (_isName(filter, '/FlateDecode') || _isName(filter, '/Fl')) {
        data = const ZLibDecoder().decodeBytes(data);
      } else {
        throw PdfMergeException('unsupported filter');
      }
    }
    var parms = s.dict['/DecodeParms'];
    if (parms is _Arr) parms = parms.items.isEmpty ? null : parms.items.first;
    if (parms is _Dict) {
      final predictor = (parms['/Predictor'] as _Num?)?.asInt ?? 1;
      if (predictor >= 10) {
        final columns = (parms['/Columns'] as _Num?)?.asInt ?? 1;
        final colors = (parms['/Colors'] as _Num?)?.asInt ?? 1;
        final bpc = (parms['/BitsPerComponent'] as _Num?)?.asInt ?? 8;
        data = _unpredictPng(data, columns, colors, bpc);
      } else if (predictor != 1) {
        throw PdfMergeException('unsupported predictor');
      }
    }
    return data;
  }

  static Uint8List _unpredictPng(Uint8List data, int columns, int colors, int bpc) {
    final bpp = ((colors * bpc) / 8).ceil().clamp(1, 16);
    final rowLen = ((columns * colors * bpc) / 8).ceil();
    final rows = data.length ~/ (rowLen + 1);
    final out = Uint8List(rows * rowLen);
    for (var r = 0; r < rows; r++) {
      final type = data[r * (rowLen + 1)];
      final src = r * (rowLen + 1) + 1;
      final dst = r * rowLen;
      for (var i = 0; i < rowLen; i++) {
        final raw = data[src + i];
        final left = i >= bpp ? out[dst + i - bpp] : 0;
        final up = r > 0 ? out[dst - rowLen + i] : 0;
        final upLeft = (r > 0 && i >= bpp) ? out[dst - rowLen + i - bpp] : 0;
        int v;
        switch (type) {
          case 0:
            v = raw;
          case 1:
            v = raw + left;
          case 2:
            v = raw + up;
          case 3:
            v = raw + ((left + up) >> 1);
          case 4:
            final p = left + up - upLeft;
            final pa = (p - left).abs();
            final pb = (p - up).abs();
            final pc = (p - upLeft).abs();
            v = raw + ((pa <= pb && pa <= pc) ? left : (pb <= pc ? up : upLeft));
          default:
            throw PdfMergeException('bad PNG predictor');
        }
        out[dst + i] = v & 0xFF;
      }
    }
    return out;
  }

  // --- pages ---------------------------------------------------------------

  List<_PageInfo> pages() {
    final root = deref(_trailer['/Root']);
    if (root is! _Dict) throw PdfMergeException('no catalog');
    final treeRef = root['/Pages'];
    if (treeRef is! _Ref) throw PdfMergeException('no page tree');
    final result = <_PageInfo>[];
    final visited = <int>{treeRef.num};
    void walk(int num, Map<String, _V> inherited, int depth) {
      if (depth > 64) throw PdfMergeException('page tree too deep');
      final node = object(num);
      if (node is! _Dict) return;
      final kids = deref(node['/Kids']);
      final type = node['/Type'];
      if (_isName(type, '/Pages') || (!_isName(type, '/Page') && kids is _Arr)) {
        if (kids is! _Arr) return;
        final inh = {...inherited};
        for (final k in _inheritable) {
          final v = node[k];
          if (v != null) inh[k] = v;
        }
        for (final kid in kids.items) {
          if (kid is! _Ref) throw PdfMergeException('direct page object');
          if (!visited.add(kid.num)) continue;
          walk(kid.num, inh, depth + 1);
        }
      } else {
        result.add(_PageInfo(num, node, inherited));
      }
    }

    walk(treeRef.num, const {}, 0);
    return result;
  }
}

class _ObjStm {
  _ObjStm(this.data, this.offsets, this.order);

  final Uint8List data;
  final Map<int, int> offsets;
  final List<int> order;

  _V get(int num, int index) {
    var off = offsets[num];
    if (off == null && index < order.length) off = offsets[order[index]];
    if (off == null) throw PdfMergeException('object $num not in stream');
    return _Lexer(data, off).parseValue();
  }
}

// ---------------------------------------------------------------------------
// Copier: renumbers and serialises everything reachable from the pages
// ---------------------------------------------------------------------------

class _Copier {
  _Copier(this.reader, this.next);

  final _PdfReader reader;

  /// Next free object number in the merged document.
  int next;

  /// Bodies of allocated objects (new number → bytes).
  final Map<int, Uint8List> out = {};
  final Map<int, int> _map = {};
  final Set<int> _nulled = {};
  final List<int> _queue = [];

  /// Reserves the merged object number of source page [oldNum] so that
  /// references to it (links, annotation /P) point to the copy.
  int reserve(int oldNum) {
    final n = next++;
    _map[oldNum] = n;
    return n;
  }

  Uint8List pageBody(_PageInfo page) {
    final m = <String, _V>{};
    page.dict.map.forEach((k, v) {
      // /Parent is replaced, /B (beads) points to catalog-level threads.
      if (k != '/Parent' && k != '/B') m[k] = v;
    });
    for (final k in _inheritable) {
      if (!m.containsKey(k) && page.inherited[k] != null) m[k] = page.inherited[k]!;
    }
    m['/Type'] = const _Name('/Page');
    m.putIfAbsent('/MediaBox',
        () => const _Arr([_Num('0'), _Num('0'), _Num('612'), _Num('792')]));
    m.putIfAbsent('/Resources', () => const _Dict({}));
    m['/Parent'] = const _Raw('2 0 R');
    final o = BytesBuilder(copy: false);
    _write(o, _Dict(m));
    return o.takeBytes();
  }

  void drain() {
    while (_queue.isNotEmpty) {
      final old = _queue.removeLast();
      final obj = reader.object(old)!;
      final o = BytesBuilder(copy: false);
      if (obj is _Stream) {
        final d = <String, _V>{};
        obj.dict.map.forEach((k, v) {
          if (k != '/Length' && k != '/F' && k != '/FFilter' && k != '/FDecodeParms') {
            d[k] = v;
          }
        });
        d['/Length'] = _Num('${obj.data.length}');
        _write(o, _Dict(d));
        o.add(_ascii('\nstream\n'));
        o.add(obj.data);
        o.add(_ascii('\nendstream'));
      } else {
        _write(o, obj);
      }
      out[_map[old]!] = o.takeBytes();
    }
  }

  /// New number for source object [oldNum], or null when the reference must
  /// become `null` (missing object, or a page tree / catalog / foreign page
  /// that would drag the whole source document along).
  int? _ref(int oldNum) {
    final mapped = _map[oldNum];
    if (mapped != null) return mapped;
    if (_nulled.contains(oldNum)) return null;
    final obj = reader.object(oldNum);
    final dict = obj is _Dict ? obj : null;
    if (obj == null ||
        _isName(dict?['/Type'], '/Pages') ||
        _isName(dict?['/Type'], '/Page') ||
        _isName(dict?['/Type'], '/Catalog')) {
      _nulled.add(oldNum);
      return null;
    }
    final n = next++;
    _map[oldNum] = n;
    _queue.add(oldNum);
    return n;
  }

  static final _space = _ascii(' ');

  void _write(BytesBuilder o, _V v) {
    switch (v) {
      case _Null():
        o.add(_ascii('null'));
      case _Bool(:final value):
        o.add(_ascii(value ? 'true' : 'false'));
      case _Num(:final raw):
        o.add(_ascii(raw));
      case _Name(:final raw):
        o.add(_ascii(raw));
      case _Str(:final raw):
        o.add(raw);
      case _Raw(:final text):
        o.add(_ascii(text));
      case _Ref(:final num):
        final n = _ref(num);
        o.add(_ascii(n == null ? 'null' : '$n 0 R'));
      case _Arr(:final items):
        o.add(_ascii('['));
        for (var i = 0; i < items.length; i++) {
          if (i > 0) o.add(_space);
          _write(o, items[i]);
        }
        o.add(_ascii(']'));
      case _Dict(:final map):
        o.add(_ascii('<<'));
        map.forEach((k, value) {
          o.add(_space);
          o.add(_ascii(k));
          o.add(_space);
          _write(o, value);
        });
        o.add(_ascii(' >>'));
      case _Stream():
        throw PdfMergeException('direct stream');
    }
  }
}

// ---------------------------------------------------------------------------
// Byte search
// ---------------------------------------------------------------------------

int _indexOf(Uint8List b, Uint8List pattern, int start, int end) {
  final last = end - pattern.length;
  final first = pattern[0];
  outer:
  for (var i = start < 0 ? 0 : start; i <= last; i++) {
    if (b[i] != first) continue;
    for (var j = 1; j < pattern.length; j++) {
      if (b[i + j] != pattern[j]) continue outer;
    }
    return i;
  }
  return -1;
}

int _lastIndexOf(Uint8List b, Uint8List pattern) {
  outer:
  for (var i = b.length - pattern.length; i >= 0; i--) {
    for (var j = 0; j < pattern.length; j++) {
      if (b[i + j] != pattern[j]) continue outer;
    }
    return i;
  }
  return -1;
}
