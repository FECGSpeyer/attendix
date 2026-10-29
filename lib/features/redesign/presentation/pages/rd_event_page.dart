import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/providers/attendance_detail_providers.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/providers/role_permission_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/services/offline_queue_service.dart' show rootScaffoldMessengerKey;
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/event_list_utils.dart';
import '../../../../core/utils/haptic_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../data/models/person/person.dart';
import '../../../../l10n/l10n.dart';
import '../../../attendance/presentation/person_attendance_writes.dart';
import '../../../attendance/presentation/widgets/attendance_detail/attendance_grid.dart'
    show mainGroupIdOf, sortPersonsByGroup;
import '../../../attendance/presentation/widgets/attendance_detail/status_chip.dart'
    show ionicStatusLabel;
import '../../data/providers/rd_today_providers.dart';
import '../../data/rd_event_logic.dart';
import '../widgets/event/rd_pult_view.dart';
import '../widgets/event/rd_record_widgets.dart';
import '../widgets/rd_split_view.dart';
import '../widgets/rd_widgets.dart';
import '../widgets/today/rd_today_common.dart';
import '../../data/rd_dates.dart';

/// Tabs of a Termin in the new design.
enum RdEventTab { overview, record }

/// REDESIGN: a Termin for Dirigent and Helfer (canvas D4 "Überblick", D5
/// "Anwesenheit" with Rückgängig). Statuses and notes are written through
/// the Termin page's write path ([PersonAttendanceWriter], as in
/// [writePersonStatus] and [writePersonAttendance]); everything else stays on the full Termin page
/// ("Alle Details").
class RdEventPage extends ConsumerStatefulWidget {
  const RdEventPage({
    super.key,
    required this.attendanceId,
    this.initialTab = RdEventTab.overview,
  });

  final int attendanceId;
  final RdEventTab initialTab;

  @override
  ConsumerState<RdEventPage> createState() => _RdEventPageState();
}

/// What "Rückgängig" restores: the previous status per person.
class _Undo {
  const _Undo(this.text, this.previous);

  final String text;
  final Map<int, AttendanceStatus> previous;
}

class _RdEventPageState extends ConsumerState<RdEventPage> {
  late RdEventTab _tab = widget.initialTab;

  // Like the Termin page: the shown status per person (local changes win
  // while a write is in flight), the row ids and the notes.
  final Map<int, AttendanceStatus> _statuses = {};
  final Map<int, AttendanceStatus> _initial = {};
  final Map<int, String?> _paIds = {};
  final Map<int, String?> _notes = {};
  final Map<int, String?> _changedAt = {};
  /// Writes in flight per person (from the tap on, so a refetch that
  /// arrives meanwhile cannot show the old status again).
  final Map<int, int> _saving = {};
  Set<int>? _rowPersonIds;

  ProviderSubscription<AsyncValue<List<PersonAttendance>>>? _rowsSub;
  AppLifecycleListener? _lifecycle;
  Timer? _reloadDebounce;
  Timer? _undoTimer;
  _Undo? _undo;
  String? _toast;
  int _bulkWrites = 0;

  bool _searching = false;
  String _query = '';

  /// Pultmodus: big tiles instead of the list (rd_pult_view.dart).
  bool _pult = false;

  // Keyboard (canvas "Desktop"): the row the keys act on, the rows shown
  // and their keys for scrolling.
  int? _kbIndex;
  List<RdMember> _kbRows = const [];
  List<AttendanceStatus> _kbAvailable = const [];
  final Map<int, GlobalKey> _rowKeys = {};
  final _search = TextEditingController();

