import 'package:attendix/core/utils/tiptap_converter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TiptapConverter.fromDeltaOps', () {
    test('plain paragraphs', () {
      final doc = TiptapConverter.fromDeltaOps([
        {'insert': 'Hallo\nWelt\n'},
      ]);
      expect(doc, {
        'type': 'doc',
        'content': [
          {
            'type': 'paragraph',
            'content': [
              {'type': 'text', 'text': 'Hallo'},
            ],
          },
          {
            'type': 'paragraph',
            'content': [
              {'type': 'text', 'text': 'Welt'},
            ],
          },
        ],
      });
    });

    test('marks: bold, italic, link', () {
      final doc = TiptapConverter.fromDeltaOps([
        {
          'insert': 'fett',
          'attributes': {'bold': true, 'italic': true},
        },
        {
          'insert': 'Link',
          'attributes': {'link': 'https://attendix.de'},
        },
        {'insert': '\n'},
      ]);
      final para = (doc['content'] as List).single as Map;
      final nodes = para['content'] as List;
      expect(nodes[0]['marks'], [
        {'type': 'bold'},
        {'type': 'italic'},
      ]);
      expect(nodes[1]['marks'], [
        {
          'type': 'link',
          'attrs': {'href': 'https://attendix.de'},
        },
      ]);
    });

    test('headings map to level 2/3 and lists are grouped', () {
      final doc = TiptapConverter.fromDeltaOps([
        {'insert': 'Titel'},
        {
          'insert': '\n',
          'attributes': {'header': 1},
        },
        {'insert': 'eins'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet'},
        },
        {'insert': 'zwei'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet'},
        },
        {'insert': 'a'},
        {
          'insert': '\n',
          'attributes': {'list': 'ordered'},
        },
        {'insert': 'Unter'},
        {
          'insert': '\n',
          'attributes': {'header': 3},
        },
      ]);
      final content = doc['content'] as List;
      expect(content.map((b) => b['type']), [
        'heading',
        'bulletList',
        'orderedList',
        'heading',
      ]);
      expect(content[0]['attrs'], {'level': 2});
      expect(content[3]['attrs'], {'level': 3});
      expect((content[1]['content'] as List), hasLength(2));
      expect(content[1]['content'][0]['type'], 'listItem');
    });

    test('empty document has no text', () {
      final doc = TiptapConverter.fromDeltaOps([
        {'insert': '\n'},
      ]);
      expect(doc['content'], isEmpty);
      expect(TiptapConverter.hasText(doc), isFalse);
    });

    test('hasText detects text and ignores whitespace', () {
      expect(
        TiptapConverter.hasText(TiptapConverter.fromDeltaOps([
          {'insert': '   \n'},
        ])),
        isFalse,
      );
      expect(
        TiptapConverter.hasText(TiptapConverter.fromDeltaOps([
          {'insert': 'x\n'},
        ])),
        isTrue,
      );
    });
  });
}
