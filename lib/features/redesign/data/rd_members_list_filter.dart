import '../../../core/utils/people_sort.dart';
import '../../../data/models/person/person.dart';
import '../../../data/models/tenant/tenant.dart' show ExtraField;
import '../../people/people_list_utils.dart' show isNewPerson;

/// REDESIGN: "Sortieren & Filtern" of the Mitglieder tab. The filter and
/// sort options of the old list (Ionic list.page filter / sort select),
/// combinable, plus a filter by group.

/// Sort orders (Ionic sortOpt). [group] keeps the register sections.
enum RdMembersSort {
  group,
  firstName,
  lastName,
  attendanceAsc,
  attendanceDesc,
  birthdayAsc,
  birthdayDesc,
  nextBirthday,
  joinedAsc,
  joinedDesc,
  testResult,
}

/// Yes/no filters (Ionic filterOpt). The VoS ones only show for VoS.
enum RdMembersOnly { leaders, noAccount, examinees, newPeople, noTeacher, noTest }

/// Sorts that only exist for the VoS tenant.
const rdMembersVosSorts = {RdMembersSort.testResult};

/// Filters that only exist for the VoS tenant.
const rdMembersVosOnly = {
  RdMembersOnly.examinees,
  RdMembersOnly.newPeople,
  RdMembersOnly.noTeacher,
  RdMembersOnly.noTest,
};

class RdMembersListFilter {
  const RdMembersListFilter({
    this.sort = RdMembersSort.group,
    this.groupIds = const {},
    this.only = const {},
    this.fields = const {},
    this.otherTenantId,
  });

  final RdMembersSort sort;

  /// Only these groups (empty = all).
  final Set<int> groupIds;

  /// All of these must hold.
  final Set<RdMembersOnly> only;

  /// Extra field id → value (as string, like Ionic filterOptAdd).
  final Map<String, String> fields;

  /// Only people whose account is also in this linked tenant.
  final int? otherTenantId;

  /// Number of active filters (the sort does not count).
  int get count => groupIds.length + only.length + fields.length + (otherTenantId != null ? 1 : 0);

  bool get isDefault => count == 0 && sort == RdMembersSort.group;

  RdMembersListFilter copyWith({
    RdMembersSort? sort,
    Set<int>? groupIds,
    Set<RdMembersOnly>? only,
    Map<String, String>? fields,
    int? Function()? otherTenantId,
  }) => RdMembersListFilter(
    sort: sort ?? this.sort,
    groupIds: groupIds ?? this.groupIds,
    only: only ?? this.only,
    fields: fields ?? this.fields,
    otherTenantId: otherTenantId != null ? otherTenantId() : this.otherTenantId,
  );

  RdMembersListFilter toggleGroup(int id) =>
      copyWith(groupIds: groupIds.contains(id) ? ({...groupIds}..remove(id)) : {...groupIds, id});

  RdMembersListFilter toggleOnly(RdMembersOnly value) =>
      copyWith(only: only.contains(value) ? ({...only}..remove(value)) : {...only, value});

  /// Sets ('' or null clears) the value of an extra field filter.
  RdMembersListFilter withField(String fieldId, String? value) {
    final next = {...fields};
    if (value == null || value.isEmpty) {
      next.remove(fieldId);
    } else {
      next[fieldId] = value;
    }
    return copyWith(fields: next);
  }

  /// Keeps the sort, drops every filter.
  RdMembersListFilter clearFilters() => RdMembersListFilter(sort: sort);
}

/// The persons of [people] passing [filter]. [otherInstanceUserIds] are the
/// accounts of the chosen linked tenant (the page passes an empty set while
/// they load, so nobody shows instead of everybody).
/// Extra field defaults must already be filled in (withExtraFieldDefaults).
List<Person> rdFilterMembers(
  List<Person> people,
  RdMembersListFilter filter, {
  Set<String>? otherInstanceUserIds,
  List<ExtraField> fieldDefs = const [],
  DateTime? now,
}) {
  if (filter.count == 0) return people;
  return people.where((p) {
    if (filter.groupIds.isNotEmpty && !filter.groupIds.contains(p.instrument)) return false;
    for (final o in filter.only) {
      final ok = switch (o) {
        RdMembersOnly.leaders => p.isLeader,
        RdMembersOnly.noAccount => p.appId == null,
        RdMembersOnly.examinees => p.examinee,
        RdMembersOnly.newPeople => isNewPerson(p, now: now),
        RdMembersOnly.noTeacher => !p.hasTeacher,
        RdMembersOnly.noTest => (p.testResult ?? '').isEmpty,
      };
      if (!ok) return false;
    }
    for (final e in filter.fields.entries) {
      // Like the old list: a person without values counts a Ja/Nein field
      // as its default (else Ja).
      final def = fieldDefs.where((f) => f.id == e.key).firstOrNull;
      final raw = p.additionalFields?[e.key] ?? (def?.type == 'boolean' ? (def!.defaultValue ?? true) : null);
      if (raw?.toString() != e.value) return false;
    }
    final ids = otherInstanceUserIds;
    if (filter.otherTenantId != null && ids != null && !(p.appId != null && ids.contains(p.appId))) {
      return false;
    }
    return true;
  }).toList();
}

/// [people] in the order of [sort] (not [RdMembersSort.group], which the
/// register sections do). Missing dates go last, like the old list.
List<Person> rdSortMembers(
  List<Person> people,
  RdMembersSort sort, {
  Map<int, int> percentages = const {},
  DateTime? now,
}) {
  int byDate(String? a, String? b, {bool desc = false}) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return desc ? b.compareTo(a) : a.compareTo(b);
  }

  final today = now ?? DateTime.now();
  DateTime? nextBirthday(String? birthday) {
    final b = DateTime.tryParse(birthday ?? '');
    if (b == null) return null;
    var next = DateTime(today.year, b.month, b.day);
    if (next.isBefore(DateTime(today.year, today.month, today.day))) next = DateTime(today.year + 1, b.month, b.day);
    return next;
  }

  final list = [...people];
  switch (sort) {
    case RdMembersSort.group:
      return list;
    case RdMembersSort.firstName:
      list.sort((a, b) => localeCompareDe(a.firstName, b.firstName));
    case RdMembersSort.lastName:
      list.sort((a, b) => localeCompareDe(a.lastName, b.lastName));
    case RdMembersSort.attendanceAsc:
    case RdMembersSort.attendanceDesc:
      list.sort((a, b) {
        final c = (percentages[a.id] ?? 0).compareTo(percentages[b.id] ?? 0);
        if (c != 0) return sort == RdMembersSort.attendanceAsc ? c : -c;
        return localeCompareDe(a.lastName, b.lastName);
      });
    case RdMembersSort.birthdayAsc:
      list.sort((a, b) => byDate(a.birthday, b.birthday));
    case RdMembersSort.birthdayDesc:
      list.sort((a, b) => byDate(a.birthday, b.birthday, desc: true));
    case RdMembersSort.nextBirthday:
      list.sort((a, b) {
        final x = nextBirthday(a.birthday);
        final y = nextBirthday(b.birthday);
        if (x == null && y == null) return 0;
        if (x == null) return 1;
        if (y == null) return -1;
        return x.compareTo(y);
      });
    case RdMembersSort.joinedAsc:
      list.sort((a, b) => byDate(a.joined, b.joined));
    case RdMembersSort.joinedDesc:
      list.sort((a, b) => byDate(a.joined, b.joined, desc: true));
    case RdMembersSort.testResult:
      list.sort((a, b) => testResultValue(b.testResult).compareTo(testResultValue(a.testResult)));
  }
  return list;
}
