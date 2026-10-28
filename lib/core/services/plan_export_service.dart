import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/models/plan/plan.dart';
import '../utils/plan_utils.dart';
import 'pdf_branding.dart';
import '../../l10n/l10n.dart';

/// One plan page of an export.
class PlanExportPage {
  const PlanExportPage({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.fields,
    this.end,
  });

  final String title;

  /// Usually the long date ("Samstag, 18.10.2025"), optionally with the plan label.
  final String subtitle;
  final String time;
  final String? end;
  final List<PlanField> fields;
}

/// PDF / image export of Ablaufpläne (Ionic `Utils.createPlanExport`).
///
/// Supports notes (full width, italic), Programmblöcke (bold head with the
/// summed duration, indented Unterpunkte), info lines and the
/// "2x A5 auf A4 quer" layout.
class PlanExportService {
  const PlanExportService();

  /// Builds the PDF. Every page in [pages] becomes its own PDF page.
  ///
  /// [branding] (logo + text) is drawn in the letterhead of every page
  /// (Ionic `Utils.addBrandingHeader`); without it only title/subtitle/rule.
  Future<Uint8List> buildPdf(List<PlanExportPage> pages, {bool sideBySide = false, PdfBranding? branding}) async {
    final doc = pw.Document();
    for (final page in pages) {
      if (sideBySide) {
        doc.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          build: (_) => pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: _withHeader(page, branding)),
              pw.Container(
                width: 1,
                margin: const pw.EdgeInsets.symmetric(horizontal: 12),
                color: PdfColors.grey400,
                height: PdfPageFormat.a4.landscape.availableHeight,
              ),
              pw.Expanded(child: _withHeader(page, branding)),
            ],
          ),
        ));
      } else {
        doc.addPage(pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(36, 28, 36, 36),
          header: (_) => buildPdfBrandingHeader(
            branding: branding,
            title: page.title,
            subtitle: page.subtitle,
          ),
          build: (_) => [_planContent(page, small: false)],
        ));
      }
    }
    return doc.save();
  }

  /// Renders the first page of the PDF as PNG (for "Als Bild").
  Future<Uint8List> buildImage(List<PlanExportPage> pages, {bool sideBySide = false, PdfBranding? branding}) async {
    final pdf = await buildPdf(pages, sideBySide: sideBySide, branding: branding);
    await for (final page in Printing.raster(pdf, pages: const [0], dpi: 150)) {
      return page.toPng();
    }
    throw StateError(l10nWithoutContext.coreFlutterExportPdfRenderFailed);
  }

  /// Opens the system print / save dialog with the PDF.
  Future<void> sharePdf(List<PlanExportPage> pages,
      {bool sideBySide = false, required String fileName, PdfBranding? branding}) async {
    final bytes = await buildPdf(pages, sideBySide: sideBySide, branding: branding);
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: '$fileName.pdf');
  }

  /// Saves the PNG via the share sheet / download.
  Future<void> shareImage(List<PlanExportPage> pages,
      {bool sideBySide = false, required String fileName, PdfBranding? branding}) async {
    final bytes = await buildImage(pages, sideBySide: sideBySide, branding: branding);
    await Printing.sharePdf(bytes: bytes, filename: '$fileName.png');
  }

  pw.Widget _withHeader(PlanExportPage page, PdfBranding? branding) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        buildPdfBrandingHeader(
          branding: branding,
          title: page.title,
          subtitle: page.subtitle,
          compact: true,
        ),
        _planContent(page, small: true),
      ],
    );
  }

  pw.Widget _planContent(PlanExportPage page, {required bool small}) {
    final fontSize = small ? 8.0 : 11.0;
    final pad = small ? 3.0 : 5.0;
    final fields = page.fields;
    final hasConductors = fields.any((f) => (f.conductor ?? '').trim().isNotEmpty);
    final start = PlanUtils.parseTimeToMinutes(page.time) ?? 0;

    pw.Widget cell(String text, {bool bold = false, bool italic = false, PdfColor? color, double indent = 0}) {
      return pw.Padding(
        padding: pw.EdgeInsets.fromLTRB(pad + indent, pad, pad, pad),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            fontStyle: italic ? pw.FontStyle.italic : pw.FontStyle.normal,
            color: color ?? PdfColors.grey900,
          ),
        ),
      );
    }

    pw.Widget nameCell(PlanField f, String name, {bool bold = false, double indent = 0}) {
      final info = (f.info ?? '').trim();
      return pw.Padding(
        padding: pw.EdgeInsets.fromLTRB(pad + indent, pad, pad, pad),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(name,
                style: pw.TextStyle(
                  fontSize: fontSize,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                )),
            if (info.isNotEmpty)
              pw.Text(info,
                  style: pw.TextStyle(
                    fontSize: fontSize - 1.5,
                    fontStyle: pw.FontStyle.italic,
                    color: PdfColors.grey700,
                  )),
          ],
        ),
      );
    }

    final l10n = l10nWithoutContext;
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey600, width: 0.8)),
        ),
        children: [
          cell(l10n.exportTime, bold: true),
          cell(l10n.exportProgrammeItem, bold: true),
          if (hasConductors) cell(l10n.exportPerformer, bold: true),
          cell(l10n.exportDuration, bold: true),
        ],
      ),
    ];

    var current = start;
    var stripe = false;
    for (final f in fields) {
      if (PlanUtils.isAgendaPlaceholder(f)) continue;
      if (PlanUtils.isNote(f)) {
        final colCount = hasConductors ? 4 : 3;
        rows.add(pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEBEBEB)),
          children: [
            cell(f.name, italic: true, color: PdfColors.grey700),
            for (var i = 1; i < colCount; i++) pw.SizedBox(),
          ],
        ));
        continue;
      }
      final head = PlanUtils.isGroupHead(f);
      final child = f.groupId != null;
      final minutes = PlanUtils.displayMinutes(f, fields);
      stripe = !stripe;
      rows.add(pw.TableRow(
        decoration: stripe ? const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF5F5F5)) : null,
        children: [
          cell(l10n.attendanceTimeOClock(PlanUtils.formatMinutes(current)),
              color: child ? PdfColors.grey700 : null),
          nameCell(f, f.name, bold: head, indent: child ? 6 : 0),
          if (hasConductors) cell(f.conductor ?? ''),
          cell(l10n.attendanceMinutesShort(minutes), bold: head),
        ],
      ));
      current += PlanUtils.fieldMinutes(f);
    }

    final endText = (page.end != null && page.end!.isNotEmpty)
        ? PlanUtils.formatTime(page.end)
        : PlanUtils.formatMinutes(current);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Table(
          columnWidths: {
            0: pw.FixedColumnWidth(small ? 46 : 64),
            1: const pw.FlexColumnWidth(3),
            if (hasConductors) 2: const pw.FlexColumnWidth(2),
            (hasConductors ? 3 : 2): pw.FixedColumnWidth(small ? 36 : 50),
          },
          children: rows,
        ),
        pw.SizedBox(height: 6),
        pw.Text(l10n.coreFlutterExportEndAt(endText), style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }
}

final planExportServiceProvider = Provider<PlanExportService>((ref) => const PlanExportService());
