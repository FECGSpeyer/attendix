import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// A Word document (.docx) reduced to what the in-app viewer shows:
/// paragraphs with their formatting, lists, tables and embedded pictures.
///
/// DOCX_VIEWER: pure Dart (no native viewer), so it works the same on
/// iPhone, Android, Mac and the web. Page layout (margins, headers, footers,
/// text boxes, columns) is not kept, the text flows to the screen width.
class DocxDocument {
  final List<DocxBlock> blocks;

  const DocxDocument(this.blocks);

  /// Reads the bytes of a .docx file. Throws [FormatException] when they
  /// are not a Word document (e.g. an old binary .doc).
  static DocxDocument parse(Uint8List bytes) => _DocxParser(bytes).parse();
}

sealed class DocxBlock {
  const DocxBlock();
}

enum DocxAlign { left, center, right, justify }

class DocxParagraph extends DocxBlock {
  final List<DocxInline> inlines;
  final DocxAlign align;

  /// 1–6 for headings ("Überschrift 1" …), 0 for the title, null otherwise.
  final int? headingLevel;

  /// "1.", "a)", "•" … for list items, null otherwise.
  final String? listLabel;

  /// Nesting depth of a list item (0 = top level).
  final int listLevel;

  /// Left indent in points (besides lists).
  final double indent;

  const DocxParagraph({
    required this.inlines,
    this.align = DocxAlign.left,
    this.headingLevel,
    this.listLabel,
    this.listLevel = 0,
    this.indent = 0,
  });

  bool get isEmpty => inlines.every((i) => i is DocxText && i.text.isEmpty);
}

class DocxTable extends DocxBlock {
  final List<List<DocxCell>> rows;

  const DocxTable(this.rows);
}

class DocxCell {
  final List<DocxBlock> blocks;

  /// Number of grid columns the cell spans.
  final int span;

  const DocxCell(this.blocks, {this.span = 1});
}

sealed class DocxInline {
  const DocxInline();
}

class DocxText extends DocxInline {
  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;

  /// In points, null = document default.
  final double? fontSize;

  /// ARGB, null = automatic (black on the white page).
  final int? color;

  /// ARGB of a highlight / shading, null = none.
  final int? background;
  final bool superscript;
  final bool subscript;

  const DocxText(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.fontSize,
    this.color,
    this.background,
    this.superscript = false,
    this.subscript = false,
  });
}

class DocxImage extends DocxInline {
  final Uint8List bytes;

  /// Size in the document in logical pixels, null when unknown.
  final double? width;
  final double? height;

  const DocxImage(this.bytes, {this.width, this.height});
}

// ---------------------------------------------------------------------------

const _w = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
const _r = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
const _a = 'http://schemas.openxmlformats.org/drawingml/2006/main';
const _wp = 'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing';
const _v = 'urn:schemas-microsoft-com:vml';

/// Run formatting while it is resolved (null = inherited).
class _RunProps {
  bool? bold, italic, underline, strike, hidden, superscript, subscript;
  double? fontSize;
  int? color, background;

  _RunProps();

  _RunProps.copy(_RunProps o)
    : bold = o.bold,
      italic = o.italic,
      underline = o.underline,
      strike = o.strike,
      hidden = o.hidden,
      superscript = o.superscript,
      subscript = o.subscript,
      fontSize = o.fontSize,
      color = o.color,
      background = o.background;

  /// [other] wins where it says something.
  _RunProps merged(_RunProps? other) {
    final r = _RunProps.copy(this);
    if (other == null) return r;
    r.bold = other.bold ?? bold;
    r.italic = other.italic ?? italic;
    r.underline = other.underline ?? underline;
    r.strike = other.strike ?? strike;
    r.hidden = other.hidden ?? hidden;
    r.superscript = other.superscript ?? superscript;
    r.subscript = other.subscript ?? subscript;
    r.fontSize = other.fontSize ?? fontSize;
    r.color = other.color ?? color;
    r.background = other.background ?? background;
    return r;
  }

