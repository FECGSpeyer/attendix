import 'dart:convert' show latin1;
import 'dart:typed_data';

import 'package:archive/archive.dart' show ZLibDecoder;

part 'pdf_page_reader.dart';
part 'pdf_page_writer.dart';

/// Thrown when a PDF cannot be imported as vector pages (damaged, encrypted,
/// unsupported filter, no pages). Callers fall back to rasterising the file.
class PdfMergeException implements Exception {
  PdfMergeException(this.message);

  final String message;

  @override
  String toString() => 'PdfMergeException: $message';
}

/// Page tree incomplete: retried once after an xref rebuild.
class _IncompleteTree extends PdfMergeException {
  _IncompleteTree(super.message);
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

/// Name incl. leading slash, decoded (`/Media#42ox` → `/MediaBox`), so
/// comparisons and dictionary keys see the real name. Re-escaped on write.
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

int _hexVal(int c) {
  if (c >= 0x30 && c <= 0x39) return c - 0x30;
  if (c >= 0x41 && c <= 0x46) return c - 0x37;
  if (c >= 0x61 && c <= 0x66) return c - 0x57;
  return -1;
}

/// Decodes `#xx` escapes of a name token (incl. leading slash). A `#` not
/// followed by two hex digits stays literal (PDF 1.1 names).
String _decodeName(Uint8List raw) {
  if (!raw.contains(0x23)) return latin1.decode(raw);
  final out = <int>[];
  for (var i = 0; i < raw.length; i++) {
    final c = raw[i];
    if (c == 0x23 && i + 2 < raw.length) {
      final hi = _hexVal(raw[i + 1]);
      final lo = _hexVal(raw[i + 2]);
      if (hi >= 0 && lo >= 0) {
        out.add(hi * 16 + lo);
        i += 2;
        continue;
      }
    }
    out.add(c);
  }
  return latin1.decode(out);
}

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
      return _Name(_decodeName(Uint8List.sublistView(b, start, pos)));
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
