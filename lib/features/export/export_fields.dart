import 'package:intl/intl.dart';

import '../../core/utils/extra_field_utils.dart';
import '../../data/models/person/person.dart';
import '../../data/models/tenant/tenant.dart';
import '../../l10n/l10n.dart';

/// Export field definitions — port of Ionic export.page.ts.
/// Standard fields are identified by their German name; only the label is
/// translated (Ionic FIELD_LABEL_KEYS / fieldLabel()).
const playerStandardExportFields = [
  'Vorname',
  'Nachname',
  'Geburtsdatum',
  'Gruppe',
  'E-Mail',
  'Telefon',
  'Eingetreten',
  'Notizen',
  'Anwesenheit %',
];
const attendanceStandardExportFields = [
  'Vorname',
  'Nachname',
  'Gruppe',
  'E-Mail',
  'Telefon',
];
const defaultPlayerExportFields = ['Vorname', 'Nachname', 'Geburtsdatum', 'Gruppe'];
const defaultAttendanceExportFields = ['Vorname', 'Nachname', 'Gruppe'];

/// Translated label of an export field (Ionic `fieldLabel`). Extra fields
/// and custom columns keep their name.
String exportFieldLabel(String field, [AppLocalizations? l10n]) {
  final t = l10n ?? l10nWithoutContext;
  return switch (field) {
    'Vorname' => t.peopleFirstName,
    'Nachname' => t.peopleLastName,
    'Geburtsdatum' => t.peopleBirthday,
    'Gruppe' => t.peopleGroup,
    'E-Mail' => t.peopleEmail,
    'Telefon' => t.peoplePhone,
    'Eingetreten' => t.peopleJoined,
    'Notizen' => t.peopleNotes,
    'Anwesenheit %' => t.exportAttendancePercent,
    _ => field,
  };
}

/// Selectable sort options for export.
class ExportSortOption {
  const ExportSortOption(this.value, this.label);
  final String value;
  final String label;
}

/// All selectable fields: standard fields + names of extra fields.
List<String> availableExportFields(
  String content,
  List<ExtraField> extraFields,
) {
  final standard = content == 'player'
      ? playerStandardExportFields
      : attendanceStandardExportFields;
  return [...standard, ...extraFields.map((f) => f.name)];
}

/// Sort options per content type (Ionic updateSortableFields).
List<ExportSortOption> exportSortOptions(
  String content,
  List<ExtraField> extraFields,
) {
  final standard = content == 'player'
      ? [
          ExportSortOption('nachname', exportFieldLabel('Nachname')),
          ExportSortOption('vorname', exportFieldLabel('Vorname')),
          ExportSortOption('gruppe', exportFieldLabel('Gruppe')),
          ExportSortOption('geburtsdatum', exportFieldLabel('Geburtsdatum')),
          ExportSortOption('eingetreten', exportFieldLabel('Eingetreten')),
          ExportSortOption('anwesenheit', exportFieldLabel('Anwesenheit %')),
        ]
      : [
          ExportSortOption('nachname', exportFieldLabel('Nachname')),
          ExportSortOption('vorname', exportFieldLabel('Vorname')),
          ExportSortOption('gruppe', exportFieldLabel('Gruppe')),
        ];
  return [
    ...standard,
    ...extraFields.map((f) => ExportSortOption('extra_${f.id}', f.name)),
  ];
}

String _fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final d = DateTime.tryParse(iso);
  return d == null ? '' : DateFormat(dateFmt()).format(d);
}

/// Value of an export column for a person (Ionic getFieldValues).
/// Unknown field names (custom columns added by the user) are empty.
String exportFieldValue(
  Person player,
  String field, {
  List<ExtraField> extraFields = const [],
  Map<String, String> churchNames = const {},
  int? percentage,
}) {
  for (final extra in extraFields) {
    if (extra.name == field) {
      return formatExtraFieldValue(
        player.additionalFields,
        extra,
        churchNames: churchNames,
      );
    }
  }
  switch (field) {
    case 'Vorname':
      return player.firstName;
    case 'Nachname':
      return player.lastName;
    case 'Geburtsdatum':
      return _fmtDate(player.birthday);
    case 'Gruppe':
      return player.groupName ?? '';
    case 'E-Mail':
    case 'Email':
      return player.email ?? '';
    case 'Telefon':
      return player.phone ?? '';
    case 'Eingetreten':
      return _fmtDate(player.joined);
    case 'Notizen':
      return player.notes ?? '';
    case 'Anwesenheit %':
      return percentage != null ? '$percentage%' : '';
    default:
      return '';
  }
}

/// Sort players for export (Ionic applySort).
List<Person> sortPlayersForExport(
  List<Person> players,
  String sortField, {
  bool ascending = true,
  Map<int, int> percentages = const {},
}) {
  final dir = ascending ? 1 : -1;
  final list = [...players];
  list.sort((a, b) {
    if (sortField == 'anwesenheit') {
      final av = percentages[a.id] ?? 0;
      final bv = percentages[b.id] ?? 0;
      return av.compareTo(bv) * dir;
    }
    String av;
    String bv;
    if (sortField.startsWith('extra_')) {
      final id = sortField.substring(6);
      av = a.additionalFields?[id]?.toString() ?? '';
      bv = b.additionalFields?[id]?.toString() ?? '';
    } else {
      switch (sortField) {
        case 'nachname':
          av = a.lastName;
          bv = b.lastName;
        case 'vorname':
          av = a.firstName;
          bv = b.firstName;
        case 'gruppe':
          av = a.groupName ?? '';
          bv = b.groupName ?? '';
        case 'geburtsdatum':
          av = a.birthday ?? '';
          bv = b.birthday ?? '';
        case 'eingetreten':
          av = a.joined ?? '';
          bv = b.joined ?? '';
        default:
          av = '';
          bv = '';
      }
    }
    return av.toLowerCase().compareTo(bv.toLowerCase()) * dir;
  });
  return list;
}
