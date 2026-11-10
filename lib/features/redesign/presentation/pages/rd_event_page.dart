import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/providers/attendance_detail_providers.dart';
import '../../../../core/providers/attendance_providers.dart';
import '../../../../core/providers/church_providers.dart';
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/providers/role_permission_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/services/offline_queue_service.dart' show offlineQueueNotifierProvider, rootScaffoldMessengerKey;
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/archived_attendance.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/event_list_utils.dart';
import '../../../../core/utils/haptic_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../data/models/church/church.dart';
import '../../../../data/models/person/person.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart' show AppActionSheetAction, showAppActionSheet;
import '../../../../shared/widgets/event_list/excuse_reason_sheet.dart' show registrationAnswerText;
import '../../../attendance/presentation/person_attendance_writes.dart';
import '../../../attendance/presentation/widgets/attendance_detail/attendance_grid.dart'
    show mainGroupIdOf, sortPersonsByGroup;
import '../../../attendance/presentation/widgets/attendance_detail/status_chip.dart'
    show ionicStatusLabel;
import '../../data/providers/rd_today_providers.dart';
import '../../data/rd_event_logic.dart';
import '../../data/providers/rd_phase_tick_provider.dart';
import '../../data/rd_event_phase.dart';
import '../../data/rd_write_queue.dart';
import '../../../../core/providers/team_org_providers.dart' show protocolTypeByIdProvider;
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/services/export_service.dart';
import '../../../attendance/presentation/attendance_add_persons.dart';
import '../../../attendance/presentation/attendance_extra_actions.dart';
import '../../../../core/providers/profile_providers.dart';
import '../../../attendance/presentation/pages/attendance_detail_page.dart' show canMutateAttendanceDetail;
import '../../../duty/presentation/widgets/duty_staffing_section.dart';
import '../../../team_organization/presentation/widgets/attendance_protocol_section.dart';
import '../widgets/event/rd_event_answers.dart';
import '../widgets/event/rd_event_sections.dart';
import '../widgets/event/rd_pult_view.dart';
import '../widgets/today/rd_remind_open_sheet.dart';
import '../widgets/event/rd_record_widgets.dart';
import '../widgets/rd_desktop.dart';
import '../widgets/rd_split_view.dart';
import '../widgets/rd_widgets.dart';
import '../widgets/event/rd_event_head.dart';
import '../widgets/event/rd_event_now.dart';
import '../../../planning/presentation/attendance_plan_viewer.dart' show attendanceHasPlan, openAttendancePlanViewer;
import '../widgets/today/rd_today_common.dart';

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
enum _MenuAction { church, excel, archive }

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
  // Writes
  // ---------------------------------------------------------------------------

  void _hold(int personId) => _saving[personId] = (_saving[personId] ?? 0) + 1;

  void _release(int personId) {
    final left = (_saving[personId] ?? 1) - 1;
    if (left <= 0) {
      _saving.remove(personId);
    } else {
      _saving[personId] = left;
    }
  }

  /// Writes one status; reverts and reports when it could not be saved.
  /// [writer] is bound and the change number ([rev], else taken now) is
  /// taken when the user acted: the write waits in [RdWriteQueue] behind
  /// earlier writes of the row (also of a page that was left) and still
  /// completes after this page was left.
  Future<bool> _write(
    PersonAttendanceWriter writer,
    int personId,
    AttendanceStatus status,
    AttendanceStatus previous, {
    int? rev,
    bool refresh = true,
  }) async {
    final paId = _paIds[personId];
    if (paId == null) {
      if (mounted) setState(() => _statuses[personId] = previous);
      return false;
    }
    final queue = _queue;
    final change = rev ?? queue.nextRev(paId);
    bool newest() => queue.isNewest(paId, change);
    // Back to what is stored, not to an in-between choice never written.
    void revert() {
      if (mounted && newest()) setState(() => _statuses[personId] = queue.stored(paId) ?? previous);
    }

    _hold(personId);
    try {
      final result = await queue.run(
        paId,
        // A newer change of this row follows in the queue and wins.
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
      queue.markStored(paId, status);
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
    final revs = {
      for (final id in targets.keys)
        if (_paIds[id] case final paId?) id: _queue.nextRev(paId),
    };
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
              rev: revs[e.key],
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
    setState(() {
      _statuses[member.id] = status;
      _pinned.add(member.id);
    });
    final l10n = context.l10n;
    final text = status == AttendanceStatus.neutral
        ? l10n.redesignEventToastReset(member.name)
        : l10n.redesignEventToastSet(member.name, ionicStatusLabel(status));
    _showToast(text, undo: _Undo(text, {member.id: previous}));
    _write(PersonAttendanceWriter(ref), member.id, status, previous);
  }

  void _allOpenPresent(List<RdMember> open) {
    if (open.isEmpty) return;
    HapticHelper.light();
    final previous = {for (final m in open) m.id: m.status};
    // Not pinned: after the bulk button the list of exceptions stays short
    // (pinning only keeps a single changed row from jumping away).
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

  /// The person sheet: status, note, registration answers, "Zur Person",
  /// "Aus Termin entfernen" and who changed it last (the last two not for
  /// Helfer, like the Termin page).
  Future<void> _openStatusSheet(RdMember member, List<AttendanceStatus> available, bool canEditNote) async {
    final l10n = context.l10n;
    final role = ref.read(effectiveRoleProvider);
    final isHelper = role == Role.helper;
    final type = ref.read(attendanceTypeForAttendanceProvider(_id)).valueOrNull;
    final result = await showRdStatusSheet(
      context,
      member: member,
      subtitle: member.groupName ?? l10n.attendanceNoGroup,
      available: available,
      canEditNote: canEditNote,
      registration: _registrationOf(member.id, type),
      changedInfo: isHelper ? null : _changedInfo(member),
      canOpenPerson: role.canSeePeopleTab,
      canRemove: !isHelper && canMutateAttendanceDetail(role),
    );
    if (result == null || !mounted) return;
    if (result.action == RdPersonSheetAction.remove) {
      await _removePerson(member);
      return;
    }
    if (result.status != member.status) _setStatus(member, result.status);
    final note = result.note ?? '';
    if (canEditNote && note != (member.note ?? '')) await _writeNote(member, note);
    if (result.action == RdPersonSheetAction.openPerson && mounted) {
      context.push(RedesignRoutes.person(member.id));
    }
  }

  /// Opens the person sheet for [member] as currently shown.
  void _openMember(RdMember member) {
    final type = ref.read(attendanceTypeForAttendanceProvider(_id)).valueOrNull;
    final typeStatuses = type?.availableStatuses;
    final available = (typeStatuses?.isNotEmpty ?? false) ? typeStatuses! : AttendanceStatus.values;
    _openStatusSheet(member, available, ref.read(canViewAttendanceNotesProvider));
  }

  /// "Mitfahrt: nein · Essen: normal" (the Termin page's registration
  /// summary); null without answers.
  String? _registrationOf(int personId, AttendanceType? type) {
    final fields = type?.registrationFields ?? const <RegistrationField>[];
    final answers = _regAnswers[personId];
    if (fields.isEmpty || answers == null || answers.isEmpty) return null;
    final parts = <String>[];
    for (final f in fields) {
      final value = answers[f.id];
      if (value == null) continue;
      final text = registrationAnswerText(f, value);
      parts.add('${f.label}: ${text.isEmpty ? '–' : text}');
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// "Zuletzt geändert von Leon Jäger · Do 26.11., 19:41" (Ionic
  /// getModifierInfo); null while the status was never changed.
  String? _changedInfo(RdMember member) {
    final by = member.changedBy;
    if (by == null) return null;
    final l10n = context.l10n;
    final persons = ref.read(filteredPersonsForAttendanceProvider(_id)).valueOrNull ?? const <Person>[];
    final modifier = persons.where((p) => p.appId == by).firstOrNull;
    final name = modifier != null && modifier.fullName.trim().isNotEmpty ? modifier.fullName.trim() : l10n.commonUnknown;
    final at = member.changedAt == null ? null : DateTime.tryParse(member.changedAt!)?.toLocal();
    return at == null ? l10n.attendanceLastChangedBy(name) : l10n.redesignEventChangedBy(name, rdDeadlineLabel(at));
  }

  /// "Aus Termin entfernen" (Termin page `_removePersonFromAttendance`):
  /// asks, checks the row's tenant, deletes the row.
  Future<void> _removePerson(RdMember member) async {
    final l10n = context.l10n;
    // Bound before the dialog (tenant switch safety); the container
    // outlives this page.
    final repo = ref.read(attendanceRepositoryWithTenantProvider);
    final session = ref.read(offlineQueueNotifierProvider.notifier).captureWriteSession();
    final container = ProviderScope.containerOf(context, listen: false);
    final paId = _paIds[member.id];
    if (paId == null) {
      ToastHelper.showError(context, l10n.attendanceFlutterNoEntry);
      return;
    }
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: l10n.attendanceRemovePerson,
      message: l10n.attendanceRemovePersonConfirm(member.name),
      confirmText: l10n.commonRemove,
      isDestructive: true,
    );
    if (!confirmed || !mounted || !session.isCurrent()) return;
    try {
      if (!repo.hasTenantId || !await repo.validatePersonAttendanceTenant(paId)) {
        if (mounted) ToastHelper.showError(context, l10n.attendanceFlutterNoPermission);
        return;
      }
      // Account switched while the check ran: never delete for the new one.
      if (!session.isCurrent()) return;
      _ownDeletedPaIds.add(paId);
      await repo.deletePersonAttendance(paId);
    } catch (e) {
      _ownDeletedPaIds.remove(paId);
      if (mounted) ToastHelper.showError(context, l10n.attendancePersonRemoveFailed);
      return;
    }
    container.invalidate(personAttendancesForAttendanceProvider(_id));
    // The Termin list's realtime channel only sees updates, not deletes:
    // reload it so its counts and percentages drop the person too.
    container.read(attendanceRefetchCounter.notifier).state++;
    if (!mounted) return;
    setState(() {
      _rowPersonIds = {...?_rowPersonIds}..remove(member.id);
      _statuses.remove(member.id);
      _paIds.remove(member.id);
      _notes.remove(member.id);
      _pinned.remove(member.id);
    });
    ToastHelper.showSuccess(context, l10n.attendancePersonRemoved);
  }

  // ---------------------------------------------------------------------------
  // ••• menu
  // ---------------------------------------------------------------------------

  /// "•••" next to "Bearbeiten" (concept L6): Status-Übersicht,
  /// Gemeinde-Übersicht, Excel, Archivieren. The Vorbereitung lives in the
  /// Überblick, the answers per status in the Anwesenheit.
  /// "Termin löschen" is at the bottom of "Bearbeiten".
  Future<void> _openMenu(Attendance attendance, List<RdMember> members) async {
    final l10n = context.l10n;
    final role = ref.read(effectiveRoleProvider);
    final type = ref.read(attendanceTypeForAttendanceProvider(_id)).valueOrNull;
    final canArchive = canArchiveAttendance(
      date: attendance.date,
      durationDays: _effectiveDays(attendance, type),
      archived: attendance.archived,
      role: role,
    );
    final action = await showAppActionSheet<_MenuAction>(
      context,
      title: rdEventInfo(attendance, type).title,
      message: role.isAdmin || role.isResponsible ? l10n.redesignEventDeleteHint : null,
      actions: [
        // Like Ionic: offered whenever the group has the Gemeinde field.
        if (members.isNotEmpty && attendanceChurchFieldId(ref) != null)
          AppActionSheetAction(
            value: _MenuAction.church,
            icon: Icons.business_outlined,
            label: l10n.attendanceChurchOverview,
          ),
        if (members.isNotEmpty)
          AppActionSheetAction(
            value: _MenuAction.excel,
            icon: Icons.table_chart_outlined,
            label: l10n.redesignEventExportExcel,
          ),
        if (canArchive)
          AppActionSheetAction(
            value: _MenuAction.archive,
            icon: attendance.archived ? Icons.unarchive_outlined : Icons.archive_outlined,
            label: attendance.archived ? l10n.attendanceRestore : l10n.attendanceArchive,
          ),
      ],
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _MenuAction.church:
        await showAttendanceChurchOverview(
          context,
          ref,
          persons: [for (final m in members) m.person],
          statusOf: (person) => members.firstWhere((m) => m.id == person.id).status,
        );
      case _MenuAction.excel:
        await _exportExcel(attendance, members);
      case _MenuAction.archive:
        await _toggleArchived(attendance);
    }
  }

  bool _menuHasActions(Attendance attendance, List<RdMember> members) {
    if (members.isNotEmpty) return true;
    final role = ref.watch(effectiveRoleProvider);
    final type = ref.watch(attendanceTypeForAttendanceProvider(_id)).valueOrNull;
    return canArchiveAttendance(
      date: attendance.date,
      durationDays: _effectiveDays(attendance, type),
      archived: attendance.archived,
      role: role,
    );
  }

  /// "Als Excel exportieren" with the statuses shown on this page.
  Future<void> _exportExcel(Attendance attendance, List<RdMember> members) async {
    final tenant = ref.read(currentTenantProvider);
    // Bound before the awaits (tenant switch safety).
    final profileRepo = ref.read(profileRepositoryWithTenantProvider);
    final canViewNotes = ref.read(canViewAttendanceNotesProvider);
    if (tenant == null) {
      ToastHelper.showError(context, context.l10n.attendanceFlutterDataUnavailable);
      return;
    }
    ToastHelper.showInfo(context, context.l10n.attendanceFlutterCreatingExcel);
    try {
      final type = ref.read(attendanceTypeForAttendanceProvider(attendance.id ?? -1)).valueOrNull;
      final churchFieldId = attendanceChurchFieldId(ref);
      final churches = churchFieldId == null
          ? const <Church>[]
          : await ref.read(churchesProvider.future);
      final persons = [for (final m in members) m.person];
      // The Gemeinde can be an organisation field (shared value).
      final exported = churchFieldId == null
          ? persons
          : await profileRepo.hydrateSharedPersonFieldValues(persons);
      if (!mounted) return;
      await ExportService().exportAttendanceToExcel(
        context: context,
        attendance: attendance,
        typeName: type?.name ?? '',
        persons: exported,
        statuses: {for (final m in members) m.id: m.status},
        // Notes stay hidden for roles that may not see them in the view.
        notes: canViewNotes ? {for (final m in members) m.id: m.note} : const {},
        churches: churches,
        churchFieldId: churchFieldId,
      );
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.exportFlutterFailedWith(friendlyErrorMessage(e)));
    }
  }

  /// Ionic 4.17.24 `toggleArchived` (Termin page): archiving asks first,
  /// restoring does not.
  Future<void> _toggleArchived(Attendance attendance) async {
    final l10n = context.l10n;
    final archive = !attendance.archived;
    // Read before the first await (tenant switch while the dialog is open).
    final repo = ref.read(attendanceRepositoryWithTenantProvider);
    final session = ref.read(offlineQueueNotifierProvider.notifier).captureWriteSession();
    final container = ProviderScope.containerOf(context, listen: false);
    if (archive) {
      final confirmed = await DialogHelper.showConfirmation(
        context,
        title: l10n.attendanceArchiveConfirmHeader,
        message: l10n.attendanceArchiveConfirmMessage,
        confirmText: l10n.attendanceArchive,
      );
      if (!confirmed || !mounted) return;
    }
    try {
      // Account or tenant switched while the dialog was open: no write.
      if (!repo.hasTenantId || !session.isCurrent()) return;
      // Current state right before the write (Termin page `_toggleArchived`):
      // archived or restored meanwhile (other device, second tap) → no write.
      final current = container.read(attendanceDetailProvider(_id)).valueOrNull;
      if (current == null || current.archived == archive) return;
      await repo.updateAttendance(_id, {
        'archived': archive,
        'archived_at': archive ? DateTime.now().toUtc().toIso8601String() : null,
        'archived_by': archive ? session.userId : null,
      });
      container
        ..invalidate(attendanceDetailProvider(_id))
        ..invalidate(realtimeAttendanceListProvider);
      if (mounted) ToastHelper.showSuccess(context, archive ? l10n.attendanceArchivedToast : l10n.attendanceRestoredToast);
    } catch (_) {
      if (mounted) ToastHelper.showError(context, l10n.attendanceArchiveFailed);
    }
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
      final result = await _queue.run(
        paId,
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

  /// Whether the Reiter Programm has something: Werke (types that manage
  /// them) or the Ablauf (everyone but Beobachter; editors can create one).
  bool _hasProgramTab(Attendance attendance, AttendanceType? type) {
    if (rdShowsProgram(ref, type) && attendance.id != null) return true;
    final role = ref.watch(effectiveRoleProvider);
    if (role == Role.viewer) return false;
    return attendanceHasPlan(attendance) || role.canEdit;
  }

  /// Reiter Programm (concept L2): the Werke, then the Ablauf as a list with
  /// "Ablauf ansehen", "Bearbeiten" and "Für Mitglieder sichtbar".
  List<Widget> _programChildren(Attendance attendance, AttendanceType? type) {
    final plan = rdPlanOf(attendance);
    return [
      if (rdShowsProgram(ref, type) && attendance.id != null) RdEventProgramSection(attendance: attendance, type: type),
      RdEventPlanSection(
        attendance: attendance,
        preview: plan == null ? null : RdPlanTimeline(day: EventListUtils.parse(attendance.date), plan: plan),
        range: plan == null ? '' : rdPlanRange(plan),
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
    // Reiter Programm: Werke and Ablauf (not for roles that see neither).
    final hasProgram = _hasProgramTab(attendance, type);
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
    children.addAll([
      const SizedBox(height: 4),
      _head(attendance, type),
      const SizedBox(height: 16),
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
        content.add(RdInfoCard(text: l10n.redesignTodayLoading, loading: true));
      } else if (members.isEmpty) {
        final canMutate = canMutateAttendanceDetail(ref.watch(effectiveRoleProvider));
        content.add(RdInfoCard(
          text: l10n.redesignEventNoPersons,
          icon: Icons.group_off_outlined,
          action: canMutate
              ? RdOutlineButton(
                  label: l10n.attendanceAddPerson,
                  onPressed: () => addPersonsToAttendance(context, ref, attendanceId: _id, currentPersonIds: _rowPersonIds ?? const {}),
                )
              : null,
        ));
        // Programm and Ablauf can be prepared before anyone is invited
        // (Reiter Programm).
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
            Expanded(child: RdGroupLabel(list.first.groupName ?? l10n.attendanceNoGroup)),
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
            onTap: () => setState(() => hidden == 0 ? _expanded.remove(group) : _expanded.add(group)),
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
        onChanged: (v) => setState(() => _query = v),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: l10n.redesignEventRecordSearchHint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  tooltip: l10n.redesignEventSearchClose,
                  icon: const Icon(Icons.close),
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
        ),
      ),
      const SizedBox(height: 12),
      RdRecordFilterChips(
        members: members,
        selected: filter,
        onChanged: (f) => setState(() => _filter = f),
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
              onPressed: () => setState(() {
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
              onPressed: () => addPersonsToAttendance(
                context,
                ref,
                attendanceId: _id,
                currentPersonIds: _rowPersonIds ?? const {},
              ),
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

/// "✓ 7 weitere anwesend · Zeigen" at the end of a voice.
class _MoreRow extends StatelessWidget {
  const _MoreRow({super.key, required this.text, required this.action, required this.onTap});

  /// null once the voice is open (only "Weniger").
  final String? text;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              if (text != null) ...[
                Icon(Icons.check_rounded, size: 18, color: p.present),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text!,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.present),
                  ),
                ),
              ] else
                const Spacer(),
              Text(action, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.link)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Überblick (concept "Termin-Bereich neu", Schritt 2): the card at the top
/// follows the phase of the Termin (Jetzt-Karte):
/// * vorher: Rückmeldungen, who signed out and why, "Offene erinnern";
/// * heute: the same with "Heute 19:30 · in 40 Min.", "Anwesenheit
///   eintragen", Pultmodus and Ablauf;
/// * läuft: Anwesenheit, "Anwesenheit eintragen", "Jetzt im Ablauf";
/// * danach: "35 von 38 · 92 %" and the Abschluss.
/// Below: Programm (opens the Reiter), Vorbereitung, "Für Mitglieder",
/// "Nur Leitung", Dienst and Protokoll.
class _Overview extends ConsumerWidget {
  const _Overview({
    required this.attendance,
    required this.type,
    required this.members,
    required this.personAttendanceIds,
    required this.span,
    required this.phase,
    this.sideBySide = false,
    required this.onRecord,
    required this.onPult,
    required this.onOpenMember,
  });

  final Attendance attendance;
  final AttendanceType? type;
  final List<RdMember> members;
  final Map<int, String?> personAttendanceIds;
  final ({DateTime start, DateTime end, bool hasTime})? span;
  final RdEventPhase phase;

  /// The Anwesenheit is next to it (desktop): no "Anwesenheit eintragen".
  final bool sideBySide;
  /// To the Anwesenheit, with the filter of a tapped count.
  final ValueChanged<RdRecordFilter> onRecord;
  final VoidCallback onPult;
  final ValueChanged<RdMember> onOpenMember;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final role = ref.watch(effectiveRoleProvider);
    final canViewNotes = ref.watch(canViewAttendanceNotesProvider);
    final canMutate = canMutateAttendanceDetail(role);
    final counts = RdStatusCounts.fromStatuses(members.map((m) => m.status));
    final ended = EventListUtils.hasEnded(attendance.date, _effectiveDays(attendance, type));
    final info = rdEventInfo(attendance, type);
    final start = info.start;
    final over = phase == RdEventPhase.after || (phase == RdEventPhase.archived && ended);
    final started = over || phase == RdEventPhase.running || (start != null && !DateTime.now().isBefore(start));
    final now = phase == RdEventPhase.today || phase == RdEventPhase.running;
    final gaps = started ? const <RdRegisterGap>[] : rdRegisterGaps(members);
    final notes = (attendance.notes ?? '').trim();
    final id = attendance.id;
    final hasPlan = attendanceHasPlan(attendance) && role != Role.viewer;

    // Before the start: answers; from the start on: who is there.
    final here = members.where((m) => m.status == AttendanceStatus.present).length;
    final late = members.where((m) => m.status == AttendanceStatus.late || m.status == AttendanceStatus.lateExcused).length;
    // Each count opens the Anwesenheit filtered to it (no arrows: the
    // card stays calm, the "›" at "eingeladen" shows it can be tapped).
    final List<(String, Color, RdRecordFilter)> legend = started
        ? [
            (l10n.redesignEventCountHere(here), p.present, RdRecordFilter.present),
            if (late > 0) (l10n.redesignEventCountLateStarted(late), p.late, RdRecordFilter.late),
            if (counts.excused > 0)
              (l10n.redesignEventCountExcusedStarted(counts.excused), p.excused, RdRecordFilter.excused),
            if (counts.absent > 0) (l10n.redesignEventCountAbsentStarted(counts.absent), p.absent, RdRecordFilter.absent),
            if (counts.open > 0) (l10n.redesignEventCountNoAnswer(counts.open), p.text2, RdRecordFilter.open),
          ]
        : [
            (l10n.redesignTodayCountYes(counts.present), p.present, RdRecordFilter.present),
            if (counts.excused > 0) (l10n.redesignTodayCountExcused(counts.excused), p.excused, RdRecordFilter.excused),
            if (counts.lateAnnounced > 0) (l10n.redesignTodayCountLater(counts.lateAnnounced), p.late, RdRecordFilter.late),
            if (counts.absent > 0) (l10n.redesignTodayCountAbsent(counts.absent), p.absent, RdRecordFilter.absent),
            if (counts.open > 0) (l10n.redesignEventCountNoAnswer(counts.open), p.text2, RdRecordFilter.open),
          ];
    final total = counts.total;
    final percent = total == 0 ? 0 : ((here + late) * 100 / total).round();
    final String title;
    final String side;
    if (!started) {
      title = l10n.redesignEventAnswers;
      side = l10n.redesignEventInvited(total);
    } else if (!over) {
      title = l10n.redesignEventTabRecord;
      side = l10n.redesignEventAttendancePersons(total);
    } else {
      title = l10n.redesignEventTabRecord;
      side = l10n.redesignEventPresentOf(here + late, total, percent);
    }
    // "Heute 19:30 · in 40 Min."
    final pill = phase == RdEventPhase.today ? rdPhasePill(l10n, phase, span: span) : null;
    final countdown = phase == RdEventPhase.today ? rdCountdown(l10n, start, hasTime: span?.hasTime ?? false) : null;
    final settled = over && counts.open == 0 && counts.absent == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (pill != null) ...[
                Text(
                  [pill.label, if (countdown != null) countdown].join(' · ').toUpperCase(),
                  key: const Key('rd-event-now-eyebrow'),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: p.late),
                ),
                const SizedBox(height: 6),
              ],
              // The whole list sits in the Anwesenheit.
              InkWell(
                key: const Key('rd-event-answers-open'),
                borderRadius: BorderRadius.circular(8),
                onTap: () => onRecord(RdRecordFilter.all),
                child: Row(
                  children: [
                    Expanded(child: Text(title, style: RdType.section(p))),
                    Text(side, style: RdType.meta(p, size: 13)),
                    Icon(Icons.chevron_right, size: 18, color: p.text2),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              RdStatusBar(
                total: total,
                segments: started
                    ? [
                        RdBarSegment(here, p.present),
                        RdBarSegment(late, p.late),
                        RdBarSegment(counts.excused, p.excused),
                        RdBarSegment(counts.absent, p.absent),
                      ]
                    : [
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
                runSpacing: 0,
                children: [
                  for (final (text, color, filter) in legend)
                    Semantics(
                      button: true,
                      child: InkWell(
                        key: Key('rd-event-count-${filter.name}'),
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => onRecord(filter),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 28),
                          child: Row(
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
                        ),
                      ),
                    ),
                ],
              ),
              for (final gap in gaps) ...[
                const SizedBox(height: 12),
                _GapNote(gap: gap),
              ],
              // From the Termin day on: record, Pultmodus, Ablauf.
              if (now) ...[
                const SizedBox(height: 16),
                if (!sideBySide) ...[
                  RdPrimaryButton(
                    label: l10n.redesignEventRecord,
                    icon: Icons.checklist_rounded,
                    onPressed: () => onRecord(RdRecordFilter.all),
                  ),
                  const SizedBox(height: 10),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    RdPillButton(
                      key: const Key('rd-event-now-pult'),
                      icon: Icons.grid_view_rounded,
                      label: l10n.redesignPultOpen,
                      onPressed: onPult,
                    ),
                    if (hasPlan)
                      RdPillButton(
                        key: const Key('rd-event-now-plan'),
                        icon: Icons.view_timeline_outlined,
                        label: phase == RdEventPhase.running ? l10n.redesignEventPlanLive : l10n.redesignEventPlanSection,
                        onPressed: () => openAttendancePlanViewer(context, attendance),
                      ),
                  ],
                ),
              ],
              if (phase == RdEventPhase.running && hasPlan) ...[
                const SizedBox(height: 14),
                if (rdPlanOf(attendance) case final plan?) RdPlanNow(day: EventListUtils.parse(attendance.date), plan: plan),
              ],
              // Only Termin-Arten with "offen" (Zusage) have someone to remind.
              if (canMutate && !ended && counts.open > 0 && id != null) ...[
                SizedBox(height: now ? 10 : 16),
                RdOutlineButton(
                  key: const Key('rd-event-remind-open'),
                  label: '${l10n.redesignEventRemindOpen} (${counts.open})',
                  icon: Icons.notifications_none,
                  height: 44,
                  onPressed: () => showRdRemindOpenSheet(
                    context,
                    attendanceId: id,
                    title: info.title,
                    when: rdRemindWhen(start, hasTime: (attendance.startTime ?? type?.startTime)?.isNotEmpty ?? false),
                  ),
                ),
              ],
              if (!over)
                RdSignoutList(
                  members: members,
                  title: info.title,
                  showNote: canViewNotes,
                  started: started,
                  onOpen: onOpenMember,
                ),
              if (settled) ...[
                const SizedBox(height: 14),
                Row(
                  key: const Key('rd-event-settled'),
                  children: [
                    Icon(Icons.check_circle_outline, size: 18, color: p.present),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        [
                          l10n.redesignEventAllSettled,
                          if (!attendance.archived &&
                              canArchiveAttendance(
                                date: attendance.date,
                                durationDays: _effectiveDays(attendance, type),
                                archived: attendance.archived,
                                role: role,
                              ))
                            l10n.redesignEventArchiveHint,
                        ].join(' · '),
                        style: RdType.meta(p, size: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        // After the Termin: Unentschuldigte anschreiben, automatische Nachricht.
        if (over)
          RdEventClosingSection(
            attendance: attendance,
            type: type,
            members: members,
            personAttendanceIds: personAttendanceIds,
          ),
        // "Vorbereitung": always there for the Leitung before the Termin
        // (empty with "+ Aufgabe"); afterwards only while tasks are open.
        if (ref.watch(canViewAttendanceChecklistProvider) &&
            ((attendance.checklist?.isNotEmpty ?? false)
                ? !(over && attendance.checklist!.every((c) => c.completed))
                : canMutate && !over && !attendance.archived)) ...[
          const SizedBox(height: 24),
          RdEventChecklistSection(attendance: attendance, type: type),
        ],
        RdEventInfoSection(attendance: attendance, title: l10n.redesignEventForMembers, ended: over),
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 24),
          RdGroupLabel(l10n.redesignEventLeadersOnly),
          RdCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.attendanceNotes, style: RdType.meta(p, size: 13)),
                const SizedBox(height: 4),
                Text(notes, style: RdType.body(p)),
              ],
            ),
          ),
        ],
        // Dienstplan "Besetzung" and Protokoll as on the Termin page.
        if (type != null && type!.dutyMode && id != null) ...[
          const SizedBox(height: 24),
          DutyStaffingSection(attendance: attendance, attendanceType: type!),
        ],
        if (id != null && (ref.watch(protocolTypeByIdProvider(attendance.typeId))?.enableProtocol ?? false)) ...[
          const SizedBox(height: 24),
          AttendanceProtocolSection(attendanceId: id, typeId: attendance.typeId),
        ],
      ],
    );
  }
}

/// "Trompete: 0 von 2 da. Max Huber, Jan Ott haben abgesagt."
class _GapNote extends StatelessWidget {
  const _GapNote({required this.gap});

  final RdRegisterGap gap;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: p.absentSoft, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: p.absent, size: 20),
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
    );
  }
}
