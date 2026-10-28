/// Pure helpers (no Flutter/Supabase) for importing persons and songs from a
/// parsed spreadsheet. Port of Ionic `src/app/utilities/import-mapper.ts`.
///
/// Consumers pass plain row maps (header -> cell value) and the tenant context;
/// these functions map them to insert payloads. Kept pure so the German
/// date/name/group edge cases are unit-testable.
library;

import '../../data/models/instrument/instrument.dart';
import '../../data/models/song/song.dart';
import '../../data/models/tenant/tenant.dart';
import '../constants/app_constants.dart';
import '../constants/enums.dart';

/// Canonical German headers, matching the export vocabulary.
const List<String> kPersonImportHeaders = [
  'Vorname',
  'Nachname',
  'Geburtsdatum',
  'Gruppe',
  'E-Mail',
  'Telefon',
  'Eingetreten',
  'Notizen',
];

/// Combined name target ("Vorname Nachname" or "Nachname, Vorname").
const String kFullNameKey = 'Name';

/// Prefix for additional field targets: `extra_<fieldId>`.
const String kExtraPrefix = 'extra_';

/// A file-column -> target-field mapping. `null` means "ignore this column".
typedef ColumnMapping = Map<String, String?>;

String _norm(Object? s) => (s ?? '').toString().trim().toLowerCase();

String _str(Object? v) => (v ?? '').toString().trim();

/// Context needed to map person rows.
class PersonMapContext {
  const PersonMapContext({
    required this.groups,
    this.mainGroupId,
    this.additionalFields = const [],
  });

  final List<Group> groups;
  final int? mainGroupId;
  final List<ExtraField> additionalFields;
}

/// Result of mapping one spreadsheet row to a person.
class MappedPersonRow {
  MappedPersonRow({
    required this.data,
    required this.rowIndex,
    required this.errors,
    required this.warnings,
    required this.groupResolved,
    this.rawGroup,
    this.isDuplicate = false,
  });

  /// Insert payload for the `player` table (without tenantId/id).
  final Map<String, dynamic> data;
  final int rowIndex;
  final List<String> errors;
  final List<String> warnings;

  /// Raw group cell from the file.
  final String? rawGroup;

  /// False when the file's group name didn't match any tenant group.
  bool groupResolved;
  bool isDuplicate;

  String get firstName => data['firstName'] as String? ?? '';
  String get lastName => data['lastName'] as String? ?? '';
  String? get email => data['email'] as String?;
  int? get instrument => data['instrument'] as int?;
  set instrument(int? value) => data['instrument'] = value;

  /// 'error' | 'duplicate' | 'warning' | 'ok'
  String get status {
    if (errors.isNotEmpty) return 'error';
    if (isDuplicate) return 'duplicate';
    if (warnings.isNotEmpty) return 'warning';
    return 'ok';
  }

  bool get isImportable => errors.isEmpty && !isDuplicate;
}

/// Auto-match each file column to a target by German header name
/// (case-insensitive, trimmed). Unmatched columns map to null.
ColumnMapping autoMapPersonHeaders(
  List<String> fileHeaders,
  PersonMapContext ctx,
) {
  final standard = <String, String>{
    for (final h in kPersonImportHeaders) _norm(h): h,
    'name': kFullNameKey,
    'email': 'E-Mail',
    'e-mail-adresse': 'E-Mail',
    'telefonnummer': 'Telefon',
    'gruppe/instrument': 'Gruppe',
    'instrument': 'Gruppe',
  };
  final extra = <String, String>{
    for (final f in ctx.additionalFields) _norm(f.name): '$kExtraPrefix${f.id}',
  };

  return {
    for (final header in fileHeaders)
      header: standard[_norm(header)] ?? extra[_norm(header)],
  };
}

/// Split a single "full name" cell into first/last name.
/// - "Nachname, Vorname" -> last before comma, first after.
/// - Otherwise the last token is the last name ("Anna Maria Müller").
/// - A single token becomes the first name only.
({String firstName, String lastName}) splitFullName(Object? value) {
  final raw = _str(value);
  if (raw.isEmpty) return (firstName: '', lastName: '');

  if (raw.contains(',')) {
    final parts = raw.split(',');
    return (
      firstName: parts.sublist(1).join(',').trim(),
      lastName: parts.first.trim(),
    );
  }

  final parts = raw.split(RegExp(r'\s+'));
  if (parts.length == 1) return (firstName: parts.first, lastName: '');
  return (
    firstName: parts.sublist(0, parts.length - 1).join(' '),
    lastName: parts.last,
  );
}

