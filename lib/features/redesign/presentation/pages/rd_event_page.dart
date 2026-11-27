import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/providers/attendance_detail_providers.dart';
import '../../../../core/providers/attendance_providers.dart';
import '../../../../core/providers/attendance_type_providers.dart' show attendanceTypesProvider;
import '../../../../core/providers/church_providers.dart';
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/providers/role_permission_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/services/offline_queue_service.dart' show offlineQueueNotifierProvider, rootScaffoldMessengerKey;
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/archived_attendance.dart';
import '../../../../core/utils/demo_guard.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/event_list_utils.dart';
import '../../../../core/utils/haptic_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../data/models/church/church.dart';
import '../../../../data/models/person/person.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart' show AppActionSheetAction, AppAlertDialog, showAppActionSheet, showAppDialog;
import '../../../../shared/widgets/adaptive/ion_loading.dart' show showIonLoading;
import '../../../../shared/widgets/event_list/excuse_reason_sheet.dart' show registrationAnswerText;
import '../../../attendance/presentation/attendance_group_sort.dart'
    show mainGroupIdOf, sortPersonsByGroup;
import '../../../attendance/presentation/attendance_permissions.dart' show canMutateAttendanceDetail;
import '../../../attendance/presentation/attendance_status_labels.dart'
    show ionicStatusLabel;
import '../../../attendance/presentation/person_attendance_writes.dart';
import '../../data/providers/rd_events_providers.dart' show rdUpcomingCountsProvider;
import '../../data/providers/rd_today_providers.dart';
import '../../data/rd_event_logic.dart';
import '../../data/providers/rd_phase_tick_provider.dart';
import '../../data/rd_event_phase.dart';
import '../../data/rd_words.dart';
import '../../data/rd_write_queue.dart';
import '../../../../core/providers/team_org_providers.dart' show protocolTypeByIdProvider;
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/services/export_service.dart';
import '../../../attendance/presentation/attendance_add_persons.dart';
import '../../../attendance/presentation/attendance_extra_actions.dart';
import '../../../../core/providers/profile_providers.dart';
import '../../../duty/presentation/widgets/duty_staffing_section.dart';
import '../../../team_organization/presentation/widgets/attendance_protocol_section.dart';
import '../widgets/event/rd_event_answers.dart';
import '../widgets/event/rd_event_sections.dart';
import '../widgets/event/rd_pult_view.dart';
import '../widgets/today/rd_player_today.dart' show RdOwnAnswerRow, rdOwnEntryFor;
import '../widgets/today/rd_remind_open_sheet.dart';
import '../widgets/event/rd_record_widgets.dart';
import '../widgets/rd_desktop.dart';
import '../widgets/rd_split_view.dart';
import '../widgets/rd_widgets.dart';
import '../widgets/event/rd_event_head.dart';
import '../widgets/event/rd_event_now.dart';
import '../widgets/event/rd_new_person_sheet.dart' show createPersonForAttendance;
import '../../../planning/presentation/attendance_plan_viewer.dart' show attendanceHasPlan, openAttendancePlanViewer;
import '../widgets/today/rd_today_common.dart';

part 'rd_event_page_overview.dart';
part 'rd_event_page_record.dart';
part 'rd_event_page_writes.dart';

/// Tabs of a Termin in the new design.
enum RdEventTab { overview, program, record }

/// REDESIGN: a Termin for Dirigent and Helfer (canvas D4 "Überblick", D5
/// "Anwesenheit" with Rückgängig; concept "Termin-Bereich neu", Schritt 1:
/// sign-outs in the answers card, Anwesenheit shows only the exceptions
/// per voice, person sheet, ••• menu, Abschluss). Statuses and notes are
/// written through the Termin page's write path ([PersonAttendanceWriter],
/// as in [writePersonStatus] and [writePersonAttendance]).
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

/// Entries of the ••• menu.
enum _MenuAction { church, excel, telegram, archive }

