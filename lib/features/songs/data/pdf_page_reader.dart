part of 'pdf_page_merger.dart';

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

  /// Object [num] that must exist (page tree, content, resources). A missing
  /// object triggers one xref rebuild by scanning, then throws.
  _V requireObject(int num) {
    var v = object(num);
    if (v == null && !_reconstructed) {
      _reconstruct();
      v = object(num);
    }
    return v ?? (throw PdfMergeException('object $num missing'));
  }

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

  /// All pages in order. An incomplete page tree (missing node, `/Count`
  /// mismatch) is retried once after an xref rebuild, then throws – never
  /// returns a shortened document.
  List<_PageInfo> pages() {
    try {
      return _walkPages();
    } on _IncompleteTree {
      if (_reconstructed) rethrow;
      _reconstruct();
      return _walkPages();
    }
  }

  List<_PageInfo> _walkPages() {
    final root = deref(_trailer['/Root']);
    if (root is! _Dict) throw _IncompleteTree('no catalog');
    // Layers and form fields live in the catalog and are not carried over
    // (hidden layers would show, fields lack their fonts): rasterise instead.
    for (final key in const ['/OCProperties', '/AcroForm']) {
      final v = root[key];
      if (v != null && v is! _Null) throw PdfMergeException('catalog has $key');
    }
    final treeRef = root['/Pages'];
    if (treeRef is! _Ref) throw _IncompleteTree('no page tree');
    final result = <_PageInfo>[];
    final visited = <int>{treeRef.num};
    _Dict? treeRoot;
    void walk(int num, Map<String, _V> inherited, int depth) {
      if (depth > 64) throw PdfMergeException('page tree too deep');
      final node = object(num);
      if (node is! _Dict) throw _IncompleteTree('page tree node $num missing');
      treeRoot ??= node;
      final kids = deref(node['/Kids']);
      final type = node['/Type'];
      if (_isName(type, '/Pages') || (!_isName(type, '/Page') && kids is _Arr)) {
        if (kids is! _Arr) throw _IncompleteTree('/Kids of $num missing');
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
    // `/Pages` pointing straight at a single page has no /Count.
    if (result.length == 1 && identical(result.first.dict, treeRoot)) return result;
    final count = deref(treeRoot!['/Count']);
    if (count is! _Num || count.asInt != result.length) {
      throw _IncompleteTree('/Count does not match ${result.length} pages');
    }
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
