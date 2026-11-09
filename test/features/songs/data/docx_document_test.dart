import 'dart:io';
import 'dart:typed_data';

import 'package:attendix/features/songs/data/docx_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads headings, formatting, lists, tables and pictures of a .docx', () {
    final bytes = File('test/fixtures/docx_sample.docx').readAsBytesSync();
    final doc = DocxDocument.parse(bytes);

    final paragraphs = doc.blocks.whereType<DocxParagraph>().toList();
    String text(DocxParagraph p) => p.inlines.whereType<DocxText>().map((t) => t.text).join();

    expect(paragraphs.first.headingLevel, 0);
    expect(text(paragraphs.first), 'Probenplan Herbstkonzert');
    expect(paragraphs[1].headingLevel, 1);

    final intro = paragraphs[2];
    expect(text(intro), startsWith('Wir treffen uns um 18:30 Uhr'));
    final time = intro.inlines.whereType<DocxText>().firstWhere((t) => t.text == '18:30 Uhr');
    expect(time.bold, isTrue);
    final hint = intro.inlines.whereType<DocxText>().firstWhere((t) => t.text == 'pünktlich');
    expect(hint.underline, isTrue);
    expect(hint.color, 0xFFC00000);

    final labels = paragraphs.where((p) => p.listLabel != null).map((p) => p.listLabel).toList();
    expect(labels, ['1.', '2.', '3.', '•', '•']);

    final table = doc.blocks.whereType<DocxTable>().single;
    expect(table.rows.length, 3);
    expect(table.rows[1].length, 3);
    final cell = table.rows[1][0].blocks.single as DocxParagraph;
    expect(text(cell), 'Sopran');

    final centered = paragraphs.firstWhere((p) => text(p) == 'Zentriert und groß');
    expect(centered.align, DocxAlign.center);
    expect((centered.inlines.single as DocxText).fontSize, 18);

    final image = paragraphs.expand((p) => p.inlines).whereType<DocxImage>().single;
    expect(image.width, closeTo(192, 1));
  });

  test('rejects files that are not Word documents', () {
    expect(() => DocxDocument.parse(Uint8List.fromList([1, 2, 3])), throwsFormatException);
  });
}
