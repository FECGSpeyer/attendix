import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/providers/attendance_detail_providers.dart';
import '../../../../../core/providers/attendance_providers.dart';
import '../../../../../core/providers/attendance_type_providers.dart';
import '../../../../../core/providers/conductor_providers.dart';
import '../../../../../core/constants/enums.dart';
import '../../../../../core/providers/debug_providers.dart';
import '../../../../../core/providers/group_providers.dart';
import '../../../../../core/providers/organisation_providers.dart';
import '../../../../../core/providers/plan_providers.dart';
import '../../../../../core/providers/player_providers.dart' show missingGroupsPlayerCountsProvider;
import '../../../../../core/providers/role_permission_providers.dart';
import '../../../../../core/providers/song_providers.dart';
import '../../../../../core/providers/tenant_providers.dart';
import '../../../../../core/router/redesign_routes.dart';
import '../../../../../core/router/route_access.dart' show canOpenSongsTab;
import '../../../../../core/services/error_reporter.dart';
import '../../../../../core/services/offline_queue_service.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../core/utils/attendance_logic_utils.dart' show showSongsForType;
import '../../../../../core/utils/dialog_helper.dart';
import '../../../../../core/utils/error_message.dart';
import '../../../../../core/utils/event_list_utils.dart';
import '../../../../../core/utils/haptic_helper.dart';
import '../../../../../core/utils/plan_utils.dart';
import '../../../../../core/utils/toast_helper.dart';
import '../../../../../data/models/attendance/attendance.dart';
import '../../../../../data/models/person/person.dart';
import '../../../../../data/models/plan/plan.dart' show Plan, PlanAttendance, PlanAttendanceType;
import '../../../../../data/models/song/song.dart';
import '../../../../../data/repositories/attendance_repository.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../../shared/widgets/event_list/event_list_widgets.dart' show openEventNavigation;
import '../../../../attendance/presentation/attendance_song_history.dart';
import '../../../../attendance/presentation/widgets/attendance_detail/attendance_detail_sheets.dart'
    show showConductorChangeDialog;
import '../../../../attendance/presentation/widgets/attendance_detail/description_attachment_sheet.dart';
import '../../../../attendance/presentation/widgets/songs_selection_sheet.dart';
import '../../../../planning/presentation/attendance_plan_viewer.dart';
import '../../../../planning/presentation/widgets/rd_plan_start.dart';
import '../../../../planning/presentation/widgets/rd_plan_widgets.dart' show PlanEventWork, showRdEventWorksSheet;
import '../../../../self_service/presentation/widgets/self_service_event_actions.dart' show openFilesFolderRoute;
import '../../../../songs/presentation/utils/song_utils.dart';
import '../../../data/providers/rd_event_works_providers.dart';
import '../../../data/providers/rd_today_providers.dart' show rdDeadlineLabel;
import '../../../data/rd_event_details_logic.dart';
import '../../../data/rd_type_flags.dart';
import '../rd_widgets.dart';
import '../today/rd_today_common.dart';
import 'rd_event_now.dart' show rdPlanOf;

/// REDESIGN: sections of a Termin's "Überblick" for Dirigent and Helfer
/// (Programm/Werke, Ablauf, Vorbereitung, Infos zum Termin). They replace
/// the old Termin page ("Alle Details") in the new design. Every write
/// goes through the tenant repositories like the old Termin page.

/// Uppercase label with an optional text action on the right ("+ Werk").
class RdSectionLabel extends StatelessWidget {
  const RdSectionLabel(
    this.text, {
    super.key,
    this.actionLabel,
    this.actionSemantics,
    this.onAction,
    this.actionIcon = Icons.add,
  });

  final String text;
  final String? actionLabel;
  final String? actionSemantics;
  final VoidCallback? onAction;

