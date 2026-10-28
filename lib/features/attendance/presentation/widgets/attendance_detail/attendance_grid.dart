import 'package:flutter/material.dart';

import '../../../../../core/constants/enums.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../data/models/instrument/instrument.dart';
import '../../../../../data/models/person/person.dart';
import 'attendance_person_tile.dart';
import '../../../../../l10n/l10n.dart';

/// Ionic Utils.getModifiedPlayersForList order: main group first, then the
/// group's sort_order, group name, the person's sort_order and last name.
List<Person> sortPersonsByGroup(
  List<Person> persons, {
  List<Group> groups = const [],
  int? mainGroupId,
}) {
  final byId = {for (final g in groups) g.id: g};
  int cmp(Person a, Person b) {
    final aMain = mainGroupId != null && a.instrument == mainGroupId;
    final bMain = mainGroupId != null && b.instrument == mainGroupId;
    if (aMain != bMain) return aMain ? -1 : 1;
    final ag = byId[a.instrument];
    final bg = byId[b.instrument];
    if (ag?.sortOrder != null && bg?.sortOrder != null) {
      final c = ag!.sortOrder!.compareTo(bg!.sortOrder!);
      if (c != 0) return c;
    }
    final gc = (ag?.name ?? a.groupName ?? '').compareTo(bg?.name ?? b.groupName ?? '');
    if (gc != 0) return gc;
    if (a.sortOrder != null && b.sortOrder != null) return a.sortOrder!.compareTo(b.sortOrder!);
    if (a.sortOrder != null) return -1;
    if (b.sortOrder != null) return 1;
    return a.lastName.compareTo(b.lastName);
  }

  return [...persons]..sort(cmp);
}

/// Person list of the attendance detail page, as a sliver.
///
/// UX_ATT: like the Ionic page every group starts with a sticky,
/// primary-colored divider "Gruppe (anwesend/gesamt)"; persons keep the
/// given order (see [sortPersonsByGroup]).
class AttendanceGrid extends StatelessWidget {
  const AttendanceGrid({
    super.key,
    required this.persons,
    required this.localStatuses,
    required this.personNotes,
    required this.availableStatuses,
    required this.onStatusChanged,
    required this.onNoteChanged,
    required this.onShowModifierInfo,
    required this.onRemoveFromAttendance,
    this.clickMode = true,
    this.registrationSummaries = const {},
    this.onEditRegistrationFields,
    this.showAvatars = true,
    this.extraLines,
    this.onSendReminder,
    this.showModifierInfo = true,
  });

  final List<Person> persons;
  final Map<int, AttendanceStatus> localStatuses;
  final Map<int, String?> personNotes;
  final List<AttendanceStatus> availableStatuses;
  final void Function(int personId, AttendanceStatus status) onStatusChanged;
  final void Function(int personId, String? notes) onNoteChanged;
  final void Function(int personId) onShowModifierInfo;
  final void Function(int personId) onRemoveFromAttendance;
  final bool clickMode;
  final Map<int, String> registrationSummaries;
  final void Function(int personId)? onEditRegistrationFields;
  final bool showAvatars;

  /// Flat (sorted) mode: persons are shown in the given order without group
  /// headers; the value is the extra line under the name.
  final Map<int, String>? extraLines;
  final void Function(int personId)? onSendReminder;
  final bool showModifierInfo;

  @override
  Widget build(BuildContext context) {
    if (persons.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    // Sorted by an extra field -> one flat list without group dividers
    if (extraLines != null) {
      return _personsSliver(persons);
    }

    final groups = <({String name, List<Person> persons})>[];
    for (final person in persons) {
      final name = person.groupName ?? l10nWithoutContext.attendanceNoGroup;
      if (groups.isEmpty || groups.last.name != name) {
        final existing = groups.where((g) => g.name == name).firstOrNull;
        if (existing != null) {
          existing.persons.add(person);
          continue;
        }
        groups.add((name: name, persons: [person]));
      } else {
        groups.last.persons.add(person);
      }
    }

    return SliverMainAxisGroup(
      slivers: [
        for (final group in groups)
          SliverMainAxisGroup(
            slivers: [
              PinnedHeaderSliver(
                child: _GroupDivider(
                  label: '${group.name} '
                      '(${_attendedCount(group.persons)}/${group.persons.length})',
                ),
              ),
              _personsSliver(group.persons),
            ],
          ),
      ],
    );
  }

  /// Ionic getAttendedPlayersForGroup: Anwesend, Verspätet, Verspätet entsch.
  int _attendedCount(List<Person> persons) => persons.where((p) {
        final s = localStatuses[p.id];
        return s == AttendanceStatus.present ||
            s == AttendanceStatus.late ||
            s == AttendanceStatus.lateExcused;
      }).length;

  Widget _personsSliver(List<Person> list) {
    return SliverList.separated(
      itemCount: list.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
      itemBuilder: (context, index) {
        final person = list[index];
        final id = person.id;
        return AttendancePersonTile(
          person: person,
          status: localStatuses[id] ?? AttendanceStatus.neutral,
          notes: personNotes[id],
          availableStatuses: availableStatuses,
          clickMode: clickMode,
          registrationSummary: registrationSummaries[id],
          showAvatar: showAvatars,
          extraLine: extraLines?[id],
          showModifierInfo: showModifierInfo,
          onSendReminder:
              onSendReminder == null || id == null ? null : () => onSendReminder!(id),
          onEditRegistrationFields: onEditRegistrationFields == null || id == null
              ? null
              : () => onEditRegistrationFields!(id),
          onStatusChanged: (s) {
            if (id != null) onStatusChanged(id, s);
          },
          onNoteChanged: (n) {
            if (id != null) onNoteChanged(id, n);
          },
          onShowModifierInfo: () {
            if (id != null) onShowModifierInfo(id);
          },
          onRemoveFromAttendance: () {
            if (id != null) onRemoveFromAttendance(id);
          },
        );
      },
    );
  }
}

/// Ionic `ion-item-divider color="primary" sticky`.
class _GroupDivider extends StatelessWidget {
  const _GroupDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }
}
