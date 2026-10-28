import '../../core/utils/instrument_sort.dart';
import '../../data/models/instrument/instrument.dart';
import '../../data/models/person/person.dart';
import '../../data/models/tenant/tenant.dart';

/// Search people by first/last name, group name and the values of text and
/// number extra fields (Ionic people/list filter()).
List<Person> searchPeople(
  List<Person> people,
  String query, {
  List<ExtraField> extraFields = const [],
}) {
  final term = query.trim().toLowerCase();
  if (term.isEmpty) return people;
  final searchable = extraFields
      .where((f) => f.type == 'number' || f.type == 'text')
      .toList();
  return people.where((p) {
    if (p.firstName.toLowerCase().contains(term) ||
        p.lastName.toLowerCase().contains(term) ||
        (p.groupName?.toLowerCase().contains(term) ?? false)) {
      return true;
    }
    for (final field in searchable) {
      final value = p.additionalFields?[field.id];
      if (value != null && value.toString().toLowerCase().contains(term)) {
        return true;
      }
    }
    return false;
  }).toList();
}

/// People whose (confirmed) birthday is today (Ionic computeTodaysBirthdays).
List<Person> todaysBirthdays(List<Person> people, {DateTime? now}) {
  final today = now ?? DateTime.now();
  return people.where((p) {
    if (p.birthday == null || !p.correctBirthday) return false;
    final b = DateTime.tryParse(p.birthday!)?.toLocal();
    return b != null && b.month == today.month && b.day == today.day;
  }).toList();
}

/// Age in full years at [now].
int ageInYears(String birthday, {DateTime? now}) {
  final b = DateTime.tryParse(birthday)?.toLocal();
  if (b == null) return 0;
  final n = now ?? DateTime.now();
  var age = n.year - b.year;
  if (n.month < b.month || (n.month == b.month && n.day < b.day)) age--;
  return age;
}

/// Sort people the way Ionic `Utils.getModifiedPlayersForList` does for the
/// "Gruppe" view: main group first, then instrument sort_order, then group
/// name; inside a group by player sort_order, then last name.
List<Person> sortPeopleByGroup(List<Person> people, List<Group> groups) {
  final byId = {for (final g in groups) g.id: g};
  final mainGroupId =
      groups.where((g) => g.maingroup == true).map((g) => g.id).firstOrNull;
  final list = [...people];
  list.sort((a, b) {
    final aMain = a.instrument != null && a.instrument == mainGroupId;
    final bMain = b.instrument != null && b.instrument == mainGroupId;
    if (aMain && !bMain) return -1;
    if (bMain && !aMain) return 1;

    final ga = byId[a.instrument];
    final gb = byId[b.instrument];
    if (ga?.sortOrder != null && gb?.sortOrder != null) {
      final c = ga!.sortOrder!.compareTo(gb!.sortOrder!);
      if (c != 0) return c;
    }
    final nameCmp = (a.groupName ?? ga?.name ?? '')
        .toLowerCase()
        .compareTo((b.groupName ?? gb?.name ?? '').toLowerCase());
    if (nameCmp != 0) return nameCmp;
    // Same group (or same name)
    if (a.instrument != b.instrument) {
      return (a.instrument ?? 0).compareTo(b.instrument ?? 0);
    }
    final c = compareSortOrder(a.sortOrder, b.sortOrder);
    if (c != 0) return c;
    return a.lastName.toLowerCase().compareTo(b.lastName.toLowerCase());
  });
  return list;
}

/// Joined within the last month (Ionic Utils.getModifiedPlayersForList isNew).
bool isNewPerson(Person p, {DateTime? now}) {
  final joined = p.joined != null ? DateTime.tryParse(p.joined!) : null;
  if (joined == null) return false;
  final n = now ?? DateTime.now();
  final oneMonthAgo = DateTime(n.year, n.month - 1, n.day, n.hour, n.minute);
  return joined.isAfter(oneMonthAgo);
}
