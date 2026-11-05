import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// Unicode font for every PDF export (Ionic `Utils.registerExportFont`).
///
/// The pdf package's built-in Helvetica only covers Latin-1, so Cyrillic
/// names, typographic quotes („“), dashes (–) and € came out as empty boxes.
/// Ionic embeds NotoSans (regular / bold / italic) in all jsPDF exports; the
/// same TTFs ship in assets/fonts (SIL OFL 1.1, NotoSans-OFL.txt).
///
/// The fonts are loaded once per session. Any failure falls back to the
/// built-in font so an export never breaks (like Ionic).
class PdfFonts {
  PdfFonts._();

  static const _regular = 'assets/fonts/NotoSans-Regular.ttf';
  static const _bold = 'assets/fonts/NotoSans-Bold.ttf';
  static const _italic = 'assets/fonts/NotoSans-Italic.ttf';

  static Future<pw.ThemeData?>? _theme;

  /// Theme with NotoSans as base/bold/italic font, null when loading failed.
  static Future<pw.ThemeData?> theme() {
    return _theme ??= _load().then((theme) {
      if (theme == null) _theme = null; // retry on the next export
      return theme;
    });
  }

  /// New PDF document that uses the export font.
  static Future<pw.Document> document() async => pw.Document(theme: await theme());

  static Future<pw.ThemeData?> _load() async {
    try {
      final regular = pw.Font.ttf(await rootBundle.load(_regular));
      final bold = pw.Font.ttf(await rootBundle.load(_bold));
      final italic = pw.Font.ttf(await rootBundle.load(_italic));
      // Ionic registers no bold-italic face either; bold is the closest.
      return pw.ThemeData.withFont(base: regular, bold: bold, italic: italic, boldItalic: bold);
    } catch (e, st) {
      if (kDebugMode) debugPrint('[PdfFonts] export font not loaded: $e $st');
      return null;
    }
  }

  /// Resets the cache (tests).
  @visibleForTesting
  static void debugReset() => _theme = null;
}