  /// Like [merged] for a style: bold, italic, strike and hidden switch
  /// the inherited value (two styles with bold = not bold), as in Word.
  _RunProps styled(_RunProps? style) {
    final r = merged(style);
    if (style == null) return r;
    bool? flip(bool? inherited, bool? own) => own == true ? !(inherited ?? false) : inherited;
    r.bold = flip(bold, style.bold);
    r.italic = flip(italic, style.italic);
    r.strike = flip(strike, style.strike);
    r.hidden = flip(hidden, style.hidden);
    return r;
  }
}

/// An explicit "auto" / "none" colour: overrides an inherited one.
const _resetColor = -1;
int? _shownColor(int? c) => c == _resetColor ? null : c;

class _Style {
  final String? basedOn;
  final String name;
  final _RunProps? run;
  final DocxAlign? align;
  final int? outlineLevel;
  final String? numId;
  final int? numLevel;

  const _Style({
    required this.basedOn,
    required this.name,
    required this.run,
    required this.align,
    required this.outlineLevel,
    required this.numId,
    required this.numLevel,
  });
}

class _Level {
  final String format;
  final String text;
  final int start;

  /// `<w:lvlRestart>`: restarts after a list item of level `restart - 1` or
  /// higher; 0 = never. Null = after any higher level (Word's default).
  final int? restart;

  const _Level(this.format, this.text, this.start, [this.restart]);
}

class _DocxParser {
  final Uint8List bytes;
  late final Archive _archive;
  final Map<String, _Style> _styles = {};
  _RunProps _defaults = _RunProps();
  String? _defaultParagraphStyle;
  final Map<String, String> _rels = {};

  /// numId -> level -> definition.
  final Map<String, Map<int, _Level>> _numbering = {};

  /// numId -> level -> current counter.
  final Map<String, Map<int, int>> _counters = {};

  _DocxParser(this.bytes);

  DocxDocument parse() {
    try {
      _archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const FormatException('Keine Word-Datei (.docx)');
    }
    final document = _xml('word/document.xml');
    if (document == null) {
      throw const FormatException('Keine Word-Datei (.docx)');
    }
    _readStyles();
    _readNumbering();
    _readRels();
    final body = document.rootElement.getElement('body', namespaceUri: _w);
    if (body == null) return const DocxDocument([]);
    return DocxDocument(_blocks(body));
  }

  /// Unpacked size limits: a small .docx may unpack to gigabytes (zip
  /// bomb); real documents stay far below.
  static const _maxXmlBytes = 40 * 1024 * 1024;
  static const _maxImageBytes = 20 * 1024 * 1024;
  static const _maxTotalBytes = 150 * 1024 * 1024;
  static const _maxBlocks = 20000;
  int _unpacked = 0;
  int _blockCount = 0;

  Uint8List? _read(String path, int limit) {
    final file = _archive.findFile(path);
    if (file == null) return null;
    // The size in the zip header first, then the real one.
    if (file.size > limit || _unpacked + file.size > _maxTotalBytes) {
      throw const FormatException('Die Datei ist zu groß für die Vorschau');
    }
    final content = file.readBytes();
    if (content == null) return null;
    _unpacked += content.length;
    if (content.length > limit || _unpacked > _maxTotalBytes) {
      throw const FormatException('Die Datei ist zu groß für die Vorschau');
    }
    return content;
  }

  XmlDocument? _xml(String path) {
    final content = _read(path, _maxXmlBytes);
    if (content == null) return null;
    try {
      return XmlDocument.parse(_utf8(content));
    } catch (_) {
      return null;
    }
  }

  Uint8List? _binary(String path) => _read(path, _maxImageBytes);

  static String _utf8(Uint8List data) {
    // Word writes UTF-8 (with or without BOM).
    final start = data.length >= 3 && data[0] == 0xEF && data[1] == 0xBB && data[2] == 0xBF ? 3 : 0;
    return utf8.decode(Uint8List.sublistView(data, start), allowMalformed: true);
  }

