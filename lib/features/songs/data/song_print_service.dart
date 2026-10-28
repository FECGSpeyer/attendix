
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../data/models/song/song.dart';
import '../../../data/models/song/song_additional_field.dart';
import '../presentation/utils/song_utils.dart';

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
  }) async {
    final date = DateFormat('dd.MM.yyyy').format(DateTime.now());
    final extraFields =
        additionalFields.where((f) => viewOpts.contains(f.id)).toList();

    final head = <String>['Nr.', 'Name'];
    final withLastSung = viewOpts.contains('lastSung') && showLastSung;
    if (withLastSung) head.add(isOrchestra ? 'Zuletzt gespielt' : 'Zuletzt gesungen');
    if (viewOpts.contains('difficulty')) head.add('Schwierigkeit');
    if (viewOpts.contains('withChoir')) head.add('Chor/Orch.');
    if (viewOpts.contains('withSolo')) head.add('Solo');
    for (final f in extraFields) {
      head.add(f.name);
    }

    final body = songs.map((song) {
      final row = <String>['${song.prefix ?? ''}${song.number ?? ''}', song.name];
      if (withLastSung) row.add(SongUtils.formatDate(song.lastSung));
      if (viewOpts.contains('difficulty')) {
        row.add(song.difficulty == null ? '' : SongUtils.difficultyLabel(song.difficulty));
      }
      if (viewOpts.contains('withChoir')) row.add(song.withChoir ? 'Ja' : '');
      if (viewOpts.contains('withSolo')) row.add(song.withSolo ? 'Ja' : '');
      for (final f in extraFields) {
        final v = song.additionalFields?[f.id];
        row.add(v == true ? 'Ja' : v == false ? 'Nein' : (v ?? '').toString());
      }
      return row;
    }).toList();

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 40),
      header: (_) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 12),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('$tenantShortName Werkverzeichnis',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text('Stand: $date', style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
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
