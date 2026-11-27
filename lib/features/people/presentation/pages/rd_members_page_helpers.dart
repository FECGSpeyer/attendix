part of 'rd_members_page.dart';

extension _RdMembersPageHelpers on _RdMembersPageState {
  /// The active filters above the list, each removable with a tap.
  List<Widget> _activeChips(
    BuildContext context, {
    required RdMembersListFilter listFilter,
    required bool byGroup,
    required bool criticalOnly,
    required List<Group> groups,
    required List<ExtraField> fields,
    required List<Church> churches,
    required List<Tenant> linkedTenants,
  }) {
    final l10n = context.l10n;
    final kind = ref.watch(rdGroupKindProvider);
    void set(RdMembersListFilter f) => ref.read(rdMembersListFilterProvider.notifier).state = f;
    Widget chip(String label, VoidCallback onRemove) => RdRemovableChip(
          label: label,
          semanticLabel: l10n.redesignMembersFilterRemove(label),
          onRemove: onRemove,
        );
    return [
      if (listFilter.sort != RdMembersSort.group)
        RdRemovableChip(
          label: rdMembersSortLabel(l10n, listFilter.sort, kind),
          semanticLabel: l10n.redesignWorksSortRemove(rdMembersSortLabel(l10n, listFilter.sort, kind)),
          onRemove: () => set(listFilter.copyWith(sort: RdMembersSort.group)),
        ),
      // Split by group instead of category (a view, so not counted).
      if (byGroup && listFilter.sort == RdMembersSort.group)
        RdRemovableChip(
          key: const Key('rd-members-by-register-chip'),
          label: l10n.redesignMembersByGroupChip(kind),
          semanticLabel: l10n.redesignWorksSortRemove(l10n.redesignMembersByGroupChip(kind)),
          onRemove: () => ref.read(rdMembersByCategoryProvider.notifier).set(true),
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
      RdMembersSort.birthdayAsc || RdMembersSort.birthdayDesc => person.birthday,
      RdMembersSort.nextBirthday => person.correctBirthday ? person.birthday : null,
      RdMembersSort.joinedAsc || RdMembersSort.joinedDesc => person.joined,
      _ => null,
    };
    final parsed = DateTime.tryParse(date ?? '');
    if (parsed == null) return null;
    return DateFormat.yMd(currentIntlLocale()).format(parsed);
  }

  /// Desktop "+": a new person or an invitation link, as a menu at the
  /// button (one entry: straight to it).
  /// "•••" of the leads: the Verwaltung entries that act on the members.
  Future<void> _more() async {
    final l10n = context.l10n;
    final hasOrgOthers = ref.read(linkedTenantsProvider).valueOrNull?.isNotEmpty ?? false;
    final entry = await showAppActionSheet<Object>(
      context,
      actions: [
        for (final e in const [
          RdManageEntry.statistics,
          RdManageEntry.bulkMembers,
          RdManageEntry.groups,
          RdManageEntry.critical,
          RdManageEntry.archive,
          RdManageEntry.export,
        ])
          AppActionSheetAction<Object>(
            value: e,
            icon: rdManageIcon(e),
            label: rdManageTitle(l10n, e, kind: ref.read(rdGroupKindProvider)),
          ),
        if (hasOrgOthers)
          AppActionSheetAction<Object>(
            value: 'handover',
            icon: Icons.swap_horiz,
            label: l10n.rdOrgHandover,
          ),
      ],
    );
    if (entry == null || !mounted) return;
    if (entry == 'handover') {
      await context.push('/settings/handover');
    } else if (entry == RdManageEntry.bulkMembers) {
      _setSelecting(true);
    } else if (entry == RdManageEntry.archive) {
      // Stays in this tab ("‹ Mitglieder"), not in Ich › Verwaltung.
      ref.read(rdManageRecentProvider.notifier).push(entry as RdManageEntry);
      await context.push(RedesignRoutes.membersArchive);
    } else if (entry is RdManageEntry) {
      rdOpenManageEntry(context, ref, entry);
    }
  }

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
    // No title: it only repeated the first entry.
    final action = await showAppActionSheet<String>(
      context,
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
        onChanged: (v) => _update(() => _query = v),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: l10n.redesignMembersSearch(ref.watch(rdGroupKindProvider)),
          prefixIcon: Icon(Icons.search, color: p.text2),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close, color: p.text2),
                  tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                  onPressed: () => _update(() {
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
    final sections = rdMemberSections(shown, groups: groups, percentages: const {}, noGroupLabel: l10n.rdWordsNoGroup(ref.watch(rdGroupKindProvider)));
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
              onChanged: (v) => _update(() => _einteilung = v),
            ),
          ),
          const SizedBox(height: 16),
          RdSwipeSwitch<String>(
            values: values,
            selected: einteilung,
            onChanged: (v) => _update(() => _einteilung = v),
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
