import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

part 'docx_parser.dart';

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

  /// ARGB of the cell shading, null = none.
  final int? background;

  const DocxCell(this.blocks, {this.span = 1, this.background});
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

  /// `<w:pStyle>`: paragraphs of this style get this level (e.g. numbered
  /// headings "1." / "1.1").
  final String? styleId;

  const _Level(this.format, this.text, this.start, [this.restart, this.styleId]);
}
