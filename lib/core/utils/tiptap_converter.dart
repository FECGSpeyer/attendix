/// Converts a Quill Delta (Flutter editor) into a Tiptap JSON document, the
/// format the `send-message` Edge Function expects for Mitteilungen.
///
/// Supported (mirrors the server allowlist in Ionic
/// supabase/functions/_shared/message-render.ts): paragraph, heading (h2/h3),
/// bulletList, orderedList, listItem, text with marks bold, italic,
/// underline, strike, link.
class TiptapConverter {
  TiptapConverter._();

  /// Converts Delta ops (`doc.toDelta().toJson()`) into `{type: 'doc', content: [...]}`.
  static Map<String, dynamic> fromDeltaOps(List<Map<String, dynamic>> ops) {
    final blocks = <Map<String, dynamic>>[];
    var inline = <Map<String, dynamic>>[];

    // Pending list being built (bulletList / orderedList).
    Map<String, dynamic>? currentList;
    String? currentListType;

    void flushList() {
      if (currentList != null) blocks.add(currentList!);
      currentList = null;
      currentListType = null;
    }

    void endLine(Map<String, dynamic>? lineAttrs) {
      final lineContent = inline;
      inline = <Map<String, dynamic>>[];
      final list = lineAttrs?['list'];
      final header = lineAttrs?['header'];

      if (list == 'bullet' || list == 'ordered') {
        final type = list == 'bullet' ? 'bulletList' : 'orderedList';
        if (currentListType != type) {
          flushList();
          currentListType = type;
          currentList = {'type': type, 'content': <Map<String, dynamic>>[]};
        }
        (currentList!['content'] as List).add({
          'type': 'listItem',
          'content': [_paragraph(lineContent)],
        });
        return;
      }

      flushList();
      if (header is int && header > 0) {
        blocks.add({
          'type': 'heading',
          'attrs': {'level': header >= 3 ? 3 : 2},
          if (lineContent.isNotEmpty) 'content': lineContent,
        });
      } else {
        blocks.add(_paragraph(lineContent));
      }
    }

    for (final op in ops) {
      final insert = op['insert'];
      if (insert is! String) continue; // embeds (images etc.) are not supported
      final attrs = (op['attributes'] as Map?)?.cast<String, dynamic>();
      final parts = insert.split('\n');
      for (var i = 0; i < parts.length; i++) {
        final text = parts[i];
        if (text.isNotEmpty) {
          inline.add(_textNode(text, attrs));
        }
        if (i < parts.length - 1) {
          // A newline: its attributes are the line (block) attributes.
          endLine(attrs);
        }
      }
    }
    if (inline.isNotEmpty) endLine(null);
    flushList();

    // Drop trailing empty paragraphs (Quill always ends with a newline).
    while (blocks.isNotEmpty &&
        blocks.last['type'] == 'paragraph' &&
        blocks.last['content'] == null) {
      blocks.removeLast();
    }

    return {'type': 'doc', 'content': blocks};
  }

  /// The reverse of [fromDeltaOps]: a Tiptap document as Quill Delta ops
  /// (Ionic 4.18: the own text of an automatic-message rule is edited
  /// again, the "Unentschuldigte anschreiben" text is prefilled).
  /// `hardBreak` becomes a plain line break.
  static List<Map<String, dynamic>> toDeltaOps(Map<String, dynamic>? doc) {
    final ops = <Map<String, dynamic>>[];

    void inline(List? content) {
      for (final node in content ?? const []) {
        if (node is! Map) continue;
        if (node['type'] == 'hardBreak') {
          ops.add({'insert': '\n'});
          continue;
        }
        final text = node['text'];
        if (node['type'] != 'text' || text is! String || text.isEmpty) continue;
        final attrs = <String, dynamic>{};
        for (final mark in (node['marks'] as List? ?? const [])) {
          if (mark is! Map) continue;
          switch (mark['type']) {
            case 'bold':
            case 'italic':
            case 'underline':
            case 'strike':
              attrs[mark['type'] as String] = true;
            case 'link':
              final href = (mark['attrs'] as Map?)?['href'];
              if (href is String && href.isNotEmpty) attrs['link'] = href;
          }
        }
        ops.add({'insert': text, if (attrs.isNotEmpty) 'attributes': attrs});
      }
    }

    void line([Map<String, dynamic>? attrs]) =>
        ops.add({'insert': '\n', if (attrs != null) 'attributes': attrs});

    for (final block in (doc?['content'] as List? ?? const [])) {
      if (block is! Map) continue;
      switch (block['type']) {
        case 'heading':
          inline(block['content'] as List?);
          final level = (block['attrs'] as Map?)?['level'];
          line({'header': level is int && level >= 3 ? 3 : 2});
        case 'bulletList':
        case 'orderedList':
          final list = block['type'] == 'bulletList' ? 'bullet' : 'ordered';
          for (final item in (block['content'] as List? ?? const [])) {
            if (item is! Map) continue;
            for (final para in (item['content'] as List? ?? const [])) {
              if (para is! Map) continue;
              inline(para['content'] as List?);
              line({'list': list});
            }
          }
        default:
          inline(block['content'] as List?);
          line();
      }
    }
    if (ops.isEmpty) ops.add({'insert': '\n'});
    return ops;
  }

  /// Whether the document contains any non-whitespace text.
  static bool hasText(Map<String, dynamic> node) {
    if (node['type'] == 'text') {
      return (node['text'] as String? ?? '').trim().isNotEmpty;
    }
    final content = node['content'];
    if (content is List) {
      return content.any((c) => c is Map<String, dynamic> && hasText(c));
    }
    return false;
  }

  static Map<String, dynamic> _paragraph(List<Map<String, dynamic>> content) => {
    'type': 'paragraph',
    if (content.isNotEmpty) 'content': content,
  };

  static Map<String, dynamic> _textNode(String text, Map<String, dynamic>? attrs) {
    final marks = <Map<String, dynamic>>[];
    if (attrs != null) {
      if (attrs['bold'] == true) marks.add({'type': 'bold'});
      if (attrs['italic'] == true) marks.add({'type': 'italic'});
      if (attrs['underline'] == true) marks.add({'type': 'underline'});
      if (attrs['strike'] == true) marks.add({'type': 'strike'});
      final link = attrs['link'];
      if (link is String && link.isNotEmpty) {
        marks.add({
          'type': 'link',
          'attrs': {'href': link},
        });
      }
    }
    return {'type': 'text', 'text': text, if (marks.isNotEmpty) 'marks': marks};
  }
}
