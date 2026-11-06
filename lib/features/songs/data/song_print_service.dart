
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/services/pdf_branding.dart';
import '../../../data/models/song/song.dart';
import '../../../data/models/song/song_additional_field.dart';
import '../presentation/utils/song_utils.dart';
import 'pdf_page_merger.dart';
import '../../../l10n/l10n.dart';
import '../../../core/services/native/native_file_service.dart';
import '../../../core/services/pdf_fonts.dart';

/// One file to print (optionally several copies)
class SongPrintEntry {
  const SongPrintEntry({required this.song, required this.file, this.copies = 1});

  final Song song;
  final SongFile file;
  final int copies;
}

/// Result of merging print entries
class SongPrintResult {
  const SongPrintResult({required this.pageCount, required this.skipped});

  final int pageCount;
  final int skipped;
}

final songPrintServiceProvider = Provider<SongPrintService>((ref) {
  return SongPrintService();
});

/// Port of Ionic `PrintService.printEntries`: merges PDFs and images of
/// several song files (with copies) into one document and opens the
/// platform print dialog.
///
/// Like Ionic `mergeEntries` (pdf-lib `copyPages`), PDF pages are taken over
/// as vector pages in their original size ([PdfPageMerger], pure Dart on all
/// platforms). Images become an A4 page with the image centred and fitted.
/// A PDF that cannot be imported (damaged, encrypted) is rasterised instead
/// of failing the whole print.
class SongPrintService {
  SongPrintService({
    Future<Uint8List?> Function(String url)? download,
    Future<Uint8List> Function(Uint8List pdf)? rasterizePdf,
  })  : _downloadFn = download ?? _httpDownload,
        _rasterizeFn = rasterizePdf ?? _rasterize;

  /// Test seams (production: HTTP download / `Printing.raster`).
  final Future<Uint8List?> Function(String url) _downloadFn;
  final Future<Uint8List> Function(Uint8List pdf) _rasterizeFn;

  bool _printing = false;

  static Future<Uint8List?> _httpDownload(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return null;
      return response.bodyBytes;
    } catch (_) {
      return null;
    }
  }

  /// Fallback for PDFs that cannot be imported as vector pages: every page
  /// rendered at 150 dpi into a new PDF of the same page size.
  static Future<Uint8List> _rasterize(Uint8List bytes) async {
    final doc = pw.Document();
    await for (final page in Printing.raster(bytes, dpi: 150)) {
      final image = pw.MemoryImage(await page.toPng());
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat(page.width * 72 / 150, page.height * 72 / 150),
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
      ));
    }
    return doc.save();
  }

  /// Ionic: PNG/JPG on an A4 page (595.28 × 841.89 pt), centred and fitted.
  static Future<Uint8List> _imagePage(Uint8List bytes) {
    final image = pw.MemoryImage(bytes);
    final doc = pw.Document()
      ..addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
      ));
    return doc.save();
  }

  /// Merge and print. Returns null if a print job is already running.
  /// [onMerged] runs once merging is done, before the print dialog opens
  /// (Ionic dismisses its loading overlay there).
  Future<SongPrintResult?> printEntries(
    List<SongPrintEntry> entries,
    String fileName, {
    VoidCallback? onMerged,
  }) async {
    if (_printing) return null;
    _printing = true;
    try {
      final merger = PdfPageMerger();
      var pages = 0;
      var skipped = 0;

      for (final entry in entries) {
        if (entry.copies <= 0) continue;
        final bytes = await _downloadFn(entry.file.url);
        if (bytes == null) {
          skipped++;
          continue;
        }

        try {
          if (SongUtils.isPdf(entry.file)) {
            try {
              pages += merger.addPdf(bytes, copies: entry.copies);
            } catch (e) {
              // Damaged / encrypted PDF: insert it rasterised instead.
              if (kDebugMode) {
                debugPrint('[SongPrintService] raster fallback ${entry.file.fileName}: $e');
              }
              pages += merger.addPdf(await _rasterizeFn(bytes), copies: entry.copies);
            }
          } else if (SongUtils.isImage(entry.file)) {
            pages += merger.addPdf(await _imagePage(bytes), copies: entry.copies);
          } else {
            skipped++;
            continue;
          }
        } catch (e) {
          if (kDebugMode) debugPrint('[SongPrintService] skip ${entry.file.fileName}: $e');
          skipped++;
          continue;
        }
        // Let the loading overlay repaint between files.
        await Future<void>.delayed(Duration.zero);
      }

      final data = pages > 0 ? merger.save() : null;
      onMerged?.call();
      if (data != null) await NativeFileService.printPdf(data, fileName);
      return SongPrintResult(pageCount: pages, skipped: skipped);
    } finally {
      _printing = false;
    }
  }

  /// Werkverzeichnis als PDF (Ionic `exportSongsPdf`).
  Future<void> exportSongsCatalogPdf({
    required List<Song> songs,
    required String tenantShortName,
    required List<String> viewOpts,
    required bool showLastSung,
    required bool isOrchestra,
    required List<SongAdditionalField> additionalFields,
    PdfBranding? branding,
  }) async {
    final l10n = l10nWithoutContext;
    final date = DateFormat(dateFmt()).format(DateTime.now());
    final extraFields =
        additionalFields.where((f) => viewOpts.contains(f.id)).toList();

    final head = <String>[l10n.songsNumberShort, l10n.songsName];
    final withLastSung = viewOpts.contains('lastSung') && showLastSung;
    if (withLastSung) head.add(isOrchestra ? l10n.songsLastPlayed : l10n.songsLastSung);
    if (viewOpts.contains('difficulty')) head.add(l10n.songsDifficultyShort);
    if (viewOpts.contains('withChoir')) head.add(l10n.songsChoirOrchShort);
    if (viewOpts.contains('withSolo')) head.add(l10n.songsSolo);
    for (final f in extraFields) {
      head.add(f.name);
    }

    final body = songs.map((song) {
      final row = <String>['${song.prefix ?? ''}${song.number ?? ''}', song.name];
      if (withLastSung) row.add(SongUtils.formatDate(song.lastSung));
      if (viewOpts.contains('difficulty')) {
        row.add(song.difficulty == null ? '' : SongUtils.difficultyLabel(song.difficulty));
      }
      if (viewOpts.contains('withChoir')) row.add(song.withChoir ? l10n.commonYes : '');
      if (viewOpts.contains('withSolo')) row.add(song.withSolo ? l10n.commonYes : '');
      for (final f in extraFields) {
        final v = song.additionalFields?[f.id];
        row.add(v == true ? l10n.commonYes : v == false ? l10n.commonNo : (v ?? '').toString());
      }
      return row;
    }).toList();

    final doc = await PdfFonts.document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 40),
      // MISC2: letterhead with tenant/org branding (Ionic addBrandingHeader)
      header: (_) => buildPdfBrandingHeader(
        branding: branding,
        title: l10n.songsCatalogTitle(tenantShortName),
        subtitle: l10n.planningAsOf(date),
      ),
      build: (_) => [
        pw.TableHelper.fromTextArray(
          headers: head,
          data: body,
          border: null,
          headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          headerDecoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(width: 0.5)),
          ),
          cellStyle: const pw.TextStyle(fontSize: 9),
          oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF5F5F5)),
          cellAlignment: pw.Alignment.centerLeft,
        ),
      ],
    ));

    final bytes = await doc.save();
    final fileName =
        '${tenantShortName}_Werkverzeichnis_${date.replaceAll('.', '-')}.pdf';
    await NativeFileService.saveBytes(bytes, fileName);
  }
}
