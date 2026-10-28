/// Conversion between the Tiptap/ProseMirror JSON docs stored in
/// `protocols.content` (written by the Ionic app) and Quill Delta ops used by
/// the Flutter editor (flutter_quill).
///
/// Supported: paragraphs, headings, bullet/ordered/task lists (nested),
/// blockquotes, code blocks, hard breaks and the marks bold, italic,
/// underline, strike, code and link. The block nodes `taskRef` and
/// `agendaItemRef` (atoms of the Ionic editor) cannot be edited in Quill; they
/// are kept aside as [TiptapDocParts.refs] and appended again when saving, so
/// the task ↔ section mapping of the protocol stays intact.
library;

typedef Json = Map<String, dynamic>;

class TiptapDocParts {
  TiptapDocParts(this.ops, this.refs);

  /// Quill Delta ops (always ends with a newline).
  final List<Json> ops;

  /// taskRef / agendaItemRef nodes of the doc, in order.
  final List<Json> refs;
}

const _refTypes = {'taskRef', 'agendaItemRef'};

Json _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Json> _children(Json node) =>
    ((node['content'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

// ── Tiptap → Delta ─────────────────────────────────────────

TiptapDocParts tiptapToDelta(Map<String, dynamic>? doc) {
  final ops = <Json>[];
  final refs = <Json>[];

  void addInline(List<Json> nodes) {
    for (final n in nodes) {
      final type = n['type'];
      if (type == 'text') {
        final text = (n['text'] ?? '').toString();
        if (text.isEmpty) continue;
        final attrs = <String, dynamic>{};
        for (final m in ((n['marks'] as List?) ?? const []).whereType<Map>()) {
          switch (m['type']) {
            case 'bold':
              attrs['bold'] = true;
            case 'italic':
              attrs['italic'] = true;
            case 'underline':
              attrs['underline'] = true;
            case 'strike':
              attrs['strike'] = true;
            case 'code':
              attrs['code'] = true;
            case 'link':
              final href = _map(m['attrs'])['href'];
              if (href != null) attrs['link'] = href.toString();
          }
        }
        ops.add({'insert': text, if (attrs.isNotEmpty) 'attributes': attrs});
      } else if (type == 'hardBreak') {
        ops.add({'insert': '\n'});
      } else if (_refTypes.contains(type)) {
        refs.add(n);
      } else {
        addInline(_children(n));
      }
    }
  }

  void newline([Json? attrs]) =>
      ops.add({'insert': '\n', if (attrs != null && attrs.isNotEmpty) 'attributes': attrs});

  void walkList(Json list, int depth) {
    final type = list['type'];
    for (final item in _children(list)) {
      final listAttr = type == 'orderedList'
          ? 'ordered'
          : type == 'taskList'
              ? (_map(item['attrs'])['checked'] == true ? 'checked' : 'unchecked')
              : 'bullet';
      final attrs = <String, dynamic>{'list': listAttr, if (depth > 0) 'indent': depth};
      var wroteLine = false;
      for (final child in _children(item)) {
        final ct = child['type'];
        if (ct == 'bulletList' || ct == 'orderedList' || ct == 'taskList') {
          if (!wroteLine) {
            newline(attrs);
            wroteLine = true;
          }
          walkList(child, depth + 1);
        } else if (_refTypes.contains(ct)) {
          refs.add(child);
        } else {
          addInline(_children(child));
          newline(attrs);
          wroteLine = true;
        }
      }
      if (!wroteLine) newline(attrs);
    }
  }

  void walkBlock(Json node) {
    final type = node['type'];
    switch (type) {
      case 'doc':
        _children(node).forEach(walkBlock);
      case 'heading':
        addInline(_children(node));
        final level = (_map(node['attrs'])['level'] as num?)?.toInt() ?? 2;
        newline({'header': level.clamp(1, 3)});
      case 'bulletList':
      case 'orderedList':
      case 'taskList':
        walkList(node, 0);
      case 'blockquote':
        for (final child in _children(node)) {
          addInline(_children(child));
          newline({'blockquote': true});
        }
      case 'codeBlock':
        final text = _children(node).map((c) => (c['text'] ?? '').toString()).join();
        for (final line in text.split('\n')) {
          if (line.isNotEmpty) ops.add({'insert': line});
          newline({'code-block': true});
        }
      case 'horizontalRule':
        ops.add({'insert': '———'});
        newline();
      case 'taskRef':
      case 'agendaItemRef':
        refs.add(node);
      default:
        addInline(_children(node));
        newline();
    }
  }

  if (doc != null) walkBlock(doc['type'] == null ? {'type': 'doc', ...doc} : doc);
  if (ops.isEmpty || !(ops.last['insert'] as String).endsWith('\n')) newline();
  return TiptapDocParts(ops, refs);
}

// ── Delta → Tiptap ─────────────────────────────────────────

class _Line {
  _Line(this.inline, this.attrs);
  final List<Json> inline;
  final Json attrs;
  String get text => inline.map((n) => n['text'] ?? '').join();
}

List<_Line> _deltaLines(List<dynamic> ops) {
  final lines = <_Line>[];
  var current = <Json>[];
  for (final raw in ops) {
    final op = _map(raw);
    final insert = op['insert'];
    if (insert is! String) continue; // embeds (images etc.) are not supported
    final attrs = _map(op['attributes']);
    final parts = insert.split('\n');
    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (part.isNotEmpty) {
        final marks = <Json>[];
        if (attrs['bold'] == true) marks.add({'type': 'bold'});
        if (attrs['italic'] == true) marks.add({'type': 'italic'});
        if (attrs['underline'] == true) marks.add({'type': 'underline'});
        if (attrs['strike'] == true) marks.add({'type': 'strike'});
        if (attrs['code'] == true) marks.add({'type': 'code'});
        if (attrs['link'] != null) {
          marks.add({'type': 'link', 'attrs': {'href': attrs['link'].toString()}});
        }
        current.add({'type': 'text', 'text': part, if (marks.isNotEmpty) 'marks': marks});
      }
      if (i < parts.length - 1) {
        lines.add(_Line(current, attrs));
        current = <Json>[];
      }
    }
  }
  if (current.isNotEmpty) lines.add(_Line(current, const {}));
  return lines;
}

Json _paragraph(List<Json> inline) =>
    inline.isEmpty ? {'type': 'paragraph'} : {'type': 'paragraph', 'content': inline};

String _listKind(String list) =>
    list == 'ordered' ? 'orderedList' : (list == 'checked' || list == 'unchecked') ? 'taskList' : 'bulletList';

int _indent(_Line l) => (l.attrs['indent'] as num?)?.toInt() ?? 0;

List<Json> _buildLists(List<_Line> lines, int depth) {
  final result = <Json>[];
  var i = 0;
  while (i < lines.length) {
    final kind = _listKind(lines[i].attrs['list'].toString());
    final items = <Json>[];
    while (i < lines.length && _indent(lines[i]) <= depth) {
      final line = lines[i];
      if (_listKind(line.attrs['list'].toString()) != kind) break;
      i++;
      final nested = <_Line>[];
      while (i < lines.length && _indent(lines[i]) > depth) {
        nested.add(lines[i]);
        i++;
      }
      final content = <Json>[_paragraph(line.inline), ..._buildLists(nested, depth + 1)];
      if (kind == 'taskList') {
        items.add({'type': 'taskItem', 'attrs': {'checked': line.attrs['list'] == 'checked'}, 'content': content});
      } else {
        items.add({'type': 'listItem', 'content': content});
      }
    }
    if (items.isEmpty) {
      // Deeper line without parent at this depth: lift it.
      final nested = <_Line>[];
      while (i < lines.length && _indent(lines[i]) > depth) {
        nested.add(lines[i]);
        i++;
      }
      result.addAll(_buildLists(nested, depth + 1));
      continue;
    }
    result.add({'type': kind, 'content': items});
  }
  return result;
}

/// Builds a Tiptap doc from Quill Delta ops and appends the kept [refs].
Map<String, dynamic> deltaToTiptap(List<dynamic> ops, [List<Json> refs = const []]) {
  final lines = _deltaLines(ops);
  // Quill always ends with an empty line; drop trailing empty plain lines.
  while (lines.isNotEmpty && lines.last.inline.isEmpty && lines.last.attrs.isEmpty) {
    lines.removeLast();
  }
  final content = <Json>[];
  var i = 0;
  while (i < lines.length) {
    final line = lines[i];
    final a = line.attrs;
    if (a['list'] != null) {
      final group = <_Line>[];
      while (i < lines.length && lines[i].attrs['list'] != null) {
        group.add(lines[i]);
        i++;
      }
      content.addAll(_buildLists(group, 0));
    } else if (a['header'] != null) {
      content.add({
        'type': 'heading',
        'attrs': {'level': (a['header'] as num).toInt()},
        if (line.inline.isNotEmpty) 'content': line.inline,
      });
      i++;
    } else if (a['blockquote'] == true) {
      final paras = <Json>[];
      while (i < lines.length && lines[i].attrs['blockquote'] == true) {
        paras.add(_paragraph(lines[i].inline));
        i++;
      }
      content.add({'type': 'blockquote', 'content': paras});
    } else if (a['code-block'] == true) {
      final texts = <String>[];
      while (i < lines.length && lines[i].attrs['code-block'] == true) {
        texts.add(lines[i].text);
        i++;
      }
      final text = texts.join('\n');
      content.add({
        'type': 'codeBlock',
        if (text.isNotEmpty) 'content': [{'type': 'text', 'text': text}],
      });
    } else {
      content.add(_paragraph(line.inline));
      i++;
    }
  }
  content.addAll(refs);
  if (content.isEmpty) content.add({'type': 'paragraph'});
  return {'type': 'doc', 'content': content};
}

// ── Reading helpers (protocol.helpers.ts) ──────────────────

String _inlineText(Json node) {
  final type = node['type'];
  if (type == 'text') return (node['text'] ?? '').toString();
  if (type == 'hardBreak') return '\n';
  if (type == 'taskRef') return 'Aufgabe: ${_map(node['attrs'])['title'] ?? ''}';
  if (type == 'agendaItemRef') return 'Thema: ${_map(node['attrs'])['title'] ?? ''}';
  return _children(node).map(_inlineText).join();
}

/// True when a stored doc has neither text nor reference nodes.
bool isDocEmpty(Map<String, dynamic>? doc) {
  if (doc == null) return true;
  bool walk(Json n) {
    if (n['type'] == 'text' && (n['text'] ?? '').toString().trim().isNotEmpty) return true;
    if (_refTypes.contains(n['type'])) return true;
    return _children(n).any(walk);
  }

  return !walk(doc);
}

/// Whole doc as one line of text (preview under a collapsed section).
String docToPlainText(Map<String, dynamic>? doc, {int maxLength = 0}) {
  if (doc == null) return '';
  final parts = <String>[];
  void walk(Json n) {
    final type = n['type'];
    if (type == 'text' || type == 'hardBreak' || _refTypes.contains(type)) {
      parts.add(_inlineText(n));
      return;
    }
    final before = parts.length;
    _children(n).forEach(walk);
    if (parts.length > before && type != 'doc') parts.add(' ');
  }

  walk(doc);
  final text = parts.join().replaceAll(RegExp(r'\s+'), ' ').trim();
  if (maxLength > 0 && text.length > maxLength) {
    return '${text.substring(0, maxLength - 1).trimRight()}…';
  }
  return text;
}

/// Flat lines (with list markers) for the PDF.
List<({String text, int indent, String? marker, bool heading})> docToLines(Map<String, dynamic>? doc) {
  final lines = <({String text, int indent, String? marker, bool heading})>[];
  if (doc == null) return lines;

  void walkList(Json list, int indent) {
    final type = list['type'];
    var n = (_map(list['attrs'])['start'] as num?)?.toInt() ?? 1;
    for (final item in _children(list)) {
      final marker = type == 'taskList'
          ? (_map(item['attrs'])['checked'] == true ? '☑' : '☐')
          : type == 'orderedList'
              ? '${n++}.'
              : '•';
      var first = true;
      for (final child in _children(item)) {
        final ct = child['type'];
        if (ct == 'bulletList' || ct == 'orderedList' || ct == 'taskList') {
          walkList(child, indent + 1);
        } else {
          final text = _inlineText(child).trim();
          if (text.isEmpty) continue;
          lines.add((text: text, indent: first ? indent : indent + 1, marker: first ? marker : null, heading: false));
          first = false;
        }
      }
    }
  }

  void walk(Json node) {
    switch (node['type']) {
      case 'doc':
        _children(node).forEach(walk);
      case 'bulletList':
      case 'orderedList':
      case 'taskList':
        walkList(node, 0);
      case 'blockquote':
        for (final c in _children(node)) {
          final t = _inlineText(c).trim();
          if (t.isNotEmpty) lines.add((text: '„$t“', indent: 0, marker: null, heading: false));
        }
      case 'horizontalRule':
        break;
      default:
        final t = _inlineText(node).trim();
        if (t.isNotEmpty) lines.add((text: t, indent: 0, marker: null, heading: node['type'] == 'heading'));
    }
  }

  walk(doc);
  return lines;
}

/// Ids of all task references in a doc.
List<String> taskRefIds(Map<String, dynamic>? doc) {
  final ids = <String>[];
  void walk(Json n) {
    if (n['type'] == 'taskRef') {
      final id = _map(n['attrs'])['id'];
      if (id != null) ids.add(id.toString());
    }
    _children(n).forEach(walk);
  }

  if (doc != null) walk(doc);
  return ids;
}

/// Builds a taskRef node (as the Ionic editor inserts it).
Json taskRefNode({required String id, required String title, required String status}) => {
      'type': 'taskRef',
      'attrs': {'id': id, 'title': title, 'status': status},
    };
