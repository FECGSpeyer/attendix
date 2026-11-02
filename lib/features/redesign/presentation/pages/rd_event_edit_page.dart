import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/attendance_detail_providers.dart';
import '../../../../core/providers/attendance_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/providers/role_permission_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/services/offline_queue_service.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/attendance_logic_utils.dart' show defaultDeadline;
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/event_list_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../data/repositories/attendance_repository.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart' show showAppDatePicker, showAppTimePicker;
import '../../../attendance/presentation/widgets/attendance_date_change.dart';
import '../../../attendance/presentation/widgets/attendance_detail/attendance_detail_sheets.dart'
    show showFilesFolderPicker;
import '../../../attendance/presentation/widgets/attendance_detail/description_attachment_sheet.dart';
import '../../../attendance/presentation/widgets/attendance_detail/general_info_accordion.dart'
    show isDeadlineReadonly;
import '../../data/providers/rd_today_providers.dart' show rdDeadlineLabel;
import '../../data/rd_create_logic.dart' show rdRecentPlaces;
import '../../data/rd_event_details_logic.dart';
import '../widgets/event/rd_form_widgets.dart';
import '../widgets/rd_widgets.dart';
import '../widgets/today/rd_today_common.dart';

/// REDESIGN: "Termin bearbeiten" (concept "Vortrag im Beta-Design", board 2):
/// the form of "Neuer Termin" for an existing Termin. Like the Termin page
/// every change is saved right away (text fields when they lose focus or
/// the page closes) through the same writes: Info-Text, Datum (with the
/// status question), Beginn/Ende (re-runs the shift computation), Ort,
/// Abmeldeschluss, Beschreibung & Anhang, Ordner and Notizen. Werke,
/// Ablauf and Vorbereitung are changed in the Überblick.
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

  // UI_TENANT_HOIST: bound when the page opens, so text that is saved when
  // the page closes still goes to this Termin's tenant.
  late final AttendanceRepository _repo;
  late final ProviderContainer _container;

  int get _id => widget.attendanceId;

  @override
  void initState() {
    super.initState();
    _repo = ref.read(attendanceRepositoryWithTenantProvider);
    _container = ProviderScope.containerOf(context, listen: false);
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
    if (!_repo.hasTenantId) return false;
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
    final value = _title.text.trim();
    if (_storedTitle == null || value == _storedTitle) return;
    _storedTitle = value;
    _write({'typeInfo': value.isEmpty ? null : value});
  }

  void _savePlace() {
    final value = _place.text.trim();
    if (_storedPlace == null || value == _storedPlace) return;
    _storedPlace = value;
    _write({'place': value.isEmpty ? null : value});
  }

  void _saveNotes() {
    final value = _notes.text;
    if (_storedNotes == null || value == _storedNotes) return;
    _storedNotes = value;
    _write({'notes': value.isEmpty ? null : value});
  }

  void _done() {
    FocusScope.of(context).unfocus();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RedesignRoutes.event(_id));
    }
  }

  Future<void> _pickTime(Attendance att, {required bool start}) async {
    final current = start ? att.startTime : att.endTime;
    final parts = (current ?? '').split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.first) ?? (start ? 17 : 20),
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
    final picked = await showAppTimePicker(context: context, initialTime: initial);
    if (picked == null || !mounted) return;
    // #232: session of the acting user, captured before the first write.
    final writeSession = ref.read(offlineQueueNotifierProvider.notifier).captureWriteSession();
    final value = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    if (value == current) return;
    if (!await _write({start ? 'start_time' : 'end_time': value})) return;
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
        await _write({'deadline': suggested!.toUtc().toIso8601String()});
      case 'pick':
        await _pickDeadlineDate(att);
    }
  }

  /// Day and time of the Abmeldeschluss (Termin page: from now until the Termin).
  Future<void> _pickDeadlineDate(Attendance att) async {
    final date = DateTime.tryParse(att.date);
    final current = att.deadline == null ? null : DateTime.tryParse(att.deadline!)?.toLocal();
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
    final value = DateTime(day.year, day.month, day.day, time?.hour ?? 23, time?.minute ?? 59);
    await _write({'deadline': value.toUtc().toIso8601String()});
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
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
              child: Row(
                children: [
                  const SizedBox(width: 64),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        l10n.redesignEventEditTitle,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.text),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: RdTextLink(
                        key: const Key('rd-edit-done'),
                        label: l10n.redesignCommonDone,
                        onTap: _done,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
    final days = att.durationDays ?? type?.durationDays ?? 1;

    return RdFormBody(children: [
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
          title: l10n.redesignCreateType,
          showChevron: false,
          trailing: type == null ? null : RdPill(type.name, tone: type.highlight ? RdTone.excused : RdTone.primary),
        ),
        RdListRow(
          key: const Key('rd-edit-date'),
          title: l10n.redesignCreateDate,
          showChevron: false,
          trailing: RdValueBox(date == null ? '–' : DateFormat.yMMMEd(locale).format(date)),
          onTap: () => promptAttendanceDateChange(context, ref, _id),
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
                  att.startTime ?? '–',
                  semantics: l10n.redesignCreateStart,
                  onTap: () => _pickTime(att, start: true),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text('–', style: TextStyle(color: p.text2)),
                ),
                RdValueBox(
                  att.endTime ?? '–',
                  semantics: l10n.redesignCreateEnd,
                  onTap: () => _pickTime(att, start: false),
                ),
              ],
            ),
          ),
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
      ]),
      const SizedBox(height: 16),
      RdGroupedList(children: [
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
      const SizedBox(height: 16),
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
      RdPrimaryButton(label: l10n.redesignCommonDone, onPressed: _done),
    ]);
  }
}
