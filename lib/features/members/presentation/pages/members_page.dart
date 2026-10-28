import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/profile_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/person/person.dart';
import '../../data/providers/members_providers.dart';
import '../../../messages/presentation/widgets/notification_bell.dart'; // MESSAGES

/// Members page - read-only list of all members for players/helpers
/// (Ionic people/members: searchbar, optional "Einteilung" segment,
/// "Personen (n)" header, primary group dividers, "Stimmführer" badge).
class MembersPage extends ConsumerWidget {
  const MembersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(filteredMembersGroupedProvider);
    final searchTerm = ref.watch(membersSearchTermProvider);
    final einteilungOptions = ref.watch(membersEinteilungOptionsProvider);
    final einteilung = ref.watch(membersEinteilungFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mitglieder'),
        actions: const [NotificationBell()], // MESSAGES
      ),
      body: Column(
        children: [
          // ion-searchbar
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.paddingM,
              AppDimensions.paddingS,
              AppDimensions.paddingM,
              AppDimensions.paddingS,
            ),
            child: SearchBar(
              hintText: 'Person suchen...',
              elevation: const WidgetStatePropertyAll(0),
              leading: const Icon(Icons.search),
              trailing: [
                if (searchTerm.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => ref.read(membersSearchTermProvider.notifier).state = '',
                  ),
              ],
              onChanged: (value) => ref.read(membersSearchTermProvider.notifier).state = value,
            ),
          ),

          // ion-segment (scrollable) on the "einteilung" extra field
          if (einteilungOptions.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
                children: [
                  for (final option in ['all', ...einteilungOptions])
                    _SegmentTab(
                      label: option == 'all' ? 'Alle' : option,
                      selected: einteilung == option,
                      onTap: () => ref.read(membersEinteilungFilterProvider.notifier).state = option,
                    ),
                ],
              ),
            ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(membersGroupedProvider);
                ref.invalidate(personExtraFieldsProvider);
                await ref.read(membersGroupedProvider.future);
              },
              child: groupsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    _NoData(text: 'Mitglieder konnten nicht geladen werden.'),
                  ],
                ),
                data: (groups) {
                  final count = groups.fold<int>(0, (sum, g) => sum + g.members.length);
                  if (count == 0) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [_NoData(text: 'Keine Mitglieder gefunden.')],
                    );
                  }

                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: AppDimensions.paddingL),
                    children: [
                      // ion-list-header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppDimensions.paddingM,
                          AppDimensions.paddingM,
                          AppDimensions.paddingM,
                          AppDimensions.paddingS,
                        ),
                        child: Text(
                          'Personen ($count)',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      for (final group in groups) ...[
                        _GroupDivider(label: '${group.groupName} (${group.members.length})'),
                        for (final member in group.members)
                          _MemberTile(key: ValueKey(member.id), person: member),
                      ],
                    ],
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

/// Ionic `ion-segment-button` look: label with an underline when selected.
class _SegmentTab extends StatelessWidget {
  const _SegmentTab({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.medium;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: selected ? AppColors.primary : Colors.transparent, width: 2),
          ),
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.5),
        ),
      ),
    );
  }
}

/// Ionic `ion-item-divider color="primary"`.
class _GroupDivider extends StatelessWidget {
  const _GroupDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      color: AppColors.primary,
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Ionic `.no-data-message`: people icon + text.
class _NoData extends StatelessWidget {
  const _NoData({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: AppDimensions.paddingL),
      child: Column(
        children: [
          const Icon(Icons.people_outline, size: 64, color: AppColors.medium),
          const SizedBox(height: AppDimensions.paddingM),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.medium)),
        ],
      ),
    );
  }
}

/// Single member row (name + "Stimmführer" badge).
class _MemberTile extends StatelessWidget {
  const _MemberTile({super.key, required this.person});

  final Person person;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          title: Text(person.fullName),
          trailing: person.isLeader
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Stimmführer',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                )
              : null,
        ),
        const Divider(height: 1, indent: AppDimensions.paddingM),
      ],
    );
  }
}
