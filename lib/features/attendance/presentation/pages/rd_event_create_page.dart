import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/config/supabase_config.dart' show currentAuthUserIdProvider, AccountScopeKey;
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/holiday_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/profile_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/providers/team_org_providers.dart' show protocolTypesProvider;
import '../../../../core/providers/role_permission_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/services/holiday_service.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/demo_guard.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../core/utils/type_circle.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/layout/route_leave_guard.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart' show showAppDatePicker, showAppTimePicker;
import '../attendance_create_writes.dart';
import '../widgets/multi_date_calendar.dart';
import '../widgets/songs_selection_sheet.dart';
import '../../data/rd_create_logic.dart';
import '../../../../core/redesign/rd_type_flags.dart';
import '../../../../shared/widgets/adaptive/app_dialog.dart';
import '../widgets/event/rd_create_sheets.dart';
import '../../../settings/presentation/widgets/manage/rd_manage_entries.dart' show rdManageAccessProvider;
import '../widgets/event/rd_form_widgets.dart';
import '../../../../shared/widgets/redesign/rd_widgets.dart';
import '../../../today/presentation/widgets/rd_today_common.dart' show RdInfoCard;
import '../../../../core/redesign/rd_dates.dart';

part 'rd_event_create_form.dart';

/// REDESIGN: "Neuer Termin" (canvas "TerminAnlegen"). Art, Titel, Datum,
/// Zeit, Ort, Abmeldeschluss,
/// weekly series with holiday preview, Werke. Creates through
/// [AttendanceCreateWriter], the same write path as the old Termin sheet.
class RdEventCreatePage extends ConsumerStatefulWidget {
  const RdEventCreatePage({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  ConsumerState<RdEventCreatePage> createState() => _RdEventCreatePageState();
}

class _RdEventCreatePageState extends ConsumerState<RdEventCreatePage> {
  void _update(VoidCallback fn) => setState(fn);

  final _title = TextEditingController();
  final _place = TextEditingController();

  AttendanceType? _type;
  late DateTime _date = rdDay(widget.initialDate ?? DateTime.now());
  String? _start;
  String? _end;
  int _durationDays = 1;
  RdDeadline _deadline = RdDeadline.none;
  RdRepeat _repeat = RdRepeat.once;
  late DateTime _until = rdAddDays(_date, 42);
  bool _skipHolidays = false;
  List<DateTime> _customDates = const [];
  List<SongHistoryEntry> _songs = const [];
  Map<int, int> _duty = {};

  bool _saving = false;
  bool _initialized = false;
  bool _titleEdited = false;
  bool _timesEdited = false;
  bool _durationEdited = false;
  bool _optionsExpanded = false;
  late final AccountScopeKey _draftScope;

  AccountScopeKey get _currentScope => (
    tenantId: ref.read(currentTenantProvider)?.id,
    userId: ref.read(currentAuthUserIdProvider),
  );

  /// The user changed something (asks before discarding).
  bool _touched = false;

  /// A tab switch replaces the page with `context.go`, which skips
  /// [PopScope]; the shell asks this guard first (SOL_FIX25).
  late final RouteLeaveGuardRegistry _leaveGuards;

  @override
  void initState() {
    super.initState();
    _draftScope = _currentScope;
    _leaveGuards = ref.read(routeLeaveGuardRegistryProvider);
    _leaveGuards.add(_onLeave);
  }

  /// Stay while saving; ask before throwing away input.
  Future<bool> _onLeave() async {
    if (_saving) return false;
    if (!await _confirmDiscard()) return false;
    _touched = false;
    return true;
  }

  @override
  void dispose() {
    _leaveGuards.remove(_onLeave);
    _title.dispose();
    _place.dispose();
    super.dispose();
  }

  void _touch(VoidCallback change) => setState(() {
    _touched = true;
    change();
  });

  void _applyType(AttendanceType type) {
    _type = type;
    if (!_titleEdited) _title.text = type.name;
    if (!_timesEdited) {
      _start = type.startTime;
      _end = type.endTime;
    } else {
      // Show the defaults the writer would use for any unset endpoint.
      _start ??= type.startTime;
      _end ??= type.endTime;
    }
    if (!_durationEdited) _durationDays = type.allDay ? (type.durationDays ?? 1) : 1;
    _duty = {};
  }

  List<DateTime> _dates(HolidayData holidays) {
    switch (_repeat) {
      case RdRepeat.once:
        return [_date];
      case RdRepeat.custom:
        return _customDates.isEmpty ? [_date] : _customDates;
      case RdRepeat.weekly:
      case RdRepeat.biweekly:
        final all = rdRepeatDates(_date, _until, everyWeeks: _repeat == RdRepeat.biweekly ? 2 : 1);
        return _skipHolidays ? all.where((d) => rdHolidayOn(holidays, d) == null).toList() : all;
    }
  }

  Future<void> _pickDate() async {
    if (_repeat == RdRepeat.custom) return _pickCustomDates();
    final now = DateTime.now();
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1, now.month, now.day),
      lastDate: DateTime(now.year + 5, now.month, now.day),
      helpText: context.l10n.redesignCreateDate,
    );
    if (picked == null || !mounted) return;
    _touch(() {
      final day = rdDay(picked);
      // A series keeps its length when its first day moves.
      _until = rdMovedSeriesEnd(_date, day, _until);
      _date = day;
      if (_until.isBefore(_date)) _until = _date;
    });
  }