  // --- styles, numbering, relationships ------------------------------------

  void _readStyles() {
    final doc = _xml('word/styles.xml');
    if (doc == null) return;
    final root = doc.rootElement;
    final defaults = root
        .getElement('docDefaults', namespaceUri: _w)
        ?.getElement('rPrDefault', namespaceUri: _w)
        ?.getElement('rPr', namespaceUri: _w);
    if (defaults != null) _defaults = _runProps(defaults);
    for (final style in root.findElements('style', namespaceUri: _w)) {
      final id = _attr(style, 'styleId');
      if (id == null) continue;
      final type = _attr(style, 'type');
      if (type != 'paragraph' && type != 'character') continue;
      final pPr = style.getElement('pPr', namespaceUri: _w);
      final rPr = style.getElement('rPr', namespaceUri: _w);
      final numPr = pPr?.getElement('numPr', namespaceUri: _w);
      _styles[id] = _Style(
        basedOn: _val(style.getElement('basedOn', namespaceUri: _w)),
        name: (_val(style.getElement('name', namespaceUri: _w)) ?? id).toLowerCase(),
        run: rPr == null ? null : _runProps(rPr),
        align: _align(_val(pPr?.getElement('jc', namespaceUri: _w))),
        outlineLevel: int.tryParse(_val(pPr?.getElement('outlineLvl', namespaceUri: _w)) ?? ''),
        numId: _val(numPr?.getElement('numId', namespaceUri: _w)),
        numLevel: int.tryParse(_val(numPr?.getElement('ilvl', namespaceUri: _w)) ?? ''),
      );
      if (type == 'paragraph' && _attr(style, 'default') == '1') {
        _defaultParagraphStyle = id;
      }
    }
  }

  /// [id] and the styles it is based on, the most basic first.
  List<_Style> _styleChain(String? id) {
    final chain = <_Style>[];
    final seen = <String>{};
    var current = id;
    while (current != null && seen.add(current)) {
      final style = _styles[current];
      if (style == null) break;
      chain.insert(0, style);
      current = style.basedOn;
    }
    return chain;
  }

  void _readNumbering() {
    final doc = _xml('word/numbering.xml');
    if (doc == null) return;
    final root = doc.rootElement;
    final abstracts = <String, Map<int, _Level>>{};
    for (final abs in root.findElements('abstractNum', namespaceUri: _w)) {
      final id = _attr(abs, 'abstractNumId');
      if (id == null) continue;
      abstracts[id] = _levels(abs);
    }
    for (final num in root.findElements('num', namespaceUri: _w)) {
      final id = _attr(num, 'numId');
      final abs = _val(num.getElement('abstractNumId', namespaceUri: _w));
      if (id == null || abs == null) continue;
      final levels = Map<int, _Level>.of(abstracts[abs] ?? const {});
      // <w:lvlOverride> may restart or redefine single levels.
      for (final override in num.findElements('lvlOverride', namespaceUri: _w)) {
        final ilvl = int.tryParse(_attr(override, 'ilvl') ?? '');
        if (ilvl == null) continue;
        final lvl = override.getElement('lvl', namespaceUri: _w);
        final start = int.tryParse(_val(override.getElement('startOverride', namespaceUri: _w)) ?? '');
        if (lvl != null) {
          final redefined = _levels(override)[ilvl];
          if (redefined != null) levels[ilvl] = redefined;
        }
        final base = levels[ilvl];
        if (start != null && base != null) levels[ilvl] = _Level(base.format, base.text, start, base.restart);
      }
      _numbering[id] = levels;
    }
  }

