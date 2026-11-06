import 'dart:typed_data';

import 'package:excel_community/excel_community.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../constants/enums.dart';
import '../../data/models/attendance/attendance.dart';
import '../../data/models/church/church.dart';
import '../../data/models/person/person.dart';
import '../../l10n/l10n.dart';
import 'native/native_file_service.dart';
import 'pdf_branding.dart';
import 'pdf_fonts.dart';

/// Font size (pt) and cell padding (mm) of one auto-fit step of the
/// player / attendance list PDF (Ionic jspdf-autotable styles).
class ExportTableStyle {
  const ExportTableStyle(this.fontSize, this.paddingVerticalMm, this.paddingHorizontalMm);

  final double fontSize;
  final double paddingVerticalMm;
  final double paddingHorizontalMm;
}

/// Export Service for generating PDF and Excel files
///
/// Based on Ionic export.page.ts
class ExportService {
  /// Workbook with exactly one sheet named [name] (Ionic `book_new` +
  /// `book_append_sheet`). `Excel.createExcel()` already contains an empty
  /// default sheet "Sheet1", so rename it instead of adding a second sheet.
  static Excel _singleSheetWorkbook(String name) {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    if (defaultSheet != name) excel.rename(defaultSheet, name);
    excel.setDefaultSheet(name);
    return excel;
  }

  /// Ionic `exportPlayerPDF` auto-fit steps (font size / cell padding in mm):
  /// default 11/3.5 → padding 2 → font 9 → font 8 + padding 1.5.
  static const List<ExportTableStyle> playerListFitSteps = [
    ExportTableStyle(11, 3.5, 3.5),
    ExportTableStyle(11, 2, 2),
    ExportTableStyle(9, 2, 2),
    ExportTableStyle(8, 1.5, 1.5),
  ];

  /// Ionic `exportAttPDF` auto-fit steps: font 8 / padding 2 → vertical
  /// padding 1.5 → font 7 → font 6 + padding 0.5/1.
  static const List<ExportTableStyle> attendanceFitSteps = [
    ExportTableStyle(8, 2, 2),
    ExportTableStyle(8, 1.5, 2),
    ExportTableStyle(7, 1.5, 2),
    ExportTableStyle(6, 0.5, 1),
  ];

  /// Ionic jsPDF page: A4 portrait, letterhead 14 mm from the sides
  /// (`addBrandingHeader` top row at 16 mm minus half the logo height),
  /// table bottom margin 14 mm.
  static const pw.EdgeInsets pdfMargin = pw.EdgeInsets.fromLTRB(
    14 * PdfPageFormat.mm,
    11 * PdfPageFormat.mm,
    14 * PdfPageFormat.mm,
    14 * PdfPageFormat.mm,
  );

  /// Player list PDF (Ionic `exportPlayerPDF`): saved as
  /// "{name}_Spielerliste_Stand_{date}.pdf" like Ionic.
  Future<void> exportPlayerListPdf({
    required List<Person> players,
    required List<String> fields,
    required String tenantName,
    PdfBranding? branding,
    String Function(Person player, String field)? valueOf,
  }) async {
    final date = DateFormat(dateFmt()).format(DateTime.now());
    final bytes = await buildPlayerListPdf(
      players: players,
      fields: fields,
      tenantName: tenantName,
      branding: branding,
      valueOf: valueOf,
    );
    await NativeFileService.saveBytes(
        bytes, '${l10nWithoutContext.exportPlayerListFile(tenantName, date)}.pdf');
  }