/// Days of [attendance], with the type's default for all-day types (a
/// Freizeit without own `duration_days` still runs on day 2).
int? _effectiveDays(Attendance attendance, AttendanceType? type) => rdEffectiveDurationDays(
      attendance.durationDays,
      typeAllDay: type?.allDay ?? false,
      typeDurationDays: type?.durationDays,
    );

/// What "Rückgängig" restores: the previous status per person.
class _Undo {
  const _Undo(this.text, this.previous);

  final String text;
  final Map<int, AttendanceStatus> previous;
}

class _RdEventPageState extends ConsumerState<RdEventPage> {
  void _update(VoidCallback fn) => setState(fn);

  late RdEventTab _tab = widget.initialTab;

  /// Thumb position of the Reiter while swiping between them.
  final _swipePos = ValueNotifier<double?>(null);

  /// Desktop: Überblick and Anwesenheit side by side (no tabs).
  bool _sideBySide = false;

  // Like the Termin page: the shown status per person (local changes win
  // while a write is in flight), the row ids and the notes.
  final Map<int, AttendanceStatus> _statuses = {};
  final Map<int, AttendanceStatus> _initial = {};
  final Map<int, String?> _paIds = {};
  final Map<int, String?> _notes = {};
  final Map<int, String?> _changedAt = {};
  final Map<int, String?> _changedBy = {};
  final Map<int, Map<String, dynamic>?> _regAnswers = {};
  /// Writes in flight per person (from the tap on, so a refetch that
  /// arrives meanwhile cannot show the old status again).
  final Map<int, int> _saving = {};
  late final RdWriteQueue _queue;
  Set<int>? _rowPersonIds;

  /// person_attendances removed on this device ("Aus Termin entfernen"),
  /// like the Termin page's `_ownDeletedPaIds`: a reload that still has
  /// the row (cache, realtime) must not bring the person back.
  final Set<String> _ownDeletedPaIds = {};

  ProviderSubscription<AsyncValue<List<PersonAttendance>>>? _rowsSub;
  AppLifecycleListener? _lifecycle;
  Timer? _reloadDebounce;
  Timer? _undoTimer;
  _Undo? _undo;
  String? _toast;
  int _bulkWrites = 0;
  bool _isSendingTelegramCard = false;

  String _query = '';

  /// Anwesenheit: chosen filter chip, voices opened with "Zeigen" and the
  /// persons changed here (they stay in the list of exceptions, also when
  /// set to Anwesend, so a row does not jump away under the finger).
  RdRecordFilter _filter = RdRecordFilter.all;
  final Set<int?> _expanded = {};
  final Set<int> _pinned = {};

  /// Pultmodus: big tiles instead of the list (rd_pult_view.dart).
  bool _pult = false;

  // Keyboard (canvas "Desktop"): the person the keys act on (by id, so a
  // filter that drops a changed row does not skip the next one), the rows
  // shown and their keys for scrolling.
  int? _kbId;
  List<RdMember> _kbRows = const [];
  List<AttendanceStatus> _kbAvailable = const [];
  final Map<int, GlobalKey> _rowKeys = {};
  final _search = TextEditingController();

  int get _id => widget.attendanceId;

  @override
  void initState() {
    super.initState();
    _queue = ref.read(rdWriteQueueProvider);
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
    _swipePos.dispose();
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    ref.invalidate(attendanceDetailProvider(_id));
    ref.invalidate(personAttendancesForAttendanceProvider(_id));
  }