  Map<int, _Level> _levels(XmlElement parent) {
    final levels = <int, _Level>{};
    for (final lvl in parent.findElements('lvl', namespaceUri: _w)) {
      final ilvl = int.tryParse(_attr(lvl, 'ilvl') ?? '');
      if (ilvl == null) continue;
      levels[ilvl] = _Level(
        _val(lvl.getElement('numFmt', namespaceUri: _w)) ?? 'decimal',
        _val(lvl.getElement('lvlText', namespaceUri: _w)) ?? '',
        int.tryParse(_val(lvl.getElement('start', namespaceUri: _w)) ?? '') ?? 1,
        int.tryParse(_val(lvl.getElement('lvlRestart', namespaceUri: _w)) ?? ''),
      );
    }
    return levels;
  }

  void _readRels() {
    final doc = _xml('word/_rels/document.xml.rels');
    if (doc == null) return;
    for (final rel in doc.rootElement.childElements) {
      final id = rel.getAttribute('Id');
      final target = rel.getAttribute('Target');
      if (id == null || target == null) continue;
      if (rel.getAttribute('TargetMode') == 'External') continue;
      _rels[id] = target.startsWith('/') ? target.substring(1) : 'word/$target';
    }
  }

  // --- body -----------------------------------------------------------------

  List<DocxBlock> _blocks(XmlElement parent) {
    final blocks = <DocxBlock>[];
    for (final child in parent.childElements) {
      if (child.namespaceUri != _w) continue;
      if (++_blockCount > _maxBlocks) {
        throw const FormatException('Die Datei ist zu groß für die Vorschau');
      }
      switch (child.localName) {
        case 'p':
          final p = _paragraph(child);
          if (p != null) blocks.add(p);
        case 'tbl':
          blocks.add(_table(child));
        case 'sdt':
          final content = child.getElement('sdtContent', namespaceUri: _w);
          if (content != null) blocks.addAll(_blocks(content));
        case 'customXml':
        case 'ins':
          blocks.addAll(_blocks(child));
      }
    }
    return blocks;
  }

  DocxTable _table(XmlElement tbl) {
    final rows = <List<DocxCell>>[];
    for (final tr in tbl.findElements('tr', namespaceUri: _w)) {
      final cells = <DocxCell>[];
      for (final tc in tr.findElements('tc', namespaceUri: _w)) {
        final tcPr = tc.getElement('tcPr', namespaceUri: _w);
        // A vertically merged continuation cell stays empty.
        final vMerge = tcPr?.getElement('vMerge', namespaceUri: _w);
        final continued = vMerge != null && _attr(vMerge, 'val') != 'restart';
        final span = int.tryParse(_val(tcPr?.getElement('gridSpan', namespaceUri: _w)) ?? '') ?? 1;
        cells.add(DocxCell(continued ? const [] : _blocks(tc), span: span < 1 ? 1 : span));
      }
      if (cells.isNotEmpty) rows.add(cells);
    }
    return DocxTable(rows);
  }

  DocxParagraph? _paragraph(XmlElement p) {
    final pPr = p.getElement('pPr', namespaceUri: _w);
    final styleId = _val(pPr?.getElement('pStyle', namespaceUri: _w)) ?? _defaultParagraphStyle;
    final chain = _styleChain(styleId);

    var base = _defaults;
    DocxAlign? align;
    int? outline;
    String? numId;
    int? numLevel;
    for (final style in chain) {
      base = base.styled(style.run);
      align = style.align ?? align;
      outline = style.outlineLevel ?? outline;
      numId = style.numId ?? numId;
      numLevel = style.numLevel ?? numLevel;
    }
    // Paragraph mark formatting (<w:pPr><w:rPr>) only formats the mark.
    align = _align(_val(pPr?.getElement('jc', namespaceUri: _w))) ?? align;
    final numPr = pPr?.getElement('numPr', namespaceUri: _w);
    if (numPr != null) {
      numId = _val(numPr.getElement('numId', namespaceUri: _w)) ?? numId;
      numLevel = int.tryParse(_val(numPr.getElement('ilvl', namespaceUri: _w)) ?? '') ?? numLevel;
    }

    final styleName = chain.isEmpty ? '' : chain.last.name;
    int? heading;
    if (styleName == 'title') {
      heading = 0;
    } else {
      final match = RegExp(r'^(heading|überschrift)\s*(\d)$').firstMatch(styleName);
      if (match != null) {
        heading = int.parse(match.group(2)!);
      } else if (outline != null && outline < 9) {
        heading = outline + 1;
      }
    }
    if (heading != null && heading > 6) heading = 6;

    final inlines = <DocxInline>[];
    _inlines(p, base, inlines);

    String? label;
    var level = 0;
    if (numId != null && numId != '0') {
      level = numLevel ?? 0;
      label = _listLabel(numId, level);
    }

    final ind = pPr?.getElement('ind', namespaceUri: _w);
    final left = double.tryParse(_attr(ind, 'left') ?? _attr(ind, 'start') ?? '') ?? 0;

    return DocxParagraph(
      inlines: _mergeTexts(inlines),
      align: align ?? DocxAlign.left,
      headingLevel: heading,
      listLabel: label,
      listLevel: level,
      indent: label == null ? (left / 20).clamp(0, 200).toDouble() : 0,
    );
  }

