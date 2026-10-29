import 'dart:io';

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/services/export_service.dart';
import 'package:attendix/core/services/pdf_branding.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';

import '../../factories/test_factories.dart';

/// ASTRA_EXPORT: player list and attendance list PDFs carry the same
/// tenant/org letterhead as Ionic export.page (`Utils.buildTenantBranding` +
/// `Utils.addBrandingHeader`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = ExportService();
  final players = TestFactories.createPersonList(5, tenantId: 1);
  final attendances = TestFactories.createAttendanceList(10, tenantId: 1, startDate: DateTime(2026, 9, 1));
  final personAttendances = [
    for (final p in players)
      for (final a in attendances)
        TestFactories.createPersonAttendance(
          attendanceId: a.id,
          personId: p.id,
          status: AttendanceStatus.values[(p.id! + a.id!) % AttendanceStatus.values.length],
        ),
  ];
  const branding = PdfBranding(text: 'Musikverein Beispiel');
  const fields = ['Vorname', 'Nachname'];

  String header(List<int> bytes) => String.fromCharCodes(bytes.take(5));

  group('Player list PDF', () {
    test('builds with and without branding; branding adds the letterhead', () async {
      final plain = await service.buildPlayerListPdf(players: players, fields: fields, tenantName: 'MVB');
      final branded = await service.buildPlayerListPdf(
          players: players, fields: fields, tenantName: 'MVB', branding: branding);
      expect(header(plain), '%PDF-');
      expect(header(branded), '%PDF-');
      expect(branded.length, greaterThan(plain.length));
    });

    test('long lists fall back to the smallest fit step and still render', () async {
      final many = TestFactories.createPersonList(150, tenantId: 1);
      final bytes = await service.buildPlayerListPdf(
          players: many, fields: fields, tenantName: 'MVB', branding: branding);
      expect(header(bytes), '%PDF-');
    });
  });

  group('Attendance list PDF', () {
    test('builds with and without branding; branding adds the letterhead', () async {
      Future<List<int>> build(PdfBranding? b) => service.buildAttendancePdf(
            players: players,
            attendances: attendances,
            personAttendances: personAttendances,
            fields: fields,
            tenantName: 'MVB',
            branding: b,
          );
      final plain = await build(null);
      final branded = await build(branding);
      expect(header(plain), '%PDF-');
      expect(branded.length, greaterThan(plain.length));
    });

    test('status cell colors match Ionic exportAttPDF didParseCell', () {
      expect(ExportService.statusCellColor('A'), const PdfColor.fromInt(0xFFB22222)); // 178,34,34
      expect(ExportService.statusCellColor('X'), const PdfColor.fromInt(0xFF32CD32)); // 50,205,50
      expect(ExportService.statusCellColor('E'), const PdfColor.fromInt(0xFFFFC409)); // 255,196,9
      expect(ExportService.statusCellColor('L'), const PdfColor.fromInt(0xFF00BFFF)); // 0,191,255
      expect(ExportService.statusCellColor('N'), const PdfColor.fromInt(0xFFDCDCDC)); // 220,220,220
      expect(ExportService.statusCellColor(''), isNull);
      expect(ExportService.statusCellColor('Max'), isNull);
    });
  });

  test('auto-fit steps follow Ionic probes', () {
    expect(ExportService.playerListFitSteps.map((s) => s.fontSize), [11, 11, 9, 8]);
    expect(ExportService.attendanceFitSteps.map((s) => s.fontSize), [8, 8, 7, 6]);
  });

  group('Source wiring', () {
    final service = File('lib/core/services/export_service.dart').readAsStringSync();
    final page = File('lib/features/export/presentation/pages/export_page.dart').readAsStringSync();

    test('both list PDFs go through the shared branding header', () {
      expect(service, contains("import 'pdf_branding.dart';"));
      expect(RegExp(r'_buildBrandedTablePdf\(').allMatches(service).length, 3,
          reason: 'definition + player list + attendance list');
      final helper = RegExp(r'Future<Uint8List> _buildBrandedTablePdf\([\s\S]*?\n  \}\n').firstMatch(service);
      expect(helper, isNotNull);
      expect(helper!.group(0), contains('buildPdfBrandingHeader('));
      expect(helper.group(0), contains('branding: branding'));
    });

    test('Ionic titles, "Stand" subtitle and file names', () {
      expect(service, contains('l10n.exportPlayerListTitle(tenantName)'));
      expect(service, contains('l10n.exportAttendanceTitle(tenantName)'));
      expect(RegExp(r'l10n\.planningAsOf\(date\)').allMatches(service).length, 2);
      expect(service, contains('exportPlayerListFile(tenantName, date)}.pdf'));
      expect(service, contains('exportAttendanceFileAsOf(tenantName, date)}.pdf'));
    });

    test('export page passes the resolved tenant branding to both PDFs', () {
      for (final method in ['exportPlayerListPdf(', 'exportAttendancePdf(']) {
        final call = RegExp('${RegExp.escape(method)}[\\s\\S]*?\\);').firstMatch(page);
        expect(call, isNotNull, reason: method);
        expect(call!.group(0), contains('branding: await resolvePdfBranding(ref)'), reason: method);
      }
    });
  });
}
