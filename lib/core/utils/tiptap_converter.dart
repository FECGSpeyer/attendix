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
