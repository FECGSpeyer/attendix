part of 'export_service.dart';

/// Excel export builders for player lists and attendance tables.
mixin _ExportServiceExcel on _ExportServiceCore {
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

    sheet.appendRow([
      TextCellValue(''),
      ...fields.map((f) => TextCellValue(f)),
    ]);

    for (var i = 0; i < players.length; i++) {
      sheet.appendRow([
        TextCellValue('${i + 1}'),
        ...fields.map((f) => TextCellValue(fieldValue(players[i], f))),
      ]);
    }

    return Uint8List.fromList(excel.encode()!);
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

    for (var i = 0; i < players.length; i++) {
      final player = players[i];
      sheet.appendRow([
        TextCellValue('${i + 1}'),
        ...fields.map((f) => TextCellValue(fieldValue(player, f))),
        for (final att in attendances)
          // BL-011: Use firstOrNull - null means "not recorded" which is correct
          TextCellValue(_getStatusCode(
            personAttendances
                .where((p) => p.personId == player.id && p.attendanceId == att.id)
                .firstOrNull
                ?.status,
          )),
      ]);
    }

    return Uint8List.fromList(excel.encode()!);
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
            churches.where((c) => c.id == churchId).firstOrNull?.name ?? '',
          ),
        TextCellValue(_getStatusCode(
          statuses[person.id] ?? AttendanceStatus.neutral,
        )),
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
      bytes,
      l10n.exportAttendanceFile(name, dateStr),
    );
  }
}
