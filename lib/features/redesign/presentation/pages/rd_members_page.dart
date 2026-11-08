import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/attendance_providers.dart';
import '../../../../core/providers/church_providers.dart';
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/player_absence_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/profile_providers.dart';
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_palette.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../data/models/church/church.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/player_absence/player_absence.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../data/repositories/shared_person_fields.dart' show mergeSharedPersonFieldValues;
import '../../../../l10n/l10n.dart';
import '../../data/providers/rd_members_providers.dart';
import '../../data/rd_members_list_filter.dart';
import '../../data/rd_members_logic.dart';
import '../../../members/data/providers/members_providers.dart' show membersEinteilungOptionsProvider;
import '../../../people/people_list_utils.dart' show withExtraFieldDefaults;
import '../../../../shared/widgets/adaptive/app_action_sheet.dart';
import '../widgets/members/rd_invite_sheet.dart';
import '../widgets/members/rd_members_filter_sheet.dart';
import '../widgets/rd_split_view.dart';
import '../widgets/rd_widgets.dart';
import '../widgets/today/rd_today_common.dart' show RdInfoCard;

/// REDESIGN: tab "Mitglieder" (canvas "Menschen"). Dirigent and Beobachter:
/// Aktiv / Pausiert / Wartet (also by swiping the list), search, registers
/// with Ø attendance, birthdays and absences in the rows. Spieler, Helfer
/// and Stimmführer (old `/members`) get the same page read-only: search,
/// "Einteilung" (Nord / Süd …) instead of Aktiv / Pausiert, names and the
/// Stimmführung tag only, no numbers and no person pages.
class RdMembersPage extends ConsumerStatefulWidget {
  const RdMembersPage({super.key});

  @override
  ConsumerState<RdMembersPage> createState() => _RdMembersPageState();
}

class _RdMembersPageState extends ConsumerState<RdMembersPage> {
  RdMembersFilter _filter = RdMembersFilter.active;
  String _query = '';

  /// Read-only list: selected "Einteilung" ('' = all).
  String _einteilung = '';

