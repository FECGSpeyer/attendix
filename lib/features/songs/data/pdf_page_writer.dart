part of 'pdf_page_merger.dart';

/// Serialises a decoded name: `#`, delimiters, whitespace and non-printable
/// bytes become `#xx`.
Uint8List _encodeName(String name) {
  final out = <int>[0x2F];
  for (var i = 1; i < name.length; i++) {
    final c = name.codeUnitAt(i);
    if (c < 0x21 || c > 0x7E || c == 0x23 || _isDelim(c)) {
      out
        ..add(0x23)
        ..addAll(_ascii(c.toRadixString(16).toUpperCase().padLeft(2, '0')));
    } else {
      out.add(c);
    }
  }
  return Uint8List.fromList(out);
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

  /// Page tree / catalog / foreign pages: written as `null`.
  final Set<int> _dropped = {};

  /// Source objects copied via [_ref] (not the reserved pages).
  final Set<int> _copied = {};

  /// Source objects reached from page content or resources: every reference
  /// inside them must resolve, otherwise the page would render incomplete.
  final Set<int> _required = {};
  final List<int> _queue = [];

  /// Page keys whose referenced objects must exist.
  static const _requiredPageKeys = {'/Contents', '/Resources', '/Group'};

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
    m.putIfAbsent('/MediaBox', () => const _Arr([_Num('0'), _Num('0'), _Num('612'), _Num('792')]));
    m.putIfAbsent('/Resources', () => const _Dict({}));
    m['/Parent'] = const _Raw('2 0 R');
    final o = BytesBuilder(copy: false);
    _writeDict(o, m, _requiredPageKeys.contains);
    return o.takeBytes();
  }

  void drain() {
    while (_queue.isNotEmpty) {
      final old = _queue.removeLast();
      final required = _required.contains(old);
      final obj = reader.requireObject(old);
      final o = BytesBuilder(copy: false);
      if (obj is _Stream) {
        final d = <String, _V>{};
        obj.dict.map.forEach((k, v) {
          if (k != '/Length' && k != '/F' && k != '/FFilter' && k != '/FDecodeParms') {
            d[k] = v;
          }
        });
        d['/Length'] = _Num('${obj.data.length}');
        _writeDict(o, d, (_) => required);
        o.add(_ascii('\nstream\n'));
        o.add(obj.data);
        o.add(_ascii('\nendstream'));
      } else {
        _write(o, obj, required);
      }
      out[_map[old]!] = o.takeBytes();
    }
  }

  /// New number for source object [oldNum], or null when the reference must
  /// become `null`: a page tree / catalog / foreign page that would drag the
  /// whole source document along, or a missing object on an optional path
  /// (annotations, metadata – the PDF spec reads it as null). A missing
  /// [required] object rebuilds the xref once, then throws.
  int? _ref(int oldNum, bool required) {
    final mapped = _map[oldNum];
    if (mapped != null) {
      // First reached optionally, now required: copy again with checks.
      if (required && _copied.contains(oldNum) && _required.add(oldNum)) {
        _queue.add(oldNum);
      }
      return mapped;
    }
    if (_dropped.contains(oldNum)) return null;
    final obj = required ? reader.requireObject(oldNum) : reader.object(oldNum);
    if (obj == null) return null;
    final dict = obj is _Dict ? obj : null;
    if (_isName(dict?['/Type'], '/Pages') ||
        _isName(dict?['/Type'], '/Page') ||
        _isName(dict?['/Type'], '/Catalog')) {
      _dropped.add(oldNum);
      return null;
    }
    final n = next++;
    _map[oldNum] = n;
    _copied.add(oldNum);
    if (required) _required.add(oldNum);
    _queue.add(oldNum);
    return n;
  }

  static final _space = _ascii(' ');

  void _writeDict(BytesBuilder o, Map<String, _V> map, bool Function(String key) required) {
    o.add(_ascii('<<'));
    map.forEach((k, value) {
      o.add(_space);
      o.add(_encodeName(k));
      o.add(_space);
      _write(o, value, required(k));
    });
    o.add(_ascii(' >>'));
  }

  void _write(BytesBuilder o, _V v, bool required) {
    switch (v) {
      case _Null():
        o.add(_ascii('null'));
      case _Bool(:final value):
        o.add(_ascii(value ? 'true' : 'false'));
      case _Num(:final raw):
        o.add(_ascii(raw));
      case _Name(:final raw):
        o.add(_encodeName(raw));
      case _Str(:final raw):
        o.add(raw);
      case _Raw(:final text):
        o.add(_ascii(text));
      case _Ref(:final num):
        final n = _ref(num, required);
        o.add(_ascii(n == null ? 'null' : '$n 0 R'));
      case _Arr(:final items):
        o.add(_ascii('['));
        for (var i = 0; i < items.length; i++) {
          if (i > 0) o.add(_space);
          _write(o, items[i], required);
        }
        o.add(_ascii(']'));
      case _Dict(:final map):
        _writeDict(o, map, (_) => required);
      case _Stream():
        throw PdfMergeException('direct stream');
    }
  }
}
