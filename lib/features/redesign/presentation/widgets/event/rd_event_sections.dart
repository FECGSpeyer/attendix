import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/providers/attendance_detail_providers.dart';
import '../../../../../core/providers/attendance_providers.dart';
import '../../../../../core/providers/attendance_type_providers.dart';
import '../../../../../core/providers/conductor_providers.dart';
import '../../../../../core/constants/enums.dart';
import '../../../../../core/providers/debug_providers.dart';
import '../../../../../core/providers/role_permission_providers.dart';
import '../../../../../core/providers/song_providers.dart';
import '../../../../../core/providers/tenant_providers.dart';
import '../../../../../core/router/redesign_routes.dart';
import '../../../../../core/router/route_access.dart' show canOpenSongsTab;
import '../../../../../core/services/offline_queue_service.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../core/utils/attendance_logic_utils.dart' show showSongsForType;
import '../../../../../core/utils/dialog_helper.dart';
import '../../../../../core/utils/error_message.dart';
import '../../../../../core/utils/event_list_utils.dart';
import '../../../../../core/utils/haptic_helper.dart';
import '../../../../../core/utils/toast_helper.dart';
import '../../../../../data/models/attendance/attendance.dart';
import '../../../../../data/models/person/person.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../../shared/widgets/event_list/event_list_widgets.dart' show openEventNavigation;
import '../../../../attendance/presentation/attendance_song_history.dart';
import '../../../../attendance/presentation/widgets/attendance_detail/attendance_detail_sheets.dart'
    show showConductorChangeDialog;
import '../../../../attendance/presentation/widgets/attendance_detail/description_attachment_sheet.dart';
import '../../../../attendance/presentation/widgets/songs_selection_sheet.dart';
import '../../../../planning/presentation/attendance_plan_viewer.dart';
import '../../../../self_service/presentation/widgets/self_service_event_actions.dart' show openFilesFolderRoute;
import '../../../data/providers/rd_today_providers.dart' show rdDeadlineLabel;
import '../../../data/rd_event_details_logic.dart';
import '../../../data/rd_type_flags.dart';
import '../rd_widgets.dart';
import '../today/rd_today_common.dart';

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
// Programm / Werke
// ---------------------------------------------------------------------------

/// Werke of the Termin: numbered, "+ Werk", tap → Zum Werk / Dirigent
/// ändern / Werk entfernen (with Rückgängig). Shown for types that manage
/// Werke (Ionic `manageSongs && !isGeneral`).
class RdEventProgramSection extends ConsumerStatefulWidget {
  const RdEventProgramSection({super.key, required this.attendance, required this.type});

  final Attendance attendance;
  final AttendanceType? type;

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

  /// Refreshes the Werke and waits for the new list: until then the shown
  /// list is the old one, and another change must not build on it.
  static Future<void> _reload(ProviderContainer container, int id) async {
    container
      ..invalidate(attendanceSongEntriesProvider(id))
      ..invalidate(currentSongsProvider)
      ..invalidate(songHistoryProvider(null));
    try {
      await container.read(attendanceSongEntriesProvider(id).future);
    } catch (_) {
      // The section shows the load error with "Erneut versuchen".
    }
  }

  Future<void> _add(List<SongHistoryEntry> current) async {
    final result = await SongsSelectionSheet.show(context, existingEntries: current);
    if (result == null || !mounted) return;
    await _save(result);
  }

  Future<void> _open(List<SongHistoryEntry> entries, int index) async {
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
        await _remove(entries, index);
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

  Future<void> _remove(List<SongHistoryEntry> entries, int index) async {
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
    setState(() => _removing = entry);
    final reason = messenger == null
        ? SnackBarClosedReason.timeout
        : await messenger
            .showSnackBar(SnackBar(
              content: Text(l10n.redesignEventWorkRemoved(entry.songName)),
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
      final at = latest.indexOf(entry);
      if (at < 0) return; // already gone (other device)
      await syncAttendanceSongHistory(repo, id, date, [...latest]..removeAt(at));
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
    final async = ref.watch(attendanceSongEntriesProvider(_id));
    final all = async.valueOrNull;
    final hidden = all == null || _removing == null ? -1 : all.indexOf(_removing!);
    final entries = hidden < 0 ? all : ([...all!]..removeAt(hidden));
    // A removal waiting for its Rückgängig counts as a write in flight.
    final busy = _saving || _removing != null;
    final title = rdProgramTitle(l10n, widget.type);
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
      body = RdGroupedList(children: [
        RdListRow(
          leading: const RdRowIcon(Icons.music_note_outlined),
          title: l10n.redesignEventAddWorkLabel,
          onTap: busy ? null : () => _add(entries),
        ),
      ]);
    } else {
      body = RdGroupedList(children: [
        for (var i = 0; i < entries.length; i++)
          RdListRow(
            key: ValueKey('rd-program-$i-${entries[i].songId}'),
            leading: RdProgramNumber(i + 1),
            title: entries[i].songName,
            subtitle: entries[i].otherConductor != null || entries[i].conductorName != null
                ? l10n.signoutConductor(entries[i].displayConductor)
                : null,
            onTap: busy ? null : () => _open(entries, i),
          ),
      ]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdSectionLabel(
          entries == null || entries.isEmpty ? title : l10n.redesignEventSectionCount(title, '${entries.length}'),
          actionLabel: entries != null && entries.isNotEmpty ? l10n.redesignEventAddWork : null,
          actionSemantics: l10n.redesignEventAddWorkLabel,
          onAction: entries == null || busy ? null : () => _add(entries),
        ),
        if (_saving) LinearProgressIndicator(minHeight: 2, color: p.primary, backgroundColor: p.track),
        body,
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
  const RdEventPlanSection({super.key, required this.attendance, this.preview, this.end = '', this.freeMinutes});

  final Attendance attendance;

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

  void _edit() => context.push<bool>('/planning?attendanceId=${widget.attendance.id}');

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        if (!hasPlan) ...[
          RdGroupLabel(heading),
          RdGroupedList(children: [
            RdListRow(
              key: const Key('rd-plan-create'),
              leading: const RdRowIcon(Icons.view_timeline_outlined),
              title: l10n.redesignEventPlanCreate,
              onTap: _edit,
            ),
          ]),
        ] else ...[
          RdSectionLabel(
            heading,
            actionLabel: canEdit ? l10n.redesignEventPlanEditShort : null,
            actionSemantics: l10n.redesignEventPlanEdit,
            actionIcon: Icons.chevron_right,
            onAction: canEdit ? _edit : null,
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
