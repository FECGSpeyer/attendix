import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/enums.dart' show AttendanceStatus;
import '../../../../core/providers/attendance_detail_providers.dart';
import '../../../../core/providers/attendance_providers.dart';
import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/providers/role_permission_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/services/offline_queue_service.dart';
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/attendance_logic_utils.dart' show defaultDeadline;
import '../../../../core/utils/demo_guard.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/event_list_utils.dart';
import '../../../../core/utils/haptic_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../data/repositories/attendance_repository.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart' show showAppDatePicker, showAppTimePicker;
import '../../../attendance/presentation/widgets/attendance_date_change.dart';
import '../../../attendance/presentation/widgets/attendance_detail/status_chip.dart' show ionicStatusLabel;
import '../../../attendance/presentation/widgets/attendance_detail/attendance_detail_sheets.dart'
    show showFilesFolderPicker;
import '../../../attendance/presentation/widgets/attendance_detail/description_attachment_sheet.dart';
import '../../../attendance/presentation/widgets/attendance_detail/general_info_accordion.dart'
    show isDeadlineReadonly;
import '../../data/providers/rd_today_providers.dart' show rdDeadlineLabel;
import '../../data/rd_create_logic.dart' show rdEndAfter, rdEndBeforeStart, rdPickedTimes, rdRecentPlaces;
import '../../data/rd_event_details_logic.dart';
import '../../data/rd_event_phase.dart' show rdEffectiveDurationDays;
import '../../../../shared/widgets/adaptive/app_dialog.dart';
import '../../../../shared/widgets/adaptive/adaptive_platform.dart';
import '../widgets/event/rd_create_sheets.dart' show showRdTypePicker;
import '../widgets/event/rd_form_widgets.dart';
import '../widgets/rd_widgets.dart';
import '../widgets/today/rd_today_common.dart';

/// REDESIGN: "Termin bearbeiten" (concept "Vortrag im Beta-Design", board 2):
/// the form of "Neuer Termin" for an existing Termin. Like the Termin page
/// every change is saved right away (text fields when they lose focus or
/// the page closes) through the same writes: Info-Text, Datum (with the
/// status question), Beginn/Ende (re-runs the shift computation), Ort,
/// Antwort bis, Beschreibung & Anhang, Ordner and Notizen. Werke,
/// Ablauf and Vorbereitung are changed in the Überblick. "Termin löschen"
/// is at the bottom, like "Werk löschen" (concept "Termin-Bereich neu").
class RdEventEditPage extends ConsumerStatefulWidget {
  const RdEventEditPage({super.key, required this.attendanceId});

  final int attendanceId;

  @override
  ConsumerState<RdEventEditPage> createState() => _RdEventEditPageState();
}

class _RdEventEditPageState extends ConsumerState<RdEventEditPage> {
  final _title = TextEditingController();
  final _place = TextEditingController();
  final _notes = TextEditingController();
  final _titleFocus = FocusNode();
  final _placeFocus = FocusNode();
  final _notesFocus = FocusNode();

  /// Stored values the text fields started from (null until loaded).
  String? _storedTitle;
  String? _storedPlace;
  String? _storedNotes;

  /// Text saves run one after another; each compares its value with what
  /// is stored when it runs, so the last typed value always wins.
  Future<void> _textQueue = Future.value();

  void _enqueue(Future<void> Function() save) {
    _textQueue = _textQueue.then((_) => save());
  }

  // UI_TENANT_HOIST: bound when the page opens, so text that is saved when
  // the page closes still goes to this Termin's tenant.
  late final AttendanceRepository _repo;
  late final ProviderContainer _container;

  /// #232: the acting user's session; text saved when the page closes
  /// after a sign-out or account switch is dropped, not written.
  late final OfflineWriteSession _session;

  int get _id => widget.attendanceId;

  /// Set once the Termin is deleted: nothing is written any more.
  bool _deleted = false;

  @override
  void initState() {
    super.initState();
    _repo = ref.read(attendanceRepositoryWithTenantProvider);
    _container = ProviderScope.containerOf(context, listen: false);
    _session = ref.read(offlineQueueNotifierProvider.notifier).captureWriteSession();
    for (final (focus, save) in [
      (_titleFocus, _saveTitle),
      (_placeFocus, _savePlace),
      (_notesFocus, _saveNotes),
    ]) {
      focus.addListener(() {
        if (!focus.hasFocus) save();
      });
    }
  }