  int get _id => widget.attendanceId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Fresh rows from the database (other devices, autoDispose cache).
      ref.invalidate(personAttendancesForAttendanceProvider(_id));
      _rowsSub = ref.listenManual<AsyncValue<List<PersonAttendance>>>(
        filteredPersonAttendancesForAttendanceProvider(_id),
        (previous, next) {
          if (next is AsyncData<List<PersonAttendance>>) _applyRows(next.value);
        },
        fireImmediately: true,
      );
    });
    _lifecycle = AppLifecycleListener(onShow: _reload);
  }

  @override
  void dispose() {
    _rowsSub?.close();
    _lifecycle?.dispose();
    _reloadDebounce?.cancel();
    _undoTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    ref.invalidate(attendanceDetailProvider(_id));
    ref.invalidate(personAttendancesForAttendanceProvider(_id));
  }

  void _applyRows(List<PersonAttendance> rows) {
    if (!mounted) return;
    setState(() {
      for (final pa in rows) {
        final personId = pa.personId;
        if (personId == null) continue;
        _paIds[personId] = pa.id;
        _changedAt[personId] = pa.changedAt;
        _initial.putIfAbsent(personId, () => pa.status);
        // Status and note only when not being changed here right now.
        if (!_saving.containsKey(personId)) {
          _statuses[personId] = pa.status;
          _notes[personId] = pa.notes;
        }
      }
      _rowPersonIds = {for (final pa in rows) if (pa.personId != null) pa.personId!};
    });
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  void _hold(int personId) => _saving[personId] = (_saving[personId] ?? 0) + 1;

  /// Last pending write per person: status, undo and note writes of one
  /// person run one after the other, so a slow earlier write can never land
  /// after (and overwrite) a later one such as "Rückgängig".
  final Map<int, Future<void>> _queues = {};

  Future<T> _serial<T>(int personId, Future<T> Function() task) {
    final before = _queues[personId] ?? Future<void>.value();
    final done = Completer<void>();
    _queues[personId] = done.future;
    return before.then((_) => task()).whenComplete(() {
      done.complete();
      if (identical(_queues[personId], done.future)) _queues.remove(personId);
    });
  }

  void _release(int personId) {
    final left = (_saving[personId] ?? 1) - 1;
    if (left <= 0) {
      _saving.remove(personId);
    } else {
      _saving[personId] = left;
    }
  }

  /// Change number per person: every local status change takes the next
  /// one. A write only runs and only rolls back while its change is still
  /// the person's newest, so a slow or failing older write can neither
  /// overwrite a newer choice nor reset it.
  final Map<int, int> _revs = {};

  int _nextRev(int personId) => _revs[personId] = (_revs[personId] ?? 0) + 1;

  /// Writes one status ([rev] from [_nextRev] when it was set); reverts and
  /// reports when it could not be saved. [writer] is bound when the user
  /// acted, so a write still waiting in [_serial] completes after the page
  /// was left.
  Future<bool> _write(
    PersonAttendanceWriter writer,
    int personId,
    AttendanceStatus status,
    AttendanceStatus previous, {
    required int rev,
    bool refresh = true,
  }) async {
    bool newest() => _revs[personId] == rev;
    void revert() {
      if (mounted && newest()) setState(() => _statuses[personId] = previous);
    }

    final paId = _paIds[personId];
    if (paId == null) {
      revert();
      return false;
    }
    _hold(personId);
    try {
      final result = await _serial(
        personId,
        // A newer change of this person follows in the queue and wins.
        () async => newest()
            ? writer.status(
                attendanceId: _id,
                personAttendanceId: paId,
                status: status,
                refresh: refresh,
              )
            : null,
      );
      if (result == null) return false;
      if (result == PersonAttendanceWrite.notAllowed) {
        revert();
        return false;
      }
      return true;
    } catch (e) {
      // A superseded write failing changes nothing: the newer one follows.
      if (!newest()) return false;
      revert();
      _showWriteError((l10n) => l10n.attendanceFlutterSaveFailedWith(friendlyErrorMessage(e)));
      return false;
    } finally {
      _release(personId);
    }
  }

  /// Error toast; after the page was left (a queued write failed) on the
  /// app's root messenger.
  void _showWriteError(String Function(AppLocalizations l10n) message) {
    if (mounted) {
      ToastHelper.showError(context, message(context.l10n));
      return;
    }
    rootScaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
      content: Text(message(l10nWithoutContext), style: const TextStyle(color: Colors.white)),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
    ));
  }

  /// Writes several statuses, a few at a time, and refreshes the list once.
  /// Bound to the moment of the tap: it finishes after the page was left.
  Future<void> _writeMany(Map<int, AttendanceStatus> targets, Map<int, AttendanceStatus> previous) async {
    final writer = PersonAttendanceWriter(ref);
    final revs = {for (final id in targets.keys) id: _nextRev(id)};
    setState(() => _bulkWrites++);
    try {
      final entries = targets.entries.toList();
      var saved = false;
      for (var i = 0; i < entries.length; i += 6) {
        final chunk = entries.skip(i).take(6);
        final results = await Future.wait([
          for (final e in chunk)
            _write(
              writer,
              e.key,
              e.value,
              previous[e.key] ?? AttendanceStatus.neutral,
              rev: revs[e.key]!,
              refresh: false,
            ),
        ]);
        saved = saved || results.any((ok) => ok);
      }
      if (saved) writer.refreshStatuses(_id);
    } finally {
      if (mounted) setState(() => _bulkWrites--);
    }
  }

  void _showToast(String text, {_Undo? undo}) {
    _undoTimer?.cancel();
    setState(() {
      _toast = text;
      _undo = undo;
    });
    _undoTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) {
        setState(() {
          _toast = null;
          _undo = null;
        });
      }
    });
  }

  void _setStatus(RdMember member, AttendanceStatus status) {
    final previous = member.status;
    if (previous == status) return;
    HapticHelper.light();
    setState(() => _statuses[member.id] = status);
    final l10n = context.l10n;
    final text = status == AttendanceStatus.neutral
        ? l10n.redesignEventToastReset(member.name)
        : l10n.redesignEventToastSet(member.name, ionicStatusLabel(status));
    _showToast(text, undo: _Undo(text, {member.id: previous}));
    _write(PersonAttendanceWriter(ref), member.id, status, previous, rev: _nextRev(member.id));
  }

  void _allOpenPresent(List<RdMember> open) {
    if (open.isEmpty) return;
    HapticHelper.light();
    final previous = {for (final m in open) m.id: m.status};
    setState(() {
      for (final m in open) {
        _statuses[m.id] = AttendanceStatus.present;
      }
    });
    final text = context.l10n.redesignEventAllDone(open.length);
    _showToast(text, undo: _Undo(text, previous));
    _writeMany({for (final m in open) m.id: AttendanceStatus.present}, previous);
  }

  void _runUndo() {
    final undo = _undo;
    if (undo == null) return;
    final current = {for (final id in undo.previous.keys) id: _statuses[id] ?? AttendanceStatus.neutral};
    setState(() {
      undo.previous.forEach((id, status) => _statuses[id] = status);
    });
    _showToast(context.l10n.redesignEventUndone);
    _writeMany(undo.previous, current);
  }

  Future<void> _openStatusSheet(RdMember member, List<AttendanceStatus> available, bool canEditNote) async {
    final l10n = context.l10n;
    final result = await showRdStatusSheet(
      context,
      member: member,
      subtitle: member.groupName ?? l10n.attendanceNoGroup,
      available: available,
      canEditNote: canEditNote,
    );
    if (result == null || !mounted) return;
    if (result.status != member.status) _setStatus(member, result.status);
    final note = result.note ?? '';
    if (canEditNote && note != (member.note ?? '')) await _writeNote(member, note);
  }

  /// Note of one person for this Termin (same rules as the Termin page).
  Future<void> _writeNote(RdMember member, String note) async {
    final paId = _paIds[member.id];
    if (paId == null) {
      ToastHelper.showError(context, context.l10n.attendanceFlutterNoEntry);
      return;
    }
    String? previousNote;
    var direct = false;
    final writer = PersonAttendanceWriter(ref);
    _hold(member.id);
    try {
      final result = await _serial(
        member.id,
        () => writer.write(
          attendanceId: _id,
          personAttendanceId: paId,
          updates: {'notes': note},
          beforeWrite: () {
            direct = true;
            previousNote = _notes[member.id];
            if (mounted) setState(() => _notes[member.id] = note);
          },
        ),
      );
      if (!mounted) return;
      switch (result) {
        case PersonAttendanceWrite.queued:
          setState(() => _notes[member.id] = note);
        case PersonAttendanceWrite.notAllowed:
          ToastHelper.showError(context, context.l10n.attendanceFlutterNoPermission);
        case PersonAttendanceWrite.saved:
          ToastHelper.showSuccess(
            context,
            note.isNotEmpty ? context.l10n.attendanceNoteAdded : context.l10n.attendanceFlutterNoteDeleted,
          );
      }
    } catch (e) {
      if (direct && mounted) setState(() => _notes[member.id] = previousNote);
      _showWriteError((l10n) => l10n.attendanceFlutterErrorWith(friendlyErrorMessage(e)));
    } finally {
      _release(member.id);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RedesignRoutes.events);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Changes on other devices (the list's realtime channel bumps the
    // counter on every person_attendances update).
    ref.listen<int>(attendanceRefetchCounter, (_, __) {
      _reloadDebounce?.cancel();
      _reloadDebounce = Timer(const Duration(milliseconds: 400), () {
        if (mounted) ref.invalidate(personAttendancesForAttendanceProvider(_id));
      });
    });

    final attendanceAsync = ref.watch(attendanceDetailProvider(_id));
    final attendance = attendanceAsync.valueOrNull;
    final busy = _bulkWrites > 0;

    final children = <Widget>[
      Row(
        children: [
          Expanded(
            child: RdSplitScope.of(context)?.isDetail ?? false
                ? const SizedBox(height: 44)
                : RdBackLink(label: l10n.redesignTabEvents, onTap: _back),
          ),
          if (_tab == RdEventTab.record)
            RdCircleButton(
              icon: _searching ? Icons.close : Icons.search,
              label: _searching ? l10n.redesignEventSearchClose : l10n.redesignEventSearch,
              onPressed: () => setState(() {
                _searching = !_searching;
                if (!_searching) {
                  _search.clear();
                  _query = '';
                }
              }),
            )
          else
            Flexible(
              child: _TextLink(
                label: l10n.redesignEventDetails,
                onTap: () => context.push('/attendance/$_id'),
              ),
            ),
        ],
      ),
    ];

    if (attendance == null) {
      children.add(attendanceAsync.isLoading
          ? RdInfoCard(text: l10n.redesignTodayLoading, loading: true)
          : RdInfoCard(
              text: attendanceAsync.hasError ? l10n.redesignTodayLoadFailed : l10n.redesignEventNotFound,
              icon: Icons.error_outline,
              action: RdOutlineButton(label: l10n.redesignCommonRetry, onPressed: _reload),
            ));
      return RdPage(children: children);
    }

    final type = ref.watch(attendanceTypeForAttendanceProvider(_id)).valueOrNull;
    final pultMembers = _pult ? _members() : null;
    if (pultMembers != null && pultMembers.isNotEmpty) {
      return _pultPage(attendance, pultMembers, type);
    }
    children.addAll([
      const SizedBox(height: 4),
      _Header(attendance: attendance, type: type),
      const SizedBox(height: 16),
      RdSegmented<RdEventTab>(
        values: RdEventTab.values,
        selected: _tab,
        labelOf: (t) => t == RdEventTab.overview ? l10n.redesignEventTabOverview : l10n.redesignEventTabRecord,
        onChanged: (t) => setState(() => _tab = t),
      ),
      const SizedBox(height: 16),
    ]);

    final members = _members();
    if (members == null) {
      children.add(RdInfoCard(text: l10n.redesignTodayLoading, loading: true));
    } else if (members.isEmpty) {
      children.add(RdInfoCard(
        text: l10n.redesignEventNoPersons,
        icon: Icons.group_off_outlined,
        action: RdOutlineButton(label: l10n.redesignEventMore, onPressed: () => context.push('/attendance/$_id')),
      ));
    } else if (_tab == RdEventTab.overview) {
      children.add(_Overview(
        attendance: attendance,
        members: members,
        onRecord: () => setState(() => _tab = RdEventTab.record),
      ));
    } else {
      children.addAll(_recordChildren(members, type));
    }

    return PopScope(
      canPop: !busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && busy) ToastHelper.showInfo(context, l10n.redesignEventBusyLeave);
      },
      child: Stack(
        children: [
          Focus(
            autofocus: true,
            onKeyEvent: _onKey,
            child: RdPage(
              onRefresh: () async => _reload(),
              padding: EdgeInsets.fromLTRB(20, 12, 20, _toast == null ? 32 : 96),
              children: children,
            ),
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

  /// Keys of the Anwesenheit tab: A anwesend, V verspätet, F fehlt (then
  /// the next person), ↑/↓ moves, ⌘Z / Strg+Z = Rückgängig. Typing in the
  /// search field is left alone.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (_tab != RdEventTab.record || _pult) return KeyEventResult.ignored;
    final primary = FocusManager.instance.primaryFocus;
    if (primary != null &&
        primary != node &&
        primary.context?.findAncestorWidgetOfExactType<EditableText>() != null) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final keys = HardwareKeyboard.instance;
    if (key == LogicalKeyboardKey.keyZ && (keys.isMetaPressed || keys.isControlPressed)) {
      if (_undo == null || _bulkWrites > 0) return KeyEventResult.ignored;
      _runUndo();
      return KeyEventResult.handled;
    }
    final rows = _kbRows;
    if (rows.isEmpty) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp) {
      final current = _kbIndex;
      final next = current == null
          ? 0
          : (current + (key == LogicalKeyboardKey.arrowDown ? 1 : -1)).clamp(0, rows.length - 1);
      _focusRow(next);
      return KeyEventResult.handled;
    }
    final status = switch (key) {
      LogicalKeyboardKey.keyA => AttendanceStatus.present,
      LogicalKeyboardKey.keyV => AttendanceStatus.late,
      LogicalKeyboardKey.keyF => AttendanceStatus.absent,
      _ => null,
    };
    if (status == null || keys.isMetaPressed || keys.isControlPressed || keys.isAltPressed) {
      return KeyEventResult.ignored;
    }
    if (!_kbAvailable.contains(status)) return KeyEventResult.handled;
    final index = (_kbIndex ?? 0).clamp(0, rows.length - 1);
    final member = rows[index];
    _setStatus(member, rdToggleTarget(member.status, status, initial: _initial[member.id]));
    _focusRow((index + 1).clamp(0, rows.length - 1));
    return KeyEventResult.handled;
  }

  void _focusRow(int index) {
    setState(() => _kbIndex = index);
    final id = _kbRows[index].id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rowContext = _rowKeys[id]?.currentContext;
      if (rowContext != null && rowContext.mounted) {
        Scrollable.ensureVisible(rowContext, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
        Scrollable.ensureVisible(rowContext, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart);
      }
    });
  }

  /// Pultmodus: the same state, writes and "Rückgängig", drawn as tiles.
  /// Back (gesture or button) returns to the list.
  Widget _pultPage(Attendance attendance, List<RdMember> members, AttendanceType? type) {
    final typeStatuses = type?.availableStatuses;
    final available = (typeStatuses?.isNotEmpty ?? false) ? typeStatuses! : AttendanceStatus.values;
    final canViewNotes = ref.watch(canViewAttendanceNotesProvider);
    final busy = _bulkWrites > 0;
    final title = rdEventInfo(attendance, type).title;
    void leave() => setState(() => _pult = false);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) leave();
      },
      child: Stack(
        children: [
          RdPultView(
            title: title,
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
        ),
    ];
  }

  List<Widget> _recordChildren(List<RdMember> members, AttendanceType? type) {
    final p = context.rd;
    final l10n = context.l10n;
    final typeStatuses = type?.availableStatuses;
    final available = (typeStatuses?.isNotEmpty ?? false) ? typeStatuses! : AttendanceStatus.values;
    final canViewNotes = ref.watch(canViewAttendanceNotesProvider);
    final counts = RdStatusCounts.fromStatuses(members.map((m) => m.status));
    final open = members.where((m) => m.isOpen).toList();
    final busy = _bulkWrites > 0;
    final visible = members.where((m) => rdMemberMatches(m, _query)).toList();
    _kbRows = visible;
    _kbAvailable = available;
    final kbIndex = _kbIndex == null || visible.isEmpty ? null : _kbIndex!.clamp(0, visible.length - 1);

    // Group headers like the Termin page ("Holz · 4").
    final rows = <Widget>[];
    int? group;
    var first = true;
    for (final m in visible) {
      if (first || m.person.instrument != group) {
        group = m.person.instrument;
        final size = visible.where((x) => x.person.instrument == group).length;
        rows.add(Padding(
          padding: EdgeInsets.only(top: first ? 0 : 14),
          child: RdGroupLabel('${m.groupName ?? l10n.attendanceNoGroup} · $size'),
        ));
        first = false;
      }
      final focused = kbIndex != null && visible[kbIndex].id == m.id;
      rows.add(RdCard(
        key: _rowKeys.putIfAbsent(m.id, GlobalKey.new),
        padding: EdgeInsets.zero,
        border: focused ? Border.all(color: p.primary, width: 2) : null,
        child: RdRecordRow(
          key: ValueKey('rd-record-${m.id}'),
          member: m,
          available: available.toSet(),
          showNote: canViewNotes,
          onTap: (s) => _setStatus(m, rdToggleTarget(m.status, s, initial: _initial[m.id])),
          onMore: () => _openStatusSheet(m, available, canViewNotes),
        ),
      ));
      rows.add(const SizedBox(height: 6));
    }

    return [
      RdRecordCounts(counts: counts),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerLeft,
        child: Tooltip(
          message: l10n.redesignPultOpenHint,
          child: RdPillButton(
            icon: Icons.grid_view_rounded,
            label: l10n.redesignPultOpen,
            onPressed: () => setState(() {
              _pult = true;
              _searching = false;
              _search.clear();
              _query = '';
            }),
          ),
        ),
      ),
      if (available.contains(AttendanceStatus.present)) ...[
        const SizedBox(height: 12),
        RdOutlineButton(
          label: busy ? l10n.redesignEventSaving : l10n.redesignEventAllOpenPresent,
          icon: Icons.done_all,
          color: p.present,
          height: 44,
          onPressed: open.isEmpty || busy ? null : () => _allOpenPresent(open),
        ),
      ],
      if (_searching) ...[
        const SizedBox(height: 12),
        TextField(
          controller: _search,
          autofocus: true,
          onChanged: (v) => setState(() => _query = v),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.redesignEventSearchHint,
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: p.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(p.buttonRadius),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
      const SizedBox(height: 16),
      if (visible.isEmpty) RdInfoCard(text: l10n.redesignEventNoMatch, icon: Icons.search_off),
      ...rows,
      // Tablets with a keyboard and desktops.
      if (MediaQuery.sizeOf(context).width >= 840 && visible.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text(l10n.redesignEventKeyboardHint, textAlign: TextAlign.center, style: RdType.meta(p, size: 13)),
      ],
    ];
  }
}

