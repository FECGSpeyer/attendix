import 'dart:convert' show latin1;
import 'dart:typed_data';

import 'package:attendix/core/services/native/native_file_service.dart';
import 'package:attendix/data/models/song/song.dart';
import 'package:attendix/features/songs/data/pdf_page_merger.dart';
import 'package:attendix/features/songs/data/song_print_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Vector PDF from the `pdf` package (PDF 1.5: xref stream + object streams).
Future<Uint8List> _vectorPdf({int pages = 2, double width = 300, double height = 400}) {
  final doc = pw.Document();
  for (var i = 0; i < pages; i++) {
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat(width, height),
      build: (_) => pw.Column(children: [
        pw.Text('Seite ${i + 1}'),
        pw.Container(width: 100, height: 20, color: PdfColors.black),
      ]),
    ));
  }
  return doc.save();
}

/// Classic xref table with wrong offsets (forces the xref rebuild) and a
/// MediaBox inherited from the page tree.
Uint8List _brokenClassicPdf() {
  const content = '0 0 m 100 50 l S';
  final s = '%PDF-1.4\n'
      '1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj\n'
      '2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 /MediaBox [0 0 200 100] >> endobj\n'
      '3 0 obj << /Type /Page /Parent 2 0 R /Contents 4 0 R /Resources << >> >> endobj\n'
      '4 0 obj << /Length ${content.length} >>\nstream\n$content\nendstream\nendobj\n'
      'xref\n0 5\n0000000000 65535 f \n0000000001 00000 n \n0000000002 00000 n \n'
      '0000000003 00000 n \n0000000004 00000 n \n'
      'trailer << /Size 5 /Root 1 0 R >>\nstartxref\n9\n%%EOF\n';
  return Uint8List.fromList(latin1.encode(s));
}

int _count(String haystack, Pattern p) => p.allMatches(haystack).length;

void main() {
  group('PdfPageMerger', () {
    test('keeps PDF pages as vector pages with their page size', () async {
      final merger = PdfPageMerger();
      expect(merger.addPdf(await _vectorPdf(), copies: 2), 4);
      final out = merger.save();
      final text = latin1.decode(out);

      expect(text.startsWith('%PDF-'), isTrue);
      // No raster images, the original fonts / content streams are kept.
      expect(text, isNot(contains('/Subtype /Image')));
      expect(text, contains('/Font'));
      expect(_count(text, RegExp(r'/MediaBox \[0 0 300(\.0+)? 400(\.0+)?\]')), 4);
      // Copies share content and resources: one font object per source doc.
      expect(_count(text, RegExp(r'/Type /Font\b')), 1);

      // The result is a valid PDF again.
      expect(PdfPageMerger().addPdf(out), 4);
    });

    test('rebuilds broken xref and resolves inherited MediaBox', () {
      final merger = PdfPageMerger();
      expect(merger.addPdf(_brokenClassicPdf()), 1);
      final text = latin1.decode(merger.save());
      expect(text, contains('/MediaBox [0 0 200 100]'));
      expect(text, contains('0 0 m 100 50 l S'));
    });

    test('rejects encrypted and non-PDF data without changing the result', () async {
      final merger = PdfPageMerger();
      merger.addPdf(await _vectorPdf(pages: 1));
      final encrypted = latin1.decode(_brokenClassicPdf()).replaceFirst(
          'trailer << /Size 5', 'trailer << /Encrypt << /Filter /Standard >> /Size 5');
      expect(() => merger.addPdf(Uint8List.fromList(latin1.encode(encrypted))),
          throwsA(isA<PdfMergeException>()));
      expect(() => merger.addPdf(Uint8List.fromList(latin1.encode('<html>404</html>'))),
          throwsA(isA<PdfMergeException>()));
      expect(merger.pageCount, 1);
      expect(PdfPageMerger().addPdf(merger.save()), 1);
    });
  });

  group('SongPrintService.printEntries', () {
    tearDown(NativeFileService.debugReset);

    test('merges vector PDFs, images (A4) and rasterised fallback', () async {
      final vector = await _vectorPdf();
      final png = img.encodePng(img.Image(width: 20, height: 10));
      final rasterFallback = await _vectorPdf(pages: 1, width: 100, height: 100);
      final files = <String, Uint8List?>{
        'a.pdf': vector,
        'b.png': png,
        'c.pdf': Uint8List.fromList(latin1.encode('%PDF-1.4 kaputt')),
        'd.pdf': null,
        'e.txt': Uint8List(3),
      };
      Uint8List? printed;
      NativeFileService.layoutPdf = (bytes, _) async {
        printed = bytes;
        return true;
      };
      var rasterized = 0;
      final service = SongPrintService(
        download: (url) async => files[url],
        rasterizePdf: (_) async {
          rasterized++;
          return rasterFallback;
        },
      );
      SongPrintEntry entry(String name, {int copies = 1}) => SongPrintEntry(
            song: const Song(name: 'Werk'),
            file: SongFile(
              fileName: name,
              fileType: name.split('.').last,
              url: name,
            ),
            copies: copies,
          );
      var merged = false;

      final result = await service.printEntries(
        [
          entry('a.pdf', copies: 2),
          entry('b.png'),
          entry('c.pdf'),
          entry('d.pdf'),
          entry('e.txt'),
        ],
        'noten.pdf',
        onMerged: () => merged = true,
      );

      expect(result!.pageCount, 4 + 1 + 1);
      expect(result.skipped, 2);
      expect(merged, isTrue);
      expect(rasterized, 1);
      final text = latin1.decode(printed!);
      expect(_count(text, RegExp(r'/MediaBox \[0 0 300(\.0+)? 400(\.0+)?\]')), 4);
      expect(_count(text, RegExp(r'/MediaBox \[0 0 595\.2\d* 841\.8\d*\]')), 1);
      // The PNG page carries an image (the vector pages none, see above).
      expect(text, contains('/Subtype /Image'));
      expect(PdfPageMerger().addPdf(printed!), 6);
    });
  });
}