  @override
  void dispose() {
    // Text typed last is saved when the page closes (no focus change).
    _saveTitle();
    _savePlace();
    _saveNotes();
    for (final c in [_title, _place, _notes]) {
      c.dispose();
    }
    for (final f in [_titleFocus, _placeFocus, _notesFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  void _fill(Attendance att) {
    if (_storedTitle != null) return;
    _storedTitle = att.typeInfo ?? '';
    _storedPlace = att.place ?? '';
    _storedNotes = att.notes ?? '';
    _title.text = _storedTitle!;
    _place.text = _storedPlace!;
    _notes.text = _storedNotes!;
  }

  void _refresh() {
    _container
      ..invalidate(attendanceDetailProvider(_id))
      ..invalidate(attendancesProvider)
      ..invalidate(realtimeAttendanceListProvider);
  }

  /// Writes [updates]; reports a failure while the page is open.
  Future<bool> _write(Map<String, dynamic> updates) async {
    if (_deleted || !_repo.hasTenantId || !_session.isCurrent()) return false;
    try {
      await _repo.updateAttendance(_id, updates);
      _refresh();
      return true;
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.attendanceFlutterErrorWith(friendlyErrorMessage(e)));
      return false;
    }
  }

  void _saveTitle() {
    final value = _title.text.trim(); // read now: the page may be gone when it runs
    _enqueue(() async {
      if (_storedTitle == null || value == _storedTitle) return;
      // Marked as stored only once written, so a failed save is tried again.
      if (await _write({'typeInfo': value.isEmpty ? null : value})) _storedTitle = value;
    });
  }

  void _savePlace() {
    final value = _place.text.trim(); // read now: the page may be gone when it runs
    _enqueue(() async {
      if (_storedPlace == null || value == _storedPlace) return;
      // Marked as stored only once written, so a failed save is tried again.
      if (await _write({'place': value.isEmpty ? null : value})) _storedPlace = value;
    });
  }

  void _saveNotes() {
    final value = _notes.text; // read now: the page may be gone when it runs
    _enqueue(() async {
      if (_storedNotes == null || value == _storedNotes) return;
      // Marked as stored only once written, so a failed save is tried again.
      if (await _write({'notes': value.isEmpty ? null : value})) _storedNotes = value;
    });
  }

  /// "Termin löschen" (old Termine list: Dirigent only, i.e. Admin and
  /// Verantwortliche): confirm, delete, back to the Termine.
  Future<void> _delete() async {
    final l10n = context.l10n;
    if (DemoGuard.blocked()) return; // DEMO_GUARD
    final confirmed = await showAppConfirm(
      context,
      title: l10n.attListRemoveConfirm,
      confirmText: l10n.commonDelete,
      destructive: true,
    );
    if (!confirmed || !mounted || !_session.isCurrent()) return;
    final router = GoRouter.of(context);
    HapticHelper.medium();
    try {
      await _repo.deleteAttendance(_id);
    } catch (e) {
      if (mounted) ToastHelper.showError(context, friendlyErrorMessage(e));
      return;
    }
    _deleted = true; // text typed last is not saved any more
    _container
      ..invalidate(attendancesProvider)
      ..invalidate(realtimeAttendanceListProvider)
      ..invalidate(playerAttendancePercentagesProvider);
    if (mounted) ToastHelper.showSuccess(context, l10n.redesignEventDeleted);
    router.go(RedesignRoutes.events);
  }

  void _done() {
    FocusScope.of(context).unfocus();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RedesignRoutes.event(_id));
    }
  }

