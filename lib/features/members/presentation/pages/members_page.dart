import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/profile_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/person/person.dart';
import '../../data/providers/members_providers.dart';
import '../../../../l10n/l10n.dart';
import '../../../messages/presentation/widgets/notification_bell.dart'; // MESSAGES
import '../../../people/presentation/widgets/ion/ion_widgets.dart'; // UX_PEOPLE

/// Members page - read-only list of all members for players/helpers
/// (Ionic people/members: condensed title, searchbar, optional "Einteilung"
/// segment, "Personen (n)" header, primary group dividers, "Stimmführer"
/// badge). UX_PEOPLE: Ionic iOS look via the people lane ion widgets.
class MembersPage extends ConsumerStatefulWidget {
  const MembersPage({super.key});

  @override
  ConsumerState<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends ConsumerState<MembersPage> {
  late final TextEditingController _searchController =
      TextEditingController(text: ref.read(membersSearchTermProvider));

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(membersGroupedProvider);
    ref.invalidate(personExtraFieldsProvider);
    await ref.read(membersGroupedProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(filteredMembersGroupedProvider);
    final einteilungOptions = ref.watch(membersEinteilungOptionsProvider);
    final einteilung = ref.watch(membersEinteilungFilterProvider);

    return IonPage(
      title: context.l10n.peopleMembers,
      actions: const [NotificationBell()], // MESSAGES
      onRefresh: _refresh,
      slivers: [
        // ion-searchbar
        SliverToBoxAdapter(
          child: IonSearchbar(
            controller: _searchController,
            placeholder: context.l10n.peopleSearchPerson,
            onChanged: (value) =>
                ref.read(membersSearchTermProvider.notifier).state = value,
          ),
        ),

        // ion-segment (scrollable, mode="md") on the "einteilung" extra field
        if (einteilungOptions.isNotEmpty)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
                children: [
                  for (final option in ['all', ...einteilungOptions])
                    _SegmentTab(
                      label: option == 'all' ? context.l10n.commonAll : option,
                      selected: einteilung == option,
                      onTap: () => ref.read(membersEinteilungFilterProvider.notifier).state = option,
                    ),
                ],
              ),
            ),
          ),

        ...groupsAsync.when(
          loading: () => [
            const SliverToBoxAdapter(
              child: SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
          error: (error, stack) => [
            SliverToBoxAdapter(child: _NoData(text: context.l10n.peopleMembersLoadFailed)),
          ],
          data: (groups) {
            final count = groups.fold<int>(0, (sum, g) => sum + g.members.length);
            if (count == 0) {
              return [
                SliverToBoxAdapter(child: _NoData(text: context.l10n.peopleNoMembersFound)),
              ];
            }
            return [
              SliverList.list(
                children: [
                  IonListHeader(text: context.l10n.peoplePeopleCount(count)),
                  for (final group in groups) ...[
                    IonItemDivider(
                      color: AppColors.primary,
                      text: '${group.groupId == -1 ? context.l10n.peopleNoGroupAssigned : group.groupName} (${group.members.length})',
                    ),
                    for (final member in group.members)
                      _MemberTile(key: ValueKey(member.id), person: member),
                  ],
                ],
              ),
            ];
          },
        ),
      ],
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

/// Ionic `.no-data-message`: people icon (48px, 50% opacity) + text,
/// 200px high.
class _NoData extends StatelessWidget {
  const _NoData({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 48, color: AppColors.medium.withValues(alpha: 0.5)),
          const SizedBox(height: AppDimensions.paddingM),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.medium, fontSize: 15.2)),
        ],
      ),
    );
  }
}

/// Single member row: ion-item with name and "Stimmführer" badge.
class _MemberTile extends StatelessWidget {
  const _MemberTile({super.key, required this.person});

  final Person person;

  @override
  Widget build(BuildContext context) {
    return IonItem(
      end: [
        if (person.isLeader)
          IonBadge(text: context.l10n.peopleVoiceLeader, color: AppColors.primary),
      ],
      child: Text(person.fullName, style: IonText.h2(context)),
    );
  }
}