  /// "+ Aufgabe"; [Icons.chevron_right] goes after the label ("Ganz
  /// ansehen ›").
  final IconData actionIcon;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: RdGroupLabel(text)),
        if (actionLabel != null && onAction != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Semantics(
              button: true,
              label: actionSemantics,
              excludeSemantics: actionSemantics != null,
              child: InkWell(
                onTap: onAction,
                borderRadius: BorderRadius.circular(10),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 40),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (actionIcon != Icons.chevron_right) ...[
                          Icon(actionIcon, size: 18, color: p.link),
                          const SizedBox(width: 2),
                        ],
                        Text(actionLabel!, style: TextStyle(fontSize: 15, color: p.link)),
                        if (actionIcon == Icons.chevron_right) Icon(actionIcon, size: 18, color: p.link),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Round number in front of a Werk ("1").
class RdProgramNumber extends StatelessWidget {
  const RdProgramNumber(this.number, {super.key});

  final int number;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(color: p.soft, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text('$number', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.softText)),
    );
  }
}

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
/// * "Ohne Tenor": the Werk has no Noten for a group somebody plays in.
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
    final songs = ref.watch(songsProvider).valueOrNull ?? const <Song>[];
    final isGeneral = ref.watch(currentTenantProvider)?.type == 'general';
    final groups = ref.watch(groupsProvider).valueOrNull ?? const [];
    final categories = ref.watch(groupCategoriesProvider).valueOrNull ?? const [];
    final playerCounts = ref.watch(missingGroupsPlayerCountsProvider);

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

    /// "Ohne Tenor": no Noten for a group somebody plays in.
    String? missing(int songId) {
      if (isGeneral) return null;
      final ids = songs.where((s) => s.id == songId).firstOrNull?.instrumentIds;
      if (ids == null || ids.isEmpty) return null;
      final text = SongUtils.missingInstrumentsText(ids, groups, categories, playerCounts: playerCounts);
      return text.isEmpty ? null : text;
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
            footer: switch (missing(entries[i].songId)) {
              final text? => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Align(alignment: Alignment.centerLeft, child: RdPill(text, tone: RdTone.late)),
                ),
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

// ---------------------------------------------------------------------------
// Ablauf
// ---------------------------------------------------------------------------

/// The Ablauf as a preview (tap: Ablauf ansehen), "Bearbeiten ›" next to
/// the heading and one switch "Für Mitglieder sichtbar"; "Ablauf anlegen"
/// without one. Everyone who edits Termine (Helfer too, like Ionic);
/// Beobachter do not see it. Taking the Ablauf over for the Terminart is
/// in the ••• of the Ablauf editor.
class RdEventPlanSection extends ConsumerStatefulWidget {
  const RdEventPlanSection({
    super.key,
    required this.attendance,
    this.type,
    this.preview,
    this.end = '',
    this.freeMinutes,
  });

  final Attendance attendance;

  /// The Termin's Terminart ("Werke dieser Probe" in the hint).
  final AttendanceType? type;

  /// The Ablauf itself (Reiter Programm).
  final Widget? preview;

  /// "17:35": when the Ablauf ends.
  final String end;

  /// Minutes between the end of the Ablauf and the end of the Termin
  /// ("Ablauf endet 17:35, 20 Min vor Terminende"); null when it fills
  /// the Termin.
  final int? freeMinutes;

  @override
  ConsumerState<RdEventPlanSection> createState() => _RdEventPlanSectionState();
}

class _RdEventPlanSectionState extends ConsumerState<RdEventPlanSection> {
  bool? _share;

  /// [start]: what the editor does first (see [rdPlanStartProvider]).
  void _edit({String? start}) {
    final id = widget.attendance.id;
    if (id == null) return;
    ref.read(rdPlanStartProvider.notifier).state = start == null ? null : (attendanceId: id, action: start);
    context.push<bool>('/planning?attendanceId=$id');
  }

  /// How a new Ablauf starts, besides "Leer beginnen" (the same choices
  /// as in the empty Ablauf editor): with the Werke of the Termin, from a
  /// Vorlage, like the last Termin of the same Terminart. Each row shows
  /// once its data is there.
  List<Widget> _startRows() {
    final l10n = context.l10n;
    final att = widget.attendance;
    final id = att.id;
    if (id == null) return const [];
    final tenantType = ref.watch(currentTenantProvider)?.type;
    final works = rdShowsProgram(ref, widget.type) ? ref.watch(rdEventWorksProvider(id)).valueOrNull : null;
    final songs = {for (final s in ref.watch(songsProvider).valueOrNull ?? const <Song>[]) s.id: s};
    final open = [
      for (final e in works?.entries ?? const <SongHistoryEntry>[])
        if (songs[e.songId] case final song?) song,
    ];
    final types = ref.watch(planAttendanceTypesProvider).valueOrNull ?? const <PlanAttendanceType>[];
    final attendances = ref.watch(planAttendancesProvider).valueOrNull ?? const <PlanAttendance>[];
    final planAtt = attendances.where((a) => a.id == id).firstOrNull ??
        PlanAttendance(id: id, date: att.date, typeId: att.typeId, type: att.type);
    final templates = rdPlanTemplates(
      type: types.where((t) => t.id == att.typeId).firstOrNull,
      auftritt: widget.type?.highlight ?? false,
      tenantType: tenantType,
      orgTemplates: ref.watch(currentOrganisationProvider).valueOrNull?.planningTemplates ?? const [],
      blockTemplates: ref.watch(planBlockTemplatesProvider).valueOrNull ?? const [],
    );
    final previous = rdPreviousPlan(planAtt, attendances);
    final previousDay = previous == null ? null : EventListUtils.parse(previous.att.date);
    return [
      if (open.isNotEmpty)
        RdListRow(
          key: const Key('rd-plan-start-works'),
          leading: const RdRowIcon(Icons.queue_music_outlined),
          title: l10n.redesignPlanStartWorks(rdWorksKind(widget.type)),
          subtitle: rdPlanStartWorksHint(l10n, open),
          onTap: () => _edit(start: 'works'),
        ),
      if (templates.isNotEmpty)
        RdListRow(
          key: const Key('rd-plan-start-template'),
          leading: const RdRowIcon(Icons.view_day_outlined),
          title: l10n.redesignPlanStartTemplate,
          subtitle: l10n.redesignPlanStartTemplateHint(templates.first.name),
          onTap: () async {
            final start = PlanUtils.formatTime(att.startTime ?? widget.type?.startTime);
            final tpl = await showRdPlanTemplateSheet(context, templates, startTime: start);
            if (tpl != null && mounted) _edit(start: 'tpl:$tpl');
          },
        ),
      if (previous != null)
        RdListRow(
          key: const Key('rd-plan-copy-last'),
          leading: const RdRowIcon(Icons.copy_all_outlined),
          title: l10n.rdTextPlanCopyFrom(
            previousDay == null ? previous.att.date : DateFormat(dateFmt()).format(previousDay),
          ),
          subtitle: l10n.rdTextPlanCopyCount(l10n.redesignPlanItemCount(previous.plan.fields.length)),
          onTap: () => _edit(start: 'copy'),
        ),
    ];
  }

  bool _sharing = false;

  Future<void> _toggleShare(bool value) async {
    if (_sharing) return; // one write at a time, see below
    final repo = ref.read(attendanceRepositoryWithTenantProvider);
    if (!repo.hasTenantId) return;
    final container = ProviderScope.containerOf(context, listen: false);
    if (!ref.read(offlineQueueNotifierProvider.notifier).captureWriteSession().isCurrent()) return;
    final id = widget.attendance.id!;
    setState(() {
      _share = value;
      _sharing = true;
    });
    try {
      await repo.updateAttendance(id, {'share_plan': value});
    } catch (e) {
      if (mounted) {
        setState(() => _share = !value);
        ToastHelper.showError(context, context.l10n.attendanceFlutterErrorWith(friendlyErrorMessage(e)));
      }
    } finally {
      container.invalidate(attendanceDetailProvider(id));
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  void didUpdateWidget(RdEventPlanSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The stored value wins again once no write is running.
    if (!_sharing && oldWidget.attendance.sharePlan != widget.attendance.sharePlan) _share = null;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final att = widget.attendance;
    final hasPlan = attendanceHasPlan(att);
    final share = _share ?? att.sharePlan;
    final role = ref.watch(effectiveRoleProvider);
    // Like Ionic (`@if (!isViewer)`): Helfer edit the Ablauf too,
    // Beobachter do not see it.
    final canEdit = role.canEdit;
    if (role == Role.viewer || (!hasPlan && !canEdit)) return const SizedBox.shrink();
    // The Termin's time stands in the page head: no second time span here,
    // the rows carry their times and the line below names the end.
    final heading = l10n.redesignEventPlanSection;
    final free = widget.freeMinutes;
    // "3 Werke dieser Probe stehen noch nicht im Ablauf": only while the
    // Termin is not over, for those who edit the Ablauf.
    final day = EventListUtils.parse(att.date);
    final now = DateTime.now();
    final coming = day != null && !day.isBefore(DateTime(now.year, now.month, now.day));
    final works = canEdit && hasPlan && coming && att.id != null && rdShowsProgram(ref, widget.type)
        ? ref.watch(rdEventWorksProvider(att.id!)).valueOrNull
        : null;
    final inPlan = {...?rdPlanOf(att)?.fields.map((f) => f.songId).whereType<int>()};
    final missing = works == null ? 0 : {for (final e in works.entries) e.songId}.difference(inPlan).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        if (!hasPlan) ...[
          RdGroupLabel(heading),
          RdGroupedList(children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.redesignPlanStartNone, style: RdType.section(p)),
                  const SizedBox(height: 2),
                  Text(l10n.redesignPlanStartAsk, style: RdType.meta(p, size: 14)),
                ],
              ),
            ),
            ..._startRows(),
            RdListRow(
              key: const Key('rd-plan-create'),
              leading: const RdRowIcon(Icons.add),
              title: l10n.redesignPlanStartEmpty,
              onTap: () => _edit(start: 'empty'),
            ),
          ]),
        ] else ...[
          RdSectionLabel(
            heading,
            actionLabel: canEdit ? l10n.redesignEventPlanEditShort : null,
            actionSemantics: l10n.redesignEventPlanEdit,
            actionIcon: Icons.chevron_right,
            onAction: canEdit ? () => _edit() : null,
          ),
          // The preview is the Ablauf: a tap opens it whole (live on the day).
          Semantics(
            button: true,
            label: l10n.redesignEventPlan,
            child: GestureDetector(
              key: const Key('rd-plan-preview'),
              behavior: HitTestBehavior.opaque,
              onTap: () => openAttendancePlanViewer(context, att),
              child: widget.preview ??
                  RdGroupedList(children: [
                    RdListRow(
                      leading: const RdRowIcon(Icons.view_timeline_outlined),
                      title: l10n.redesignEventPlan,
                      onTap: () => openAttendancePlanViewer(context, att),
                    ),
                  ]),
            ),
          ),
          if (free != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                l10n.redesignEventPlanEndsEarly(widget.end, free),
                key: const Key('rd-plan-free'),
                style: RdType.meta(p, size: 13),
              ),
            ),
          ],
          if (missing > 0) ...[
            const SizedBox(height: 12),
            Material(
              color: p.lateSoft,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const Key('rd-plan-works-missing'),
                onTap: () => _edit(start: 'works'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.music_note, size: 20, color: p.late),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.redesignEventWorksMissing(rdWorksKind(widget.type), missing),
                          style: TextStyle(fontSize: 14, color: p.text, height: 1.3),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        l10n.redesignEventWorksMissingInsert,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.late),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (canEdit) ...[
            const SizedBox(height: 12),
            RdGroupedList(children: [
              RdListRow(
                key: const Key('rd-plan-share'),
                title: l10n.redesignEventPlanShare,
                showChevron: false,
                onTap: _sharing ? null : () => _toggleShare(!share),
                trailing: Switch.adaptive(value: share, onChanged: _sharing ? null : _toggleShare),
              ),
            ]),
          ],
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Vorbereitung (Checkliste)
// ---------------------------------------------------------------------------

/// "Vorbereitung": what the Leitung has to get done before the Termin
/// (the Termin's checklist). Tick off, "+ Aufgabe", delete. A new Termin
/// already carries the tasks of its Terminart (Verwaltung › Terminarten);
/// without any the section explains itself and, when the Terminart has
/// tasks, offers to take them over.
class RdEventChecklistSection extends ConsumerStatefulWidget {
  const RdEventChecklistSection({super.key, required this.attendance, this.type, this.canEdit = true});

  final Attendance attendance;

  /// Leitung: tick off, add, delete; others with view permission only read.
  final bool canEdit;

  /// The Termin's Terminart: its tasks can be taken over into an empty list.
  final AttendanceType? type;

  @override
  ConsumerState<RdEventChecklistSection> createState() => _RdEventChecklistSectionState();
}

class _RdEventChecklistSectionState extends ConsumerState<RdEventChecklistSection> {
  /// Local list while a write is in flight (or after it failed: the
  /// stored one comes back with the next refresh).
  List<ChecklistItem>? _local;

  List<ChecklistItem> get _items => _local ?? widget.attendance.checklist ?? const [];

  /// Writes still running; they run one after another (each sends the
  /// whole list) so a later tick never loses to an earlier one.
  int _pending = 0;
  Future<void> _queue = Future.value();

  @override
  void didUpdateWidget(RdEventChecklistSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_pending == 0 && oldWidget.attendance.checklist != widget.attendance.checklist) _local = null;
  }

  Future<void> _save(List<ChecklistItem> items) {
    setState(() => _local = items);
    _pending++;
    final write = rdChecklistWriter(context, ref, widget.attendance.id!);
    final done = _queue.then((_) => write(items)).then((ok) {
      _pending--;
      // Failed: show the stored list again once nothing else is pending.
      if (!ok && _pending == 0 && mounted) setState(() => _local = null);
    });
    _queue = done;
    return done;
  }

  Future<void> _add() async {
    final item = await rdAskChecklistItem(context, widget.attendance);
    if (item == null || !mounted) return;
    await _save([..._items, item]);
  }

  Future<void> _takeOverTemplate() async {
    final type = widget.type;
    if (type == null) return;
    await _save(rdDefaultChecklist(type, widget.attendance));
  }

  Future<void> _delete(int index) async {
    final l10n = context.l10n;
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: l10n.attendanceFlutterDeleteTodoTitle,
      message: l10n.attendanceDeleteTodoConfirm,
      confirmText: l10n.commonDelete,
      isDestructive: true,
    );
    if (confirmed != true || !mounted) return;
    await _save([..._items]..removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final items = _items;
    if (items.isEmpty) {
      final templateCount = widget.type?.checklist?.length ?? 0;
      return Column(
        key: const Key('rd-event-prep-empty'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RdSectionLabel(
            l10n.redesignEventPrepTitle,
            actionLabel: l10n.redesignEventAddTask,
            actionSemantics: l10n.redesignEventAddTaskLabel,
            onAction: _add,
          ),
          RdCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.redesignEventPrepEmpty, style: RdType.meta(p, size: 14)),
                if (templateCount > 0) ...[
                  const SizedBox(height: 10),
                  RdPillButton(
                    key: const Key('rd-event-prep-template'),
                    icon: Icons.playlist_add_check_rounded,
                    label: l10n.redesignEventPrepTakeOver(templateCount),
                    onPressed: _takeOverTemplate,
                  ),
                ],
              ],
            ),
          ),
          if (_local != null && _local != widget.attendance.checklist)
            LinearProgressIndicator(minHeight: 2, color: p.primary, backgroundColor: p.track),
        ],
      );
    }
    final done = items.where((i) => i.completed).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdSectionLabel(
          l10n.redesignEventPrep('$done', '${items.length}'),
          actionLabel: widget.canEdit ? l10n.redesignEventAddTask : null,
          actionSemantics: l10n.redesignEventAddTaskLabel,
          onAction: widget.canEdit ? _add : null,
        ),
        RdGroupedList(children: [
          for (var i = 0; i < items.length; i++)
            _ChecklistRow(
              key: ValueKey('rd-check-${items[i].id}'),
              item: items[i],
              onToggle: !widget.canEdit
                  ? null
                  : () {
                      HapticHelper.light();
                      final next = [...items];
                      next[i] = items[i].copyWith(completed: !items[i].completed);
                      _save(next);
                    },
              onDelete: widget.canEdit ? () => _delete(i) : null,
            ),
        ]),
        if (_local != null && _local != widget.attendance.checklist)
          LinearProgressIndicator(minHeight: 2, color: p.primary, backgroundColor: p.track),
      ],
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({super.key, required this.item, required this.onToggle, required this.onDelete});

  final ChecklistItem item;
  final VoidCallback? onToggle;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final due = rdChecklistDue(item);
    final dueText = item.completed ? '' : rdChecklistDueText(l10n, item);
    return Semantics(
      checked: item.completed,
      child: InkWell(
        onTap: onToggle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: item.completed ? p.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: item.completed ? p.primary : p.text2, width: 2),
                  ),
                  child: item.completed ? Icon(Icons.check, size: 15, color: p.onPrimary) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.text,
                    style: TextStyle(
                      fontSize: 16,
                      color: item.completed ? p.text2 : p.text,
                      decoration: item.completed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                if (dueText.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  RdPill(
                    dueText,
                    tone: switch (due) {
                      RdDue.overdue => RdTone.absent,
                      RdDue.soon => RdTone.late,
                      RdDue.none => null,
                    },
                  ),
                ],
                if (onDelete != null)
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: p.text2),
                    tooltip: l10n.redesignEventDeleteTask,
                    onPressed: onDelete,
                  )
                else
                  const SizedBox(width: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Writes the checklist of [attendanceId] (whole list, like the Termin page).
Future<void> rdSaveChecklist(BuildContext context, WidgetRef ref, int attendanceId, List<ChecklistItem> items) =>
    rdChecklistWriter(context, ref, attendanceId)(items);

/// Binds repository and provider container now, so the write still
/// finishes (and refreshes the Termin) when the page is left meanwhile.
/// The returned writer answers false when the write failed.
Future<bool> Function(List<ChecklistItem>) rdChecklistWriter(BuildContext context, WidgetRef ref, int attendanceId) {
  final repo = ref.read(attendanceRepositoryWithTenantProvider);
  final container = ProviderScope.containerOf(context, listen: false);
  // #232: a queued write of a signed-out / switched account is dropped.
  final session = ref.read(offlineQueueNotifierProvider.notifier).captureWriteSession();
  return (items) async {
    if (!repo.hasTenantId || !session.isCurrent()) return false;
    var ok = true;
    try {
      await repo.updateAttendance(attendanceId, {'checklist': [for (final i in items) i.toJson()]});
    } catch (e) {
      ok = false;
      if (context.mounted) {
        ToastHelper.showError(context, context.l10n.attendanceFlutterSaveFailedWith(friendlyErrorMessage(e)));
      }
    }
    container.invalidate(attendanceDetailProvider(attendanceId));
    return ok;
  };
}

/// "Aufgabe hinzufügen": text and optional "Stunden vorher" (Termin page dialog).
Future<ChecklistItem?> rdAskChecklistItem(BuildContext context, Attendance attendance) async {
  final l10n = context.l10n;
  final text = TextEditingController();
  final hours = TextEditingController();
  final result = await showAppDialog<({String text, int? hours})>(
    context: context,
    builder: (ctx) => AppAlertDialog(
      title: Text(l10n.attendanceAddTodo),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: text,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: l10n.attendanceTodoText),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: hours,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(hintText: l10n.attendanceDeadlineHours),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
        TextButton(
          onPressed: () {
            if (text.text.trim().isEmpty) {
              ToastHelper.showWarning(ctx, l10n.attendanceEnterText);
              return;
            }
            Navigator.pop(ctx, (text: text.text.trim(), hours: int.tryParse(hours.text.trim())));
          },
          child: Text(l10n.attendanceAdd),
        ),
      ],
    ),
  );
  text.dispose();
  hours.dispose();
  if (result == null) return null;
  return rdNewChecklistItem(result.text, result.hours, rdChecklistEventStart(attendance));
}

