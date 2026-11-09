import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
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

  test('style toggles, explicit auto colour and list restarts', () {
    const w = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"';
    const styles =
        '<w:styles $w>'
        '<w:style w:type="paragraph" w:styleId="Strong"><w:name w:val="Strong"/><w:rPr><w:b/><w:color w:val="FFFFFF"/></w:rPr></w:style>'
        '<w:style w:type="character" w:styleId="B"><w:name w:val="B"/><w:rPr><w:b/></w:rPr></w:style>'
        '</w:styles>';
    const numbering =
        '<w:numbering $w>'
        '<w:abstractNum w:abstractNumId="0">'
        '<w:lvl w:ilvl="0"><w:numFmt w:val="bullet"/><w:lvlText w:val="•"/></w:lvl>'
        '<w:lvl w:ilvl="1"><w:start w:val="1"/><w:numFmt w:val="decimal"/><w:lvlText w:val="%2."/></w:lvl>'
        '</w:abstractNum><w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num></w:numbering>';
    String item(int level, String text) =>
        '<w:p><w:pPr><w:numPr><w:ilvl w:val="$level"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>$text</w:t></w:r></w:p>';
    final document =
        '<w:document $w><w:body>'
        '<w:p><w:pPr><w:pStyle w:val="Strong"/></w:pPr>'
        '<w:r><w:rPr><w:rStyle w:val="B"/><w:color w:val="auto"/></w:rPr><w:t>x</w:t></w:r></w:p>'
        '${item(0, 'A')}${item(1, 'a1')}${item(1, 'a2')}${item(0, 'B')}${item(1, 'b1')}'
        '</w:body></w:document>';
    final archive = Archive();
    void add(String name, String xml) {
      final data = utf8.encode(xml);
      archive.addFile(ArchiveFile(name, data.length, data));
    }

    add('word/document.xml', document);
    add('word/styles.xml', styles);
    add('word/numbering.xml', numbering);
    final doc = DocxDocument.parse(Uint8List.fromList(ZipEncoder().encode(archive)));
    final paragraphs = doc.blocks.cast<DocxParagraph>();

    final run = paragraphs.first.inlines.single as DocxText;
    expect(run.bold, isFalse, reason: 'bold style + bold character style = not bold');
    expect(run.color, isNull, reason: 'explicit auto overrides the inherited white');
    expect(paragraphs.skip(1).map((p) => p.listLabel), ['•', '1.', '2.', '•', '1.']);
  });
}