  Future<void> _pickCustomDates() async {
    final result = await MultiDateCalendarDialog.show(
      context,
      initialDates: _repeat == RdRepeat.custom ? _customDates : [_date],
    );
    if (result == null || !mounted) return;
    final days = {for (final d in result) rdDay(d)}.toList()..sort();
    _touch(() {
      if (days.isEmpty) return;
      _date = days.first;
      if (days.length == 1) {
        _repeat = RdRepeat.once;
        _customDates = const [];
      } else {
        _repeat = RdRepeat.custom;
        _customDates = days;
      }
    });
  }

  bool get _isLead => ref.read(rdManageAccessProvider).isAdmin;

  /// Leads open a Verwaltung page from a picker ("Terminarten verwalten");
  /// the form stays below. Back on the form, the chosen Art is read anew
  /// (filters or default status may have changed), the inputs stay.
  Future<void> _manage(String route) async {
    // Tenant repository read before the first await (account switch).
    final repo = ref.read(attendanceTypeRepositoryWithTenantProvider);
    await context.push(route);
    final id = _type?.id;
    if (!mounted || id == null) return;
    final List<AttendanceType> types;
    try {
      // Read the rows directly: a failed load throws and leaves the draft as
      // it is, an Art missing from a successful load was deleted or hidden.
      final rows = await repo.getTypeRows();
      types = [for (final row in rows) AttendanceType.fromJson(row)];
    } catch (_) {
      return;
    }
    if (!mounted || _type?.id != id) return;
    final fresh = types.where((t) => t.id == id && t.visible == true).firstOrNull;
    // Deleted or hidden: the Art has to be chosen again.
    if (fresh != _type) setState(() => _type = fresh);
  }

  Future<void> _pickRepeat(HolidayData holidays) async {
    final holidaysOff = ref.read(currentTenantProvider)?.showHolidays != true;
    final choice = await showRdRepeatSheet(
      context,
      start: _date,
      repeat: _repeat,
      until: _until.isAfter(_date) ? _until : rdAddDays(_date, 42),
      skipHolidays: _skipHolidays,
      holidays: holidays,
      offerHolidays: holidaysOff && _isLead,
    );
    if (choice == null || !mounted) return;
    if (choice.custom) return _pickCustomDates();
    _touch(() {
      _repeat = choice.repeat;
      _until = choice.until;
      _skipHolidays = choice.skipHolidays;
      _customDates = const [];
    });
    if (choice.showHolidays) await _manage(RedesignRoutes.holidays);
  }

