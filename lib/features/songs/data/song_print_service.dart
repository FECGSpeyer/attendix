
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
import '../../../l10n/l10n.dart';

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
/// PDF pages are rasterized (the `pdf` package cannot import existing PDFs).
class SongPrintService {
  bool _printing = false;

  Future<Uint8List?> _download(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return null;
      return response.bodyBytes;
    } catch (_) {
      return null;
    }
  }

  /// Merge and print. Returns null if a print job is already running.
  Future<SongPrintResult?> printEntries(
    List<SongPrintEntry> entries,
    String fileName,
  ) async {
    if (_printing) return null;
    _printing = true;
    try {
      final doc = pw.Document();
      var pages = 0;
      var skipped = 0;

      for (final entry in entries) {
        if (entry.copies <= 0) continue;
        final bytes = await _download(entry.file.url);
        if (bytes == null) {
          skipped++;
          continue;
        }

        final images = <pw.MemoryImage>[];
        final pageFormats = <PdfPageFormat>[];
        try {
          if (SongUtils.isPdf(entry.file)) {
            await for (final page in Printing.raster(bytes, dpi: 150)) {
              final png = await page.toPng();
              images.add(pw.MemoryImage(png));
              pageFormats.add(PdfPageFormat(
                page.width * 72 / 150,
                page.height * 72 / 150,
              ));
            }
          } else if (SongUtils.isImage(entry.file)) {
            images.add(pw.MemoryImage(bytes));
            pageFormats.add(PdfPageFormat.a4);
          } else {
            skipped++;
            continue;
          }
        } catch (e) {
          if (kDebugMode) debugPrint('[SongPrintService] skip ${entry.file.fileName}: $e');
          skipped++;
          continue;
        }

        for (var c = 0; c < entry.copies; c++) {
          for (var i = 0; i < images.length; i++) {
            final image = images[i];
            doc.addPage(pw.Page(
              pageFormat: pageFormats[i],
              margin: pw.EdgeInsets.zero,
              build: (_) => pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
            ));
            pages++;
          }
        }
      }

      if (pages > 0) {
        final data = await doc.save();
        await Printing.layoutPdf(onLayout: (_) async => data, name: fileName);
      }
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

    final doc = pw.Document();
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
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }
}
