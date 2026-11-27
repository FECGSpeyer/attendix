part of 'rd_event_sections.dart';

// ---------------------------------------------------------------------------
// Werke
// ---------------------------------------------------------------------------

/// Werke of the Termin in the Überblick (always called "Werke").
///
/// * Auftritt (hervorgehobene Terminart): numbered, "+ Werk".
/// * Every other Termin ("Probe"): while it has no Werke of its own it
///   shows those of the next Auftritt ("Vom Adventskonzert"); "Ändern"
///   ticks what is rehearsed, from then on the list is its own. A Werk in
///   the Ablauf carries its clock time.
/// * Tap → Zum Werk / Dirigent ändern / Werk entfernen (with Rückgängig;
///   a removed Werk also leaves the Ablauf).
///
/// Shown for types that manage Werke (Ionic `manageSongs && !isGeneral`).
class RdEventProgramSection extends ConsumerStatefulWidget {
  const RdEventProgramSection({super.key, required this.attendance, required this.type, this.ended = false});

  final Attendance attendance;
  final AttendanceType? type;

  /// The Termin is over: nothing is taken from a coming Auftritt any more.
  final bool ended;

  @override
  ConsumerState<RdEventProgramSection> createState() => _RdEventProgramSectionState();
}

class _RdEventProgramSectionState extends ConsumerState<RdEventProgramSection> {
  bool _saving = false;

  /// Werk hidden while its "Rückgängig" is offered; deleted only once the
  /// SnackBar closes without Rückgängig (keeps its row, number and flags).
  /// Only this one entry: a Werk may be in the list more than once.
  SongHistoryEntry? _removing;

  int get _id => widget.attendance.id!;

  bool get _auftritt => widget.type?.highlight ?? false;