  /// Thumb of Aktiv / Pausiert / Wartet while swiping the list.
  /// Notifier so only the segmented control rebuilds while swiping, not
  /// the whole page with every row.
  final _swipePos = ValueNotifier<double?>(null);
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    // DB_REVIEW_REST (F3) like the old list: admins/responsibles lift
    // expired pauses (paused_until reached) when opening the list.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndUnpause());
  }

  Future<void> _checkAndUnpause() async {
    if (!mounted) return;
    final role = ref.read(effectiveRoleProvider);
    if (!role.canSeePeopleTab || !(role.isAdmin || role.isResponsible)) return;
    final repo = ref.read(playerRepositoryWithTenantProvider);
    if (!repo.hasTenantId) return;
    try {
      await repo.checkAndUnpausePlayers();
    } catch (_) {
      return;
    }
    if (mounted) ref.invalidate(realtimePlayersProvider);
  }

  @override
  void dispose() {
    _search.dispose();
    _swipePos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(effectiveRoleProvider);
    if (!role.canSeePeopleTab) return _readOnly(context);
    final p = context.rd;
    final l10n = context.l10n;
    final inSplit = RdSplitScope.of(context) != null;
    final canApprove = role.isAdmin || role.isResponsible;
    final peopleAsync = ref.watch(realtimePlayersProvider);
    final rawPeople = peopleAsync.valueOrNull ?? const <Person>[];
    final rawPending = canApprove
        ? ref.watch(realtimePendingPlayersProvider).valueOrNull ?? const <Person>[]
        : const <Person>[];
    final percentages = ref.watch(playerAttendancePercentagesProvider).valueOrNull ?? const <int, int>{};
    final groups = ref.watch(groupsProvider).valueOrNull ?? const [];
    final absences = ref.watch(playerAbsencesProvider).valueOrNull ?? const <PlayerAbsence>[];

    // "Sortieren & Filtern" (old list: filter, sort; plus groups).
    final listFilter = ref.watch(rdMembersListFilterProvider);
    final tenant = ref.watch(currentTenantProvider);
    final vos = tenant?.shortName == 'VoS';
    final general = tenant?.type == 'general';
    final fields = ref.watch(personListExtraFieldsProvider).where(rdMembersFilterableField).toList();
    final hasChurch = fields.any((f) => f.type == 'bfecg_church');
    final churches = hasChurch ? ref.watch(churchesProvider).valueOrNull ?? const [] : const <Church>[];
    final linkedTenants = ref.watch(allLinkedTenantsProvider).valueOrNull ?? const [];
    final otherIds = listFilter.otherTenantId == null
        ? null
        : ref.watch(rdOtherInstanceUserIdsProvider(listFilter.otherTenantId!)).valueOrNull;
    // Extra field filters see the old list's values: shared organisation
    // values, then the field defaults (Ionic getModifiedPlayersForList).
    List<Person> prepared(List<Person> list) {
      if (listFilter.fields.isEmpty) return list;
      final shared = ref.watch(sharedPersonFieldValuesProvider).valueOrNull ?? const {};
      return withExtraFieldDefaults(
        mergeSharedPersonFieldValues(list, shared),
        fields,
        churchIds: [for (final c in churches) if (c.id != null) c.id!],
      );
    }

    final allPeople = prepared(rawPeople);
    final allPending = prepared(rawPending);
    List<Person> apply(List<Person> list, RdMembersListFilter f, Set<String>? ids) =>
        rdFilterMembers(list, f, otherInstanceUserIds: ids);
    final people = apply(allPeople, listFilter, otherIds);
    final pending = apply(allPending, listFilter, otherIds);

    final active = people.where((x) => !x.paused).toList();
    final paused = people.where((x) => x.paused).toList();
    final filter = _filter == RdMembersFilter.pending && rawPending.isEmpty ? RdMembersFilter.active : _filter;
    final filters = [
      RdMembersFilter.active,
      RdMembersFilter.paused,
      if (rawPending.isNotEmpty) RdMembersFilter.pending,
    ];
    // UX D3: "Fehlen oft · N" narrows Aktiv to the critical members.
    final critical = rdCriticalMembers(active);
    // An empty filter stays on (shows nobody) instead of silently showing all.
    final criticalOnly = filter == RdMembersFilter.active && ref.watch(rdMembersCriticalOnlyProvider);
    final shown = switch (filter) {
      RdMembersFilter.active => criticalOnly ? critical : active,
      RdMembersFilter.paused => paused,
      RdMembersFilter.pending => pending,
    };

    // Another sort than by group: one list without register headers.
    final sections = listFilter.sort == RdMembersSort.group
        ? rdMemberSections(
            shown,
            groups: groups,
            percentages: percentages,
            noGroupLabel: l10n.attendanceNoGroup,
          )
        : [
            if (shown.isNotEmpty)
              RdMemberSection(
                title: '',
                people: rdSortMembers(shown, listFilter.sort, percentages: percentages),
                isRegister: true,
              ),
          ];
    final filterCount = listFilter.count + (criticalOnly ? 1 : 0);
    final filtering = filterCount > 0;
    void resetFilters() {
      ref.read(rdMembersListFilterProvider.notifier).state = listFilter.clearFilters();
      ref.read(rdMembersCriticalOnlyProvider.notifier).state = false;
    }

    // Groups to filter by: those with someone in the (unfiltered) lists.
    final usedGroups = {for (final x in [...allPeople, ...allPending]) x.instrument};
    void openFilter() => showRdMembersFilterSheet(
          context,
          countFor: (f, critical, ids) {
            final base = switch (filter) {
              RdMembersFilter.active => allPeople.where((x) => !x.paused),
              RdMembersFilter.paused => allPeople.where((x) => x.paused),
              RdMembersFilter.pending => allPending,
            };
            var list = apply(base.toList(), f, ids);
            if (critical && filter == RdMembersFilter.active) list = rdCriticalMembers(list);
            return list.where((x) => rdPersonMatches(x, _query, register: x.groupName)).length;
          },
          groups: [for (final g in groups) if (usedGroups.contains(g.id)) g],
          fields: fields,
          churches: churches,
          linkedTenants: linkedTenants,
          vos: vos,
          general: general,
          withCritical: filter == RdMembersFilter.active,
        );
    final filtered = [
      for (final s in sections)
        if (s.people.any((x) => rdPersonMatches(x, _query, register: s.title)))
          RdMemberSection(
            title: s.title,
            people: s.people.where((x) => rdPersonMatches(x, _query, register: s.title)).toList(),
            average: s.average,
            isRegister: s.isRegister,
          ),
    ];

    final children = <Widget>[
      Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(l10n.redesignTabMembers, style: RdType.largeTitle(p)),
            ),
          ),
          // UX D1: invite right here (Dirigent, Verantwortlich). On desktop
          // it is part of the one "+" in the header.
          if (canApprove && !inSplit) ...[
            RdPillButton(
              icon: Icons.person_add_alt_outlined,
              label: l10n.redesignInviteButton,
              onPressed: () => showRdInviteSheet(context),
            ),
            const SizedBox(width: 8),
          ],
          if (canApprove)
            RdCircleButton(
              icon: Icons.bar_chart_rounded,
              label: l10n.redesignMembersStats,
              onPressed: () => context.push(RedesignRoutes.stats),
            ),
          if (inSplit && (role.canEdit || canApprove)) ...[
            const SizedBox(width: 8),
            Builder(
              builder: (button) => RdCircleButton(
                key: const Key('rd-members-add'),
                icon: Icons.add,
                label: l10n.redesignMembersAdd,
                primary: true,
                onPressed: () => _add(button, canCreate: role.canEdit, canInvite: canApprove),
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 12),
      _searchField(context),
      const SizedBox(height: 12),
      ValueListenableBuilder<double?>(
        valueListenable: _swipePos,
        builder: (context, pos, _) => RdSegmented<RdMembersFilter>(
          values: filters,
          selected: filter,
          position: pos,
          labelOf: (f) => switch (f) {
            RdMembersFilter.active => l10n.redesignMembersActive(active.length),
            RdMembersFilter.paused => l10n.redesignMembersPaused(paused.length),
            RdMembersFilter.pending => l10n.redesignMembersPending(pending.length),
          },
          onChanged: (f) => setState(() => _filter = f),
        ),
      ),
      const SizedBox(height: 6),
      Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  for (final chip in _activeChips(
                    context,
                    listFilter: listFilter,
                    criticalOnly: criticalOnly,
                    groups: groups,
                    fields: fields,
                    churches: churches,
                    linkedTenants: linkedTenants,
                  )) ...[chip, const SizedBox(width: 8)],
                  // UX D3: quick "Fehlen oft · N" while nothing is filtered.
                  if (!filtering && filter == RdMembersFilter.active && critical.isNotEmpty)
                    RdChoiceChip(
                      label: l10n.redesignMembersCritical(critical.length),
                      selected: false,
                      onTap: () => ref.read(rdMembersCriticalOnlyProvider.notifier).state = true,
                    ),
                ],
              ),
            ),
          ),
          RdFilterLink(
            key: const Key('rd-members-filter'),
            label: filtering ? '${l10n.redesignWorksFilter} · $filterCount' : l10n.redesignWorksFilter,
            onTap: openFilter,
          ),
        ],
      ),
      const SizedBox(height: 10),
    ];

    final body = <Widget>[];
    if (peopleAsync.isLoading && people.isEmpty) {
      body.add(RdInfoCard(text: l10n.redesignTodayLoading, loading: true));
    } else if (peopleAsync.hasError && people.isEmpty) {
      body.add(RdInfoCard(
        text: l10n.redesignTodayLoadFailed,
        icon: Icons.cloud_off_outlined,
        action: RdOutlineButton(
          label: l10n.redesignCommonRetry,
          onPressed: () => ref.invalidate(realtimePlayersProvider),
        ),
      ));
    } else if (filtered.isEmpty && rawPeople.isEmpty && _query.trim().isEmpty && canApprove) {
      // UX D1: a new group starts with the invitation.
      body.add(RdInfoCard(
        icon: Icons.people_outline,
        text: l10n.redesignInviteEmptyMembers,
        action: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RdPrimaryButton(
              label: l10n.redesignInviteButton,
              icon: Icons.person_add_alt_outlined,
              onPressed: () => showRdInviteSheet(context),
            ),
            if (role.canEdit) ...[
              const SizedBox(height: 8),
              RdOutlineButton(
                label: l10n.redesignInviteAddPerson,
                onPressed: () => context.push(RedesignRoutes.personNew),
              ),
            ],
          ],
        ),
      ));
    } else if (filtered.isEmpty) {
      body.add(RdInfoCard(
        icon: Icons.people_outline,
        text: filtering
            ? l10n.redesignMembersFilterNoMatch
            : _query.trim().isNotEmpty
                ? l10n.redesignMembersNoMatch
                : switch (filter) {
                    RdMembersFilter.active => l10n.redesignMembersEmpty,
                    RdMembersFilter.paused => l10n.redesignMembersEmptyPaused,
                    RdMembersFilter.pending => l10n.redesignMembersEmptyPending,
                  },
        action: filtering
            ? RdOutlineButton(label: l10n.redesignWorksResetFilter, onPressed: resetFilters)
            : null,
      ));
    } else {
      if (filter == RdMembersFilter.pending) {
        body.add(Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Text(l10n.redesignMembersPendingHint, style: RdType.meta(p, size: 13)),
        ));
      }
      for (final s in filtered) {
        if (s.title.isNotEmpty) body.add(_SectionHeader(section: s));
        body.add(RdGroupedList(children: [
          for (final person in s.people)
            _MemberRow(
              person: person,
              showGroup: s.isRegister,
              sortHint: _sortHint(person, listFilter.sort),
              percent: filter == RdMembersFilter.pending || person.id == null ? null : percentages[person.id],
              absence: person.id == null ? null : rdCurrentAbsence(absences, person.id!),
              selected: person.id != null && RdSplitScope.of(context)?.selectedId == person.id,
              onTap: person.id == null
                  ? null
                  : () => filter == RdMembersFilter.pending
                      ? context.push(RedesignRoutes.approvalReview(person.id!))
                      : RdSplitScope.open(context, RedesignRoutes.person(person.id!)),
            ),
        ]));
        body.add(const SizedBox(height: 18));
      }
    }

    children.add(RdSwipeSwitch<RdMembersFilter>(
      values: filters,
      selected: filter,
      onChanged: (f) => setState(() => _filter = f),
      onDrag: (pos) => _swipePos.value = pos,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: body),
    ));

    return RdPage(
      onRefresh: () async {
        ref.invalidate(realtimePlayersProvider);
        ref.invalidate(playerAttendancePercentagesProvider);
        ref.invalidate(playerAbsencesProvider);
        if (canApprove) ref.invalidate(realtimePendingPlayersProvider);
      },
      floatingActionButton: role.canEdit && !inSplit
          ? FloatingActionButton(
              tooltip: l10n.redesignMembersAdd,
              backgroundColor: p.primary,
              foregroundColor: p.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              onPressed: () => context.push(RedesignRoutes.personNew),
              child: const Icon(Icons.person_add_alt_1_outlined, size: 26),
            )
          : null,
      children: children,
    );
  }

  /// The active filters above the list, each removable with a tap.
  List<Widget> _activeChips(
    BuildContext context, {
    required RdMembersListFilter listFilter,
    required bool criticalOnly,
    required List<Group> groups,
    required List<ExtraField> fields,
    required List<Church> churches,
    required List<Tenant> linkedTenants,
  }) {
    final l10n = context.l10n;
    void set(RdMembersListFilter f) => ref.read(rdMembersListFilterProvider.notifier).state = f;
    Widget chip(String label, VoidCallback onRemove) => RdRemovableChip(
          label: label,
          semanticLabel: l10n.redesignMembersFilterRemove(label),
          onRemove: onRemove,
        );
    return [
      if (listFilter.sort != RdMembersSort.group)
        RdRemovableChip(
          label: rdMembersSortLabel(l10n, listFilter.sort),
          semanticLabel: l10n.redesignWorksSortRemove(rdMembersSortLabel(l10n, listFilter.sort)),
          onRemove: () => set(listFilter.copyWith(sort: RdMembersSort.group)),
        ),
      if (criticalOnly)
        chip(l10n.redesignMembersFilterCritical, () => ref.read(rdMembersCriticalOnlyProvider.notifier).state = false),
      for (final o in RdMembersOnly.values)
        if (listFilter.only.contains(o)) chip(rdMembersOnlyLabel(l10n, o), () => set(listFilter.toggleOnly(o))),
      for (final g in groups)
        if (listFilter.groupIds.contains(g.id)) chip(g.name, () => set(listFilter.toggleGroup(g.id!))),
      for (final e in listFilter.fields.entries)
        if (fields.where((f) => f.id == e.key).firstOrNull case final field?)
          chip(
            l10n.redesignMembersFilterField(field.name, rdMembersFieldValueLabel(l10n, field, e.value, churches)),
            () => set(listFilter.withField(e.key, null)),
          ),
      if (listFilter.otherTenantId != null)
        chip(
          l10n.redesignMembersFilterOtherChip(
            linkedTenants.where((t) => t.id == listFilter.otherTenantId).map((t) => t.shortName).firstOrNull ?? '…',
          ),
          () => set(listFilter.copyWith(otherTenantId: () => null)),
        ),
    ];
  }

  /// Birthday or joining date in the row while the list is sorted by it.
  String? _sortHint(Person person, RdMembersSort sort) {
    final date = switch (sort) {
      RdMembersSort.birthdayAsc || RdMembersSort.birthdayDesc || RdMembersSort.nextBirthday => person.birthday,
      RdMembersSort.joinedAsc || RdMembersSort.joinedDesc => person.joined,
      _ => null,
    };
    final parsed = DateTime.tryParse(date ?? '');
    if (parsed == null) return null;
    return DateFormat.yMd(currentIntlLocale()).format(parsed);
  }

  /// Desktop "+": a new person or an invitation link, as a menu at the
  /// button (one entry: straight to it).
  Future<void> _add(BuildContext anchor, {required bool canCreate, required bool canInvite}) async {
    final l10n = context.l10n;
    if (!canInvite) {
      await context.push(RedesignRoutes.personNew);
      return;
    }
    if (!canCreate) {
      await showRdInviteSheet(context);
      return;
    }
    final action = await showAppActionSheet<String>(
      context,
      title: l10n.redesignMembersAdd,
      anchor: anchor,
      actions: [
        AppActionSheetAction(value: 'new', icon: Icons.person_add_alt_1_outlined, label: l10n.redesignMembersAdd),
        AppActionSheetAction(value: 'invite', icon: Icons.link, label: l10n.redesignInviteButton),
      ],
    );
    if (!mounted) return;
    switch (action) {
      case 'new':
        await context.push(RedesignRoutes.personNew);
      case 'invite':
        await showRdInviteSheet(context);
    }
  }

  Widget _searchField(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    return TextField(
        controller: _search,
        onChanged: (v) => setState(() => _query = v),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: l10n.redesignMembersSearch,
          prefixIcon: Icon(Icons.search, color: p.text2),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close, color: p.text2),
                  tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                  onPressed: () => setState(() {
                    _search.clear();
                    _query = '';
                  }),
                ),
          filled: true,
          fillColor: p.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(p.buttonRadius),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(p.buttonRadius),
            borderSide: BorderSide.none,
          ),
        ),
      );
  }

  /// Spieler, Helfer, Stimmführer: the same list, read-only (old `/members`).
  Widget _readOnly(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final peopleAsync = ref.watch(realtimePlayersProvider);
    // Like the old list (membersGroupedProvider): a person without an
    // "Einteilung" value counts under the field's default option.
    final people = withExtraFieldDefaults(
      peopleAsync.valueOrNull ?? const <Person>[],
      ref.watch(personListExtraFieldsProvider),
    );
    final groups = ref.watch(groupsProvider).valueOrNull ?? const [];
    final options = ref.watch(membersEinteilungOptionsProvider);
    final einteilung = options.contains(_einteilung) ? _einteilung : '';
    final values = ['', ...options];

    final shown = einteilung.isEmpty ? people : people.where((x) => rdEinteilungOf(x) == einteilung).toList();
    final sections = rdMemberSections(shown, groups: groups, percentages: const {}, noGroupLabel: l10n.attendanceNoGroup);
    final filtered = [
      for (final s in sections)
        if (s.people.any((x) => rdPersonMatches(x, _query, register: s.title)))
          RdMemberSection(
            title: s.title,
            people: s.people.where((x) => rdPersonMatches(x, _query, register: s.title)).toList(),
            isRegister: s.isRegister,
          ),
    ];

    final body = <Widget>[];
    if (peopleAsync.isLoading && people.isEmpty) {
      body.add(RdInfoCard(text: l10n.redesignTodayLoading, loading: true));
    } else if (peopleAsync.hasError && people.isEmpty) {
      body.add(RdInfoCard(
        text: l10n.redesignTodayLoadFailed,
        icon: Icons.cloud_off_outlined,
        action: RdOutlineButton(
          label: l10n.redesignCommonRetry,
          onPressed: () => ref.invalidate(realtimePlayersProvider),
        ),
      ));
    } else if (filtered.isEmpty) {
      body.add(RdInfoCard(
        icon: Icons.people_outline,
        text: _query.trim().isNotEmpty || einteilung.isNotEmpty ? l10n.redesignMembersNoMatch : l10n.redesignMembersEmpty,
      ));
    } else {
      for (final s in filtered) {
        body.add(_SectionHeader(section: s));
        body.add(RdGroupedList(children: [
          for (final person in s.people)
            _MemberRow(
              key: ValueKey('rd-member-${person.id}'),
              person: person,
              showGroup: s.isRegister,
              percent: null,
              absence: null,
              onTap: null,
              readOnly: true,
              einteilung: options.isNotEmpty && einteilung.isEmpty ? rdEinteilungOf(person) : null,
            ),
        ]));
        body.add(const SizedBox(height: 18));
      }
    }

    final list = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: body);
    return RdPage(
      onRefresh: () async {
        ref.invalidate(realtimePlayersProvider);
        ref.invalidate(personExtraFieldsProvider);
      },
      children: [
        Semantics(
          header: true,
          child: Text(l10n.redesignTabMembers, style: RdType.largeTitle(p)),
        ),
        // Ionic "Personen (n)".
        if (people.isNotEmpty) Text(l10n.redesignMembersTotal(people.length), style: RdType.meta(p, size: 15)),
        const SizedBox(height: 12),
        _searchField(context),
        const SizedBox(height: 12),
        if (options.isNotEmpty) ...[
          ValueListenableBuilder<double?>(
            valueListenable: _swipePos,
            builder: (context, pos, _) => RdSegmented<String>(
              values: values,
              selected: einteilung,
              position: pos,
              labelOf: (v) => v.isEmpty ? l10n.redesignCommonAll : v,
              onChanged: (v) => setState(() => _einteilung = v),
            ),
          ),
          const SizedBox(height: 16),
          RdSwipeSwitch<String>(
            values: values,
            selected: einteilung,
            onChanged: (v) => setState(() => _einteilung = v),
            onDrag: (pos) => _swipePos.value = pos,
            child: list,
          ),
        ] else ...[
          const SizedBox(height: 4),
          list,
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.section});

  final RdMemberSection section;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                l10n.redesignMembersSection(section.title, section.people.length).toUpperCase(),
                style: RdType.eyebrow(p.text2),
              ),
            ),
          ),
          if (section.average != null)
            Text(l10n.redesignMembersAverage(section.average!), style: RdType.meta(p, size: 13)),
        ],
      ),
    );
  }
}

