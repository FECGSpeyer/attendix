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

part 'export_service_excel.dart';
part 'export_service_pdf.dart';

/// Font size (pt) and cell padding (mm) of one auto-fit step of the
/// player / attendance list PDF (Ionic jspdf-autotable styles).
class ExportTableStyle {
  const ExportTableStyle(
    this.fontSize,
    this.paddingVerticalMm,
    this.paddingHorizontalMm,
  );

  final double fontSize;
  final double paddingVerticalMm;
  final double paddingHorizontalMm;
}

/// Shared field and status helpers for [ExportService] mixins.
abstract class _ExportServiceCore {
  /// Get player field value by field name.
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

  /// Get status code for display.
  /// BL-011: Accept nullable status - null means "not recorded".
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
}

/// Export Service for generating PDF and Excel files.
///
/// Based on Ionic export.page.ts.
class ExportService extends _ExportServiceCore
    with _ExportServicePdf, _ExportServiceExcel {
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
}