  /// Builds the player list PDF: tenant letterhead (logo + branding text,
  /// "Erstellt am", title "{name} Spielerliste", "Stand: {date}", rule) on
  /// every page via the shared [buildPdfBrandingHeader], then Ionic's plain
  /// table shrunk step by step until it fits on one page.
  Future<Uint8List> buildPlayerListPdf({
    required List<Person> players,
    required List<String> fields,
    required String tenantName,
    PdfBranding? branding,
    String Function(Person player, String field)? valueOf,
  }) async {
    final fieldValue = valueOf ?? _getPlayerFieldValue;
    final l10n = l10nWithoutContext;
    final date = DateFormat(dateFmt()).format(DateTime.now());

    final data = <List<String>>[];
    var row = 1;
    for (final player in players) {
      data.add([row.toString(), ...fields.map((f) => fieldValue(player, f))]);
      row++;
    }

    return _buildBrandedTablePdf(
      branding: branding,
      title: l10n.exportPlayerListTitle(tenantName),
      subtitle: l10n.planningAsOf(date),
      headers: ['', ...fields],
      rows: data,
      fitSteps: playerListFitSteps,
    );
  }

  /// Generate player list Excel
  Future<Uint8List> exportPlayerListExcel({
    required List<Person> players,
    required List<String> fields,
    required String tenantName,
    String Function(Person player, String field)? valueOf,
  }) async {
    final fieldValue = valueOf ?? _getPlayerFieldValue;
    // Ionic exportPlayerExcel: one sheet "Anwesenheit", header row starts
    // with an empty cell, no styling.
    final sheetName = l10nWithoutContext.exportAttendance;
    final excel = _singleSheetWorkbook(sheetName);
    final sheet = excel[sheetName];

    // Header row
    sheet.appendRow([
      TextCellValue(''),
      ...fields.map((f) => TextCellValue(f)),
    ]);

    // Data rows
    int row = 1;
    for (final player in players) {
      sheet.appendRow([
        TextCellValue(row.toString()),
        ...fields.map((f) => TextCellValue(fieldValue(player, f))),
      ]);
      row++;
    }

    return Uint8List.fromList(excel.encode()!);
  }

  /// Attendance list PDF (Ionic `exportAttPDF`): saved as
  /// "{name}_Anwesenheit_Stand_{date}.pdf" like Ionic.
  Future<void> exportAttendancePdf({
    required List<Person> players,
    required List<Attendance> attendances,
    required List<PersonAttendance> personAttendances,
    required List<String> fields,
    required String tenantName,
    PdfBranding? branding,
    String Function(Person player, String field)? valueOf,
  }) async {
    final date = DateFormat(dateFmt()).format(DateTime.now());
    final bytes = await buildAttendancePdf(
      players: players,
      attendances: attendances,
      personAttendances: personAttendances,
      fields: fields,
      tenantName: tenantName,
      branding: branding,
      valueOf: valueOf,
    );
    await NativeFileService.saveBytes(
        bytes, '${l10nWithoutContext.exportAttendanceFileAsOf(tenantName, date)}.pdf');
  }

  /// Builds the attendance list PDF with the same letterhead as the player
  /// list (title "{name} Anwesenheit") and Ionic's colored status cells.
  Future<Uint8List> buildAttendancePdf({
    required List<Person> players,
    required List<Attendance> attendances,
    required List<PersonAttendance> personAttendances,
    required List<String> fields,
    required String tenantName,
    PdfBranding? branding,
    String Function(Person player, String field)? valueOf,
  }) async {
    final fieldValue = valueOf ?? _getPlayerFieldValue;
    final l10n = l10nWithoutContext;
    final date = DateFormat(dateFmt()).format(DateTime.now());

    // Limit to last 8 attendances for PDF
    final limitedAttendances = attendances.length > 8
        ? attendances.sublist(attendances.length - 8)
        : attendances;

    // Prepare attendance dates
    final attDates = limitedAttendances.map((a) {
      final d = DateTime.tryParse(a.date);
      // Ionic exportType: dayjs(att.date).format(dateFmt('short'))
      return d != null ? DateFormat(dateFmt(DateFmtKind.short)).format(d) : '';
    }).toList();

    // Build data rows
    final data = <List<String>>[];
    var row = 1;

    for (final player in players) {
      final attInfo = <String>[];

      for (final att in limitedAttendances) {
        // BL-011: Use firstOrNull - null means "not recorded" which is correct
        final pa = personAttendances
            .where((p) => p.personId == player.id && p.attendanceId == att.id)
            .firstOrNull;
        attInfo.add(_getStatusCode(pa?.status));
      }

      data.add([
        row.toString(),
        ...fields.map((f) => fieldValue(player, f)),
        ...attInfo,
      ]);
      row++;
    }

    return _buildBrandedTablePdf(
      branding: branding,
      title: l10n.exportAttendanceTitle(tenantName),
      subtitle: l10n.planningAsOf(date),
      headers: ['', ...fields, ...attDates],
      rows: data,
      fitSteps: attendanceFitSteps,
      statusColors: true,
    );
  }