/// Color of an attendance percentage (≥ 75 present, ≥ 50 late, else absent).
Color rdPercentColor(RdPalette p, int percent) =>
    percent >= 75 ? p.present : (percent >= 50 ? p.late : p.absent);

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    super.key,
    required this.person,
    required this.showGroup,
    required this.percent,
    required this.absence,
    required this.onTap,
    this.selected = false,
    this.readOnly = false,
    this.einteilung,
    this.sortHint,
  });

  /// Date of the chosen sort order (birthday, joined).
  final String? sortHint;

  /// Spieler/Helfer view: no birthdays, absences, pauses or mail addresses.
  final bool readOnly;

  /// "Nord" / "Süd" while all are shown (read-only view).
  final String? einteilung;

  final Person person;
  final bool showGroup;
  final int? percent;
  final PlayerAbsence? absence;
  final VoidCallback? onTap;

  /// Open on the right of the split view.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final locale = currentIntlLocale();
    final short = DateFormat.Md(locale);
    final name = '${person.firstName} ${person.lastName}'.trim();

    final hints = <String>[
      if (showGroup && (person.groupName ?? '').isNotEmpty) person.groupName!,
      if (einteilung != null) einteilung!,
      if (sortHint != null) sortHint!,
    ];
    final birthdayIn = readOnly ? null : rdDaysToBirthday(person.birthday);
    if (birthdayIn != null && birthdayIn <= 7) {
      hints.add(switch (birthdayIn) {
        0 => l10n.redesignMembersBirthdayToday,
        1 => l10n.redesignMembersBirthdayTomorrow,
        _ => l10n.redesignMembersBirthdayIn(birthdayIn),
      });
    }
    if (readOnly) {
      // Names only, like the old list.
    } else if (person.paused) {
      final until = DateTime.tryParse(person.pausedUntil ?? '');
      if (until != null) hints.add(l10n.redesignMembersPausedUntil(short.format(until)));
    } else if (absence != null) {
      final from = DateTime.tryParse(absence!.fromDate);
      final until = DateTime.tryParse(absence!.untilDate);
      final today = DateTime.now();
      final running = from != null && !from.isAfter(DateTime(today.year, today.month, today.day));
      if (running && until != null) {
        hints.add(l10n.redesignMembersAbsentUntil(short.format(until)));
      } else if (from != null) {
        hints.add(l10n.redesignMembersAbsentFrom(short.format(from)));
      }
    }
    if (!readOnly && person.pending && (person.email ?? '').isNotEmpty) hints.add(person.email!);

    final pct = percent;
    final low = pct != null && pct < 50;
    final color = pct == null ? p.text2 : rdPercentColor(p, pct);

    return Semantics(
      button: onTap != null,
      selected: selected,
      child: Material(
        color: selected ? p.soft : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
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
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.text),
                              ),
                            ),
                            if (person.isLeader) ...[
                              const SizedBox(width: 6),
                              const RdLeaderTag(),
                            ],
                          ],
                        ),
                        if (hints.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              hints.join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: RdType.meta(p, size: 13),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (pct != null) ...[
                    const SizedBox(width: 8),
                    if (low) ...[
                      Icon(Icons.warning_amber_rounded, size: 16, color: color, semanticLabel: l10n.redesignMembersLow),
                      const SizedBox(width: 2),
                    ],
                    Text(
                      l10n.redesignMembersPercent(pct),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: color,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                  if (onTap != null) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 20, color: p.text2),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The "einteilung" value of [person] ("Nord"), null when unset or "-".
String? rdEinteilungOf(Person person) {
  final value = person.additionalFields?['einteilung']?.toString().trim();
  if (value == null || value.isEmpty || value == '-') return null;
  return value;
}