  void _inlines(XmlElement parent, _RunProps base, List<DocxInline> out) {
    for (final child in parent.childElements) {
      final ns = child.namespaceUri;
      if (ns != _w) continue;
      switch (child.localName) {
        case 'r':
          _run(child, base, out);
        case 'hyperlink':
        case 'smartTag':
        case 'ins':
        case 'fldSimple':
        case 'customXml':
        case 'bdo':
        case 'dir':
          _inlines(child, base, out);
        case 'sdt':
          final content = child.getElement('sdtContent', namespaceUri: _w);
          if (content != null) _inlines(content, base, out);
      }
    }
  }

  void _run(XmlElement r, _RunProps base, List<DocxInline> out) {
    var props = base;
    final rPr = r.getElement('rPr', namespaceUri: _w);
    if (rPr != null) {
      final charStyle = _val(rPr.getElement('rStyle', namespaceUri: _w));
      for (final style in _styleChain(charStyle)) {
        props = props.styled(style.run);
      }
      props = props.merged(_runProps(rPr));
    }
    if (props.hidden == true) return;

    DocxText text(String value) => DocxText(
      value,
      bold: props.bold ?? false,
      italic: props.italic ?? false,
      underline: props.underline ?? false,
      strike: props.strike ?? false,
      fontSize: props.fontSize,
      color: _shownColor(props.color),
      background: _shownColor(props.background),
      superscript: props.superscript ?? false,
      subscript: props.subscript ?? false,
    );

    for (final child in r.childElements) {
      if (child.namespaceUri == _w) {
        switch (child.localName) {
          case 't':
            out.add(text(child.innerText));
          case 'tab':
            out.add(text('\t'));
          case 'br':
          case 'cr':
            out.add(text('\n'));
          case 'noBreakHyphen':
            out.add(text('‑'));
          case 'sym':
            final char = int.tryParse(_attr(child, 'char') ?? '', radix: 16);
            // Symbol fonts map to the private use area: show a bullet.
            out.add(text(char == null || char >= 0xF000 ? '•' : String.fromCharCode(char)));
          case 'drawing':
            _drawing(child, out);
          case 'pict':
            _vmlImage(child, out);
        }
      } else if (child.localName == 'AlternateContent') {
        // mc:AlternateContent: the first choice usually holds the drawing.
        final choice = child.childElements.firstOrNull;
        if (choice != null) {
          for (final d in choice.findAllElements('drawing', namespaceUri: _w)) {
            _drawing(d, out);
          }
        }
      }
    }
  }

  void _drawing(XmlElement drawing, List<DocxInline> out) {
    final blip = drawing.findAllElements('blip', namespaceUri: _a).firstOrNull;
    final id = blip?.getAttribute('embed', namespaceUri: _r);
    final bytes = _imageBytes(id);
    if (bytes == null) return;
    final extent = drawing.findAllElements('extent', namespaceUri: _wp).firstOrNull;
    // EMU -> logical pixels (914400 EMU = 1 inch = 96 px).
    final cx = double.tryParse(extent?.getAttribute('cx') ?? '');
    final cy = double.tryParse(extent?.getAttribute('cy') ?? '');
    out.add(DocxImage(bytes, width: cx == null ? null : cx / 9525, height: cy == null ? null : cy / 9525));
  }