/// Type and day, title, date · time · place.
class _Header extends StatelessWidget {
  const _Header({required this.attendance, required this.type});

  final Attendance attendance;
  final AttendanceType? type;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final info = rdEventInfo(attendance, type);
    final start = info.start;
    final locale = currentIntlLocale();
    String day(DateTime d) =>
        '${DateFormat.E(locale).format(d).replaceAll('.', '')} ${DateFormat.MMMd(locale).format(d)}';
    final days = attendance.durationDays ?? 1;
    final date = start == null
        ? ''
        : days > 1
            ? '${day(start)} – ${day(rdAddDays(start, days - 1))}'
            : day(start);
    final meta = [date, info.timeRange, info.place].where((s) => s.isNotEmpty).join(' · ');
    final ended = EventListUtils.hasEnded(attendance.date, attendance.durationDays);
    final relative = start == null || ended ? null : rdRelativeDay(l10n, start);
    final showRelative = relative == l10n.redesignTodayDayToday || relative == l10n.redesignTodayDayTomorrow;
    final typeName = type?.name ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (typeName.isNotEmpty || showRelative)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (typeName.isNotEmpty) RdPill(typeName, tone: RdTone.primary),
              if (showRelative) RdPill(relative!, tone: RdTone.late),
            ],
          ),
        const SizedBox(height: 8),
        Semantics(header: true, child: Text(info.title, style: RdType.title(p))),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(meta, style: RdType.meta(p, size: 15)),
        ],
      ],
    );
  }
}

