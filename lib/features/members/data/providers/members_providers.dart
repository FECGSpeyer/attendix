import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/profile_providers.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/models/person/person.dart';
import '../../../../l10n/l10n.dart';
import '../../../people/people_list_utils.dart';

/// Model for a grouped member list
class MembersGroup {
  final int groupId;
  final String groupName;
  final List<Person> members;

  const MembersGroup({
    required this.groupId,
    required this.groupName,
    required this.members,
  });
}

/// Ionic members.page → Utils.getModifiedPlayersForList without a main
/// group: groups by sort_order, then name (players without a known group
/// first); inside a group by player sort_order, then last name.
List<MembersGroup> buildMembersGroups(List<Person> players, List<Group> groups) {
  final sorted = sortPeopleByGroup(
    players,
    [for (final g in groups) g.copyWith(maingroup: false)],
  );
  final names = {for (final g in groups) g.id: g.name};

  final result = <MembersGroup>[];
  for (final p in sorted) {
    final known = names.containsKey(p.instrument);
    final groupId = known ? p.instrument! : -1;
    if (result.isEmpty || result.last.groupId != groupId) {
      result.add(MembersGroup(
        groupId: groupId,
        groupName: known
            ? names[p.instrument]!
            : l10nWithoutContext.peopleNoGroupAssigned,
        members: [],
      ));
    }
    result.last.members.add(p);
  }
  return result;
}

/// Provider for all active members grouped by instrument
final membersGroupedProvider = FutureProvider<List<MembersGroup>>((ref) async {
  final groupRepo = ref.watch(groupRepositoryWithTenantProvider);
  final playerRepo = ref.watch(playerRepositoryWithTenantProvider);

  if (!groupRepo.hasTenantId || !playerRepo.hasTenantId) return [];

  // Get all groups/instruments
  final groups = await groupRepo.getGroups();

  // Get all active players (getPlayers defaults: pending=false, left=null)
  final players = await playerRepo.getPlayers();

  return buildMembersGroups(players, groups);
});

/// Provider for total member count
final memberCountProvider = Provider<int>((ref) {
  final groupsAsync = ref.watch(membersGroupedProvider);
  return groupsAsync.whenOrNull(
    data: (groups) => groups.fold<int>(0, (sum, g) => sum + g.members.length),
  ) ?? 0;
});

/// Provider for filtered members based on search term
final membersSearchTermProvider = StateProvider<String>((ref) => '');

/// Provider for group filter (null = show all groups)
final membersGroupFilterProvider = StateProvider<int?>((ref) => null);

/// Ionic members page: segment filter on the "einteilung" person extra field
/// ('all' = no filter).
final membersEinteilungFilterProvider = StateProvider<String>((ref) => 'all');

/// Options of the "einteilung" select extra field (empty = no segment).
final membersEinteilungOptionsProvider = Provider<List<String>>((ref) {
  final fields = ref.watch(personExtraFieldsProvider).valueOrNull ?? const [];
  for (final f in fields) {
    if (f.id == 'einteilung' && f.type == 'select') {
      return f.options.where((o) => o != '-').toList();
    }
  }
  return const [];
});

/// Provider for filtered members
final filteredMembersGroupedProvider = Provider<AsyncValue<List<MembersGroup>>>((ref) {
  final groupsAsync = ref.watch(membersGroupedProvider);
  final searchTerm = ref.watch(membersSearchTermProvider).toLowerCase();
  final groupFilter = ref.watch(membersGroupFilterProvider);
  final einteilung = ref.watch(membersEinteilungFilterProvider);
  final hasEinteilung = ref.watch(membersEinteilungOptionsProvider).isNotEmpty;

  return groupsAsync.whenData((groups) {
    var filtered = groups;

    // Einteilung filter (Ionic applyFilters)
    if (hasEinteilung && einteilung != 'all') {
      filtered = [
        for (final g in filtered)
          MembersGroup(
            groupId: g.groupId,
            groupName: g.groupName,
            members: g.members
                .where((p) => p.additionalFields?['einteilung']?.toString() == einteilung)
                .toList(),
          ),
      ].where((g) => g.members.isNotEmpty).toList();
    }

    // Apply group filter
    if (groupFilter != null) {
      filtered = filtered.where((g) => g.groupId == groupFilter).toList();
    }

    // Apply search filter
    if (searchTerm.isNotEmpty) {
      final List<MembersGroup> searchFiltered = [];
      for (final group in filtered) {
        final matchingMembers = group.members.where((p) {
          return p.firstName.toLowerCase().contains(searchTerm) ||
              p.lastName.toLowerCase().contains(searchTerm) ||
              group.groupName.toLowerCase().contains(searchTerm);
        }).toList();

        if (matchingMembers.isNotEmpty) {
          searchFiltered.add(MembersGroup(
            groupId: group.groupId,
            groupName: group.groupName,
            members: matchingMembers,
          ));
        }
      }
      return searchFiltered;
    }

    return filtered;
  });
});