  void _vmlImage(XmlElement pict, List<DocxInline> out) {
    final data = pict.findAllElements('imagedata', namespaceUri: _v).firstOrNull;
    final bytes = _imageBytes(data?.getAttribute('id', namespaceUri: _r));
    if (bytes != null) out.add(DocxImage(bytes));
  }

  Uint8List? _imageBytes(String? relId) {
    if (relId == null) return null;
    final path = _rels[relId];
    if (path == null) return null;
    final lower = path.toLowerCase();
    // Flutter cannot draw EMF/WMF/TIFF.
    const shown = ['.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp'];
    if (!shown.any(lower.endsWith)) return null;
    return _binary(_normalize(path));
  }

  static String _normalize(String path) {
    final parts = <String>[];
    for (final part in path.split('/')) {
      if (part == '..') {
        if (parts.isNotEmpty) parts.removeLast();
      } else if (part.isNotEmpty && part != '.') {
        parts.add(part);
      }
    }
    return parts.join('/');
  }

  /// Joins neighbouring texts with the same formatting (Word splits runs
  /// at every spell check / revision mark).
  static List<DocxInline> _mergeTexts(List<DocxInline> inlines) {
    final out = <DocxInline>[];
    for (final inline in inlines) {
      final last = out.lastOrNull;
      if (inline is DocxText && last is DocxText && _sameFormat(inline, last)) {
        out[out.length - 1] = DocxText(
          last.text + inline.text,
          bold: last.bold,
          italic: last.italic,
          underline: last.underline,
          strike: last.strike,
          fontSize: last.fontSize,
          color: last.color,
          background: last.background,
          superscript: last.superscript,
          subscript: last.subscript,
        );
      } else {
        out.add(inline);
      }
    }
    return out;
  }

  static bool _sameFormat(DocxText a, DocxText b) =>
      a.bold == b.bold &&
      a.italic == b.italic &&
      a.underline == b.underline &&
      a.strike == b.strike &&
      a.fontSize == b.fontSize &&
      a.color == b.color &&
      a.background == b.background &&
      a.superscript == b.superscript &&
      a.subscript == b.subscript;

  // --- lists ----------------------------------------------------------------

  String _listLabel(String numId, int level) {
    final levels = _numbering[numId];
    final def = levels?[level];
    final counters = _counters.putIfAbsent(numId, () => {});
    // Every item (bullets too) restarts the deeper levels, unless their
    // <w:lvlRestart> says otherwise.
    counters.removeWhere((l, _) {
      if (l <= level) return false;
      final restart = levels?[l]?.restart;
      return restart == null ? true : restart != 0 && level < restart;
    });
    if (def == null || def.format == 'bullet') {
      const bullets = ['•', '◦', '▪'];
      return bullets[level % bullets.length];
    }
    if (def.format == 'none') return '';
    counters[level] = (counters[level] ?? (def.start - 1)) + 1;
    return def.text.replaceAllMapped(RegExp(r'%(\d)'), (m) {
      final l = int.parse(m.group(1)!) - 1;
      final d = levels?[l];
      final value = counters[l] ?? d?.start ?? 1;
      return _formatNumber(value, d?.format ?? 'decimal');
    });
  }

  static String _formatNumber(int n, String format) {
    switch (format) {
      case 'lowerLetter':
        return _letters(n).toLowerCase();
      case 'upperLetter':
        return _letters(n);
      case 'lowerRoman':
        return _roman(n).toLowerCase();
      case 'upperRoman':
        return _roman(n);
      default:
        return '$n';
    }
  }