/// Canvas D4: answers, empty registers, sign-outs, notes, all details.
class _Overview extends ConsumerWidget {
  const _Overview({required this.attendance, required this.members, required this.onRecord});

  final Attendance attendance;
  final List<RdMember> members;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final canViewNotes = ref.watch(canViewAttendanceNotesProvider);
    final counts = RdStatusCounts.fromStatuses(members.map((m) => m.status));
    final ended = EventListUtils.hasEnded(attendance.date, attendance.durationDays);
    final gaps = ended ? const <RdRegisterGap>[] : rdRegisterGaps(members);
    final signouts = rdSignouts(members);
    final notes = (attendance.notes ?? '').trim();
    final legend = [
      (l10n.redesignTodayCountYes(counts.present), p.present),
      if (counts.excused > 0) (l10n.redesignTodayCountExcused(counts.excused), p.excused),
      if (counts.lateAnnounced > 0) (l10n.redesignTodayCountLater(counts.lateAnnounced), p.late),
      if (counts.absent > 0) (l10n.redesignTodayCountAbsent(counts.absent), p.absent),
      if (counts.open > 0) (l10n.redesignEventCountNoAnswer(counts.open), p.text2),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(l10n.redesignEventAnswers, style: RdType.section(p))),
                  Text(l10n.redesignEventInvited(counts.total), style: RdType.meta(p, size: 13)),
                ],
              ),
              const SizedBox(height: 12),
              RdStatusBar(
                total: counts.total,
                segments: [
                  RdBarSegment(counts.present, p.present),
                  RdBarSegment(counts.lateAnnounced, p.late),
                  RdBarSegment(counts.excused, p.excused),
                  RdBarSegment(counts.absent, p.absent),
                ],
                semanticLabel: legend.map((e) => e.$1).join(', '),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  for (final (text, color) in legend)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(text, style: RdType.meta(p, size: 14).copyWith(color: p.text)),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 16),
              RdPrimaryButton(
                label: l10n.redesignTodayRecord,
                icon: Icons.checklist_rounded,
                onPressed: onRecord,
              ),
            ],
          ),
        ),
        for (final gap in gaps) ...[
          const SizedBox(height: 12),
          RdCard(
            color: p.absentSoft,
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: p.absent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: l10n.redesignEventRegisterEmpty(gap.group, gap.members.length),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const TextSpan(text: ' '),
                        TextSpan(
                          text: l10n.redesignEventRegisterNames(
                            gap.members.length,
                            gap.members.map((m) => m.name).join(', '),
                          ),
                        ),
                      ],
                    ),
                    style: TextStyle(fontSize: 14, color: p.text),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (signouts.isNotEmpty) ...[
          const SizedBox(height: 24),
          RdGroupLabel(l10n.redesignEventSignouts),
          RdGroupedList(
            children: [
              for (final m in signouts)
                RdListRow(
                  title: m.name,
                  subtitle: [
                    m.groupName ?? '',
                    if (canViewNotes && (m.note ?? '').trim().isNotEmpty) '„${m.note!.trim()}“',
                  ].where((s) => s.isNotEmpty).join(' · '),
                  showChevron: false,
                  trailing: RdPill(
                    m.status == AttendanceStatus.excused ? l10n.redesignStatusExcused : l10n.redesignStatusLater,
                    tone: m.status == AttendanceStatus.excused ? RdTone.excused : RdTone.late,
                  ),
                ),
            ],
          ),
        ],
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 24),
          RdGroupLabel(l10n.attendanceNotes),
          RdCard(
            padding: const EdgeInsets.all(14),
            child: Text(notes, style: RdType.body(p)),
          ),
        ],
        const SizedBox(height: 24),
        RdGroupedList(
          children: [
            RdListRow(
              leading: const RdRowIcon(Icons.tune),
              title: l10n.redesignEventMore,
              subtitle: l10n.redesignEventMoreHint,
              onTap: () => context.push('/attendance/${attendance.id}'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Plain text link in the header ("Alle Details").
class _TextLink extends StatelessWidget {
  const _TextLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 17, color: p.link),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
