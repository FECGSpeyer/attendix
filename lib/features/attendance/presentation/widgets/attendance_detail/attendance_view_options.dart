import '../../../../../core/constants/enums.dart';
import '../../../../../data/models/attendance/attendance.dart';
import '../../../../../data/models/church/church.dart';
import '../../../../../data/models/person/person.dart';
import '../../../../../data/repositories/profile_repository.dart';

/// Where the value of a sortable field lives.
enum SortFieldLevel { person, registration }

/// A field the attendance list can be sorted by (Ionic getSortableExtraFields):
/// person extra fields (except textarea) and the type's registration fields.
class SortableField {
  const SortableField({
    required this.id,
    required this.name,
    required this.level,
    this.fieldType,
  });

  final String id;
  final String name;
  final SortFieldLevel level;
  final String? fieldType;
}

/// Active sort of the attendance list. `null` field = "Standard (Gruppe)".
class AttendanceSort {
  const AttendanceSort({this.fieldId, this.level, this.ascending = true});

  final String? fieldId;
  final SortFieldLevel? level;
  final bool ascending;

  bool get isDefault => fieldId == null;
}

List<SortableField> sortableFields(
  List<ProfileExtraField> personFields,
  List<RegistrationField> registrationFields,
) {
  return [
    for (final f in personFields)
      if (f.type != 'textarea')
        SortableField(id: f.id, name: f.name, level: SortFieldLevel.person, fieldType: f.type),
    for (final f in registrationFields)
      SortableField(id: f.id, name: f.label, level: SortFieldLevel.registration, fieldType: f.type),
  ];
}

/// Status filter of the Termin (Ionic filteredPlayers): empty = all.
List<Person> filterPersonsByStatus(
  List<Person> persons,
  Map<int, AttendanceStatus> statuses,
  Set<AttendanceStatus> filter,
) {
  if (filter.isEmpty) return persons;
  return persons
      .where((p) => filter.contains(statuses[p.id] ?? AttendanceStatus.neutral))
      .toList();
}

dynamic _rawValue(
  Person person,
  AttendanceSort sort,
  Map<int, Map<String, dynamic>?> registrationAnswers,
) {
  if (sort.fieldId == null) return null;
  if (sort.level == SortFieldLevel.registration) {
    return registrationAnswers[person.id]?[sort.fieldId];
  }
  return person.additionalFields?[sort.fieldId];
}

String _churchName(dynamic raw, List<Church> churches) =>
    churches.where((c) => c.id == raw.toString()).firstOrNull?.name ?? raw.toString();

/// Sort key (Ionic resolveExtraFieldSortKey).
String sortKeyOf(
  Person person,
  AttendanceSort sort,
  SortableField? field,
  Map<int, Map<String, dynamic>?> registrationAnswers,
  List<Church> churches,
) {
  final raw = _rawValue(person, sort, registrationAnswers);
  if (raw == null) return '';
  if (field?.fieldType == 'bfecg_church') return _churchName(raw, churches);
  if (raw is List) return raw.join(', ');
  return raw.toString();
}

/// Value shown under the name while sorted (Ionic getActiveExtraSortValue).
String sortDisplayValueOf(
  Person person,
  AttendanceSort sort,
  SortableField? field,
  Map<int, Map<String, dynamic>?> registrationAnswers,
  List<Church> churches,
) {
  final raw = _rawValue(person, sort, registrationAnswers);
  if (raw == null || raw == '') return '–';
  if (raw is bool) return raw ? 'Ja' : 'Nein';
  if (raw is List) return raw.join(', ');
  if (field?.fieldType == 'bfecg_church') return _churchName(raw, churches);
  return raw.toString();
}

/// Natural ("numeric") comparison like `localeCompare(…, {numeric: true})`.
int naturalCompare(String a, String b) {
  final re = RegExp(r'(\d+|\D+)');
  final pa = re.allMatches(a.toLowerCase()).map((m) => m.group(0)!).toList();
  final pb = re.allMatches(b.toLowerCase()).map((m) => m.group(0)!).toList();
  for (var i = 0; i < pa.length && i < pb.length; i++) {
    final na = int.tryParse(pa[i]);
    final nb = int.tryParse(pb[i]);
    final cmp = (na != null && nb != null) ? na.compareTo(nb) : pa[i].compareTo(pb[i]);
    if (cmp != 0) return cmp;
  }
  return pa.length.compareTo(pb.length);
}

/// Sorts [persons] by the active extra field (flat list, no group headers).
List<Person> sortPersonsByField(
  List<Person> persons,
  AttendanceSort sort,
  SortableField? field,
  Map<int, Map<String, dynamic>?> registrationAnswers,
  List<Church> churches,
) {
  if (sort.isDefault) return persons;
  final keyed = [
    for (final p in persons) (p, sortKeyOf(p, sort, field, registrationAnswers, churches)),
  ];
  keyed.sort((a, b) {
    final cmp = naturalCompare(a.$2, b.$2);
    return sort.ascending ? cmp : -cmp;
  });
  return keyed.map((e) => e.$1).toList();
}
