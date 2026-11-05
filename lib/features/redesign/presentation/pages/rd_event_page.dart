import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
import '../../data/rd_event_details_logic.dart';
import '../widgets/event/rd_event_answers.dart';
import '../widgets/event/rd_event_sections.dart';
import '../widgets/event/rd_pult_view.dart';
import '../widgets/today/rd_remind_open_sheet.dart';
import '../widgets/event/rd_record_widgets.dart';
import '../widgets/rd_split_view.dart';
import '../widgets/rd_widgets.dart';
import '../widgets/today/rd_today_common.dart';
import '../../data/rd_dates.dart';

/// Tabs of a Termin in the new design.
enum RdEventTab { overview, record }

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
enum _MenuAction { statusOverview, church, excel, checklist, archive }

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
  /// Gemeinde-Übersicht, Excel, Checkliste starten, Archivieren.
  /// "Termin löschen" is at the bottom of "Bearbeiten".
  Future<void> _openMenu(Attendance attendance, List<RdMember> members) async {
    final l10n = context.l10n;
    final role = ref.read(effectiveRoleProvider);
    final type = ref.read(attendanceTypeForAttendanceProvider(_id)).valueOrNull;
    final canMutate = canMutateAttendanceDetail(role);
    final canArchive = canArchiveAttendance(
      date: attendance.date,
      durationDays: attendance.durationDays,
      archived: attendance.archived,
      role: role,
    );
    final action = await showAppActionSheet<_MenuAction>(
      context,
      title: rdEventInfo(attendance, type).title,
      message: role.isAdmin || role.isResponsible ? l10n.redesignEventDeleteHint : null,
      actions: [
        if (members.isNotEmpty)
          AppActionSheetAction(
            value: _MenuAction.statusOverview,
            icon: Icons.bar_chart_rounded,
            label: l10n.attendanceStatusOverview,
            subtitle: l10n.redesignEventStatusOverviewHint,
          ),
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
        if (canMutate && ref.read(canViewAttendanceChecklistProvider) && (attendance.checklist?.isEmpty ?? true))
          AppActionSheetAction(
            value: _MenuAction.checklist,
            icon: Icons.check_box_outlined,
            label: l10n.attendanceStartChecklist,
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
      case _MenuAction.statusOverview:
        await showRdStatusOverviewSheet(context, members: members);
      case _MenuAction.church:
        await showAttendanceChurchOverview(
          context,
          ref,
          persons: [for (final m in members) m.person],
          statusOf: (person) => members.firstWhere((m) => m.id == person.id).status,
        );
      case _MenuAction.excel:
        await _exportExcel(attendance, members);
      case _MenuAction.checklist:
        await _startChecklist(attendance, type);
      case _MenuAction.archive:
        await _toggleArchived(attendance);
    }
  }

  bool _menuHasActions(Attendance attendance, List<RdMember> members) {
    if (members.isNotEmpty) return true;
    final role = ref.watch(effectiveRoleProvider);
    return (canMutateAttendanceDetail(role) &&
            ref.watch(canViewAttendanceChecklistProvider) &&
            (attendance.checklist?.isEmpty ?? true)) ||
        canArchiveAttendance(
          date: attendance.date,
          durationDays: attendance.durationDays,
          archived: attendance.archived,
          role: role,
        );
  }

  /// "Checkliste starten": the type's default checklist when it has one,
  /// else a first task.
  Future<void> _startChecklist(Attendance attendance, AttendanceType? type) async {
    final id = attendance.id;
    if (id == null) return;
    if (type != null && (type.checklist?.isNotEmpty ?? false)) {
      await rdSaveChecklist(context, ref, id, rdDefaultChecklist(type, attendance));
      if (mounted) ToastHelper.showSuccess(context, context.l10n.attendanceChecklistRestored);
      return;
    }
    final item = await rdAskChecklistItem(context, attendance);
    if (item == null || !mounted) return;
    await rdSaveChecklist(context, ref, id, [item]);
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

    if (members == null) {
      children.add(RdInfoCard(text: l10n.redesignTodayLoading, loading: true));
    } else if (members.isEmpty) {
      final canMutate = canMutateAttendanceDetail(ref.watch(effectiveRoleProvider));
      children.add(RdInfoCard(
        text: l10n.redesignEventNoPersons,
        icon: Icons.group_off_outlined,
        action: canMutate
            ? RdOutlineButton(
                label: l10n.attendanceAddPerson,
                onPressed: () => addPersonsToAttendance(context, ref, attendanceId: _id, currentPersonIds: _rowPersonIds ?? const {}),
              )
            : null,
      ));
      // Programm and Ablauf can be prepared before anyone is invited.
      children.addAll([
        if (rdShowsProgram(ref, type) && attendance.id != null) ...[
          const SizedBox(height: 24),
          RdEventProgramSection(attendance: attendance, type: type),
        ],
        RdEventPlanSection(attendance: attendance),
      ]);
    } else if (_tab == RdEventTab.overview) {
      children.add(_Overview(
        attendance: attendance,
        type: type,
        members: members,
        personAttendanceIds: _paIds,
        onRecord: () => setState(() => _tab = RdEventTab.record),
        onOpenMember: _openMember,
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

/// Canvas D4 plus the Termin details (concept "Vortrag im Beta-Design"),
/// reworked in "Termin-Bereich neu" (Schritt 1): the answers card holds
/// the register gaps, "Anwesenheit eintragen", "Offene erinnern" and who
/// signed out and why; then Programm/Werke, Ablauf, Vorbereitung, Infos,
/// notes, Dienst and Protokoll, and the Abschluss after the start.
class _Overview extends ConsumerWidget {
  const _Overview({
    required this.attendance,
    required this.type,
    required this.members,
    required this.personAttendanceIds,
    required this.onRecord,
    required this.onOpenMember,
  });

  final Attendance attendance;
  final AttendanceType? type;
  final List<RdMember> members;
  final Map<int, String?> personAttendanceIds;
  final VoidCallback onRecord;
  final ValueChanged<RdMember> onOpenMember;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final canViewNotes = ref.watch(canViewAttendanceNotesProvider);
    final canMutate = canMutateAttendanceDetail(ref.watch(effectiveRoleProvider));
    final counts = RdStatusCounts.fromStatuses(members.map((m) => m.status));
    final ended = EventListUtils.hasEnded(attendance.date, attendance.durationDays);
    final info = rdEventInfo(attendance, type);
    final start = info.start;
    final started = ended || (start != null && !DateTime.now().isBefore(start));
    final gaps = ended ? const <RdRegisterGap>[] : rdRegisterGaps(members);
    final notes = (attendance.notes ?? '').trim();
    final id = attendance.id;
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
              for (final gap in gaps) ...[
                const SizedBox(height: 12),
                _GapNote(gap: gap),
              ],
              const SizedBox(height: 16),
              RdPrimaryButton(
                label: l10n.redesignEventRecord,
                icon: Icons.checklist_rounded,
                onPressed: onRecord,
              ),
              // Only Termin-Arten with "offen" (Zusage) have someone to remind.
              if (canMutate && !ended && counts.open > 0 && id != null) ...[
                const SizedBox(height: 8),
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
              RdSignoutList(
                members: members,
                title: info.title,
                showNote: canViewNotes,
                started: started,
                onOpen: onOpenMember,
              ),
            ],
          ),
        ),
        if (rdShowsProgram(ref, type) && id != null) ...[
          const SizedBox(height: 24),
          RdEventProgramSection(attendance: attendance, type: type),
        ],
        RdEventPlanSection(attendance: attendance),
        if (ref.watch(canViewAttendanceChecklistProvider) && (attendance.checklist?.isNotEmpty ?? false)) ...[
          const SizedBox(height: 24),
          RdEventChecklistSection(attendance: attendance),
        ],
        if (rdHasInfos(ref, attendance)) ...[
          const SizedBox(height: 24),
          RdEventInfoSection(attendance: attendance),
        ],
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 24),
          RdGroupLabel(l10n.attendanceNotes),
          RdCard(
            padding: const EdgeInsets.all(14),
            child: Text(notes, style: RdType.body(p)),
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
        RdEventClosingSection(
          attendance: attendance,
          type: type,
          members: members,
          personAttendanceIds: personAttendanceIds,
        ),
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
