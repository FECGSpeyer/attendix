part of 'event_page.dart';

extension _RdEventPageRecord on _RdEventPageState {
  /// Pultmodus: the same state, writes and "Rückgängig", drawn as tiles.
  /// Back (gesture or button) returns to the list.
  Widget _pultPage(Attendance attendance, List<RdMember> members, AttendanceType? type) {
    final typeStatuses = type?.availableStatuses;
    final available = (typeStatuses?.isNotEmpty ?? false) ? typeStatuses! : AttendanceStatus.values;
    final canViewNotes = ref.watch(canViewAttendanceNotesProvider);
    final busy = _bulkWrites > 0;
    final title = rdEventInfo(attendance, type).title;
    void leave() => _update(() => _pult = false);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) leave();
      },
      child: Stack(
        children: [
          RdPultView(
            title: title,
            noGroupLabel: context.l10n.rdWordsNoGroup(ref.watch(rdGroupKindProvider)),
            members: members,
            available: available.toSet(),
            showNote: canViewNotes,
            busy: busy,
            bottomPadding: _toast == null ? 24 : 88,
            onToggle: (m) => _setStatus(
              m,
              rdToggleTarget(m.status, AttendanceStatus.present, initial: _initial[m.id]),
            ),
            onMore: (m) => _openStatusSheet(m, available, canViewNotes),
            onAllOpenPresent: () => _allOpenPresent(members.where((m) => m.isOpen).toList()),
            onDone: leave,
          ),
          if (_toast != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                top: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: RdUndoBar(
                      text: _toast!,
                      onUndo: _undo == null || busy ? null : _runUndo,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Persons of the Termin inside the confirmed group scope, in the Termin
  /// page's group order; null while loading.
  List<RdMember>? _members() {
    final rowIds = _rowPersonIds;
    final persons = ref.watch(filteredPersonsForAttendanceProvider(_id)).valueOrNull;
    final groupsAsync = ref.watch(groupsProvider);
    final scopeAsync = ref.watch(attendanceGroupScopeProvider);
    if (rowIds == null || persons == null || (groupsAsync.isLoading && !groupsAsync.hasValue) || scopeAsync.isLoading) {
      return null;
    }
    // SOL_FIX2: loading/error/missing profile group = no access.
    final scope = resolvedGroupScope(scopeAsync);
    final inTermin = persons.where((p) => p.id != null && rowIds.contains(p.id));
    final scoped = scope.isAll ? inTermin.toList() : inTermin.where((p) => scope.allowsGroup(p.instrument)).toList();
    final groups = groupsAsync.valueOrNull ?? const [];
    final sorted = sortPersonsByGroup(
      scoped,
      groups: groups,
      mainGroupId: mainGroupIdOf(groups) ?? ref.watch(mainGroupProvider).valueOrNull?.id,
      usePersonSortOrder: false,
    );
    return [
      for (final Person person in sorted)
        RdMember(
          person: person,
          status: _statuses[person.id] ?? AttendanceStatus.neutral,
          note: _notes[person.id],
          changedAt: _changedAt[person.id],
          changedBy: _changedBy[person.id],
        ),
    ];
  }

  /// Anwesenheit (concept L3): most persons simply are there, so each voice
  /// shows only its exceptions (everyone not "Anwesend", plus whoever was
  /// changed here) and "N weitere anwesend · Zeigen". The search "Wer
  /// fehlt?" and the filter chips show every match.
  List<Widget> _recordChildren(List<RdMember> members, AttendanceType? type) {
    final p = context.rd;
    final l10n = context.l10n;
    final typeStatuses = type?.availableStatuses;
    final available = (typeStatuses?.isNotEmpty ?? false) ? typeStatuses! : AttendanceStatus.values;
    final canViewNotes = ref.watch(canViewAttendanceNotesProvider);
    final canMutate = canMutateAttendanceDetail(ref.watch(effectiveRoleProvider));
    final open = members.where((m) => m.isOpen).toList();
    final busy = _bulkWrites > 0;
    final filter = _filter;
    // Only the exceptions while nothing narrows the list.
    final collapsing = filter == RdRecordFilter.all && _query.trim().isEmpty;

    // Voices in the Termin page's order.
    final groups = <int?, List<RdMember>>{};
    for (final m in members) {
      groups.putIfAbsent(m.person.instrument, () => []).add(m);
    }

    final entries = <({int? group, List<RdMember> list, List<RdMember> shown, int hidden})>[];
    for (final MapEntry(key: group, value: list) in groups.entries) {
      final matching = list.where((m) => rdFilterMatches(filter, m.status) && rdMemberMatches(m, _query)).toList();
      if (matching.isEmpty) continue;
      final expanded = !collapsing || _expanded.contains(group);
      final shown = expanded
          ? matching
          : matching.where((m) => m.status != AttendanceStatus.present || _pinned.contains(m.id)).toList();
      entries.add((group: group, list: list, shown: shown, hidden: matching.length - shown.length));
    }
    final visible = [for (final e in entries) ...e.shown];
    _kbRows = visible;
    _kbAvailable = available;

    final sections = <Widget>[];
    var first = true;
    for (final (:group, :list, :shown, :hidden) in entries) {
      final here = list.where((m) => m.status.countsAsPresent).length;
      sections.add(Padding(
        padding: EdgeInsets.only(top: first ? 0 : 14),
        child: Row(
          children: [
            Expanded(child: RdGroupLabel(list.first.groupName ?? l10n.rdWordsNoGroup(ref.watch(rdGroupKindProvider)))),
            Padding(
              padding: const EdgeInsets.only(right: 4, bottom: 8),
              child: Text(
                l10n.redesignEventRegisterPresent(here, list.length),
                style: RdType.meta(p, size: 13),
              ),
            ),
          ],
        ),
      ));
      first = false;
      final rows = <Widget>[
        for (final m in shown) _recordRow(m, available, canViewNotes),
        if (collapsing && (hidden > 0 || _expanded.contains(group)))
          _MoreRow(
            key: ValueKey('rd-more-$group'),
            text: hidden == 0
                ? null
                : shown.isEmpty
                    ? l10n.redesignEventAllPresent(hidden)
                    : l10n.redesignEventMorePresent(hidden),
            action: hidden == 0 ? l10n.redesignEventHide : l10n.redesignEventShow,
            onTap: () => _update(() => hidden == 0 ? _expanded.remove(group) : _expanded.add(group)),
          ),
      ];
      sections.add(RdCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) Divider(height: 1, thickness: 1, color: p.line),
              rows[i],
            ],
          ],
        ),
      ));
    }

    return [
      TextField(
        key: const Key('rd-record-search'),
        controller: _search,
        onChanged: (v) => _update(() => _query = v),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: l10n.redesignEventRecordSearchHint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  tooltip: l10n.redesignEventSearchClose,
                  icon: const Icon(Icons.close),
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
        ),
      ),
      const SizedBox(height: 12),
      RdRecordFilterChips(
        members: members,
        selected: filter,
        onChanged: (f) => _update(() => _filter = f),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          Tooltip(
            message: l10n.redesignPultOpenHint,
            child: RdPillButton(
              icon: Icons.grid_view_rounded,
              label: l10n.redesignPultOpen,
              onPressed: () => _update(() {
                _pult = true;
                _search.clear();
                _query = '';
              }),
            ),
          ),
          if (canMutate)
            RdPillButton(
              key: const Key('rd-record-add-person'),
              icon: Icons.person_add_alt_1_outlined,
              label: l10n.redesignEventAddPersonShort,
              semanticLabel: l10n.attendanceAddPerson,
              onPressed: _addPersons,
            ),
        ],
      ),
      // Termin-Arten with "offen" (Zusage): everyone without an entry at once.
      if (available.contains(AttendanceStatus.present) && open.isNotEmpty) ...[
        const SizedBox(height: 12),
        RdOutlineButton(
          label: busy ? l10n.redesignEventSaving : l10n.redesignEventAllOpenPresent,
          icon: Icons.done_all,
          color: p.present,
          height: 44,
          onPressed: busy ? null : () => _allOpenPresent(open),
        ),
      ],
      const SizedBox(height: 16),
      if (sections.isEmpty) RdInfoCard(text: l10n.redesignEventNoMatch, icon: Icons.search_off),
      ...sections,
      // Tablets with a keyboard and desktops.
      if (MediaQuery.sizeOf(context).width >= 840 && visible.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text(l10n.redesignEventKeyboardHint, textAlign: TextAlign.center, style: RdType.meta(p, size: 13)),
      ],
    ];
  }

  Widget _recordRow(RdMember m, List<AttendanceStatus> available, bool canViewNotes) {
    final p = context.rd;
    final focused = _kbId == m.id;
    return DecoratedBox(
      key: _rowKeys.putIfAbsent(m.id, GlobalKey.new),
      decoration: BoxDecoration(border: focused ? Border.all(color: p.primary, width: 2) : null),
      child: RdRecordRow(
        key: ValueKey('rd-record-${m.id}'),
        member: m,
        available: available.toSet(),
        showNote: canViewNotes,
        onTap: (s) => _setStatus(m, rdToggleTarget(m.status, s, initial: _initial[m.id])),
        onMore: () => _openStatusSheet(m, available, canViewNotes),
      ),
    );
  }
}
