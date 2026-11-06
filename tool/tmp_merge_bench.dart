import 'package:attendix/features/songs/data/pdf_page_merger.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<void> main() async {
  final sw = Stopwatch()..start();
  final doc = pw.Document();
  for (var i = 0; i < 2; i++) {
    doc.addPage(pw.Page(
      pageFormat: const PdfPageFormat(300, 400),
      build: (_) => pw.Text('Seite $i'),
    ));
  }
  final bytes = await doc.save();
  print('generate ${sw.elapsedMilliseconds} ms');
  final m = PdfPageMerger();
  print('pages ${m.addPdf(bytes, copies: 2)} ${sw.elapsedMilliseconds} ms');
  final out = m.save();
  print('save ${sw.elapsedMilliseconds} ms');
  print('again ${PdfPageMerger().addPdf(out)} ${sw.elapsedMilliseconds} ms');
}