  static String _letters(int n) {
    if (n < 1) return '$n';
    final letter = String.fromCharCode(65 + (n - 1) % 26);
    return letter * ((n - 1) ~/ 26 + 1);
  }

  static String _roman(int n) {
    if (n < 1 || n > 3999) return '$n';
    const values = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1];
    const symbols = ['M', 'CM', 'D', 'CD', 'C', 'XC', 'L', 'XL', 'X', 'IX', 'V', 'IV', 'I'];
    final buffer = StringBuffer();
    var rest = n;
    for (var i = 0; i < values.length; i++) {
      while (rest >= values[i]) {
        buffer.write(symbols[i]);
        rest -= values[i];
      }
    }
    return buffer.toString();
  }

  // --- attributes -------------------------------------------------------------

  static String? _attr(XmlElement? e, String name) =>
      e?.getAttribute(name, namespaceUri: _w) ?? e?.getAttribute('w:$name');

  static String? _val(XmlElement? e) => _attr(e, 'val');

  /// `<w:b/>`, `<w:b w:val="true"/>` = on; w:val="0"/"false"/"off" = off.
  static bool? _toggle(XmlElement? e) {
    if (e == null) return null;
    final v = _val(e);
    return !(v == '0' || v == 'false' || v == 'off');
  }

  static DocxAlign? _align(String? jc) => switch (jc) {
    'center' => DocxAlign.center,
    'right' || 'end' => DocxAlign.right,
    'both' || 'distribute' => DocxAlign.justify,
    'left' || 'start' => DocxAlign.left,
    _ => null,
  };

  static int? _hexColor(String? hex) {
    if (hex == 'auto') return _resetColor;
    if (hex == null || hex.length != 6) return null;
    final value = int.tryParse(hex, radix: 16);
    return value == null ? null : 0xFF000000 | value;
  }

  static const _highlights = <String, int>{
    'yellow': 0xFFFFFF00,
    'green': 0xFF00FF00,
    'cyan': 0xFF00FFFF,
    'magenta': 0xFFFF00FF,
    'blue': 0xFF0000FF,
    'red': 0xFFFF0000,
    'darkBlue': 0xFF000080,
    'darkCyan': 0xFF008080,
    'darkGreen': 0xFF008000,
    'darkMagenta': 0xFF800080,
    'darkRed': 0xFF800000,
    'darkYellow': 0xFF808000,
    'darkGray': 0xFF808080,
    'lightGray': 0xFFC0C0C0,
    'black': 0xFF000000,
    'white': 0xFFFFFFFF,
  };

  _RunProps _runProps(XmlElement rPr) {
    final p = _RunProps();
    p.bold = _toggle(rPr.getElement('b', namespaceUri: _w));
    p.italic = _toggle(rPr.getElement('i', namespaceUri: _w));
    final u = rPr.getElement('u', namespaceUri: _w);
    if (u != null) p.underline = _val(u) != 'none';
    p.strike =
        _toggle(rPr.getElement('strike', namespaceUri: _w)) ?? _toggle(rPr.getElement('dstrike', namespaceUri: _w));
    p.hidden = _toggle(rPr.getElement('vanish', namespaceUri: _w));
    final sz = double.tryParse(_val(rPr.getElement('sz', namespaceUri: _w)) ?? '');
    if (sz != null && sz > 0) p.fontSize = sz / 2;
    p.color = _hexColor(_val(rPr.getElement('color', namespaceUri: _w)));
    final highlight = _val(rPr.getElement('highlight', namespaceUri: _w));
    p.background =
        _highlights[highlight] ??
        (highlight == 'none' ? _resetColor : null) ??
        _hexColor(_attr(rPr.getElement('shd', namespaceUri: _w), 'fill'));
    final vertAlign = _val(rPr.getElement('vertAlign', namespaceUri: _w));
    if (vertAlign != null) {
      p.superscript = vertAlign == 'superscript';
      p.subscript = vertAlign == 'subscript';
    }
    return p;
  }
}