  /// Writes [entries] as the Werke of the Termin; false when it failed.
  Future<bool> _save(List<SongHistoryEntry> entries) async {
    if (_saving) return false;
    final repo = ref.read(attendanceRepositoryWithTenantProvider);
    if (!repo.hasTenantId) return false;
    final container = ProviderScope.containerOf(context, listen: false);
    final session = ref.read(offlineQueueNotifierProvider.notifier).captureWriteSession();
    final typeNotifier = ref.read(attendanceTypeNotifierProvider.notifier);
    setState(() => _saving = true);
    try {
      if (!session.isCurrent()) return false;
      await syncAttendanceSongHistory(repo, _id, widget.attendance.date, entries);
      final type = widget.type;
      if (entries.isNotEmpty && type != null) {
        await rdEnsureTypeFlags(typeNotifier, type, songs: true, onFailed: () {
          if (mounted) ToastHelper.showError(context, context.l10n.typeSettingsUpdateFailed);
        });
      }
      return true;
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.attendanceFlutterSaveFailedWith(friendlyErrorMessage(e)));
      return false;
    } finally {
      await _reload(container, _id);
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Takes the Werke [songIds] out of the Ablauf of the Termin [id], read
  /// anew just before (another device may have changed it). Returns the
  /// Ablauf before and after, null when none of them was in it.
  static Future<({Plan before, Plan after})?> _dropFromPlan(
    ProviderContainer container,
    AttendanceRepository repo,
    int id,
    Set<int> songIds,
  ) async {
    container.invalidate(attendanceDetailProvider(id));
    final fresh = await container.read(attendanceDetailProvider(id).future);
    final plan = fresh == null ? null : rdPlanOf(fresh);
    if (plan == null || !plan.fields.any((f) => songIds.contains(f.songId))) return null;
    final fields = PlanUtils.normalizeGroups([
      for (final f in plan.fields)
        if (!songIds.contains(f.songId)) f,
    ]);
    final after = plan.copyWith(fields: fields, end: PlanUtils.computeEndIso(plan.time, fields));
    await repo.updateAttendance(id, {'plan': after.toJson()});
    _planChanged(container, id);
    return (before: plan, after: after);
  }

  /// The Ablauf of the Termin [id] was written here: the Termin page and
  /// the Ablauf editor (which keeps its own copies) read it anew.
  static void _planChanged(ProviderContainer container, int id) {
    container
      ..invalidate(attendanceDetailProvider(id))
      ..invalidate(planAttendancesProvider)
      ..invalidate(planAttendanceByIdProvider(id));
  }

  /// Refreshes the Werke and waits for the new list: until then the shown
  /// list is the old one, and another change must not build on it.
  static Future<void> _reload(ProviderContainer container, int id) async {
    container
      ..invalidate(attendanceSongEntriesProvider(id))
      ..invalidate(currentSongsProvider)
      ..invalidate(songHistoryProvider(null));
    try {
      await container.read(rdEventWorksProvider(id).future);
    } catch (_) {
      // The section shows the load error with "Erneut versuchen".
    }
  }

  Future<void> _add(List<SongHistoryEntry> current) async {
    final result = await SongsSelectionSheet.show(context, existingEntries: current);
    if (result == null || !mounted) return;
    await _save(result);
  }

  /// "Ändern" (Probe): the Werke of this Termin and of the coming
  /// Auftritte as a checklist. [shown]: the list on screen, [own]: whether
  /// it is the Termin's own one (else the one of `sources.first`).
  Future<void> _change(List<SongHistoryEntry> shown, List<RdWorksSource> sources, {required bool own}) async {
    final l10n = context.l10n;
    // Bound now, before the sheet: the group may change while it is open.
    final repo = ref.read(attendanceRepositoryWithTenantProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final session = ref.read(offlineQueueNotifierProvider.notifier).captureWriteSession();
    final id = _id;
    final date = widget.attendance.date;
    final songs = ref.read(songsProvider).valueOrNull ?? const <Song>[];
    PlanEventWork? work(SongHistoryEntry e) {
      final song = songs.where((s) => s.id == e.songId).firstOrNull;
      if (song == null) return null;
      return (song: song, conductor: e.otherConductor != null || e.conductorName != null ? e.displayConductor : '');
    }

    // Every Werk once: at this Termin first, then at the nearest Auftritt.
    final listed = <int>{};
    List<PlanEventWork> works(List<SongHistoryEntry> entries) => [
      for (final e in entries)
        if (listed.add(e.songId))
          if (work(e) case final w?) w,
    ];
    final groups = <({String label, List<PlanEventWork> works})>[
      if (own) (label: l10n.redesignPlanEventWorksThis, works: works(shown)),
      for (final source in sources) (label: _sourceLabel(source), works: works(source.entries)),
    ]..removeWhere((g) => g.works.isEmpty);
    final plan = rdPlanOf(widget.attendance);
    final kind = rdWorksKind(widget.type);
    final choice = await showRdEventWorksSheet(
      context,
      title: l10n.redesignEventWorksOfThis(kind),
      subtitle: l10n.redesignEventWorksOfThisHint(kind),
      groups: groups,
      initial: {for (final e in shown) e.songId},
      inPlanIds: {...?plan?.fields.map((f) => f.songId).whereType<int>()},
      offerOther: true,
      confirmLabel: l10n.redesignEventWorksTake,
      followLabel: own && sources.isNotEmpty ? l10n.redesignEventWorksFollowAgain : null,
    );
    if (choice == null || !mounted || !session.isCurrent()) return;
    if (choice.follow) {
      await _save(const []);
      return;
    }
    if (choice.other) {
      await _add(shown);
      return;
    }
    // The Termin's own entry when it has one (its conductor), else the one
    // of the Auftritt the Werk comes from.
    final byId = <int, SongHistoryEntry>{
      for (final source in sources.reversed)
        for (final e in source.entries) e.songId: e,
      for (final e in shown) e.songId: e,
    };
    final next = [
      for (final w in choice.works)
        if (byId[w.song.id] case final e?) e,
    ];
    // Still the list of the Auftritt: it keeps following it.
    if (!own && _sameWorks(next, shown)) return;
    if (!await _save(next) || !session.isCurrent()) return;
    // A Werk that left the list also leaves the Ablauf, as with "Werk
    // entfernen" (else the Ablauf would bring it back with its next save).
    final kept = {for (final e in next) e.songId};
    final gone = {
      for (final e in shown)
        if (!kept.contains(e.songId)) e.songId,
    };
    if (gone.isEmpty) return;
    try {
      final change = await _dropFromPlan(container, repo, id, gone);
      if (change == null) return;
      final count = change.before.fields.where((f) => gone.contains(f.songId)).length;
      messenger?.showSnackBar(SnackBar(
        content: Text(l10n.redesignEventWorksRemovedPlan(count)),
        duration: const Duration(seconds: 5),
        persist: false,
        action: SnackBarAction(
          label: l10n.redesignEventUndo,
          onPressed: () => unawaited(_restore(container, repo, session, id, date, change, own ? shown : const [])),
        ),
      ));
    } catch (e) {
      if (mounted) ToastHelper.showError(context, l10n.attendanceFlutterSaveFailedWith(friendlyErrorMessage(e)));
    }
  }

  /// "Rückgängig" after "Ändern" took Werke out of the Ablauf: the list as
  /// it was ([entries]; empty: it follows the Auftritt again) and the
  /// Ablauf, unless that was changed since.
  Future<void> _restore(
    ProviderContainer container,
    AttendanceRepository repo,
    OfflineWriteSession session,
    int id,
    String date,
    ({Plan before, Plan after}) change,
    List<SongHistoryEntry> entries,
  ) async {
    if (!session.isCurrent()) return;
    try {
      await syncAttendanceSongHistory(repo, id, date, entries);
      container.invalidate(attendanceDetailProvider(id));
      final fresh = await container.read(attendanceDetailProvider(id).future);
      if (fresh != null && rdPlanOf(fresh) == change.after) {
        await repo.updateAttendance(id, {'plan': change.before.toJson()});
        _planChanged(container, id);
      }
    } catch (e, st) {
      ErrorReporter.report(e, st, where: 'RdEventProgramSection._restore');
    } finally {
      await _reload(container, id);
    }
  }

  static bool _sameWorks(List<SongHistoryEntry> a, List<SongHistoryEntry> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].songId != b[i].songId) return false;
    }
    return true;
  }

  /// "Adventskonzert · So., 13. Dez."
  String _sourceLabel(RdWorksSource source) {
    final date = EventListUtils.parse(source.att.date);
    String? day;
    try {
      day = date == null ? null : DateFormat('EEE, d. MMM', currentIntlLocale()).format(date);
    } catch (_) {
      // Locale data not loaded: the name alone.
    }
    return [if (source.name.isNotEmpty) source.name, if (day != null) day].join(' · ');
  }

  Future<void> _open(List<SongHistoryEntry> entries, int index, {required bool own}) async {
    final entry = entries[index];
    final l10n = context.l10n;
    final canOpenWork = canOpenSongsTab(ref.read(effectiveRoleProvider));
    final action = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.rd.bg,
      builder: (ctx) {
        final p = ctx.rd;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(header: true, child: Text(entry.songName, style: RdType.cardTitle(p))),
                const SizedBox(height: 4),
                Text(
                  [
                    l10n.redesignEventWorkNumber('${index + 1}'),
                    if (entry.otherConductor != null || entry.conductorName != null)
                      l10n.signoutConductor(entry.displayConductor),
                  ].join(' · '),
                  style: RdType.meta(p, size: 15),
                ),
                const SizedBox(height: 16),
                RdGroupedList(children: [
                  if (canOpenWork)
                    RdListRow(
                      leading: const RdRowIcon(Icons.music_note_outlined),
                      title: l10n.attendanceToSong,
                      subtitle: l10n.redesignEventToWorkHint,
                      onTap: () => Navigator.of(ctx).pop('song'),
                    ),
                  RdListRow(
                    leading: const RdRowIcon(Icons.person_outline),
                    title: l10n.attendanceChangeConductor,
                    subtitle: l10n.redesignEventChangeConductorHint,
                    onTap: () => Navigator.of(ctx).pop('conductor'),
                  ),
                  RdListRow(
                    key: const Key('rd-program-remove'),
                    leading: RdRowIcon(Icons.remove, color: p.absent, background: p.absentSoft),
                    title: l10n.redesignEventRemoveWork,
                    titleColor: p.absent,
                    showChevron: false,
                    onTap: () => Navigator.of(ctx).pop('remove'),
                  ),
                ]),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'song':
        context.push(RedesignRoutes.work(entry.songId));
      case 'conductor':
        await _changeConductor(entries, index);
      case 'remove':
        await _remove(entries, index, own: own);
    }
  }

  Future<void> _changeConductor(List<SongHistoryEntry> entries, int index) async {
    final entry = entries[index];
    final List<Person> conductors;
    try {
      conductors = await ref.read(activeConductorsProvider.future);
    } catch (e) {
      if (mounted) ToastHelper.showError(context, friendlyErrorMessage(e));
      return;
    }
    if (!mounted) return;
    final choice = await showConductorChangeDialog(
      context,
      conductors: conductors,
      currentConductorId: entry.conductorId,
      currentOtherConductor: entry.otherConductor,
    );
    if (choice == null || !mounted) return;
    final updated = [...entries];
    updated[index] = choice.person != null
        ? entry.copyWith(conductorId: choice.person!.id, conductorName: choice.person!.fullName, otherConductor: null)
        : entry.copyWith(conductorId: null, conductorName: null, otherConductor: choice.otherConductor);
    await _save(updated);
  }

  /// [own] false: [entries] is the list of the next Auftritt, which becomes
  /// the Termin's own without this Werk.
  Future<void> _remove(List<SongHistoryEntry> entries, int index, {required bool own}) async {
    final entry = entries[index];
    HapticHelper.light();
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final repo = ref.read(attendanceRepositoryWithTenantProvider);
    if (!repo.hasTenantId) return;
    // Bound now: the delete may run after the page was left.
    final container = ProviderScope.containerOf(context, listen: false);
    // #232: captured now, checked before the (later) delete.
    final session = ref.read(offlineQueueNotifierProvider.notifier).captureWriteSession();
    final id = _id;
    final date = widget.attendance.date;
    final inPlan = rdPlanOf(widget.attendance)?.fields.any((f) => f.songId == entry.songId) ?? false;
    setState(() => _removing = entry);
    final reason = messenger == null
        ? SnackBarClosedReason.timeout
        : await messenger
            .showSnackBar(SnackBar(
              content: Text(
                inPlan ? l10n.redesignEventWorkRemovedPlan(entry.songName) : l10n.redesignEventWorkRemoved(entry.songName),
              ),
              duration: const Duration(seconds: 5),
              persist: false,
              action: SnackBarAction(label: l10n.redesignEventUndo, onPressed: () {}),
            ))
            .closed;
    if (reason == SnackBarClosedReason.action || !session.isCurrent()) {
      if (mounted) setState(() => _removing = null);
      return;
    }
    try {
      // The latest stored list without this Werk: nothing else changes.
      final latest = await loadAttendanceSongEntries(
        repo: repo,
        songsFuture: container.read(songsProvider.future),
        conductorsFuture: container.read(conductorsProvider.future),
        attendanceId: id,
      );
      if (latest == null) return;
      // Still without Werke of its own: the list of the Auftritt as shown.
      final base = !own && latest.isEmpty ? entries : latest;
      final at = base.indexOf(entry);
      if (at < 0) return; // already gone (other device)
      final rest = [...base]..removeAt(at);
      await syncAttendanceSongHistory(repo, id, date, rest);
      // The Werk also leaves the Ablauf, unless the list still has it
      // (twice in it, or the list follows the Auftritt again).
      await _reload(container, id);
      final shown = await container.read(rdEventWorksProvider(id).future);
      if (!shown.entries.any((e) => e.songId == entry.songId)) await _dropFromPlan(container, repo, id, {entry.songId});
    } catch (e) {
      if (mounted) ToastHelper.showError(context, l10n.attendanceFlutterSaveFailedWith(friendlyErrorMessage(e)));
    } finally {
      await _reload(container, id);
      if (mounted) setState(() => _removing = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final async = ref.watch(rdEventWorksProvider(_id));
    final works = async.valueOrNull;
    final own = works?.own ?? false;
    final sources = widget.ended ? const <RdWorksSource>[] : (works?.sources ?? const <RdWorksSource>[]);
    // A Probe takes the Werke of the next Auftritt until it has its own.
    final source = widget.ended ? null : works?.source;
    final all = works == null ? null : (own || source != null ? works.entries : const <SongHistoryEntry>[]);
    final hidden = all == null || _removing == null ? -1 : all.indexOf(_removing!);
    final entries = hidden < 0 ? all : ([...all!]..removeAt(hidden));
    // A removal waiting for its Rückgängig counts as a write in flight.
    final busy = _saving || _removing != null;
    // Who edits Termine changes the Werke (Helfer too, like the Ablauf).
    final canEdit = ref.watch(effectiveRoleProvider).canEdit;
    final canOpenWork = canOpenSongsTab(ref.watch(effectiveRoleProvider));
    final title = l10n.redesignEventWorks;
    final plan = rdPlanOf(widget.attendance);

    /// "19:45": where the Werk stands in the Ablauf (null: not in it).
    String? planTime(int songId) {
      if (plan == null) return null;
      final at = plan.fields.indexWhere((f) => f.songId == songId);
      if (at < 0) return null;
      final start = PlanUtils.parseTimeToMinutes(plan.time);
      return start == null
          ? l10n.redesignPlanSongInPlan
          : PlanUtils.formatMinutes(PlanUtils.startMinutesAt(start, plan.fields, at));
    }

    final Widget body;
    if (entries == null) {
      body = async.hasError
          ? RdInfoCard(
              text: l10n.redesignEventWorksLoadFailed,
              icon: Icons.error_outline,
              action: RdOutlineButton(
                label: l10n.redesignCommonRetry,
                onPressed: () => ref.invalidate(attendanceSongEntriesProvider(_id)),
              ),
            )
          : RdInfoCard(text: l10n.redesignTodayLoading, loading: true);
    } else if (entries.isEmpty) {
      if (!canEdit) return const SizedBox.shrink();
      body = RdGroupedList(children: [
        RdListRow(
          leading: const RdRowIcon(Icons.music_note_outlined),
          title: l10n.redesignEventAddWorkLabel,
          onTap: busy ? null : () => _add(entries),
        ),
      ]);
    } else {
      body = RdGroupedList(children: [
        // Whose list this is while the Probe has none of its own.
        if (source != null)
          Container(
            key: const Key('rd-program-source'),
            color: p.soft,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.event_outlined, size: 18, color: p.softText),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.redesignEventWorksFrom(_sourceLabel(source)),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.softText),
                  ),
                ),
              ],
            ),
          ),
        for (var i = 0; i < entries.length; i++)
          RdListRow(
            key: ValueKey('rd-program-$i-${entries[i].songId}'),
            leading: _auftritt ? RdProgramNumber(i + 1) : const RdRowIcon(Icons.music_note),
            title: entries[i].songName,
            subtitle: entries[i].otherConductor != null || entries[i].conductorName != null
                ? l10n.signoutConductor(entries[i].displayConductor)
                : null,
            trailing: switch (planTime(entries[i].songId)) {
              final time? => RdPill(time, key: ValueKey('rd-program-time-$i')),
              null => null,
            },
            showChevron: canEdit || canOpenWork,
            onTap: canEdit
                ? (busy ? null : () => _open(entries, i, own: own))
                : (canOpenWork ? () => context.push(RedesignRoutes.work(entries[i].songId)) : null),
          ),
      ]);
    }
    // "3 von 6 stehen im Ablauf. Die Liste folgt dem Adventskonzert, …"
    final inPlan = entries == null || plan == null ? 0 : entries.where((e) => planTime(e.songId) != null).length;
    final caption = [
      if (!_auftritt && entries != null && inPlan > 0 && inPlan < entries.length)
        l10n.redesignEventWorksInPlan(inPlan, entries.length),
      if (source != null && canEdit) l10n.redesignEventWorksFollows,
    ].join(' ');
    // A Probe ticks its Werke from the coming Auftritte; without one (and
    // for an Auftritt) a Werk is added from the Werk list.
    final change = sources.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        RdSectionLabel(
          entries == null || entries.isEmpty ? title : l10n.redesignEventSectionCount(title, '${entries.length}'),
          key: const Key('rd-program-label'),
          actionLabel: entries == null || entries.isEmpty || !canEdit
              ? null
              : (change ? l10n.redesignEventWorksChange : l10n.redesignEventAddWork),
          actionSemantics: change ? l10n.redesignEventWorksOfThis(rdWorksKind(widget.type)) : l10n.redesignEventAddWorkLabel,
          actionIcon: change ? Icons.tune : Icons.add,
          onAction: entries == null || busy || !canEdit
              ? null
              : (change ? () => _change(entries, sources, own: own) : () => _add(entries)),
        ),
        if (_saving) LinearProgressIndicator(minHeight: 2, color: p.primary, backgroundColor: p.track),
        body,
        if (caption.isNotEmpty) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(caption, key: const Key('rd-program-caption'), style: RdType.meta(p, size: 13)),
          ),
        ],
      ],
    );
  }
}

/// Whether the Termin shows the Werke section (Ionic `manageSongs && !isGeneral`).
/// Beta: those who edit Termine get it at every Art ("+ Werk"); the first
/// Werk switches Werke on at the Art (see [rdEnsureTypeFlags]).
bool rdShowsProgram(WidgetRef ref, AttendanceType? type) =>
    showSongsForType(type, ref.watch(currentTenantProvider)?.type) ||
    (type != null && ref.watch(currentTenantProvider)?.type != 'general' && ref.watch(effectiveRoleProvider).canEdit);
