import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/profile_providers.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../data/models/person/person.dart';
import '../../../../l10n/l10n.dart';
import '../../../members/data/providers/members_providers.dart';
import '../widgets/rd_widgets.dart';
import '../widgets/today/rd_today_common.dart' show RdInfoCard;

/// REDESIGN: tab "Mitglieder" for Spieler, Helfer and Stimmführer (the
/// read-only list of the old `/members` page in the new design): search,
/// the "Einteilung" filter when the group has that field, one card per
/// register and the "Stimmführung" tag. No attendance numbers and no
/// person pages, like the old list.
class RdMemberListPage extends ConsumerStatefulWidget {
  const RdMemberListPage({super.key});

  @override
  ConsumerState<RdMemberListPage> createState() => _RdMemberListPageState();
}

class _RdMemberListPageState extends ConsumerState<RdMemberListPage> {
  late final TextEditingController _search = TextEditingController(text: ref.read(membersSearchTermProvider));

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _setQuery(String value) => ref.read(membersSearchTermProvider.notifier).state = value;

  Future<void> _refresh() async {
    ref.invalidate(membersGroupedProvider);
    ref.invalidate(personExtraFieldsProvider);
    try {
      await ref.read(membersGroupedProvider.future);
    } catch (_) {
      // The page shows the error with "retry".
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final async = ref.watch(filteredMembersGroupedProvider);
    final query = ref.watch(membersSearchTermProvider);
    final options = ref.watch(membersEinteilungOptionsProvider);
    final einteilung = ref.watch(membersEinteilungFilterProvider);
    final selected = options.contains(einteilung) ? einteilung : 'all';
    final groups = async.valueOrNull;
    final count = groups?.fold<int>(0, (sum, g) => sum + g.members.length) ?? 0;

    final children = <Widget>[
      Semantics(header: true, child: Text(l10n.redesignTabMembers, style: RdType.largeTitle(p))),
      if (groups != null && count > 0)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(l10n.redesignMembersTotal(count), style: RdType.meta(p, size: 15)),
        ),
      const SizedBox(height: 12),
      TextField(
        controller: _search,
        onChanged: _setQuery,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: l10n.redesignMembersSearchRead,
          prefixIcon: Icon(Icons.search, color: p.text2),
          suffixIcon:
              query.isEmpty
                  ? null
                  : IconButton(
                    icon: Icon(Icons.close, color: p.text2),
                    tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                    onPressed: () {
                      _search.clear();
                      _setQuery('');
                    },
                  ),
          filled: true,
          fillColor: p.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(p.buttonRadius), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(p.buttonRadius),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      // "Einteilung" (e.g. Nord / Süd): chips instead of the old segment,
      // so long option lists wrap instead of scrolling sideways.
      if (options.isNotEmpty) ...[
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in ['all', ...options])
              RdChoiceChip(
                label: option == 'all' ? l10n.redesignCommonAll : option,
                selected: selected == option,
                onTap: () => ref.read(membersEinteilungFilterProvider.notifier).state = option,
              ),
          ],
        ),
      ],
      const SizedBox(height: 16),
    ];

    if (groups == null) {
      children.add(
        async.hasError
            ? RdInfoCard(
              text: l10n.redesignTodayLoadFailed,
              icon: Icons.cloud_off_outlined,
              action: RdOutlineButton(
                label: l10n.redesignCommonRetry,
                onPressed: () => ref.invalidate(membersGroupedProvider),
              ),
            )
            : RdInfoCard(text: l10n.redesignTodayLoading, loading: true),
      );
    } else if (count == 0) {
      children.add(
        RdInfoCard(
          icon: Icons.people_outline,
          text: query.trim().isNotEmpty || selected != 'all' ? l10n.redesignMembersNoMatch : l10n.redesignMembersEmpty,
        ),
      );
    } else {
      for (final g in groups) {
        final title = g.groupId == -1 ? l10n.attendanceNoGroup : g.groupName;
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Semantics(
              header: true,
              child: Text(
                l10n.redesignMembersSection(title, g.members.length).toUpperCase(),
                style: RdType.eyebrow(p.text2),
              ),
            ),
          ),
        );
        children.add(
          RdGroupedList(
            children: [
              for (final person in g.members)
                RdMemberListRow(
                  key: ValueKey('rd-member-${person.id}'),
                  person: person,
                  einteilung: options.isNotEmpty && selected == 'all' ? rdEinteilungOf(person) : null,
                ),
            ],
          ),
        );
        children.add(const SizedBox(height: 18));
      }
    }

    return RdPage(onRefresh: _refresh, children: children);
  }
}

/// The "einteilung" value of [person] ("Nord"), null when unset or "-".
String? rdEinteilungOf(Person person) {
  final value = person.additionalFields?['einteilung']?.toString().trim();
  if (value == null || value.isEmpty || value == '-') return null;
  return value;
}

/// One person of the read-only member list: initials, name, the
/// "Stimmführung" tag and, while all are shown, the Einteilung.
class RdMemberListRow extends StatelessWidget {
  const RdMemberListRow({super.key, required this.person, this.einteilung});

  final Person person;
  final String? einteilung;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final name = person.fullName.trim();
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            RdInitials(rdInitialsOf(name.isEmpty ? '?' : name)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.text),
                  ),
                  if (einteilung != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(einteilung!, style: RdType.meta(p, size: 13)),
                    ),
                ],
              ),
            ),
            if (person.isLeader) ...[
              const SizedBox(width: 8),
              RdPill(l10n.redesignMembersLeader, tone: RdTone.primary),
            ],
          ],
        ),
      ),
    );
  }
}
