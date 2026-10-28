import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/profile_providers.dart';
import '../../../../data/models/person/person.dart';

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

/// Provider for all active members grouped by instrument
final membersGroupedProvider = FutureProvider<List<MembersGroup>>((ref) async {
  final groupRepo = ref.watch(groupRepositoryWithTenantProvider);
  final playerRepo = ref.watch(playerRepositoryWithTenantProvider);

  if (!groupRepo.hasTenantId || !playerRepo.hasTenantId) return [];

  // Get all groups/instruments
  final groups = await groupRepo.getGroups();

  // Get all active players (getPlayers defaults: pending=false, left=null)
  final players = await playerRepo.getPlayers();

  // Sort players: isLeader desc, then lastName asc (preserved from original query)
  players.sort((a, b) {
    final leaderCmp = (b.isLeader ? 1 : 0).compareTo(a.isLeader ? 1 : 0);
    if (leaderCmp != 0) return leaderCmp;
    return a.lastName.toLowerCase().compareTo(b.lastName.toLowerCase());
  });

  // Sort groups: maingroup desc, then name asc (preserved from original query)
  final sortedGroups = [...groups]..sort((a, b) {
    final aMain = a.maingroup ?? false;
    final bMain = b.maingroup ?? false;
    final mainCmp = (bMain ? 1 : 0).compareTo(aMain ? 1 : 0);
    if (mainCmp != 0) return mainCmp;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });

  // Group players by instrument
  final List<MembersGroup> result = [];

  for (final group in sortedGroups) {
    final groupId = group.id;
    if (groupId == null) continue;
    final groupName = group.name;
    final groupMembers = players.where((p) => p.instrument == groupId).toList();

    if (groupMembers.isNotEmpty) {
      result.add(MembersGroup(
        groupId: groupId,
        groupName: groupName,
        members: groupMembers,
      ));
    }
  }

  // Ionic recalculateGroupHeaders: players without a (known) group are shown
  // under "Ohne Gruppe" instead of being dropped.
  final knownIds = sortedGroups.map((g) => g.id).whereType<int>().toSet();
  final ungrouped = players.where((p) => !knownIds.contains(p.instrument)).toList();
  if (ungrouped.isNotEmpty) {
    result.add(MembersGroup(groupId: -1, groupName: 'Ohne Gruppe', members: ungrouped));
  }

  return result;
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