  void _applyRows(List<PersonAttendance> allRows) {
    if (!mounted) return;
    final rows = _ownDeletedPaIds.isEmpty
        ? allRows
        : [for (final pa in allRows) if (!_ownDeletedPaIds.contains(pa.id)) pa];
    setState(() {
      for (final pa in rows) {
        final personId = pa.personId;
        if (personId == null) continue;
        _paIds[personId] = pa.id;
        _changedAt[personId] = pa.changedAt;
        _changedBy[personId] = pa.changedBy;
        _regAnswers[personId] = pa.registrationAnswers;
        _initial.putIfAbsent(personId, () => pa.status);
        // Status and note only when not being changed here right now.
        if (!_saving.containsKey(personId)) {
          _statuses[personId] = pa.status;
          _notes[personId] = pa.notes;
        }
        if (pa.id case final rowId? when !_queue.isBusy(rowId)) _queue.markStored(rowId, pa.status);
      }
      _rowPersonIds = {for (final pa in rows) if (pa.personId != null) pa.personId!};
    });
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  /// Whether the Reiter Programm has something: the Ablauf (everyone but
  /// Beobachter; editors can create one). The Werke are in the Überblick.
  bool _hasProgramTab(Attendance attendance) {
    final role = ref.watch(effectiveRoleProvider);
    if (role == Role.viewer) return false;
    return attendanceHasPlan(attendance) || role.canEdit;
  }

  /// Reiter Programm: the Ablauf as a list with "Bearbeiten", the hint
  /// about Werke that are not in it yet and "Für Mitglieder sichtbar".
  List<Widget> _programChildren(Attendance attendance, AttendanceType? type) {
    final plan = rdPlanOf(attendance);
    return [
      RdEventPlanSection(
        attendance: attendance,
        type: type,
        preview: plan == null ? null : RdPlanTimeline(day: EventListUtils.parse(attendance.date), plan: plan),
        end: plan == null ? '' : rdPlanEnd(plan),
        freeMinutes: plan == null ? null : rdPlanFreeMinutes(plan, _span(attendance, type)),
      ),
    ];
  }

  /// Start and end of the Termin (times of the Termin, else of its type).
  ({DateTime start, DateTime end, bool hasTime})? _span(Attendance attendance, AttendanceType? type) => rdEventSpan(
        day: EventListUtils.parse(attendance.date),
        startTime: attendance.startTime ?? type?.startTime,
        endTime: attendance.endTime ?? type?.endTime,
        durationDays: _effectiveDays(attendance, type),
      );

  /// Type and phase, title, date · time · place (the same head as on the
  /// members' Termin page).
  Widget _head(Attendance attendance, AttendanceType? type) {
    final info = rdEventInfo(attendance, type);
    final span = _span(attendance, type);
    // Head and top card follow the phase without new data.
    if (span != null) ref.watch(rdPhaseTickProvider((start: span.start, end: span.end)));
    return RdEventHead(
      title: info.title,
      phase: rdEventPhase(span, archived: attendance.archived),
      span: span,
      typeName: type?.name,
      typeHighlight: type?.highlight ?? false,
      timeRange: info.timeRange,
      place: info.place,
      durationDays: _effectiveDays(attendance, type),
    );
  }

  /// This Termin as the Termine list holds it (null when the list is not
  /// loaded, e.g. after a link straight to the Termin). Read only when the
  /// list is alive: the page never starts the list's subscription.
  Attendance? _listed() {
    if (!ref.exists(realtimeAttendanceListProvider)) return null;
    final tenantId = ref.read(currentTenantProvider)?.id;
    final list = ref.read(realtimeAttendanceListProvider).valueOrNull ?? const <Attendance>[];
    return list.where((a) => a.id == _id && a.tenantId == tenantId).firstOrNull;
  }

  /// The answers the list or Heute counted for this Termin, if any.
  RdStatusCounts? _listedCounts() {
    if (ref.exists(rdUpcomingCountsProvider)) {
      final counts = ref.read(rdUpcomingCountsProvider).valueOrNull?[_id];
      if (counts != null) return counts;
    }
    if (ref.exists(rdAttendanceCountsProvider(_id))) return ref.read(rdAttendanceCountsProvider(_id)).valueOrNull;
    return null;
  }

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
    // counter on every attendance and person_attendances update): reload
    // the Termin too, so time, place and notes stay current without a pull
    // (the desktop columns have none).
    ref.listen<int>(attendanceRefetchCounter, (_, __) {
      _reloadDebounce?.cancel();
      _reloadDebounce = Timer(const Duration(milliseconds: 400), _reload);
    });

    final attendanceAsync = ref.watch(attendanceDetailProvider(_id));
    final attendance = attendanceAsync.valueOrNull;
    final busy = _bulkWrites > 0;
    final members = attendance == null ? null : _members();
    // Gemeinde-Übersicht in the ••• menu only where persons have a BFECG
    // Gemeinde field (read when the menu opens).
    ref.watch(personExtraFieldsProvider);

    final children = <Widget>[
      Row(
        children: [
          Expanded(
            child: RdSplitScope.of(context)?.isDetail ?? false
                ? const SizedBox(height: 44)
                : RdBackLink(label: l10n.redesignTabEvents, onTap: _back),
          ),
          RdTextLink(
            key: const Key('rd-event-edit'),
            label: l10n.redesignEventEdit,
            onTap: () => context.push(RedesignRoutes.eventEdit(_id)),
          ),
          if (attendance != null && members != null && _menuHasActions(attendance, members)) ...[
            const SizedBox(width: 4),
            RdCircleButton(
              key: const Key('rd-event-menu'),
              icon: Icons.more_horiz,
              label: l10n.redesignEventMenu,
              onPressed: () => _openMenu(attendance, members),
            ),
          ],
        ],
      ),
    ];

    if (attendance == null) {
      // While the Termin loads: its head (and the answers already counted)
      // from the list the user came from, the rest keeps its place.
      final listed = attendanceAsync.isLoading ? _listed() : null;
      if (listed != null) {
        final types = ref.watch(attendanceTypesProvider).valueOrNull ?? const <AttendanceType>[];
        final type = types.where((t) => t.id == listed.typeId).firstOrNull;
        children.addAll([
          const SizedBox(height: 4),
          _head(listed, type),
          const SizedBox(height: 16),
          _LoadingAnswers(counts: _listedCounts()),
        ]);
        return RdPage(children: children);
      }
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
    // Reiter Programm: the Ablauf (not for roles that do not see it).
    final hasProgram = _hasProgramTab(attendance);
    final tabs = [
      RdEventTab.overview,
      if (hasProgram) RdEventTab.program,
      RdEventTab.record,
    ];
    final tab = tabs.contains(_tab) ? _tab : RdEventTab.overview;
    // Desktop (wide detail column): Überblick and Programm on the left, the
    // Anwesenheit on the right instead of three tabs.
    final wide = members != null && members.isNotEmpty && rdEventSideBySide(context);
    _sideBySide = wide;
    // Who leads or helps and is part of the Termin: the own answer on this
    // page too ("Ändern" opens the own Termin page), not on a second page
    // only.
    final ownEntry = ref.watch(effectiveRoleProvider).canSeeSelfServiceTab
        ? rdOwnEntryFor(ref.watch(rdSignoutDataProvider).valueOrNull, _id, attendance.tenantId)
        : null;
    children.addAll([
      const SizedBox(height: 4),
      _head(attendance, type),
      const SizedBox(height: 16),
      if (ownEntry != null) ...[
        RdOwnAnswerRow(attendance: ownEntry, label: l10n.rdTextYourAnswer),
        const SizedBox(height: 16),
      ],
      if (!wide) ...[
        ValueListenableBuilder<double?>(
          valueListenable: _swipePos,
          builder: (context, pos, _) => RdSegmented<RdEventTab>(
            values: tabs,
            selected: tab,
            position: pos,
            labelOf: (t) => switch (t) {
              RdEventTab.overview => l10n.redesignEventTabOverview,
              RdEventTab.program => l10n.redesignEventTabProgram,
              RdEventTab.record => l10n.redesignEventTabRecord,
            },
            onChanged: (t) => setState(() => _tab = t),
          ),
        ),
        const SizedBox(height: 16),
      ],
    ]);

    Widget overview(List<RdMember> members, {bool sideBySide = false}) {
      final span = _span(attendance, type);
      return _Overview(
        attendance: attendance,
        type: type,
        members: members,
        personAttendanceIds: _paIds,
        span: span,
        phase: rdEventPhase(span, archived: attendance.archived),
        sideBySide: sideBySide,
        onRecord: (filter) => setState(() {
          _tab = RdEventTab.record;
          _filter = filter;
        }),
        onPult: () => setState(() {
          _tab = RdEventTab.record;
          _pult = true;
          _search.clear();
          _query = '';
        }),
        onOpenMember: _openMember,
      );
    }

    final bottom = _toast == null ? 32.0 : 96.0;
    final Widget body;
    if (wide) {
      body = RdEventColumns(
        header: children,
        left: [
          overview(members, sideBySide: true),
          if (hasProgram) ...[
            const SizedBox(height: 24),
            ..._programChildren(attendance, type),
          ],
        ],
        right: _recordChildren(members, type),
        bottomPadding: bottom,
        onRefresh: () async => _reload(),
      );
    } else {
      final content = <Widget>[];
      if (tab == RdEventTab.program) {
        content.addAll(_programChildren(attendance, type));
      } else if (members == null) {
        // The persons load last: the answers the list counted show meanwhile.
        content.add(_LoadingAnswers(counts: _listedCounts()));
      } else if (members.isEmpty) {
        final canMutate = canMutateAttendanceDetail(ref.watch(effectiveRoleProvider));
        content.add(RdInfoCard(
          text: l10n.redesignEventNoPersons,
          icon: Icons.group_off_outlined,
          action: canMutate
              ? RdOutlineButton(
                  label: l10n.attendanceAddPerson,
                  onPressed: _addPersons,
                )
              : null,
        ));
        // Programm and Ablauf can be prepared before anyone is invited
        // (Reiter Programm), the Vorbereitung too (Überblick).
        final phase = rdEventPhase(_span(attendance, type), archived: attendance.archived);
        final over = phase == RdEventPhase.after ||
            (phase == RdEventPhase.archived &&
                EventListUtils.hasEnded(attendance.date, _effectiveDays(attendance, type)));
        if (tab == RdEventTab.overview &&
            _showPrep(attendance, over: over, canMutate: canMutate, canView: ref.watch(canViewAttendanceChecklistProvider))) {
          content.addAll([
            const SizedBox(height: 24),
            RdEventChecklistSection(attendance: attendance, type: type, canEdit: canMutate),
          ]);
        }
        if (tab == RdEventTab.overview && rdShowsProgram(ref, type) && attendance.id != null) {
          content.add(RdEventProgramSection(attendance: attendance, type: type, ended: over));
        }
      } else if (tab == RdEventTab.overview) {
        content.add(overview(members));
      } else {
        content.addAll(_recordChildren(members, type));
      }
      // Swipe between Überblick, Programm and Anwesenheit (the segmented
      // control stays the main way; the left edge stays the back gesture).
      children.add(RdSwipeSwitch<RdEventTab>(
        key: const Key('rd-event-swipe'),
        values: tabs,
        selected: tab,
        onChanged: (t) => setState(() => _tab = t),
        onDrag: (pos) => _swipePos.value = pos,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: content,
        ),
      ));
      body = RdPage(
        onRefresh: () async => _reload(),
        padding: EdgeInsets.fromLTRB(20, 12, 20, bottom),
        children: children,
      );
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
            child: body,
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
    if ((_tab != RdEventTab.record && !_sideBySide) || _pult) return KeyEventResult.ignored;
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
    final current = rows.indexWhere((m) => m.id == _kbId);
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp) {
      final next = current < 0
          ? 0
          : (current + (key == LogicalKeyboardKey.arrowDown ? 1 : -1)).clamp(0, rows.length - 1);
      _focusRow(rows[next].id);
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
    final index = current < 0 ? 0 : current;
    final member = rows[index];
    // The next person is chosen before the write: with a status filter the
    // changed row leaves the list.
    final nextId = index + 1 < rows.length ? rows[index + 1].id : member.id;
    _setStatus(member, rdToggleTarget(member.status, status, initial: _initial[member.id]));
    _focusRow(nextId);
    return KeyEventResult.handled;
  }

  void _focusRow(int id) {
    setState(() => _kbId = id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rowContext = _rowKeys[id]?.currentContext;
      if (rowContext != null && rowContext.mounted) {
        Scrollable.ensureVisible(rowContext, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
        Scrollable.ensureVisible(rowContext, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart);
      }
    });
  }
}