  Future<void> _pickTime(Attendance att, AttendanceType? type, {required bool start}) async {
    // Shown times: the Termin's own, else its type's (like the Termin page).
    final shownStart = att.startTime ?? type?.startTime;
    final shownEnd = att.endTime ?? type?.endTime;
    final current = start ? shownStart : shownEnd;
    final parts = (current ?? '').split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.first) ?? (start ? 17 : 20),
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
    final iosLook = useIosLook(context);
    var picked = await showAppTimePicker(
      context: context,
      initialTime: initial,
      helpText: start ? context.l10n.redesignCreateStart : context.l10n.redesignCreateEnd,
    );
    // The iOS wheel returns null when the shown time was confirmed unchanged:
    // with no time yet, that shown default is the choice.
    if (picked == null && iosLook && current == null) picked = initial;
    if (picked == null || !mounted) return;
    // #232: session of the acting user, captured before the first write.
    final writeSession = ref.read(offlineQueueNotifierProvider.notifier).captureWriteSession();
    final value = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    // The Ende never lies before the Beginn: a later Beginn moves the Ende
    // along, an earlier Ende is refused.
    final times = rdPickedTimes(start: shownStart, end: shownEnd, pickedStart: start, value: value);
    if (times == null) {
      ToastHelper.showError(context, context.l10n.redesignCreateEndBeforeStart);
      return;
    }
    final updates = <String, dynamic>{
      if (start && times.start != att.startTime) 'start_time': times.start,
      // A Beginn change writes the Ende only when it moved along.
      if (start ? times.end != shownEnd : times.end != att.endTime) 'end_time': times.end,
    };
    if (updates.isEmpty) return;
    if (!await _write(updates)) return;
    try {
      // LOGIC_ATT: the time window moved, re-run the shift computation for
      // everyone in this Termin (Ionic onInfoChanged).
      await _repo.updateShiftAssignmentsForAttendance(
        _id,
        isSessionCurrent: writeSession.isCurrent,
        actingUserId: writeSession.userId,
      );
      _container.invalidate(personAttendancesForAttendanceProvider(_id));
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.attendanceFlutterErrorWith(friendlyErrorMessage(e)));
    }
  }

  /// "Art" (Beta only, Ionic shows it read-only): another type for this
  /// Termin. Who is still on the old type's default status gets the new
  /// default when the user agrees (each row only while it still has that
  /// status, checked in the update itself); who takes part stays the same.
  /// Times that would put the Ende before the Beginn are corrected. Then
  /// the shift computation runs again (times and all-day come from the type).
  Future<void> _pickType(Attendance att, AttendanceType? current) async {
    // One type change at a time, including its status adoption.
    if (_typeChanging) return;
    _typeChanging = true;
    try {
      await _changeType(att, current);
    } finally {
      _typeChanging = false;
    }
  }

  bool _typeChanging = false;

  Future<void> _changeType(Attendance att, AttendanceType? current) async {
    final l10n = context.l10n;
    if (DemoGuard.blocked()) return; // DEMO_GUARD
    final all = await ref.read(attendanceTypesProvider.future).catchError((_) => const <AttendanceType>[]);
    if (!mounted) return;
    // The current type from the list itself: the row may be tapped before
    // the Termin's type finished loading.
    final currentId = att.typeId;
    current = currentId == null ? null : all.where((t) => t.id == currentId).firstOrNull;
    final types = [
      for (final t in all)
        if (t.visible == true || t.id == current?.id) t,
    ];
    if (types.isEmpty || (currentId != null && current == null)) {
      ToastHelper.showError(context, l10n.redesignTodayLoadFailed);
      return;
    }
    final picked = await showRdTypePicker(context, types: types, selected: current);
    if (picked == null || !mounted || picked.id == current?.id) return;
    // #232: session of the acting user, captured before the first write.
    final writeSession = ref.read(offlineQueueNotifierProvider.notifier).captureWriteSession();

    Future<List<PersonAttendance>> onDefault(AttendanceStatus status) async {
      _container.invalidate(personAttendancesForAttendanceProvider(_id));
      final sub = _container.listen(personAttendancesForAttendanceProvider(_id).future, (_, __) {});
      try {
        final rows = await sub.read();
        return [for (final r in rows) if (r.id != null && r.status == status) r];
      } finally {
        sub.close();
      }
    }

    // Rows still on the old default status (never changed by anyone).
    final oldDefault = current?.defaultStatus;
    final changesDefault = oldDefault != null && oldDefault != picked.defaultStatus;
    var count = 0;
    if (changesDefault) {
      try {
        count = (await onDefault(oldDefault)).length;
      } catch (_) {
        if (mounted) ToastHelper.showError(context, l10n.dateDialogLoadFailed);
        return;
      }
      if (!mounted) return;
    }
    var adopt = false;
    if (count > 0) {
      final choice = await showAppDialog<String>(
        context: context,
        builder: (ctx) => AppAlertDialog(
          title: Text(l10n.redesignEventEditTypeStatusTitle),
          content: Text(l10n.redesignEventEditTypeStatusMessage(
            count,
            ionicStatusLabel(oldDefault!),
            ionicStatusLabel(picked.defaultStatus),
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
            TextButton(onPressed: () => Navigator.pop(ctx, 'keep'), child: Text(l10n.dateDialogKeep)),
            FilledButton(onPressed: () => Navigator.pop(ctx, 'adopt'), child: Text(l10n.redesignEventEditTypeStatusAdopt)),
          ],
        ),
      );
      if (choice == null || !mounted) return;
      adopt = choice == 'adopt';
    }

    // The Ende must not end up before the Beginn with the new type's times
    // (e.g. own Beginn 20:00, no own Ende, new type ends 19:00).
    // Effective times = own ones, else the type's (like the Termin page).
    // The new Ende keeps the new type's duration, else the former one.
    final start = att.startTime ?? picked.startTime;
    final end = att.endTime ?? picked.endTime;
    final oldStart = att.startTime ?? current?.startTime;
    final oldEnd = att.endTime ?? current?.endTime;
    final fixEnd = !picked.allDay && rdEndBeforeStart(start, end)
        ? (rdEndBeforeStart(picked.startTime, picked.endTime) || picked.startTime == null || picked.endTime == null
            ? rdEndAfter(start!, from: oldStart, to: oldEnd)
            : rdEndAfter(start!, from: picked.startTime, to: picked.endTime))
        : null;
    if (!await _write({'type_id': picked.id, if (fixEnd != null) 'end_time': fixEnd})) return;
    var failed = 0;
    try {
      if (adopt) {
        // Read again right before writing: who changed meanwhile is left out,
        // and each update still checks the old status itself.
        List<PersonAttendance> rows;
        try {
          rows = await onDefault(oldDefault!);
        } catch (_) {
          // Nothing adjusted: the hint below asks to do it by hand.
          failed = count;
          rows = const [];
        }
        for (final r in rows) {
          writeSession.ensureCurrent();
          try {
            await _repo.updatePersonAttendance(
              r.id!,
              {'status': picked.defaultStatus.value},
              isSessionCurrent: writeSession.isCurrent,
              actingUserId: writeSession.userId,
              onlyIfStatus: oldDefault,
            );
          } on PersonAttendanceStatusChangedException {
            continue; // changed meanwhile: keep that person's status
          } on OfflineSessionChangedException {
            rethrow;
          } catch (_) {
            failed++;
          }
        }
      }
      writeSession.ensureCurrent();
      // LOGIC_ATT: times and all-day may come from the new type.
      await _repo.updateShiftAssignmentsForAttendance(
        _id,
        isSessionCurrent: writeSession.isCurrent,
        actingUserId: writeSession.userId,
      );
    } catch (e) {
      if (mounted) ToastHelper.showError(context, l10n.attendanceFlutterErrorWith(friendlyErrorMessage(e)));
    } finally {
      _container
        ..invalidate(attendanceTypeForAttendanceProvider(_id))
        ..invalidate(personAttendancesForAttendanceProvider(_id));
    }
    // The Art is already changed: name who still has the old status, so it
    // can be set by hand in the Anwesenheit.
    if (failed > 0 && mounted) {
      ToastHelper.showError(context, l10n.redesignEventEditTypeStatusFailed(failed));
    }
  }

  Future<void> _pickDeadline(Attendance att, AttendanceType? type) async {
    final l10n = context.l10n;
    final date = DateTime.tryParse(att.date);
    final suggested = date == null ? null : defaultDeadline(date, type?.startTime);
    final choice = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: context.rd.bg,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Text(l10n.redesignCreateDeadline, style: RdType.cardTitle(ctx.rd)),
              ),
              RdGroupedList(children: [
                RdListRow(
                  title: l10n.redesignCreateDeadlineNone,
                  showChevron: false,
                  selected: att.deadline == null,
                  onTap: () => Navigator.of(ctx).pop('none'),
                ),
                if (suggested != null)
                  RdListRow(
                    title: l10n.redesignEventEditDeadlineSuggested(rdDeadlineLabel(suggested.toLocal())),
                    showChevron: false,
                    onTap: () => Navigator.of(ctx).pop('suggested'),
                  ),
                RdListRow(
                  title: l10n.redesignEventEditDeadlinePick,
                  onTap: () => Navigator.of(ctx).pop('pick'),
                ),
              ]),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
                child: Text(l10n.redesignCreateDeadlineHint, style: RdType.meta(ctx.rd, size: 13)),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case 'none':
        await _write({'deadline': null});
      case 'suggested':
        await _write({'deadline': EventListUtils.deadlineToStore(suggested!)});
      case 'pick':
        await _pickDeadlineDate(att);
    }
  }

  /// Day and time of the Abmeldeschluss (Termin page: from now until the Termin).
  Future<void> _pickDeadlineDate(Attendance att) async {
    final date = DateTime.tryParse(att.date);
    final current = EventListUtils.deadlineLocal(att.deadline);
    final now = DateTime.now();
    var initial = current ?? date?.subtract(const Duration(days: 1)) ?? now;
    final last = date ?? now.add(const Duration(days: 365));
    if (initial.isBefore(now)) initial = now;
    if (initial.isAfter(last)) initial = last;
    final day = await showAppDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.isAfter(last) ? last : now,
      lastDate: last,
      helpText: context.l10n.attendanceFlutterChooseDeadline,
    );
    if (day == null || !mounted) return;
    final time = await showAppTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (!mounted) return;
    // The iOS wheel returns null when the shown time was confirmed unchanged.
    final t = time ?? TimeOfDay.fromDateTime(initial);
    final value = DateTime(day.year, day.month, day.day, t.hour, t.minute);
    await _write({'deadline': EventListUtils.deadlineToStore(value)});
  }

  Future<void> _pickFolder(Attendance att) async {
    final tenantId = ref.read(currentTenantIdProvider);
    if (tenantId == null) return;
    final l10n = context.l10n;
    final current = (att.filesFolder ?? '').trim();
    if (current.isNotEmpty) {
      final choice = await showModalBottomSheet<String>(
        context: context,
        useRootNavigator: true,
        showDragHandle: true,
        backgroundColor: context.rd.bg,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: RdGroupedList(children: [
              RdListRow(title: l10n.attendanceChangeFolder, onTap: () => Navigator.of(ctx).pop('change')),
              RdListRow(
                title: l10n.attendanceRemoveFolder,
                titleColor: ctx.rd.absent,
                showChevron: false,
                onTap: () => Navigator.of(ctx).pop('remove'),
              ),
            ]),
          ),
        ),
      );
      if (choice == null || !mounted) return;
      if (choice == 'remove') {
        await _write({'files_folder': null});
        return;
      }
    }
    final path = await showFilesFolderPicker(context, tenantId: tenantId, initialPath: current);
    if (path == null || path.isEmpty || !mounted) return;
    await _write({'files_folder': path});
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final async = ref.watch(attendanceDetailProvider(_id));
    final att = async.valueOrNull;
    final type = ref.watch(attendanceTypeForAttendanceProvider(_id)).valueOrNull;

    final Widget body;
    if (att == null) {
      body = RdFormBody(children: [
        async.isLoading
            ? RdInfoCard(text: l10n.redesignTodayLoading, loading: true)
            : RdInfoCard(
                text: async.hasError ? l10n.redesignTodayLoadFailed : l10n.redesignEventNotFound,
                icon: Icons.error_outline,
                action: RdOutlineButton(
                  label: l10n.redesignCommonRetry,
                  onPressed: () => ref.invalidate(attendanceDetailProvider(_id)),
                ),
              ),
      ]);
    } else {
      _fill(att);
      body = _form(context, att, type);
    }

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            RdEditTopBar(title: l10n.redesignEventEditTitle, doneKey: const Key('rd-edit-done'), onDone: _done),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  Widget _form(BuildContext context, Attendance att, AttendanceType? type) {
    final p = context.rd;
    final l10n = context.l10n;
    final locale = currentIntlLocale();
    final date = DateTime.tryParse(att.date)?.toLocal();
    final allDay = type?.allDay ?? false;
    final history = ref.watch(realtimeAttendanceListProvider).valueOrNull ?? const <Attendance>[];
    final places = rdRecentPlaces(history).where((s) => s != _place.text.trim()).toList();
    final deadline = EventListUtils.deadlineLocal(att.deadline);
    final deadlineLocked = isDeadlineReadonly(att);
    final description = rdPlainText(att.description);
    final attachment = (att.attachmentName ?? '').trim();
    final folder = (att.filesFolder ?? '').trim();
    final canFiles = ref.watch(canAccessFilesProvider);
    final role = ref.watch(effectiveRoleProvider);
    final typeReady = type != null || att.typeId == null;
    final days = rdEffectiveDurationDays(att.durationDays,
            typeAllDay: type?.allDay ?? false, typeDurationDays: type?.durationDays) ??
        1;

    return RdFormBody(children: [
      RdGroupLabel(l10n.redesignEventEditBasics),
      RdGroupedList(children: [
        RdFieldRow(
          label: l10n.redesignCreateTitleLabel,
          child: TextField(
            key: const Key('rd-edit-title'),
            controller: _title,
            focusNode: _titleFocus,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            style: TextStyle(fontSize: 17, color: p.text),
            decoration: rdInputDecoration(p, type?.name ?? ''),
            onSubmitted: (_) => _titleFocus.unfocus(),
          ),
        ),
        RdListRow(
          key: const Key('rd-edit-type'),
          title: l10n.redesignCreateType,
          showChevron: false,
          trailing: type == null ? null : RdPill(type.name, tone: type.highlight ? RdTone.excused : RdTone.primary),
          onTap: () => _pickType(att, type),
        ),
        RdListRow(
          key: const Key('rd-edit-date'),
          title: l10n.redesignCreateDate,
          showChevron: false,
          trailing: RdValueBox(date == null ? '–' : DateFormat.yMMMEd(locale).format(date)),
          onTap: () => promptAttendanceDateChange(context, ref, _id, directPicker: true),
        ),
        if (allDay)
          RdListRow(
            title: l10n.redesignCreateDuration,
            showChevron: false,
            trailing: RdValueBox(l10n.redesignCreateDays(days)),
          )
        else
          RdListRow(
            title: l10n.redesignCreateTime,
            showChevron: false,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RdValueBox(
                  att.startTime ?? type?.startTime ?? '–',
                  semantics: l10n.redesignCreateStart,
                  // The Termin's type gives the times shown and checked.
                  onTap: typeReady ? () => _pickTime(att, type, start: true) : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text('–', style: TextStyle(color: p.text2)),
                ),
                RdValueBox(
                  att.endTime ?? type?.endTime ?? '–',
                  semantics: l10n.redesignCreateEnd,
                  error: rdEndBeforeStart(att.startTime ?? type?.startTime, att.endTime ?? type?.endTime),
                  onTap: typeReady ? () => _pickTime(att, type, start: false) : null,
                ),
              ],
            ),
          ),
      ]),
      const SizedBox(height: 20),
      // What members see of the Termin, then what only the Leitung sees.
      RdGroupLabel(l10n.redesignEventForMembers),
      RdGroupedList(children: [
        if (type?.placeEnabled == true || (att.place ?? '').isNotEmpty)
          RdFieldRow(
            label: l10n.redesignCreatePlace,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  key: const Key('rd-edit-place'),
                  controller: _place,
                  focusNode: _placeFocus,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  style: TextStyle(fontSize: 17, color: p.text),
                  decoration: rdInputDecoration(p, l10n.redesignCreatePlaceHint),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _placeFocus.unfocus(),
                ),
                if (places.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final place in places)
                          RdPlaceChip(place, onTap: () {
                            setState(() => _place.text = place);
                            _savePlace();
                          }),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        RdListRow(
          key: const Key('rd-edit-deadline'),
          title: l10n.redesignCreateDeadline,
          subtitle: deadlineLocked ? l10n.redesignEventEditDeadlineLocked : null,
          value: deadline == null ? l10n.redesignCreateDeadlineNone : rdDeadlineLabel(deadline),
          onTap: deadlineLocked ? null : () => _pickDeadline(att, type),
        ),
        RdListRow(
          title: l10n.redesignEventDescription,
          subtitle: [if (description.isNotEmpty) description, if (attachment.isNotEmpty) attachment].join(' · '),
          onTap: () => showDescriptionAttachmentSheet(context, attendance: att),
        ),
        if (canFiles)
          RdListRow(
            title: l10n.attendanceFilesFolder,
            value: folder.isEmpty ? l10n.redesignEventEditFolderNone : folder,
            onTap: () => _pickFolder(att),
          ),
      ]),
      const SizedBox(height: 20),
      RdGroupLabel(l10n.redesignEventLeadersOnly),
      RdGroupedList(children: [
        RdFieldRow(
          label: l10n.attendanceNotes,
          child: TextField(
            key: const Key('rd-edit-notes'),
            controller: _notes,
            focusNode: _notesFocus,
            minLines: 2,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(fontSize: 17, color: p.text),
            decoration: rdInputDecoration(p, ''),
          ),
        ),
      ]),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 20),
        child: Text(l10n.redesignEventEditHint, style: RdType.meta(p, size: 13)),
      ),
      if (role.isAdmin || role.isResponsible) ...[
        const SizedBox(height: 8),
        RdGroupedList(children: [
          RdListRow(
            key: const Key('rd-event-delete'),
            title: l10n.redesignEventDelete,
            titleColor: p.absent,
            leading: Icon(Icons.delete_outline, color: p.absent),
            showChevron: false,
            onTap: _delete,
          ),
        ]),
      ],
    ]);
  }
}
