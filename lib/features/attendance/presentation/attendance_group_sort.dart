import '../../../core/utils/people_sort.dart';
import '../../../data/models/instrument/instrument.dart';
import '../../../data/models/person/person.dart';

/// Sorts persons by main group first, then groups by `sortOrder` / name,
/// then persons inside each group by optional `sortOrder` and last name.
List<Person> sortPersonsByGroup(
  List<Person> persons, {
  List<Group> groups = const [],
  int? mainGroupId,
  bool usePersonSortOrder = true,
}) {
  final byId = {for (final g in groups) g.id: g};

  int personCmp(Person a, Person b) {
    final ao = usePersonSortOrder ? a.sortOrder : null;
    final bo = usePersonSortOrder ? b.sortOrder : null;
    if (ao != null && bo != null) return ao.compareTo(bo);
    if (ao != null) return -1;
    if (bo != null) return 1;
    return localeCompareDe(a.lastName, b.lastName);
  }

  List<Person> stableSort(List<Person> list, int Function(Person, Person) cmp) {
    final indexed = [for (var i = 0; i < list.length; i++) (i, list[i])];
    indexed.sort((x, y) {
      final c = cmp(x.$2, y.$2);
      return c != 0 ? c : x.$1.compareTo(y.$1);
    });
    return [for (final e in indexed) e.$2];
  }

  final main = mainGroupId == null
      ? <Person>[]
      : persons.where((p) => p.instrument == mainGroupId).toList();
  final others = mainGroupId == null
      ? persons
      : persons.where((p) => p.instrument != mainGroupId).toList();

  final grouped = <int?, List<Person>>{};
  for (final p in others) {
    grouped.putIfAbsent(p.instrument, () => []).add(p);
  }
  final keys = grouped.keys.toList();
  final keyIndex = {for (var i = 0; i < keys.length; i++) keys[i]: i};
  int groupCmp(int? a, int? b) {
    final ao = byId[a]?.sortOrder;
    final bo = byId[b]?.sortOrder;
    if (ao != null && bo != null) return ao.compareTo(bo);
    if (ao != null) return -1;
    if (bo != null) return 1;
    final an = grouped[a]!.first.groupName ?? byId[a]?.name ?? '';
    final bn = grouped[b]!.first.groupName ?? byId[b]?.name ?? '';
    return localeCompareDe(an, bn);
  }

  keys.sort((a, b) {
    final c = groupCmp(a, b);
    return c != 0 ? c : keyIndex[a]!.compareTo(keyIndex[b]!);
  });

  return [
    ...stableSort(main, personCmp),
    for (final k in keys) ...stableSort(grouped[k]!, personCmp),
  ];
}

/// First group with `maingroup == true` in [groups].
int? mainGroupIdOf(List<Group> groups) =>
    groups.where((g) => g.maingroup == true).firstOrNull?.id;

/// Collapses runs of whitespace for displayed names and notes.
String collapseHtmlWhitespace(String value) =>
    value.replaceAll(RegExp(r'\s+'), ' ').trim();
