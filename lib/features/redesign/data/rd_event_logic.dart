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
  });

  final Person person;
  final AttendanceStatus status;
  final String? note;
  final String? changedAt;

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

/// Sign-outs ("Entschuldigt", "Kommt später"), latest change first.
List<RdMember> rdSignouts(List<RdMember> members) {
  final list = members
      .where((m) => m.status == AttendanceStatus.excused || m.status == AttendanceStatus.lateExcused)
      .toList();
  list.sort((a, b) => (b.changedAt ?? '').compareTo(a.changedAt ?? ''));
  return list;
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

/// Whether [member] matches the search [query] (first or last name).
bool rdMemberMatches(RdMember member, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return member.name.toLowerCase().contains(q);
}
