import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/person/person.dart';
import '../../../../shared/widgets/loading/loading.dart';
import '../../data/providers/members_providers.dart';
import '../../../messages/presentation/widgets/notification_bell.dart'; // MESSAGES

/// Members page - read-only list of all members for players/helpers
class MembersPage extends ConsumerWidget {
  const MembersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(filteredMembersGroupedProvider);
    final allGroupsAsync = ref.watch(membersGroupedProvider);
    final totalCount = ref.watch(memberCountProvider);
    final searchTerm = ref.watch(membersSearchTermProvider);
    final groupFilter = ref.watch(membersGroupFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mitglieder'),
        actions: const [NotificationBell()], // MESSAGES
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Person suchen...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchTerm.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          ref.read(membersSearchTermProvider.notifier).state = '';
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              onChanged: (value) {
                ref.read(membersSearchTermProvider.notifier).state = value;
              },
            ),
          ),

          // Group filter chips
          allGroupsAsync.whenOrNull(
            data: (allGroups) {
              if (allGroups.length <= 1) return null;
              return SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: AppDimensions.paddingS),
                      child: FilterChip(
                        label: const Text('Alle'),
                        selected: groupFilter == null,
                        onSelected: (_) {
                          ref.read(membersGroupFilterProvider.notifier).state = null;
                        },
                      ),
                    ),
                    ...allGroups.map((g) => Padding(
                          padding: const EdgeInsets.only(right: AppDimensions.paddingS),
                          child: FilterChip(
                            label: Text(g.groupName),
                            selected: groupFilter == g.groupId,
                            onSelected: (_) {
                              ref.read(membersGroupFilterProvider.notifier).state =
                                  groupFilter == g.groupId ? null : g.groupId;
                            },
                          ),
                        )),
                  ],
                ),
              );
            },
          ) ?? const SizedBox.shrink(),
          const SizedBox(height: AppDimensions.paddingS),

          // Members list
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(membersGroupedProvider);
                await ref.read(membersGroupedProvider.future);
              },
              child: groupsAsync.when(
                loading: () => const GroupedListSkeleton(),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: AppColors.danger),
                      const SizedBox(height: AppDimensions.paddingM),
                      Text(
                        'Fehler beim Laden',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppDimensions.paddingL),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(membersGroupedProvider),
                        child: const Text('Erneut versuchen'),
                      ),
                    ],
                  ),
                ),
                data: (groups) {
                  if (groups.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.group_off_outlined,
                            size: 64,
                            color: AppColors.medium,
                          ),
                          const SizedBox(height: AppDimensions.paddingM),
                          Text(
                            searchTerm.isNotEmpty
                                ? 'Keine Ergebnisse'
                                : 'Keine Mitglieder',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (searchTerm.isNotEmpty) ...[
                            const SizedBox(height: AppDimensions.paddingS),
                            Text(
                              'Keine Mitglieder für "$searchTerm" gefunden.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.medium,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.paddingM,
                    ),
                    // +1 for header, +1 for card wrapper (contains all groups), +1 for footer
                    itemCount: 3,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        // Header with total count
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppDimensions.paddingS,
                          ),
                          child: Text(
                            'Personen ($totalCount)',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: AppColors.medium,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        );
                      }
                      if (index == 2) {
                        // Footer spacing
                        return const SizedBox(height: AppDimensions.paddingL);
                      }
                      // Groups card
                      return Card(
                        margin: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (int i = 0; i < groups.length; i++) ...[
                              _GroupSection(
                                key: ValueKey(groups[i].groupName),
                                group: groups[i],
                              ),
                              if (i < groups.length - 1)
                                const Divider(height: 1),
                            ],
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section for a single group with its members
class _GroupSection extends StatelessWidget {
  const _GroupSection({super.key, required this.group});

  final MembersGroup group;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingM,
            vertical: AppDimensions.paddingS,
          ),
          color: AppColors.primary.withValues(alpha: 0.05),
          child: Text(
            '${group.groupName} (${group.members.length})',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
          ),
        ),

        // Members
        for (final member in group.members)
          _MemberTile(key: ValueKey(member.id), person: member),
      ],
    );
  }
}

/// Single member tile
class _MemberTile extends StatelessWidget {
  const _MemberTile({super.key, required this.person});

  final Person person;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Row(
        children: [
          Expanded(
            child: Text(
              person.fullName,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          if (person.isLeader)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Sf',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
