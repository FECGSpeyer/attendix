import 'package:flutter/material.dart';

import '../../../../../core/constants/enums.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/people_sort.dart';
import '../../../../../data/models/instrument/instrument.dart';
import '../../../../../data/models/person/person.dart';
import '../../../../../shared/widgets/adaptive/adaptive_platform.dart';
import 'attendance_person_tile.dart';
import '../../../../../l10n/l10n.dart';

/// Ionic `Utils.sortPlayers` (attendance page, via getModifiedPlayers):
/// 1. the main group's persons first,
/// 2. the other persons grouped by group (instrument id); the groups ordered
///    by the group's `sort_order` – a group WITH a sort_order comes before
///    one without – and otherwise by group name,
/// 3. inside each group by the person's `sort_order` (same rule), then by
///    last name (JS `localeCompare`).
///
/// IOS_DETAIL: equal keys keep their incoming order (JS sort is stable).
///
/// GROUP_ORDER: [usePersonSortOrder] = false sorts the persons of a group
/// by last name only. That is what the Ionic Termin page renders: its
/// `attendanceSelect` never loads `player.sort_order`, so the person
/// sort_order branch of `Utils.sortPlayers` never applies there.
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

  // Groups in order of first appearance (JS Map insertion order).
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

/// IOS_DETAIL: Ionic `db.getMainGroup()` = the first group with
/// `maingroup` in the tenant's group list.
int? mainGroupIdOf(List<Group> groups) =>
    groups.where((g) => g.maingroup == true).firstOrNull?.id;

/// IOS_DETAIL: HTML collapses runs of whitespace ("Max  Mustermann" renders
/// as "Max Mustermann"); Flutter Text keeps them, so collapse them for
/// displayed names / notes.
String collapseHtmlWhitespace(String value) =>
    value.replaceAll(RegExp(r'\s+'), ' ').trim();

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
  int _attendedCount(List<Person> persons) => persons
      .where((p) => localStatuses[p.id]?.countsAsPresent ?? false)
      .length;

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

/// Ionic `ion-item-divider color="primary" sticky` (iOS: 17 px semibold,
/// md: 14 px regular).
class _GroupDivider extends StatelessWidget {
  const _GroupDivider({required this.label, this.topRadius});

  final String label;

  /// Rounded top corners for the first divider of the section.
  final Radius? topRadius;

  @override
  Widget build(BuildContext context) {
    final ios = useIosLook(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: topRadius == null
            ? null
            : BorderRadius.only(topLeft: topRadius!, topRight: topRadius!),
      ),
      // IOS_DETAIL: iOS divider row ≈28 pt, 17 px semibold.
      // PARITY_R3: Ionic md item-divider: min-height 30, 14 px regular
      // (`font-size: .875rem`, no weight), label margin 13/10.
      constraints: BoxConstraints(minHeight: ios ? 28 : 30),
      padding: ios
          ? const EdgeInsets.fromLTRB(16, 3, 16, 3)
          : const EdgeInsets.fromLTRB(16, 13, 16, 10),
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontWeight: ios ? FontWeight.w600 : FontWeight.w400,
          fontSize: ios ? 17 : 14,
          height: ios ? 1.2 : null,
        ),
      ),
    );
  }
}