// ---------------------------------------------------------------------------
// Infos zum Termin
// ---------------------------------------------------------------------------

/// Navigation, Beschreibung & Anhang, Ordner, Antwort bis: only rows with
/// content (all of them are edited in "Termin bearbeiten"). After the
/// Termin without Navigation and Antwort bis.
class RdEventInfoSection extends ConsumerWidget {
  const RdEventInfoSection({super.key, required this.attendance, this.title, this.ended = false});

  final Attendance attendance;

  /// Heading; default "Infos".
  final String? title;
  final bool ended;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final att = attendance;
    final place = (att.place ?? '').trim();
    final description = rdPlainText(att.description);
    final attachment = (att.attachmentName ?? '').trim();
    final hasDescription = description.isNotEmpty || (att.attachmentUrl ?? '').isNotEmpty;
    final folder = (att.filesFolder ?? '').trim();
    final canFiles = ref.watch(canAccessFilesProvider);
    final deadline = EventListUtils.deadlineLocal(att.deadline);
    final rows = <Widget>[
      if (place.isNotEmpty && !ended)
        RdListRow(
          leading: const RdRowIcon(Icons.navigation_outlined),
          title: l10n.signoutOpenNavigation,
          subtitle: place,
          onTap: () => openEventNavigation(context, place),
        ),
      if (hasDescription)
        RdListRow(
          leading: const RdRowIcon(Icons.info_outline),
          title: l10n.redesignEventDescription,
          subtitle: [
            if (description.isNotEmpty) description,
            if (attachment.isNotEmpty) attachment,
          ].join(' · '),
          onTap: () => showDescriptionAttachmentSheet(context, attendance: att),
        ),
      if (folder.isNotEmpty && canFiles)
        RdListRow(
          leading: const RdRowIcon(Icons.folder_outlined),
          title: l10n.attendanceFilesFolder,
          subtitle: folder,
          onTap: () => openFilesFolderRoute(context, folder),
        ),
      if (deadline != null && !ended)
        RdListRow(
          leading: const RdRowIcon(Icons.schedule),
          title: l10n.redesignCreateDeadline,
          subtitle: rdDeadlineLabel(deadline),
          showChevron: false,
        ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        RdGroupLabel(title ?? l10n.redesignOwnInfos),
        RdGroupedList(children: rows),
      ],
    );
  }
}
