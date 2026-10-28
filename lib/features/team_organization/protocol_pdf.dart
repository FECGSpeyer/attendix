import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../l10n/l10n.dart';
import 'tiptap_delta.dart';

class ProtocolPdfSection {
  ProtocolPdfSection({required this.title, this.meta, this.outcome, this.doc, this.tasks = const []});

  /// e.g. "TOP 1 · Konzertplanung"
  final String title;

  /// e.g. "19:35 · 20 min · Anna Weber"
  final String? meta;
  final String? outcome;
  final Map<String, dynamic>? doc;
  final List<String> tasks;
}

class ProtocolPdfData {
  ProtocolPdfData({
    required this.title,
    required this.subtitle,
    this.status,
    this.present = const [],
    this.excused = const [],
    this.sections = const [],
    this.generalNotes,
    this.otherTasks = const [],
  });

  final String title;
  final String subtitle;
  final String? status;
  final List<String> present;
  final List<String> excused;
  final List<ProtocolPdfSection> sections;
  final Map<String, dynamic>? generalNotes;
  final List<String> otherTasks;
}

const _accent = PdfColor.fromInt(0xFF438E96);

/// Builds the protocol as A4 PDF (port of Ionic protocol-pdf.ts).
Future<Uint8List> createProtocolPdf(ProtocolPdfData data) async {
  final doc = pw.Document();
  final l10n = l10nWithoutContext;

  List<pw.Widget> docWidgets(Map<String, dynamic>? d) => [
        for (final line in docToLines(d))
          pw.Padding(
            padding: pw.EdgeInsets.only(left: 12.0 * line.indent, bottom: 2),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (line.marker != null)
                  pw.SizedBox(
                    width: 14,
                    child: pw.Text(
                      line.marker == '☑' ? '[x]' : line.marker == '☐' ? '[ ]' : line.marker!,
                      style: const pw.TextStyle(fontSize: 10.5),
                    ),
                  ),
                pw.Expanded(
                  child: pw.Text(
                    line.text,
                    style: pw.TextStyle(
                      fontSize: line.heading ? 12 : 10.5,
                      fontWeight: line.heading ? pw.FontWeight.bold : pw.FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ];

  pw.Widget label(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
        child: pw.Text(text, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _accent)),
      );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(l10n.protocolPage(context.pageNumber, context.pagesCount),
            style: const pw.TextStyle(fontSize: 8)),
      ),
      build: (context) => [
        pw.Text(data.title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _accent)),
        if (data.subtitle.isNotEmpty) pw.Text(data.subtitle, style: const pw.TextStyle(fontSize: 11)),
        if (data.status != null)
          pw.Text(data.status!, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.Divider(color: _accent),
        if (data.present.isNotEmpty) ...[
          label(l10n.protocolPresentList(data.present.length)),
          pw.Text(data.present.join(', '), style: const pw.TextStyle(fontSize: 10)),
        ],
        if (data.excused.isNotEmpty) ...[
          label(l10n.protocolExcusedList(data.excused.length)),
          pw.Text(data.excused.join(', '), style: const pw.TextStyle(fontSize: 10)),
        ],
        for (final s in data.sections) ...[
          pw.SizedBox(height: 8),
          pw.Row(children: [
            pw.Expanded(
              child: pw.Text(s.title, style: pw.TextStyle(fontSize: 12.5, fontWeight: pw.FontWeight.bold)),
            ),
            if (s.outcome != null)
              pw.Text(s.outcome!, style: pw.TextStyle(fontSize: 10, color: _accent, fontWeight: pw.FontWeight.bold)),
          ]),
          if (s.meta != null && s.meta!.isNotEmpty)
            pw.Text(s.meta!, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          pw.SizedBox(height: 3),
          ...docWidgets(s.doc),
          for (final t in s.tasks) pw.Text('-> $t', style: const pw.TextStyle(fontSize: 10)),
        ],
        if (data.generalNotes != null && !isDocEmpty(data.generalNotes)) ...[
          label(l10n.protocolGeneralNotes),
          ...docWidgets(data.generalNotes),
        ],
        if (data.otherTasks.isNotEmpty) ...[
          label(l10n.protocolFurtherTasks),
          for (final t in data.otherTasks) pw.Text('-> $t', style: const pw.TextStyle(fontSize: 10)),
        ],
      ],
    ),
  );

  return doc.save();
}
