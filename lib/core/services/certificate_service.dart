import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Asset path of the Vorkurs certificate background (A4 portrait, copied
/// from Ionic `src/assets/urkunde-vorkurs.jpg`).
const String vorkursCertificateAsset = 'assets/certificates/urkunde-vorkurs.jpg';

/// Ionic settings.page `isVorkursTenant`: short or long name contains
/// "vorkurs" (case-insensitive).
bool isVorkursTenantName(String? shortName, String? longName) {
  return (shortName?.toLowerCase().contains('vorkurs') ?? false) ||
      (longName?.toLowerCase().contains('vorkurs') ?? false);
}

/// Builds the Vorkurs certificates PDF — one A4 page per person.
///
/// Port of Ionic `Utils.generateVorkursCertificates`: name (Times bold
/// italic, 48pt shrinking to min. 28pt), fixed body text and
/// "`city`, den `date`" overlaid on the background image.
class CertificateService {
  const CertificateService();

  static const double _mm = PdfPageFormat.mm;

  Future<Uint8List> buildVorkursCertificates(
    List<({String firstName, String lastName})> persons, {
    String city = 'Speyer',
    DateTime? date,
    Uint8List? backgroundBytes,
  }) async {
    final bg = backgroundBytes ??
        (await rootBundle.load(vorkursCertificateAsset)).buffer.asUint8List();
    final image = pw.MemoryImage(bg);
    final today = DateFormat('d.M.yyyy').format(date ?? DateTime.now());

    final boldItalic = pw.Font.timesBoldItalic();
    final italic = pw.Font.timesItalic();

    final doc = pw.Document();
    const w = 210.0;

    // jsPDF positions text by its baseline; approximate the ascent so the
    // widgets land on the same baselines as in Ionic.
    double topFor(double baselineMm, double fontSizePt) =>
        (baselineMm * _mm) - fontSizePt * 0.78;

    pw.Widget centered(String text, double baselineMm, double size, pw.Font font) {
      return pw.Positioned(
        left: 30 * _mm,
        right: 30 * _mm,
        top: topFor(baselineMm, size),
        child: pw.Center(
          child: pw.FittedBox(
            fit: pw.BoxFit.scaleDown,
            child: pw.Text(
              text,
              style: pw.TextStyle(
                font: font,
                fontSize: size,
                color: const PdfColor.fromInt(0xFF141414),
              ),
            ),
          ),
        ),
      );
    }

    for (final p in persons) {
      final fullName = '${p.firstName} ${p.lastName}'.trim();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Stack(
            children: [
              pw.Positioned.fill(child: pw.Image(image, fit: pw.BoxFit.fill)),
              centered(fullName, 138, 48, boldItalic),
              centered('hat die Vorkursprüfung', 168, 33, boldItalic),
              centered('erfolgreich bestanden', 186, 33, boldItalic),
              pw.Positioned(
                left: 35 * _mm,
                top: topFor(252, 24),
                child: pw.SizedBox(
                  width: (w - 70) * _mm,
                  child: pw.Text(
                    '$city, den $today',
                    style: pw.TextStyle(
                      font: italic,
                      fontSize: 24,
                      color: const PdfColor.fromInt(0xFF141414),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return doc.save();
  }
}