String _isoUtcMidnight(int y, int m, int d) =>
    DateTime.utc(y, m, d).toIso8601String();

DateTime? _validDate(int y, int m, int d) {
  if (m < 1 || m > 12 || d < 1 || d > 31) return null;
  final dt = DateTime.utc(y, m, d);
  if (dt.year != y || dt.month != m || dt.day != d) return null;
  return dt;
}

/// Parse a date cell into an ISO string at UTC midnight (how Ionic stores
/// `birthday`/`joined`). Accepts DateTime, Excel serial numbers and the
/// formats DD.MM.YYYY, YYYY-MM-DD, DD/MM/YYYY, D.M.YYYY, DD.MM.YY.
/// Returns null when empty or unparseable.
String? parseGermanDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) {
    return _isoUtcMidnight(value.year, value.month, value.day);
  }
  if (value is num) {
    if (!value.isFinite) return null;
    final d = DateTime.utc(1899, 12, 30).add(Duration(days: value.floor()));
    return _isoUtcMidnight(d.year, d.month, d.day);
  }

  final str = value.toString().trim();
  if (str.isEmpty) return null;

  // DD.MM.YYYY and D.M.YYYY
  var m = RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})$').firstMatch(str);
  if (m != null) {
    final dt = _validDate(
        int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
    if (dt != null) return dt.toIso8601String();
  }
  // YYYY-MM-DD
  m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(str);
  if (m != null) {
    final dt = _validDate(
        int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
    if (dt != null) return dt.toIso8601String();
  }
  // DD/MM/YYYY
  m = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(str);
  if (m != null) {
    final dt = _validDate(
        int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
    if (dt != null) return dt.toIso8601String();
  }
  // DD.MM.YY (dayjs: 00-68 -> 20xx, 69-99 -> 19xx)
  m = RegExp(r'^(\d{2})\.(\d{2})\.(\d{2})$').firstMatch(str);
  if (m != null) {
    final yy = int.parse(m[3]!);
    final year = yy > 68 ? 1900 + yy : 2000 + yy;
    final dt = _validDate(year, int.parse(m[2]!), int.parse(m[1]!));
    if (dt != null) return dt.toIso8601String();
  }
  return null;
}

/// Case-insensitive exact match of a group name to a group id.
int? resolveGroupId(Object? name, List<Group> groups) {
  final n = _norm(name);
  if (n.isEmpty) return null;
  for (final g in groups) {
    if (_norm(g.name) == n) return g.id;
  }
  return null;
}

final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

const _truthy = ['ja', 'yes', 'true', '1', 'x', 'wahr'];

/// Coerce a raw cell value to the type expected by an additional field.
dynamic coerceExtraValue(ExtraField field, Object? raw) {
  final str = _str(raw);
  switch (FieldType.fromValue(field.type)) {
    case FieldType.boolean:
      return _truthy.contains(str.toLowerCase());
    case FieldType.number:
      final num? parsed = num.tryParse(str.replaceFirst(',', '.'));
      return (str.isEmpty || parsed == null) ? field.defaultValue : parsed;
    default:
      return str.isEmpty ? (field.defaultValue ?? '') : str;
  }
}

/// True if the mapping can produce a name: a combined `Name` column, or both
/// Vorname and Nachname.
bool mappingHasName(ColumnMapping mapping) {
  final targets = mapping.values.toSet();
  if (targets.contains(kFullNameKey)) return true;
  return targets.contains('Vorname') && targets.contains('Nachname');
}

String? _columnFor(ColumnMapping mapping, String target) {
  for (final entry in mapping.entries) {
    if (entry.value == target) return entry.key;
  }
  return null;
}

/// Map one row to a person payload using the (possibly user-edited) mapping.
MappedPersonRow mapPersonRow(
  Map<String, dynamic> row,
  ColumnMapping mapping,
  PersonMapContext ctx,
  int rowIndex, {
  DateTime? now,
}) {
  final errors = <String>[];
  final warnings = <String>[];
  Object? get(String target) {
    final col = _columnFor(mapping, target);
    return col == null ? '' : row[col];
  }

  // --- Name ---
  String firstName;
  String lastName;
  if (_columnFor(mapping, kFullNameKey) != null) {
    final split = splitFullName(get(kFullNameKey));
    firstName = split.firstName;
    lastName = split.lastName;
  } else {
    firstName = _str(get('Vorname'));
    lastName = _str(get('Nachname'));
  }
  if (firstName.isEmpty || lastName.isEmpty) {
    errors.add('Vor- und Nachname sind erforderlich');
  }

  // --- Dates --- (null, never '' for nullable timestamptz columns)
  final rawBirthday = get('Geburtsdatum');
  String? birthday;
  if (_str(rawBirthday).isNotEmpty) {
    birthday = parseGermanDate(rawBirthday);
    if (birthday == null) {
      warnings.add('Geburtsdatum "${_str(rawBirthday)}" konnte nicht gelesen werden');
    }
  }

  final today = now ?? DateTime.now();
  final rawJoined = get('Eingetreten');
  var joined = _isoUtcMidnight(today.year, today.month, today.day);
  if (_str(rawJoined).isNotEmpty) {
    final parsed = parseGermanDate(rawJoined);
    if (parsed != null) {
      joined = parsed;
    } else {
      warnings.add('Eintrittsdatum "${_str(rawJoined)}" konnte nicht gelesen werden');
    }
  }

  // --- Group --- unmatched names default to the main group but are flagged.
  final rawGroup = _str(get('Gruppe'));
  final resolvedId = resolveGroupId(rawGroup, ctx.groups);
  final groupResolved = resolvedId != null || rawGroup.isEmpty;
  final instrument = resolvedId ??
      ctx.mainGroupId ??
      (ctx.groups.isNotEmpty ? ctx.groups.first.id : null);

  // --- Email ---
  final email = _str(get('E-Mail')).toLowerCase();
  if (email.isNotEmpty && !_emailRe.hasMatch(email)) {
    warnings.add('E-Mail "$email" sieht ungültig aus');
  }

  final phone = _str(get('Telefon'));
  final notes = _str(get('Notizen'));

  // --- Additional fields ---
  final additionalFields = <String, dynamic>{};
  for (final field in ctx.additionalFields) {
    final col = _columnFor(mapping, '$kExtraPrefix${field.id}');
    if (col != null) {
      additionalFields[field.id] = coerceExtraValue(field, row[col]);
    }
  }

  final data = <String, dynamic>{
    'firstName': firstName,
    'lastName': lastName,
    'instrument': instrument,
    'img': kDefaultAvatarUrl,
    'joined': joined,
    if (email.isNotEmpty) 'email': email,
    'hasTeacher': false,
    'playsSince': null,
    'correctBirthday': birthday != null,
    'birthday': birthday,
    'isLeader': false,
    'isCritical': false,
    'notes': notes,
    'phone': phone,
    'history': <dynamic>[],
    'pending': false,
    'self_register': false,
    'additional_fields': additionalFields,
  };

  return MappedPersonRow(
    data: data,
    rowIndex: rowIndex,
    errors: errors,
    warnings: warnings,
    rawGroup: rawGroup,
    groupResolved: groupResolved,
  );
}

/// Whether a raw row is entirely blank.
bool isEmptyRow(Map<String, dynamic> row) =>
    row.values.every((v) => _str(v).isEmpty);

/// Map all rows, skipping blank ones and flagging duplicate emails within the
/// file.
List<MappedPersonRow> mapPersonRows(
  List<Map<String, dynamic>> rows,
  ColumnMapping mapping,
  PersonMapContext ctx, {
  DateTime? now,
}) {
  final result = <MappedPersonRow>[];
  final seen = <String>{};
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    if (isEmptyRow(row)) continue;
    final mapped = mapPersonRow(row, mapping, ctx, i, now: now);
    final email = mapped.email;
    if (email != null && email.isNotEmpty) {
      if (seen.contains(email)) {
        mapped.warnings.add('Doppelte E-Mail in der Datei');
        mapped.isDuplicate = true;
      } else {
        seen.add(email);
      }
    }
    result.add(mapped);
  }
  return result;
}

/// Mark rows whose email already exists in the tenant (lowercased set).
List<MappedPersonRow> detectPersonDuplicates(
  List<MappedPersonRow> mapped,
  Set<String> existingEmails,
) {
  const msg = 'E-Mail existiert bereits in dieser Instanz';
  for (final row in mapped) {
    final email = row.email;
    if (email != null && existingEmails.contains(email)) {
      row.isDuplicate = true;
      if (!row.warnings.contains(msg)) row.warnings.add(msg);
    }
  }
  return mapped;
}

/// Headers for the downloadable person import template.
List<String> buildPersonImportTemplateHeaders(List<ExtraField> additionalFields) =>
    [...kPersonImportHeaders, ...additionalFields.map((f) => f.name)];

// ─── Song import ────────────────────────────────────────────────────────────

const List<String> kSongImportHeaders = [
  'Nummer',
  'Präfix',
  'Name',
  'Chor & Orchester',
  'Mit Solo',
  'Link',
  'Schwierigkeit',
  'Kategorien',
];

class SongMapContext {
  const SongMapContext({
    this.songCategories = const [],
    this.additionalFields = const [],
  });

  final List<SongCategory> songCategories;

  /// From `tenants.song_additional_fields`.
  final List<ExtraField> additionalFields;
}

class MappedSongRow {
  MappedSongRow({
    required this.data,
    required this.rowIndex,
    required this.errors,
    required this.warnings,
    required this.compositeKey,
    this.isDuplicate = false,
  });

  /// Insert payload for the `songs` table (without tenantId/id).
  final Map<String, dynamic> data;
  final int rowIndex;
  final List<String> errors;
  final List<String> warnings;

  /// `${prefix ?? ''}${number}` — unique dedup key.
  final String compositeKey;
  bool isDuplicate;

  String get displayTitle =>
      '${data['prefix'] ?? ''}${data['number'] ?? ''} ${data['name'] ?? ''}'.trim();

  String get status {
    if (errors.isNotEmpty) return 'error';
    if (isDuplicate) return 'duplicate';
    if (warnings.isNotEmpty) return 'warning';
    return 'ok';
  }

  bool get isImportable => errors.isEmpty && !isDuplicate;
}

ColumnMapping autoMapSongHeaders(List<String> fileHeaders, SongMapContext ctx) {
  final standard = <String, String>{
    for (final h in kSongImportHeaders) _norm(h): h,
    'number': 'Nummer',
    'nr': 'Nummer',
    'no': 'Nummer',
    'prefix': 'Präfix',
    'prafix': 'Präfix',
    'name': 'Name',
    'titel': 'Name',
    'title': 'Name',
    'chor': 'Chor & Orchester',
    'orchester': 'Chor & Orchester',
    'choir': 'Chor & Orchester',
    'solo': 'Mit Solo',
    'link': 'Link',
    'url': 'Link',
    'difficulty': 'Schwierigkeit',
    'schwierigkeit': 'Schwierigkeit',
    'categories': 'Kategorien',
    'category': 'Kategorien',
    'kategorien': 'Kategorien',
    'kategorie': 'Kategorien',
  };
  final extra = <String, String>{
    for (final f in ctx.additionalFields) _norm(f.name): '$kExtraPrefix${f.id}',
  };
  return {
    for (final header in fileHeaders)
      header: standard[_norm(header)] ?? extra[_norm(header)],
  };
}

bool mappingSongHasRequired(ColumnMapping mapping) {
  final targets = mapping.values.toSet();
  return targets.contains('Nummer') && targets.contains('Name');
}

final _httpUrlRe = RegExp(r'^https?://.+', caseSensitive: false);

MappedSongRow mapSongRow(
  Map<String, dynamic> row,
  ColumnMapping mapping,
  SongMapContext ctx,
  int rowIndex,
) {
  final errors = <String>[];
  final warnings = <String>[];
  Object? get(String target) {
    final col = _columnFor(mapping, target);
    return col == null ? '' : row[col];
  }

  // --- Nummer ---
  final numberStr = _str(get('Nummer'));
  final num? parsedNumber = numberStr.isEmpty ? null : num.tryParse(numberStr);
  if (parsedNumber == null) {
    errors.add('Nummer ist erforderlich und muss eine Zahl sein');
  }
  // Column `number` is an integer.
  final int? number = parsedNumber?.toInt();

  final prefixStr = _str(get('Präfix'));
  final String? prefix = prefixStr.isEmpty ? null : prefixStr;

  final name = _str(get('Name'));
  if (name.isEmpty) errors.add('Name ist erforderlich');

  bool parseBool(Object? raw) => _truthy.contains(_str(raw).toLowerCase());
  final withChoir = parseBool(get('Chor & Orchester'));
  final withSolo = parseBool(get('Mit Solo'));

  final linkStr = _str(get('Link'));
  final String? link = linkStr.isEmpty ? null : linkStr;
  if (link != null && !_httpUrlRe.hasMatch(link)) {
    warnings.add('Link "$link" sieht ungültig aus');
  }

  final rawDiff = _str(get('Schwierigkeit'));
  int? difficulty;
  if (rawDiff.isNotEmpty) {
    final d = int.tryParse(RegExp(r'^\d+').stringMatch(rawDiff) ?? '');
    if (d != null && [1, 2, 3].contains(d)) {
      difficulty = d;
    } else {
      warnings.add('Schwierigkeit "$rawDiff" muss 1, 2 oder 3 sein');
    }
  }

  final rawCats = _str(get('Kategorien'));
  final categoryIds = <String>[];
  if (rawCats.isNotEmpty) {
    for (final token in rawCats.split(',')) {
      final t = token.trim();
      if (t.isEmpty) continue;
      SongCategory? match;
      for (final c in ctx.songCategories) {
        if (_norm(c.name) == _norm(t)) {
          match = c;
          break;
        }
      }
      if (match?.id != null) {
        categoryIds.add(match!.id!);
      } else {
        warnings.add('Kategorie "$t" nicht gefunden');
      }
    }
  }

  final additionalFields = <String, dynamic>{};
  for (final field in ctx.additionalFields) {
    final col = _columnFor(mapping, '$kExtraPrefix${field.id}');
    if (col != null) {
      additionalFields[field.id] = coerceExtraValue(field, row[col]);
    }
  }

  final compositeKey = '${prefix ?? ''}${number ?? ''}';

  final data = <String, dynamic>{
    if (number != null) 'number': number,
    if (prefix != null) 'prefix': prefix,
    'name': name,
    'withChoir': withChoir,
    'withSolo': withSolo,
    if (link != null) 'link': link,
    if (difficulty != null) 'difficulty': difficulty,
    if (categoryIds.isNotEmpty) 'category_ids': categoryIds,
    if (additionalFields.isNotEmpty) 'additional_fields': additionalFields,
  };

  return MappedSongRow(
    data: data,
    rowIndex: rowIndex,
    errors: errors,
    warnings: warnings,
    compositeKey: compositeKey,
  );
}

List<MappedSongRow> mapSongRows(
  List<Map<String, dynamic>> rows,
  ColumnMapping mapping,
  SongMapContext ctx,
) {
  final result = <MappedSongRow>[];
  final seen = <String>{};
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    if (isEmptyRow(row)) continue;
    final mapped = mapSongRow(row, mapping, ctx, i);
    if (mapped.compositeKey.isNotEmpty && mapped.errors.isEmpty) {
      if (seen.contains(mapped.compositeKey)) {
        mapped.warnings.add('Doppelte Nummer in der Datei');
        mapped.isDuplicate = true;
      } else {
        seen.add(mapped.compositeKey);
      }
    }
    result.add(mapped);
  }
  return result;
}

List<MappedSongRow> detectSongDuplicates(
  List<MappedSongRow> mapped,
  Set<String> existingKeys,
) {
  const msg = 'Liednummer existiert bereits in dieser Instanz';
  for (final row in mapped) {
    if (row.compositeKey.isNotEmpty && existingKeys.contains(row.compositeKey)) {
      row.isDuplicate = true;
      if (!row.warnings.contains(msg)) row.warnings.add(msg);
    }
  }
  return mapped;
}

List<String> buildSongImportTemplateHeaders(List<ExtraField> additionalFields) =>
    [...kSongImportHeaders, ...additionalFields.map((f) => f.name)];
