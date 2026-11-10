import '../../data/models/person/person.dart';

/// Aushilfe ("dabei bis"): a person who only helps out for a while (e.g. a
/// few extra players for one concert). The last day is stored as
/// `YYYY-MM-DD` under this key of `additional_fields` (no own column, so no
/// database change). Aushilfen are only put into Termine up to that day,
/// are not counted as Problemfälle and are archived automatically after it.
const String helperUntilKey = 'aushilfeBis';

/// The last day (`YYYY-MM-DD`) of an Aushilfe, null for a regular member.
String? helperUntilOf(Map<String, dynamic>? additionalFields) {
  final v = additionalFields?[helperUntilKey];
  if (v is! String || v.length < 10) return null;
  final day = v.substring(0, 10);
  return DateTime.tryParse(day) == null ? null : day;
}

/// [helperUntilOf] of a person.
String? helperUntil(Person person) => helperUntilOf(person.additionalFields);

/// Whether the person is an Aushilfe.
bool isHelperMember(Person person) => helperUntil(person) != null;

/// Whether a Termin on [date] (ISO date or timestamp) lies within the time
/// of an Aushilfe; always true for regular members or an unknown date.
bool helperCoversDate(Map<String, dynamic>? additionalFields, String? date) {
  final until = helperUntilOf(additionalFields);
  if (until == null || date == null || date.length < 10) return true;
  return date.substring(0, 10).compareTo(until) <= 0;
}

/// `YYYY-MM-DD` of a local day (as stored under [helperUntilKey]).
String helperDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
