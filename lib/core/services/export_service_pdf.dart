part of 'export_service.dart';

/// PDF export builders for player lists, attendance tables, and rehearsal plans.
mixin _ExportServicePdf on _ExportServiceCore {
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
      bytes,
      '${l10nWithoutContext.exportPlayerListFile(tenantName, date)}.pdf',
    );
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

    final data = <List<String>>[
      for (var i = 0; i < players.length; i++)
        ['${i + 1}', ...fields.map((f) => fieldValue(players[i], f))],
    ];

    return _buildBrandedTablePdf(
      branding: branding,
      title: l10n.exportPlayerListTitle(tenantName),
      subtitle: l10n.planningAsOf(date),
      headers: ['', ...fields],
      rows: data,
      fitSteps: ExportService.playerListFitSteps,
    );
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
      bytes,
      '${l10nWithoutContext.exportAttendanceFileAsOf(tenantName, date)}.pdf',
    );
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

    final limitedAttendances = attendances.length > 8
        ? attendances.sublist(attendances.length - 8)
        : attendances;

    final attDates = limitedAttendances.map((a) {
      final d = DateTime.tryParse(a.date);
      // Ionic exportType: dayjs(att.date).format(dateFmt('short'))
      return d != null ? DateFormat(dateFmt(DateFmtKind.short)).format(d) : '';
    }).toList();

    final data = <List<String>>[
      for (var i = 0; i < players.length; i++)
        [
          '${i + 1}',
          ...fields.map((f) => fieldValue(players[i], f)),
          for (final att in limitedAttendances)
            // BL-011: Use firstOrNull - null means "not recorded" which is correct
            _getStatusCode(
              personAttendances
                  .where((p) => p.personId == players[i].id && p.attendanceId == att.id)
                  .firstOrNull
                  ?.status,
            ),
        ],
    ];

    return _buildBrandedTablePdf(
      branding: branding,
      title: l10n.exportAttendanceTitle(tenantName),
      subtitle: l10n.planningAsOf(date),
      headers: ['', ...fields, ...attDates],
      rows: data,
      fitSteps: ExportService.attendanceFitSteps,
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
        margin: ExportService.pdfMargin,
        // ASTRA_EXPORT: tenant/org letterhead (Ionic Utils.addBrandingHeader,
        // drawn on every page via didDrawPage).
        header: (_) => buildPdfBrandingHeader(
          branding: branding,
          title: title,
          subtitle: subtitle,
        ),
        build: (_) => [
          _ionicTable(
            headers: headers,
            rows: rows,
            style: style,
            statusColors: statusColors,
          ),
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
      final fill =
          statusColors && !header ? ExportService.statusCellColor(text) : null;
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
              bottom: pw.BorderSide(
                width: 0.5 * mm,
                color: PdfColor.fromInt(0xFF646464),
              ),
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
      name:
          '${tenantName}_${l10nWithoutContext.coreFlutterExportRehearsalProgramme}_$date.pdf',
    );
  }

  /// Generate plan/program PDF in 2xA5 format (two identical plans side-by-side on A4 landscape).
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
      name:
          '${tenantName}_${l10nWithoutContext.coreFlutterExportRehearsalProgramme}_2xA5_$date.pdf',
    );
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
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (_) => _buildPlanBlock(
          tenantName: tenantName,
          date: date,
          startTime: startTime,
          endTime: endTime,
          fields: fields,
          durationHeader: l10n.exportDuration,
          showZeroDuration: true,
          compact: false,
        ),
      ),
    );
    return pdf;
  }

  pw.Document _buildPlan2xA5PdfDocument({
    pw.ThemeData? theme,
    required String tenantName,
    required String date,
    required String startTime,
    required String? endTime,
    required List<Map<String, dynamic>> fields,
  }) {
    final pdf = pw.Document(theme: theme);
    pw.Widget half() => _buildPlanBlock(
          tenantName: tenantName,
          date: date,
          startTime: startTime,
          endTime: endTime,
          fields: fields,
          durationHeader: '',
          showZeroDuration: false,
          compact: true,
        );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(15),
        build: (_) => pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.only(right: 10),
                child: half(),
              ),
            ),
            pw.Container(width: 0.5, color: PdfColors.grey400),
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.only(left: 10),
                child: half(),
              ),
            ),
          ],
        ),
      ),
    );
    return pdf;
  }

  pw.Widget _buildPlanBlock({
    required String tenantName,
    required String date,
    required String startTime,
    required String? endTime,
    required List<Map<String, dynamic>> fields,
    required String durationHeader,
    required bool showZeroDuration,
    required bool compact,
  }) {
    final l10n = l10nWithoutContext;
    final pad = compact ? 4.0 : 8.0;
    final fontSize = compact ? 8.0 : 11.0;
    final timeWidth = compact ? 35.0 : 60.0;
    final durWidth = compact ? 25.0 : 50.0;
    final tableRows = _buildPlanTableRows(
      l10n: l10n,
      startTime: startTime,
      endTime: endTime,
      fields: fields,
      durationHeader: durationHeader,
      showZeroDuration: showZeroDuration,
      pad: pad,
      fontSize: fontSize,
      timeWidth: timeWidth,
      durWidth: durWidth,
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          tenantName,
          style: pw.TextStyle(
            fontSize: compact ? 12 : 18,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: compact ? 2 : 4),
        pw.Text(
          '${l10n.coreFlutterExportRehearsalProgramme} $date',
          style: pw.TextStyle(
            fontSize: compact ? 10 : 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: compact ? 10 : 20),
        pw.Table(
          border: pw.TableBorder.all(
            color: PdfColors.grey300,
            width: compact ? 0.5 : 1.0,
          ),
          columnWidths: {
            0: pw.FixedColumnWidth(timeWidth),
            1: const pw.FlexColumnWidth(3),
            2: const pw.FlexColumnWidth(2),
            3: pw.FixedColumnWidth(durWidth),
          },
          children: tableRows,
        ),
      ],
    );
  }

  List<pw.TableRow> _buildPlanTableRows({
    required AppLocalizations l10n,
    required String startTime,
    required String? endTime,
    required List<Map<String, dynamic>> fields,
    required String durationHeader,
    required bool showZeroDuration,
    required double pad,
    required double fontSize,
    required double timeWidth,
    required double durWidth,
  }) {
    final tableRows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF005238)),
        children: [
          _buildPlanCell(l10n.exportTime, pad: pad, fontSize: fontSize, header: true, width: timeWidth),
          _buildPlanCell(l10n.exportProgrammeItem, pad: pad, fontSize: fontSize, header: true, flex: 3),
          _buildPlanCell(l10n.exportPerformer, pad: pad, fontSize: fontSize, header: true, flex: 2),
          _buildPlanCell(durationHeader, pad: pad, fontSize: fontSize, header: true, width: durWidth),
        ],
      ),
    ];

    var currentMinutes = _parseTime(startTime);
    for (final field in fields) {
      final name = field['name'] as String? ?? '';
      final conductor = field['conductor'] as String? ?? '';
      final duration = int.tryParse(field['time']?.toString() ?? '0') ?? 0;
      final isNote = field['isNote'] as bool? ?? false;
      final formattedTime = _formatMinutes(currentMinutes);

      if (isNote) {
        tableRows.add(pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF5F5F5)),
          children: [
            _noteCell(formattedTime, pad, fontSize),
            _noteCell(name, pad, fontSize, italic: true),
            _noteCell('', pad, fontSize),
            _noteCell('', pad, fontSize),
          ],
        ));
      } else {
        final durLabel = showZeroDuration || duration > 0 ? "$duration'" : '';
        tableRows.add(pw.TableRow(
          children: [
            _buildPlanCell(formattedTime, pad: pad, fontSize: fontSize, width: timeWidth),
            _buildPlanCell(name, pad: pad, fontSize: fontSize, flex: 3),
            _buildPlanCell(conductor, pad: pad, fontSize: fontSize, flex: 2),
            _buildPlanCell(durLabel, pad: pad, fontSize: fontSize, width: durWidth),
          ],
        ));
      }
      currentMinutes += duration;
    }

    final finalTime = endTime ?? _formatMinutes(currentMinutes);
    tableRows.add(pw.TableRow(
      children: [
        _buildPlanCell(finalTime, pad: pad, fontSize: fontSize, width: timeWidth),
        _buildPlanCell(l10n.attendanceEnd, pad: pad, fontSize: fontSize, flex: 3),
        _buildPlanCell('', pad: pad, fontSize: fontSize, flex: 2),
        _buildPlanCell('', pad: pad, fontSize: fontSize, width: durWidth),
      ],
    ));
    return tableRows;
  }

  pw.Widget _noteCell(String text, double pad, double fontSize, {bool italic = false}) {
    return pw.Container(
      padding: pw.EdgeInsets.all(pad),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontStyle: italic ? pw.FontStyle.italic : pw.FontStyle.normal,
        ),
      ),
    );
  }

  pw.Widget _buildPlanCell(
    String text, {
    required double pad,
    required double fontSize,
    bool header = false,
    double? width,
    int flex = 1,
  }) {
    final content = pw.Container(
      padding: pw.EdgeInsets.all(pad),
      alignment: header ? pw.Alignment.center : pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: header ? PdfColors.white : null,
        ),
      ),
    );
    if (width != null) return pw.SizedBox(width: width, child: content);
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
}
