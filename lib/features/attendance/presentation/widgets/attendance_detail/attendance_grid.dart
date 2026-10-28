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
    this.cornerRadius,
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

  /// UX_ATT: when set, the list is drawn as a rounded white section (Ionic
  /// item-group inside the inset list); first divider and last row get the
  /// matching corners.
  final BorderRadius? cornerRadius;

  @override
  Widget build(BuildContext context) {
    if (persons.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final lastId = persons.last.id;
    final radius = cornerRadius;

    Widget decorate(Widget sliver) {
      if (radius == null) return sliver;
      return DecoratedSliver(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: radius,
        ),
        sliver: sliver,
      );
    }

    // Sorted by an extra field -> one flat list without group dividers
    if (extraLines != null) {
      return decorate(_personsSliver(persons, lastId: lastId, first: true));
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

    return decorate(SliverMainAxisGroup(
      slivers: [
        for (var i = 0; i < groups.length; i++)
          SliverMainAxisGroup(
            slivers: [
              PinnedHeaderSliver(
                child: _GroupDivider(
                  label: '${groups[i].name} '
                      '(${_attendedCount(groups[i].persons)}/${groups[i].persons.length})',
                  topRadius: i == 0 && radius != null ? radius.topLeft : null,
                ),
              ),
              _personsSliver(groups[i].persons, lastId: lastId),
            ],
          ),
      ],
    ));
  }

  /// Ionic getAttendedPlayersForGroup: Anwesend, Verspätet, Verspätet entsch.
  int _attendedCount(List<Person> persons) => persons.where((p) {
        final s = localStatuses[p.id];
        return s == AttendanceStatus.present ||
            s == AttendanceStatus.late ||
            s == AttendanceStatus.lateExcused;
      }).length;

  Widget _personsSliver(List<Person> list, {int? lastId, bool first = false}) {
    // UX_ATT: iOS inset lines start at the label (after the avatar)
    final indent = showAvatars ? 68.0 : 16.0;
    return SliverList.separated(
      itemCount: list.length,
      separatorBuilder: (_, __) => Divider(height: 0.5, thickness: 0.5, indent: indent),
      itemBuilder: (context, index) {
        final person = list[index];
        final id = person.id;
        final tile = AttendancePersonTile(
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
        final radius = cornerRadius;
        if (radius == null) return tile;
        final isFirst = first && index == 0;
        final isLast = id == lastId && index == list.length - 1;
        if (!isFirst && !isLast) return tile;
        return ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: isFirst ? radius.topLeft : Radius.zero,
            topRight: isFirst ? radius.topRight : Radius.zero,
            bottomLeft: isLast ? radius.bottomLeft : Radius.zero,
            bottomRight: isLast ? radius.bottomRight : Radius.zero,
          ),
          child: tile,
        );
      },
    );
  }
}

/// Ionic `ion-item-divider color="primary" sticky` (iOS: 17 px semibold).
class _GroupDivider extends StatelessWidget {
  const _GroupDivider({required this.label, this.topRadius});

  final String label;

  /// Rounded top corners for the first divider of the section.
  final Radius? topRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: topRadius == null
            ? null
            : BorderRadius.only(topLeft: topRadius!, topRight: topRadius!),
      ),
      constraints: const BoxConstraints(minHeight: 30),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 17,
        ),
      ),
    );
  }
}
