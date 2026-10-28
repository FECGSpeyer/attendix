import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Tenant / organisation branding drawn on exported PDFs and images.
///
/// Port of Ionic `Utils.buildTenantBranding` + `Utils.addBrandingHeader`.
class PdfBranding {
  const PdfBranding({this.logoPng, this.logoWidth = 0, this.logoHeight = 0, this.text});

  /// Downscaled PNG bytes of the logo (null when none / not decodable).
  final Uint8List? logoPng;
  final int logoWidth;
  final int logoHeight;
  final String? text;

  bool get hasLogo => logoPng != null && logoWidth > 0 && logoHeight > 0;
  bool get isEmpty => !hasLogo && (text == null || text!.isEmpty);

  /// Builds the branding from a configured logo URL + text. The logo is
  /// fetched and downscaled to max. 120px (like Ionic) — any failure just
  /// drops the logo so branding never breaks an export. Returns null when
  /// nothing is configured.
  static Future<PdfBranding?> fromSource({String? logoUrl, String? text}) async {
    final trimmed = text?.trim();
    final hasText = trimmed != null && trimmed.isNotEmpty;
    final hasUrl = logoUrl != null && logoUrl.isNotEmpty;
    if (!hasText && !hasUrl) return null;
    final logo = hasUrl ? await loadLogo(logoUrl) : null;
    if (logo == null && !hasText) return null;
    return PdfBranding(
      logoPng: logo?.png,
      logoWidth: logo?.width ?? 0,
      logoHeight: logo?.height ?? 0,
      text: hasText ? trimmed : null,
    );
  }

  static final Map<String, ({Uint8List png, int width, int height})?> _logoCache = {};

  /// Fetches [url] and returns a downscaled PNG (cached per session).
  static Future<({Uint8List png, int width, int height})?> loadLogo(String url) async {
    if (_logoCache.containsKey(url)) return _logoCache[url];
    ({Uint8List png, int width, int height})? result;
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        result = await downscaleToPng(response.bodyBytes);
      }
    } catch (_) {
      result = null;
    }
    _logoCache[url] = result;
    return result;
  }

  /// Decodes any image format the engine supports and re-encodes it as PNG
  /// with the longest edge capped at [maxEdge] px.
  static Future<({Uint8List png, int width, int height})?> downscaleToPng(
    Uint8List bytes, {
    int maxEdge = 120,
  }) async {
    try {
      final probe = await ui.instantiateImageCodec(bytes);
      final first = (await probe.getNextFrame()).image;
      final w = first.width, h = first.height;
      first.dispose();
      if (w == 0 || h == 0) return null;
      final scale = maxEdge / (w > h ? w : h);
      final tw = scale < 1 ? (w * scale).round().clamp(1, maxEdge) : w;
      final th = scale < 1 ? (h * scale).round().clamp(1, maxEdge) : h;
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: tw, targetHeight: th);
      final image = (await codec.getNextFrame()).image;
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) return null;
      return (png: data.buffer.asUint8List(), width: tw, height: th);
    } catch (_) {
      return null;
    }
  }
}

/// Letterhead-style export header (Ionic `Utils.addBrandingHeader`):
///  * top row: logo + branding text (left), "Erstellt am: …" (right)
///  * large title + smaller subtitle ("Stand: …" / date)
///  * thin accent-colored divider rule.
///
/// The title/subtitle/rule are always drawn; the branding parts are optional.
/// [compact] is the scaled-down variant for the "2x A5 auf A4 quer" layout.
pw.Widget buildPdfBrandingHeader({
  PdfBranding? branding,
  required String title,
  String? subtitle,
  bool compact = false,
  DateTime? createdAt,
  PdfColor accentColor = const PdfColor.fromInt(0xFF005238),
}) {
  const mm = PdfPageFormat.mm;
  final logoHeight = (compact ? 7 : 10) * mm;
  final brandFontSize = compact ? 9.0 : 12.0;
  final stampFontSize = compact ? 6.0 : 8.0;
  final stamp = 'Erstellt am: ${DateFormat('dd.MM.yyyy HH:mm').format(createdAt ?? DateTime.now())}';

  final logo = branding != null && branding.hasLogo
      ? pw.Image(
          pw.MemoryImage(branding.logoPng!),
          height: logoHeight,
          width: logoHeight * branding.logoWidth / branding.logoHeight,
        )
      : null;
  final text = branding?.text;

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.SizedBox(
        height: logoHeight,
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logo != null) ...[logo, pw.SizedBox(width: (compact ? 2 : 4) * mm)],
            if (text != null && text.isNotEmpty)
              pw.Expanded(
                child: pw.Text(
                  text,
                  maxLines: 1,
                  style: pw.TextStyle(
                    fontSize: brandFontSize,
                    fontWeight: pw.FontWeight.bold,
                    color: const PdfColor.fromInt(0xFF3C3C3C),
                  ),
                ),
              )
            else
              pw.Spacer(),
            pw.Text(
              stamp,
              style: pw.TextStyle(fontSize: stampFontSize, color: const PdfColor.fromInt(0xFF8C8C8C)),
            ),
          ],
        ),
      ),
      pw.SizedBox(height: (compact ? 3 : 4) * mm),
      pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: compact ? 13 : 20,
          fontWeight: pw.FontWeight.bold,
          color: const PdfColor.fromInt(0xFF1E1E1E),
        ),
      ),
      if (subtitle != null && subtitle.isNotEmpty) ...[
        pw.SizedBox(height: compact ? 1 : 2),
        pw.Text(
          subtitle,
          style: pw.TextStyle(fontSize: compact ? 8 : 10, color: const PdfColor.fromInt(0xFF787878)),
        ),
      ],
      pw.SizedBox(height: (compact ? 2 : 3) * mm),
      pw.Container(height: compact ? 0.4 * mm : 0.6 * mm, color: accentColor),
      pw.SizedBox(height: (compact ? 4 : 6) * mm),
    ],
  );
}