  /// Ionic dry-run auto-fit: renders with the first style of [fitSteps]
  /// whose table fits on one page, else with the last (smallest) one.
  Future<Uint8List> _buildBrandedTablePdf({
    required PdfBranding? branding,
    required String title,
    required String subtitle,
    required List<String> headers,
    required List<List<String>> rows,
    required List<ExportTableStyle> fitSteps,
    bool statusColors = false,
  }) async {
    final theme = await PdfFonts.theme();
    pw.Document build(ExportTableStyle style) {
      final doc = pw.Document(theme: theme);
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pdfMargin,
        // ASTRA_EXPORT: tenant/org letterhead (Ionic Utils.addBrandingHeader,
        // drawn on every page via didDrawPage).
        header: (_) => buildPdfBrandingHeader(
          branding: branding,
          title: title,
          subtitle: subtitle,
        ),
        build: (_) => [
          _ionicTable(headers: headers, rows: rows, style: style, statusColors: statusColors),
        ],
      ));
      return doc;
    }

    for (var i = 0; i < fitSteps.length - 1; i++) {
      final probe = build(fitSteps[i]);
      final bytes = await probe.save();
      if (probe.document.pdfPageList.pages.length <= 1) return bytes;
    }
    return build(fitSteps.last).save();
  }

  /// Ionic jspdf-autotable `theme: 'plain'`: bold header with a bottom rule
  /// (repeated on every page), zebra rows (245) and — for the attendance
  /// list — colored, centered status cells with white text.
  pw.Widget _ionicTable({
    required List<String> headers,
    required List<List<String>> rows,
    required ExportTableStyle style,
    bool statusColors = false,
  }) {
    const mm = PdfPageFormat.mm;
    final padding = pw.EdgeInsets.symmetric(
      vertical: style.paddingVerticalMm * mm,
      horizontal: style.paddingHorizontalMm * mm,
    );

    pw.Widget cell(String text, {bool header = false}) {
      final fill = statusColors && !header ? statusCellColor(text) : null;
      final centered = fill != null || (statusColors && text.contains('%'));
      return pw.Container(
        padding: padding,
        color: fill,
        alignment: centered ? pw.Alignment.center : pw.Alignment.centerLeft,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: style.fontSize,
            fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: header
                ? const PdfColor.fromInt(0xFF323232)
                : fill != null
                    ? PdfColors.white
                    : const PdfColor.fromInt(0xFF1E1E1E),
          ),
        ),
      );
    }

    return pw.Table(
      tableWidth: pw.TableWidth.max,
      children: [
        pw.TableRow(
          repeat: true,
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(width: 0.5 * mm, color: PdfColor.fromInt(0xFF646464)),
            ),
          ),
          children: [for (final h in headers) cell(h, header: true)],
        ),
        for (var i = 0; i < rows.length; i++)
          pw.TableRow(
            verticalAlignment: pw.TableCellVerticalAlignment.full,
            decoration: i.isOdd
                ? const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF5F5F5))
                : null,
            children: [for (final v in rows[i]) cell(v)],
          ),
      ],
    );
  }

  /// Generate attendance Excel
  Future<Uint8List> exportAttendanceExcel({
    required List<Person> players,
    required List<Attendance> attendances,
    required List<PersonAttendance> personAttendances,
    required List<String> fields,
    required String tenantName,
    String Function(Person player, String field)? valueOf,
  }) async {
    final fieldValue = valueOf ?? _getPlayerFieldValue;
    final sheetName = l10nWithoutContext.exportAttendance;
    final excel = _singleSheetWorkbook(sheetName);
    final sheet = excel[sheetName];

    // Attendance dates
    final attDates = attendances.map((a) {
      final d = DateTime.tryParse(a.date);
      return d != null ? DateFormat(dateFmt(DateFmtKind.short)).format(d) : '';
    }).toList();

    // Header row (Ionic: first cell empty)
    sheet.appendRow([
      TextCellValue(''),
      ...fields.map((f) => TextCellValue(f)),
      ...attDates.map((d) => TextCellValue(d)),
    ]);

    // Data rows
    int row = 1;
    for (final player in players) {
      final attInfo = <String>[];

      for (final att in attendances) {
        // BL-011: Use firstOrNull - null means "not recorded" which is correct
        final pa = personAttendances
            .where((p) => p.personId == player.id && p.attendanceId == att.id)
            .firstOrNull;
        attInfo.add(_getStatusCode(pa?.status));
      }

      sheet.appendRow([
        TextCellValue(row.toString()),
        ...fields.map((f) => TextCellValue(fieldValue(player, f))),
        ...attInfo.map((s) => TextCellValue(s)),
      ]);
      row++;
    }

    return Uint8List.fromList(excel.encode()!);
  }

  /// Get player field value by field name
  String _getPlayerFieldValue(Person player, String field) {
    switch (field) {
      case 'Vorname':
        return player.firstName;
      case 'Nachname':
        return player.lastName;
      case 'Geburtsdatum':
        if (player.birthday != null) {
          final d = DateTime.tryParse(player.birthday!);
          return d != null ? DateFormat(dateFmt()).format(d) : '';
        }
        return '';
      case 'Gruppe':
        return player.groupName ?? '';
      case 'Email':
      case 'E-Mail':
        return player.email ?? '';
      case 'Telefon':
        return player.phone ?? '';
      case 'Testergebnis':
        return player.testResult ?? '';
      default:
        return '';
    }
  }

  /// Get status code for display
  /// BL-011: Accept nullable status - null means "not recorded"
  String _getStatusCode(AttendanceStatus? status) {
    if (status == null) return ''; // Ionic: not part of this attendance
    switch (status) {
      case AttendanceStatus.present:
        return 'X';
      case AttendanceStatus.absent:
        return 'A';
      case AttendanceStatus.excused:
        return 'E';
      case AttendanceStatus.late:
      case AttendanceStatus.lateExcused:
        return 'L';
      case AttendanceStatus.neutral:
        return 'N';
    }
  }

  /// Status cell fill of the attendance PDF — Ionic `exportAttPDF`
  /// `didParseCell` colors (A firebrick, X limegreen, E amber, L deepskyblue,
  /// N light grey); null for every other cell.
  static PdfColor? statusCellColor(String code) {
    switch (code) {
      case 'A':
        return const PdfColor.fromInt(0xFFB22222);
      case 'X':
        return const PdfColor.fromInt(0xFF32CD32);
      case 'E':
        return const PdfColor.fromInt(0xFFFFC409);
      case 'L':
        return const PdfColor.fromInt(0xFF00BFFF);
      case 'N':
        return const PdfColor.fromInt(0xFFDCDCDC);
      default:
        return null;
    }
  }

  /// Generate plan/program PDF
  Future<void> exportPlanPdf({
    required BuildContext context,
    required String tenantName,
    required String date,
    required String startTime,
    required String? endTime,
    required List<Map<String, dynamic>> fields,
  }) async {
    final pdf = _buildPlanPdfDocument(
      theme: await PdfFonts.theme(),
      tenantName: tenantName,
      date: date,
      startTime: startTime,
      endTime: endTime,
      fields: fields,
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: '${tenantName}_${l10nWithoutContext.coreFlutterExportRehearsalProgramme}_$date.pdf',
    );
  }

  /// Build a plan PDF document (shared logic for export and bytes generation)
  pw.Document _buildPlanPdfDocument({
    pw.ThemeData? theme,
    required String tenantName,
    required String date,
    required String startTime,
    required String? endTime,
    required List<Map<String, dynamic>> fields,
  }) {
    final l10n = l10nWithoutContext;
    final pdf = pw.Document(theme: theme);

    // Calculate times for each field and build rows
    var currentMinutes = _parseTime(startTime);

    // Build table rows manually to support colspan for notes
    final tableRows = <pw.TableRow>[];

    // Header row
    tableRows.add(pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF005238)),
      children: [
        _buildHeaderCell(l10n.exportTime, width: 60),
        _buildHeaderCell(l10n.exportProgrammeItem, flex: 3),
        _buildHeaderCell(l10n.exportPerformer, flex: 2),
        _buildHeaderCell(l10n.exportDuration, width: 50),
      ],
    ));

    // Data rows
    for (final field in fields) {
      final name = field['name'] as String? ?? '';
      final conductor = field['conductor'] as String? ?? '';
      final duration = int.tryParse(field['time']?.toString() ?? '0') ?? 0;
      final isNote = field['isNote'] as bool? ?? false;
      final formattedTime = _formatMinutes(currentMinutes);

      if (isNote) {
        // Note field: use 4 cells but make the note span visually by merging content
        tableRows.add(pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF5F5F5)),
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(formattedTime, style: const pw.TextStyle(fontSize: 11)),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                name,
                style: pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic),
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('', style: const pw.TextStyle(fontSize: 11)),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('', style: const pw.TextStyle(fontSize: 11)),
            ),
          ],
        ));
      } else {
        tableRows.add(pw.TableRow(
          children: [
            _buildDataCell(formattedTime, width: 60),
            _buildDataCell(name, flex: 3),
            _buildDataCell(conductor, flex: 2),
            _buildDataCell('$duration\'', width: 50),
          ],
        ));
      }

      currentMinutes += duration;
    }

    // End time row
    final finalTime = endTime ?? _formatMinutes(currentMinutes);
    tableRows.add(pw.TableRow(
      children: [
        _buildDataCell(finalTime, width: 60),
        _buildDataCell(l10n.attendanceEnd, flex: 3),
        _buildDataCell('', flex: 2),
        _buildDataCell('', width: 50),
      ],
    ));

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Text(
              tenantName,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              '${l10n.coreFlutterExportRehearsalProgramme} $date',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 20),

            // Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FixedColumnWidth(60),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FixedColumnWidth(50),
              },
              children: tableRows,
            ),
          ],
        ),
      ),
    );

    return pdf;
  }

  pw.Widget _buildHeaderCell(String text, {double? width, int flex = 1}) {
    final content = pw.Container(
      padding: const pw.EdgeInsets.all(8),
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
    if (width != null) {
      return pw.SizedBox(width: width, child: content);
    }
    return pw.Expanded(flex: flex, child: content);
  }

  pw.Widget _buildDataCell(String text, {double? width, int flex = 1}) {
    final content = pw.Container(
      padding: const pw.EdgeInsets.all(8),
      alignment: pw.Alignment.centerLeft,
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 11)),
    );
    if (width != null) {
      return pw.SizedBox(width: width, child: content);
    }
    return pw.Expanded(flex: flex, child: content);
  }

  /// Parse time string "HH:MM" to minutes since midnight
  int _parseTime(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return 0;
    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = int.tryParse(parts[1]) ?? 0;
    return hours * 60 + minutes;
  }

  /// Format minutes since midnight to "HH:MM"
  String _formatMinutes(int minutes) {
    final hours = (minutes ~/ 60) % 24;
    final mins = minutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
  }

  /// Export a single attendance to Excel (Ionic Utils.exportAttendanceToExcel):
  /// Nachname, Vorname, Gruppe, [Gemeinde], Status letter, Bemerkung; one
  /// sheet "Anwesenheit"; file "{Termin}_{DD_MM_YYYY}_Anwesenheit.xlsx".
  Future<void> exportAttendanceToExcel({
    required BuildContext context,
    required Attendance attendance,
    required String typeName,
    required List<Person> persons,
    required Map<int, AttendanceStatus> statuses,
    required Map<int, String?> notes,
    List<Church> churches = const [],
    String? churchFieldId,
  }) async {
    final l10n = l10nWithoutContext;
    final sheetName = l10n.exportAttendance;
    final excel = _singleSheetWorkbook(sheetName);
    final sheet = excel[sheetName];
    final withChurch = churches.isNotEmpty;

    sheet.appendRow([
      TextCellValue(l10n.exportLastName),
      TextCellValue(l10n.exportFirstName),
      TextCellValue(l10n.exportGroup),
      if (withChurch) TextCellValue(l10n.exportChurch),
      TextCellValue(l10n.exportStatus),
      TextCellValue(l10n.exportNotes),
    ]);

    for (final person in persons) {
      final churchId = person.additionalFields?[churchFieldId ?? 'bfecg_church'];
      sheet.appendRow([
        TextCellValue(person.lastName),
        TextCellValue(person.firstName),
        TextCellValue(person.groupName ?? ''),
        if (withChurch)
          TextCellValue(
              churches.where((c) => c.id == churchId).firstOrNull?.name ?? ''),
        TextCellValue(_getStatusCode(
            statuses[person.id] ?? AttendanceStatus.neutral)),
        TextCellValue(notes[person.id] ?? ''),
      ]);
    }

    final dateObj = DateTime.tryParse(attendance.date);
    final dateStr = dateObj != null
        ? DateFormat('dd_MM_yyyy').format(dateObj.toLocal())
        : attendance.date;
    final name = (attendance.typeInfo?.isNotEmpty ?? false)
        ? attendance.typeInfo!
        : typeName;

    final bytes = Uint8List.fromList(excel.encode()!);
    await NativeFileService.saveBytes(
        bytes, l10n.exportAttendanceFile(name, dateStr));
  }

  /// Generate plan/program PDF in 2xA5 format (two identical plans side-by-side on A4 landscape)
  /// Useful for cutting in half to have two copies
  Future<void> exportPlanPdf2xA5({
    required BuildContext context,
    required String tenantName,
    required String date,
    required String startTime,
    required String? endTime,
    required List<Map<String, dynamic>> fields,
  }) async {
    final pdf = _buildPlan2xA5PdfDocument(
      theme: await PdfFonts.theme(),
      tenantName: tenantName,
      date: date,
      startTime: startTime,
      endTime: endTime,
      fields: fields,
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: '${tenantName}_${l10nWithoutContext.coreFlutterExportRehearsalProgramme}_2xA5_$date.pdf',
    );
  }

  /// Build a 2xA5 plan PDF document (shared logic for export and bytes generation)
  pw.Document _buildPlan2xA5PdfDocument({
    pw.ThemeData? theme,
    required String tenantName,
    required String date,
    required String startTime,
    required String? endTime,
    required List<Map<String, dynamic>> fields,
  }) {
    final l10n = l10nWithoutContext;
    final pdf = pw.Document(theme: theme);

    // Build single plan widget with note support
    pw.Widget buildPlanContent() {
      final tableRows = <pw.TableRow>[];

      // Header row
      tableRows.add(pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF005238)),
        children: [
          _buildSmallHeaderCell(l10n.exportTime, width: 35),
          _buildSmallHeaderCell(l10n.exportProgrammeItem, flex: 3),
          _buildSmallHeaderCell(l10n.exportPerformer, flex: 2),
          _buildSmallHeaderCell('', width: 25),
        ],
      ));

      // Reset counter for second half
      var mins = _parseTime(startTime);

      // Data rows
      for (final field in fields) {
        final name = field['name'] as String? ?? '';
        final conductor = field['conductor'] as String? ?? '';
        final duration = int.tryParse(field['time']?.toString() ?? '0') ?? 0;
        final isNote = field['isNote'] as bool? ?? false;
        final formattedTime = _formatMinutes(mins);

        if (isNote) {
          // Note field: use 4 cells with gray background
          tableRows.add(pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF5F5F5)),
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(formattedTime, style: const pw.TextStyle(fontSize: 8)),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  name,
                  style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic),
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text('', style: const pw.TextStyle(fontSize: 8)),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text('', style: const pw.TextStyle(fontSize: 8)),
              ),
            ],
          ));
        } else {
          tableRows.add(pw.TableRow(
            children: [
              _buildSmallDataCell(formattedTime, width: 35),
              _buildSmallDataCell(name, flex: 3),
              _buildSmallDataCell(conductor, flex: 2),
              _buildSmallDataCell(duration > 0 ? '$duration\'' : '', width: 25),
            ],
          ));
        }

        mins += duration;
      }

      // End time row
      final finalTime = endTime ?? _formatMinutes(mins);
      tableRows.add(pw.TableRow(
        children: [
          _buildSmallDataCell(finalTime, width: 35),
          _buildSmallDataCell(l10n.attendanceEnd, flex: 3),
          _buildSmallDataCell('', flex: 2),
          _buildSmallDataCell('', width: 25),
        ],
      ));

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Text(
            tenantName,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            '${l10n.coreFlutterExportRehearsalProgramme} $date',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),

          // Table with smaller font
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(35),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FixedColumnWidth(25),
            },
            children: tableRows,
          ),
        ],
      );
    }

    // A4 landscape page with two identical A5 halves
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(15),
        build: (context) => pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Left half (A5)
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.only(right: 10),
                child: buildPlanContent(),
              ),
            ),
            // Vertical divider line (for cutting)
            pw.Container(
              width: 0.5,
              color: PdfColors.grey400,
            ),
            // Right half (A5) - identical content
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.only(left: 10),
                child: buildPlanContent(),
              ),
            ),
          ],
        ),
      ),
    );

    return pdf;
  }

  pw.Widget _buildSmallHeaderCell(String text, {double? width, int flex = 1}) {
    final content = pw.Container(
      padding: const pw.EdgeInsets.all(4),
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
    if (width != null) {
      return pw.SizedBox(width: width, child: content);
    }
    return pw.Expanded(flex: flex, child: content);
  }

  pw.Widget _buildSmallDataCell(String text, {double? width, int flex = 1}) {
    final content = pw.Container(
      padding: const pw.EdgeInsets.all(4),
      alignment: pw.Alignment.centerLeft,
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 8)),
    );
    if (width != null) {
      return pw.SizedBox(width: width, child: content);
    }
    return pw.Expanded(flex: flex, child: content);
  }

  /// Generate plan PDF as bytes (for sending via Telegram etc.)
  Future<Uint8List> generatePlanPdfBytes({
    required String tenantName,
    required String date,
    required String startTime,
    required String? endTime,
    required List<Map<String, dynamic>> fields,
  }) async {
    final pdf = _buildPlanPdfDocument(
      theme: await PdfFonts.theme(),
      tenantName: tenantName,
      date: date,
      startTime: startTime,
      endTime: endTime,
      fields: fields,
    );

    return pdf.save();
  }

  /// Generate 2xA5 plan PDF as bytes (for sending via Telegram etc.)
  Future<Uint8List> generatePlan2xA5PdfBytes({
    required String tenantName,
    required String date,
    required String startTime,
    required String? endTime,
    required List<Map<String, dynamic>> fields,
  }) async {
    final pdf = _buildPlan2xA5PdfDocument(
      theme: await PdfFonts.theme(),
      tenantName: tenantName,
      date: date,
      startTime: startTime,
      endTime: endTime,
      fields: fields,
    );

    return pdf.save();
  }
}
