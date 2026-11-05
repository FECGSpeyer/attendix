import 'package:flutter/foundation.dart';

import '../../../core/constants/enums.dart';
import '../../../data/models/person/person.dart';

/// REDESIGN: one person of a Termin as the new Termin view shows it (status
/// and note as currently shown, including unsaved local changes).
@immutable
class RdMember {
  const RdMember({
    required this.person,
    required this.status,
    this.note,
    this.changedAt,
    this.changedBy,
  });

  final Person person;
  final AttendanceStatus status;
  final String? note;
  final String? changedAt;

  /// App user id of who changed the status last (`changed_by`).
  final String? changedBy;

  int get id => person.id!;
  String get name => '${person.firstName} ${person.lastName}'.trim();
  String? get groupName => person.groupName;
  bool get isOpen => status == AttendanceStatus.neutral;
}

/// A group in which nobody will be there ("1. Trompete: 0 von 2 da").
@immutable
class RdRegisterGap {
  const RdRegisterGap({required this.group, required this.members});

  final String group;
  final List<RdMember> members;
}

/// Groups where every member signed out or is absent, biggest first, at
/// most [limit]. Members without a group are left out.
List<RdRegisterGap> rdRegisterGaps(List<RdMember> members, {int limit = 3}) {
  final byGroup = <int, List<RdMember>>{};
  for (final m in members) {
    final group = m.person.instrument;
    if (group == null) continue;
    byGroup.putIfAbsent(group, () => []).add(m);
  }
  final gaps = <RdRegisterGap>[
    for (final list in byGroup.values)
      if (list.every((m) => m.status == AttendanceStatus.excused || m.status == AttendanceStatus.absent))
        RdRegisterGap(group: list.first.groupName ?? '', members: list),
  ]..sort((a, b) => b.members.length.compareTo(a.members.length));
  return gaps.where((g) => g.group.isNotEmpty).take(limit).toList();
}

/// Who will not be there or comes later, for the card at the top of the
/// Termin (concept L1/L4): [away] = abgemeldet/entschuldigt and abwesend,
/// [later] = kommt später/verspätet; each latest change first.
({List<RdMember> away, List<RdMember> later}) rdSignouts(List<RdMember> members) {
  List<RdMember> latestFirst(bool Function(AttendanceStatus s) test) =>
      members.where((m) => test(m.status)).toList()
        ..sort((a, b) => (b.changedAt ?? '').compareTo(a.changedAt ?? ''));
  return (
    away: latestFirst((s) => s == AttendanceStatus.excused || s == AttendanceStatus.absent),
    later: latestFirst((s) => s == AttendanceStatus.late || s == AttendanceStatus.lateExcused),
  );
}

/// Status after tapping the [tapped] button of a person with [current]
/// status. Tapping the active button undoes it: back to the status the
/// person had when the Termin was opened ([initial]), or neutral.
AttendanceStatus rdToggleTarget(
  AttendanceStatus current,
  AttendanceStatus tapped, {
  AttendanceStatus? initial,
}) {
  if (current != tapped) return tapped;
  if (initial != null && initial != tapped) return initial;
  return AttendanceStatus.neutral;
}

/// Filter of the Anwesenheit tab.
enum RdRecordFilter { all, present, late, excused, absent, open }

/// Whether [status] belongs to the filter [filter] ("Verspätet" holds
/// both late statuses).
bool rdFilterMatches(RdRecordFilter filter, AttendanceStatus status) => switch (filter) {
      RdRecordFilter.all => true,
      RdRecordFilter.present => status == AttendanceStatus.present,
      RdRecordFilter.late => status == AttendanceStatus.late || status == AttendanceStatus.lateExcused,
      RdRecordFilter.excused => status == AttendanceStatus.excused,
      RdRecordFilter.absent => status == AttendanceStatus.absent,
      RdRecordFilter.open => status == AttendanceStatus.neutral,
    };

/// Whether [member] matches the search [query] (first or last name).
bool rdMemberMatches(RdMember member, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return member.name.toLowerCase().contains(q);
}
