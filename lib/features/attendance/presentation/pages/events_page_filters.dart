part of 'events_page.dart';

/// Header controls, search/type filters, segment switchers, and pending
/// notification navigation for [RdEventsPage].
extension _RdEventsFilters on _RdEventsPageState {
  bool _matches(String title, String? place) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return title.toLowerCase().contains(q) || (place ?? '').toLowerCase().contains(q);
  }

  Widget _buildHeader(
    BuildContext context, {
    required bool canReportAbsence,
    required Person? player,
    required List<CurrentSongsGroup> songs,
    required bool canCreate,
    required bool inSplit,
  }) {
    final p = context.rd;
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(l10n.redesignTabEvents, style: RdType.largeTitle(p)),
          ),
        ),
        if (canReportAbsence) ...[
          RdPillButton(
            icon: Icons.event_busy_outlined,
            label: l10n.redesignEventsAbsent,
            onPressed: () => showRdAbsenceSheet(
              context,
              ref,
              player!,
              canSelfPause: ref.read(canSelfPauseProvider),
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (songs.isNotEmpty) ...[
          RdCircleButton(
            icon: Icons.music_note_outlined,
            label: l10n.selfServiceShowCurrentSongs,
            onPressed: () => showCurrentSongsSheet(context, songs),
          ),
          const SizedBox(width: 8),
        ],
        RdCircleButton(
          icon: _searching ? Icons.close : Icons.search,
          label: _searching ? l10n.redesignEventsSearchClose : l10n.redesignEventsSearch,
          onPressed: () => _update(() {
            _searching = !_searching;
            if (!_searching) {
              _search.clear();
              _query = '';
            }
          }),
        ),
        if (inSplit && _orgSegmentActive()) ...[
          const SizedBox(width: 8),
          const RdOrgPlanAddButton(compact: true),
        ] else if (canCreate && inSplit) ...[
          const SizedBox(width: 8),
          const RdEventCreateMenu(compact: true),
        ],
      ],
    );
  }

  Widget _buildSearchField(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    return TextField(
      controller: _search,
      autofocus: true,
      onChanged: (v) => _update(() => _query = v),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: l10n.redesignEventsSearchHint,
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: p.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(p.buttonRadius),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildTypeFilterChips(BuildContext context, List<AttendanceType> types) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          RdChoiceChip(
            label: l10n.redesignCommonAll,
            selected: _type == null,
            onTap: () => _update(() => _type = null),
          ),
          for (final t in types) ...[
            const SizedBox(width: 8),
            RdChoiceChip(
              label: t.name,
              selected: _type == t.id,
              onTap: () => _update(() => _type = _type == t.id ? null : t.id),
            ),
          ],
        ],
      ),
    );
  }

  /// Own upcoming Termine of Helfer in this group by attendance id, for the
  /// "Du ✓" chips of the leader list.
  Map<int, CrossTenantPersonAttendance> _ownByAttendance() {
    final data = ref.watch(rdSignoutDataProvider).valueOrNull;
    final tenantId = ref.watch(currentTenantProvider)?.id;
    if (data == null || tenantId == null) return const {};
    return {
      for (final att in data.allUpcoming)
        if (att.isMember && att.tenantId == tenantId && att.attendanceId != null && att.id != null)
          att.attendanceId!: att,
    };
  }

  void _setSegment(RdEventsSegment segment) => _update(() {
    _segment = segment;
    _onlyOpen = false;
  });

  void _setPast(bool past) => _setSegment(past ? RdEventsSegment.past : RdEventsSegment.upcoming);

  Widget _segments(BuildContext context, {required String pastLabel}) {
    final l10n = context.l10n;
    return ValueListenableBuilder<double?>(
      valueListenable: _swipePos,
      builder: (context, pos, _) => RdSegmented<bool>(
        values: const [false, true],
        selected: _past,
        position: pos,
        labelOf: (past) => past ? pastLabel : l10n.redesignEventsUpcoming,
        onChanged: _setPast,
      ),
    );
  }

  /// Swipe between Kommend and Vergangen (the segments stay the main way).
  Widget _swipe(Widget child) => RdSwipeSwitch<bool>(
    values: const [false, true],
    selected: _past,
    onChanged: _setPast,
    onDrag: (pos) => _swipePos.value = pos,
    child: child,
  );

  /// Opens the Termin a notification asked for (`pendingAttendanceId`)
  /// once the own Termine are loaded.
  void _openPending(SignoutData data, SelfServiceEventActions actions) {
    final pendingId = ref.read(pendingAttendanceIdProvider);
    if (pendingId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ref.read(pendingAttendanceIdProvider) != pendingId) return;
      final source = ref.read(signoutDataProvider);
      final shown = ref.read(rdSignoutDataProvider);
      if (source.isLoading || shown.isLoading || source.hasError || shown.hasError) return;
      ref.read(pendingAttendanceIdProvider.notifier).state = null;
      final all = source.valueOrNull ?? data;
      final att = [...all.allUpcoming, ...all.past].where((a) => a.attendanceId == pendingId).firstOrNull;
      if (att == null) {
        ToastHelper.showInfo(context, context.l10n.redesignEventNotFound);
        return;
      }
      if (isUnassignedDutyAttendance(att)) {
        showOpenDutiesSheet(context);
        return;
      }
      final own = actions.isOwn(att);
      final listed = [...data.allUpcoming, ...data.past].any((a) => a.id == att.id);
      if (att.id != null && own && listed) {
        context.push(RedesignRoutes.ownEvent(att.id!));
      } else {
        actions.presentActions(context, att);
      }
    });
  }

  /// Opens the Termin requested by a notification for a parent account.
  void _openParentPending() {
    final pendingId = ref.read(pendingAttendanceIdProvider);
    if (pendingId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ref.read(pendingAttendanceIdProvider) != pendingId) return;
      final kids = ref.read(parentChildrenProvider);
      final atts = ref.read(childrenAttendancesProvider);
      if (kids.isLoading || atts.isLoading || kids.hasError || atts.hasError) return;
      ref.read(pendingAttendanceIdProvider.notifier).state = null;
      final all = ref.read(parentAttendanceGroupsProvider);
      if (all.any((g) => g.attendanceId == pendingId)) {
        showRdParentEventSheet(context, pendingId);
      } else {
        ToastHelper.showInfo(context, context.l10n.redesignEventNotFound);
      }
    });
  }
}