  Future<void> _pickTime({required bool start}) async {
    final current = start ? _start : _end;
    final parts = (current ?? (start ? '19:00' : '21:00')).split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.first) ?? 19,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
    final iosLook = Theme.of(context).platform == TargetPlatform.iOS;
    var picked = await showAppTimePicker(
      context: context,
      initialTime: initial,
      helpText: start ? context.l10n.redesignCreateStart : context.l10n.redesignCreateEnd,
    );
    // The iOS wheel returns null when the shown time was confirmed unchanged:
    // with no time yet, that shown default is the choice.
    if (picked == null && iosLook && current == null) picked = initial;
    if (picked == null || !mounted) return;
    final value = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    // The Ende never lies before the Beginn: a later Beginn moves the Ende
    // along, an earlier Ende is refused.
    final times = rdPickedTimes(start: _start, end: _end, pickedStart: start, value: value);
    if (times == null) {
      ToastHelper.showError(context, context.l10n.redesignCreateEndBeforeStart);
      return;
    }
    _touch(() {
      _start = times.start;
      _end = times.end;
      _timesEdited = true;
    });
  }

  Future<void> _pickType(List<AttendanceType> types) async {
    final picked = await showRdTypePicker(
      context,
      types: types,
      selected: _type,
      onManage: _isLead ? () => _manage(RedesignRoutes.attendanceTypes) : null,
    );
    if (picked == null || !mounted || picked.id == _type?.id) return;
    _touch(() {
      _applyType(picked);
    });
  }

  Future<void> _pickDeadline() async {
    final picked = await showRdDeadlinePicker(context, _deadline);
    if (picked != null && mounted) _touch(() => _deadline = picked);
  }

  Future<void> _addSongs() async {
    final result = await SongsSelectionSheet.show(context, existingEntries: _songs);
    if (result != null && mounted) _touch(() => _songs = result);
  }

  Future<bool> _confirmDiscard() async {
    if (!_touched) return true;
    final l10n = context.l10n;
    return showAppConfirm(
      context,
      title: l10n.redesignCreateDiscardTitle,
      message: l10n.redesignCreateDiscardBody,
      confirmText: l10n.redesignCreateDiscard,
      cancelText: l10n.redesignCreateKeepEditing,
      destructive: true,
    );
  }

  Future<void> _cancel() async {
    if (_saving || !await _confirmDiscard() || !mounted) return;
    _touched = false;
    context.canPop() ? context.pop() : context.go(RedesignRoutes.events);
  }

  Future<void> _save(List<DateTime> dates) async {
    var type = _type;
    if (_saving || type == null || dates.isEmpty || _currentScope != _draftScope) return;
    if (DemoGuard.blocked()) return; // DEMO_GUARD
    final l10n = context.l10n;
    final title = _title.text.trim();
    final place = _place.text.trim();
    final start = _start ?? type.startTime;
    final end = _end ?? type.endTime;
    final deadline = _deadline;
    final duration = _durationDays;
    final songs = List<SongHistoryEntry>.of(_songs);
    final duty = Map<int, int>.of(_duty);
    final chosenDates = List<DateTime>.of(dates);
    final selectedTypeId = type.id;
    // Lock immediately, including permission and type-flag checks.
    setState(() => _saving = true);
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      // UI_TENANT_HOIST: bind repositories before the first await.
      final writer = AttendanceCreateWriter(ref);
      final typeNotifier = ref.read(attendanceTypeNotifierProvider.notifier);
      final mayCreate = await confirmCanCreateAttendance(
        () => ref.read(canCreateAttendanceConfirmedProvider.future),
      );
      if (!mounted || _currentScope != _draftScope) return;
      if (!mayCreate) {
        ToastHelper.showError(context, l10n.attendanceFlutterNoPermission);
        return;
      }
      if (writer.tenant == null) {
        ToastHelper.showError(context, l10n.historyFlutterNoTenant);
        return;
      }
      final available = ref.read(visibleAttendanceTypesProvider).valueOrNull;
      final protocols = ref.read(protocolTypesProvider);
      if (available == null ||
          !available.any((t) => t.id == selectedTypeId) ||
          !protocols.hasValue ||
          protocols.hasError ||
          protocols.requireValue.any((t) => t.id == selectedTypeId && t.enableProtocol)) {
        ToastHelper.showError(context, l10n.redesignCreateChooseType);
        return;
      }
      if (!type.allDay && rdEndBeforeStart(start, end)) {
        ToastHelper.showError(context, l10n.redesignCreateEndBeforeStart);
        return;
      }
      final passed = rdDeadlinePassedOn(deadline, chosenDates, start);
      if (passed != null) {
        ToastHelper.showError(
          context,
          l10n.redesignCreateDeadlinePassed(DateFormat.MEd(currentIntlLocale()).format(passed)),
        );
        return;
      }
      var flagsFailed = false;
      type = await rdEnsureTypeFlags(
        typeNotifier,
        type,
        place: place.isNotEmpty,
        songs: songs.isNotEmpty,
        onFailed: () => flagsFailed = true,
      );
      if (!mounted || _currentScope != _draftScope) return;
      final input = AttendanceCreateInput(
        type: type,
        dates: chosenDates,
        typeInfo: title.isEmpty || title == type.name ? null : title,
        startTime: start,
        endTime: end,
        durationDays: duration,
        place: place.isEmpty ? null : place,
        songEntries: songs,
        dutyRequiredByWeekday: duty,
        deadlineFor: deadline == RdDeadline.none ? null : (day) => rdDeadlineFor(deadline, day, start),
      );
      final ids = await writer.create(input);
      if (!mounted || _currentScope != _draftScope) return;
      AttendanceCreateWriter.invalidateAfterCreate(ref, input);
      ref.invalidate(realtimeAttendanceListProvider);
      if (flagsFailed) {
        ToastHelper.showError(context, l10n.rdTypeFlagsFailed);
      } else {
        ToastHelper.showSuccess(context, ids.length == 1 ? l10n.attListEventAdded : l10n.attListEventsAdded);
      }
      _touched = false;
      context.go(ids.length == 1 ? RedesignRoutes.event(ids.single) : RedesignRoutes.events);
    } catch (e) {
      if (!mounted || _currentScope != _draftScope) return;
      ToastHelper.showError(context, l10n.attendanceFlutterErrorWith(friendlyErrorMessage(e)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    ref.watch(currentTenantProvider);
    ref.watch(currentAuthUserIdProvider);
    final sameScope = _currentScope == _draftScope;
    final canCreate = ref.watch(canCreateAttendanceProvider);
    final typesAsync = ref.watch(visibleAttendanceTypesProvider);
    final protocolsAsync = ref.watch(protocolTypesProvider);
    final meetingIds = {
      for (final t in protocolsAsync.valueOrNull ?? [])
        if (t.enableProtocol) t.id,
    };
    final loading = typesAsync.isLoading || protocolsAsync.isLoading;
    final failed = typesAsync.hasError || protocolsAsync.hasError;
    final types = [
      for (final t in typesAsync.valueOrNull ?? <AttendanceType>[])
        if (!meetingIds.contains(t.id)) t,
    ];
    final history = ref.watch(realtimeAttendanceListProvider).valueOrNull ?? const <Attendance>[];
    final holidays = ref.watch(holidaysProvider).valueOrNull ?? const HolidayData();
    final preferredType = rdTemplates(history, types).firstOrNull?.type;

    // Choose a useful type once; history refreshes never replace the draft.
    if (!_initialized && !loading && !failed && types.isNotEmpty && sameScope) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _initialized || _currentScope != _draftScope) return;
        setState(() {
          _initialized = true;
          _applyType(preferredType ?? types.first);
        });
      });
    }
    final dates = _dates(holidays);
    final validType = types.any((t) => t.id == _type?.id);
    final ready = sameScope && canCreate && !loading && !failed && types.isNotEmpty;
    final canSubmit = ready && validType && dates.isNotEmpty && !_saving;
    final Widget body;
    if (!sameScope) {
      body = RdFormBody(
        children: [RdInfoCard(text: l10n.rdCreateFormScopeChanged, icon: Icons.info_outline)],
      );
    } else if (!canCreate) {
      body = RdFormBody(
        children: [RdInfoCard(text: l10n.redesignCreateNoPermission, icon: Icons.lock_outline)],
      );
    } else if (loading) {
      body = RdFormBody(children: [RdInfoCard(text: l10n.redesignTodayLoading, loading: true)]);
    } else if (failed || types.isEmpty) {
      body = RdFormBody(
        children: [
          RdInfoCard(
            text: failed ? l10n.redesignTodayLoadFailed : l10n.rdCreateFormNoEventTypes,
            icon: Icons.event_busy_outlined,
            action:
                failed
                    ? RdOutlineButton(
                      label: l10n.redesignCommonRetry,
                      onPressed: () {
                        ref.invalidate(attendanceTypesProvider);
                        ref.invalidate(protocolTypesProvider);
                      },
                    )
                    : _isLead
                    ? RdOutlineButton(
                      label: l10n.rdAdminManageTypes,
                      onPressed: () => _manage(RedesignRoutes.attendanceTypes),
                    )
                    : null,
          ),
        ],
      );
    } else {
      body = AbsorbPointer(
        absorbing: _saving,
        child: ExcludeFocus(
          excluding: _saving,
          child: _form(context, types: types, history: history, holidays: holidays, dates: dates),
        ),
      );
    }
    return PopScope(
      canPop: !_saving && !_touched,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        backgroundColor: p.bg,
        body: SafeArea(
          child: LayoutBuilder(
            builder:
                (context, constraints) => Column(
                  children: [
                    if (constraints.maxHeight >= 240)
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 672),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 4, 8, 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    l10n.redesignCreateTitle,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: p.text,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: _saving ? null : _cancel,
                                  tooltip: l10n.redesignCommonCancel,
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Expanded(child: body),
                    if (ready)
                      _footer(
                        context,
                        dates,
                        canSubmit: canSubmit,
                        validType: validType,
                        compact: constraints.maxHeight < 360,
                      ),
                  ],
                ),
          ),
        ),
      ),
    );
  }

  Widget _footer(
    BuildContext context,
    List<DateTime> dates, {
    required bool canSubmit,
    required bool validType,
    required bool compact,
  }) {
    final p = context.rd;
    final l10n = context.l10n;
    final type = _type;
    final date = DateFormat.MMMEd(currentIntlLocale()).format(_date);
    final time =
        type?.allDay == true
            ? l10n.redesignTypesListAllDayDays(_durationDays)
            : [if (_start != null) _start!, if (_end != null) _end!].join('–');
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 672),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, compact ? 4 : 8, 16, compact ? 4 : 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!compact)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Text(
                    !validType
                        ? l10n.redesignCreateChooseType
                        : dates.isEmpty
                        ? l10n.rdCreateFormNoDates
                        : [
                          (_title.text.trim().isEmpty ? type?.name : _title.text.trim()) ?? '',
                          date,
                          if (time.isNotEmpty) time,
                        ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: RdType.meta(p, size: 12),
                  ),
                ),
              KeyedSubtree(
                key: const ValueKey('rd-create-submit'),
                child: FilledButton(
                  onPressed: canSubmit ? () => _save(dates) : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: p.primary,
                    foregroundColor: p.onPrimary,
                    textStyle: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                    minimumSize: const Size.fromHeight(50),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child:
                      _saving
                          ? Semantics(
                            label: l10n.redesignTodayLoading,
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: p.primary),
                            ),
                          )
                          : Text(
                            l10n.redesignCreateSubmitMany(dates.length),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
