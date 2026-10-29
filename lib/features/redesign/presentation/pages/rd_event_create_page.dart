import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/holiday_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/profile_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/providers/role_permission_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/services/holiday_service.dart';
import '../../../../core/theme/redesign/rd_palette.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/demo_guard.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/layout/route_leave_guard.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'
    show showAppDatePicker, showAppTimePicker;
import '../../../attendance/presentation/attendance_create_writes.dart';
import '../../../attendance/presentation/widgets/multi_date_calendar.dart';
import '../../../attendance/presentation/widgets/songs_selection_sheet.dart';
import '../../data/rd_create_logic.dart';
import '../widgets/event/rd_create_sheets.dart';
import '../widgets/rd_widgets.dart';
import '../widgets/today/rd_today_common.dart' show RdInfoCard;
import '../../data/rd_dates.dart';

/// REDESIGN: "Neuer Termin" (canvas "TerminAnlegen"). Vorlagen from the
/// group's earlier Termine, Art, Titel, Datum, Zeit, Ort, Abmeldeschluss,
/// weekly series with holiday preview, Werke. Creates through
/// [AttendanceCreateWriter], the same write path as the old Termin sheet.
class RdEventCreatePage extends ConsumerStatefulWidget {
  const RdEventCreatePage({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  ConsumerState<RdEventCreatePage> createState() => _RdEventCreatePageState();
}

class _RdEventCreatePageState extends ConsumerState<RdEventCreatePage> {
  final _title = TextEditingController();
  final _place = TextEditingController();

  AttendanceType? _type;
  String? _templateTitle;
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

  /// The user changed something (asks before discarding, stops the
  /// automatic template).
  bool _touched = false;

  /// A tab switch replaces the page with `context.go`, which skips
  /// [PopScope]; the shell asks this guard first (SOL_FIX25).
  late final RouteLeaveGuardRegistry _leaveGuards;

  @override
  void initState() {
    super.initState();
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
    _start = type.startTime;
    _end = type.endTime;
    _durationDays = type.allDay ? (type.durationDays ?? 1) : 1;
    _duty = {};
    if (!type.manageSongs) _songs = const [];
  }

  void _applyTemplate(RdCreateTemplate t) {
    _applyType(t.type);
    _templateTitle = t.title;
    _start = t.startTime ?? t.type.startTime;
    _end = t.endTime ?? t.type.endTime;
    if (t.durationDays != null) _durationDays = t.durationDays!;
    _title.text = t.typeInfo ?? '';
    _place.text = t.place ?? '';
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
      if (_repeat != RdRepeat.once) _until = rdMovedSeriesEnd(_date, day, _until);
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

  Future<void> _pickRepeat(HolidayData holidays) async {
    final choice = await showRdRepeatSheet(
      context,
      start: _date,
      repeat: _repeat,
      until: _until.isAfter(_date) ? _until : rdAddDays(_date, 42),
      skipHolidays: _skipHolidays,
      holidays: holidays,
    );
    if (choice == null || !mounted) return;
    if (choice.custom) return _pickCustomDates();
    _touch(() {
      _repeat = choice.repeat;
      _until = choice.until;
      _skipHolidays = choice.skipHolidays;
      _customDates = const [];
    });
  }

  Future<void> _pickTime({required bool start}) async {
    final current = start ? _start : _end;
    final parts = (current ?? (start ? '19:00' : '21:00')).split(':');
    final picked = await showAppTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 19,
        minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      ),
      helpText: start ? context.l10n.redesignCreateStart : context.l10n.redesignCreateEnd,
    );
    if (picked == null || !mounted) return;
    final value = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    _touch(() => start ? _start = value : _end = value);
  }

  Future<void> _pickType(List<AttendanceType> types) async {
    final picked = await showRdTypePicker(context, types: types, selected: _type);
    if (picked == null || !mounted || picked.id == _type?.id) return;
    _touch(() {
      _applyType(picked);
      _templateTitle = null;
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
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.redesignCreateDiscardTitle),
        content: Text(l10n.redesignCreateDiscardBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.redesignCreateKeepEditing),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: ctx.rd.absent),
            child: Text(l10n.redesignCreateDiscard),
          ),
        ],
      ),
    );
    return discard == true;
  }

  Future<void> _cancel() async {
    if (_saving || !await _confirmDiscard() || !mounted) return;
    _touched = false;
    context.canPop() ? context.pop() : context.go(RedesignRoutes.events);
  }

  Future<void> _save(List<DateTime> dates) async {
    // UI_TENANT_HOIST: tenant + repositories bound before the first await.
    final writer = AttendanceCreateWriter(ref);
    final type = _type;
    if (_saving || type == null || dates.isEmpty) return;
    if (DemoGuard.blocked()) return; // DEMO_GUARD
    final l10n = context.l10n;
    // SOL_FIX2: the resolved create permission, freshly loaded.
    final mayCreate = await confirmCanCreateAttendance(
      () => ref.read(canCreateAttendanceConfirmedProvider.future),
    );
    if (!mounted) return;
    if (!mayCreate) {
      ToastHelper.showError(context, l10n.attendanceFlutterNoPermission);
      return;
    }
    if (writer.tenant == null) {
      ToastHelper.showError(context, l10n.historyFlutterNoTenant);
      return;
    }

    final deadline = _deadline;
    final start = _start ?? type.startTime;
    final title = _title.text.trim();
    final place = _place.text.trim();
    final input = AttendanceCreateInput(
      type: type,
      dates: dates,
      typeInfo: title.isEmpty || title == type.name ? null : title,
      startTime: _start,
      endTime: _end,
      durationDays: _durationDays,
      place: place.isEmpty ? null : place,
      songEntries: _songs,
      dutyRequiredByWeekday: _duty,
      deadlineFor: deadline == RdDeadline.none ? null : (day) => rdDeadlineFor(deadline, day, start),
    );

    setState(() => _saving = true);
    try {
      final ids = await writer.create(input);
      if (!mounted) return;
      AttendanceCreateWriter.invalidateAfterCreate(ref, input);
      ref.invalidate(realtimeAttendanceListProvider);
      ToastHelper.showSuccess(context, ids.length == 1 ? l10n.attListEventAdded : l10n.attListEventsAdded);
      _touched = false;
      context.go(ids.length == 1 ? RedesignRoutes.event(ids.single) : RedesignRoutes.events);
    } catch (e) {
      if (!mounted) return;
      ToastHelper.showError(context, l10n.attendanceFlutterErrorWith(friendlyErrorMessage(e)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final canCreate = ref.watch(canCreateAttendanceProvider);
    final typesAsync = ref.watch(visibleAttendanceTypesProvider);
    final types = typesAsync.valueOrNull ?? const <AttendanceType>[];
    final history = ref.watch(realtimeAttendanceListProvider).valueOrNull ?? const <Attendance>[];
    final holidays = ref.watch(holidaysProvider).valueOrNull ?? const HolidayData();
    final templates = rdTemplates(history, types);

    // Start with the most used template (or the first Art) until the user
    // changes something.
    if (!_touched && types.isNotEmpty) {
      final first = templates.isNotEmpty ? templates.first : null;
      if ((first != null && _templateTitle != first.title) || (first == null && _type == null)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _touched) return;
          setState(() => first != null ? _applyTemplate(first) : _applyType(types.first));
        });
      }
    }

    final dates = _dates(holidays);
    final canSubmit = canCreate && _type != null && dates.isNotEmpty && !_saving;

    final Widget body;
    if (!canCreate) {
      body = _Body(children: [RdInfoCard(text: l10n.redesignCreateNoPermission, icon: Icons.lock_outline)]);
    } else if (typesAsync.isLoading && types.isEmpty) {
      body = _Body(children: [RdInfoCard(text: l10n.redesignTodayLoading, loading: true)]);
    } else if (types.isEmpty) {
      body = _Body(children: [
        RdInfoCard(
          text: typesAsync.hasError ? l10n.redesignTodayLoadFailed : l10n.redesignCreateNoTypes,
          icon: Icons.event_busy_outlined,
          action: typesAsync.hasError
              ? RdOutlineButton(
                  label: l10n.redesignCommonRetry,
                  onPressed: () => ref.invalidate(attendanceTypesProvider),
                )
              : null,
        ),
      ]);
    } else {
      body = _form(context, types: types, templates: templates, history: history, holidays: holidays, dates: dates, canSubmit: canSubmit);
    }

    return PopScope(
      canPop: !_saving && !_touched,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        backgroundColor: p.bg,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _TopBar(
                title: l10n.redesignCreateTitle,
                cancel: l10n.redesignCommonCancel,
                submit: l10n.redesignCreateSubmit,
                saving: _saving,
                onCancel: _saving ? null : _cancel,
                onSubmit: canSubmit ? () => _save(dates) : null,
              ),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }

  Widget _form(
    BuildContext context, {
    required List<AttendanceType> types,
    required List<RdCreateTemplate> templates,
    required List<Attendance> history,
    required HolidayData holidays,
    required List<DateTime> dates,
    required bool canSubmit,
  }) {
    final p = context.rd;
    final l10n = context.l10n;
    final locale = currentIntlLocale();
    final type = _type;
    final places = rdRecentPlaces(history).where((s) => s != _place.text.trim()).toList();
    final holidayHits = [for (final d in dates) if (rdHolidayOn(holidays, d) != null) d];

    return _Body(children: [
      if (templates.length > 1) ...[
        _Label(l10n.redesignCreateTemplate),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in templates)
              RdChoiceChip(
                label: t.title,
                selected: t.title == _templateTitle,
                onTap: () => _touch(() => _applyTemplate(t)),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(l10n.redesignCreateTemplateHint, style: RdType.meta(p, size: 12)),
        ),
        const SizedBox(height: 16),
      ],
      RdGroupedList(children: [
        _FieldRow(
          label: l10n.redesignCreateTitleLabel,
          child: TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(fontSize: 17, color: p.text),
            decoration: _inputDecoration(p, type?.name ?? ''),
            onChanged: (_) => _touch(() => _templateTitle = null),
          ),
        ),
        RdListRow(
          title: l10n.redesignCreateType,
          trailing: type == null ? null : RdPill(type.name),
          onTap: () => _pickType(types),
        ),
        RdListRow(
          title: l10n.redesignCreateDate,
          trailing: _ValueBox(DateFormat.yMMMEd(locale).format(_date)),
          showChevron: false,
          onTap: _pickDate,
        ),
        if (type?.allDay == true)
          RdListRow(
            title: l10n.redesignCreateDuration,
            showChevron: false,
            trailing: _Stepper(
              value: l10n.redesignCreateDays(_durationDays),
              lessLabel: l10n.redesignCreateFewerDays,
              moreLabel: l10n.redesignCreateMoreDays,
              onLess: _durationDays > 1 ? () => _touch(() => _durationDays--) : null,
              onMore: _durationDays < 30 ? () => _touch(() => _durationDays++) : null,
            ),
          )
        else
          RdListRow(
            title: l10n.redesignCreateTime,
            showChevron: false,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ValueBox(_start ?? '–', semantics: l10n.redesignCreateStart, onTap: () => _pickTime(start: true)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text('–', style: TextStyle(color: p.text2)),
                ),
                _ValueBox(_end ?? '–', semantics: l10n.redesignCreateEnd, onTap: () => _pickTime(start: false)),
              ],
            ),
          ),
        if (type?.placeEnabled == true)
          _FieldRow(
            label: l10n.redesignCreatePlace,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _place,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(fontSize: 17, color: p.text),
                  decoration: _inputDecoration(p, l10n.redesignCreatePlaceHint),
                  onChanged: (_) => _touch(() {}),
                ),
                if (places.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final place in places)
                          _PlaceChip(place, onTap: () => _touch(() => _place.text = place)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ]),
      const SizedBox(height: 16),
      RdGroupedList(children: [
        if (type != null) _InvitedRow(type: type),
        RdListRow(
          title: l10n.redesignCreateDeadline,
          value: rdDeadlineLabel(l10n, _deadline),
          onTap: _pickDeadline,
        ),
        RdListRow(
          title: l10n.redesignCreateMoreDates,
          value: _repeatLabel(l10n, locale),
          onTap: () => _pickRepeat(holidays),
        ),
        if (type?.manageSongs == true)
          RdListRow(
            title: l10n.redesignCreateSongs,
            value: _songs.isEmpty ? l10n.redesignCreateSongsNone : l10n.redesignCreateSongsCount(_songs.length),
            onTap: _addSongs,
          ),
        for (final s in _songs)
          RdListRow(
            leading: const RdRowIcon(Icons.music_note_outlined),
            title: s.songName,
            subtitle: s.displayConductor,
            showChevron: false,
            trailing: IconButton(
              icon: Icon(Icons.close, size: 20, color: p.text2),
              tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              onPressed: () => _touch(() => _songs = [..._songs]..remove(s)),
            ),
          ),
      ]),
      if (type?.dutyMode == true) ...[
        const SizedBox(height: 16),
        RdGroupedList(children: [
          for (final wd in _dutyWeekdays(type!, dates))
            RdListRow(
              title: l10n.redesignCreateDuty(DateFormat.EEEE(locale).format(DateTime(2024, 1, wd.weekday))),
              subtitle: l10n.redesignCreateDutyCount(wd.count),
              showChevron: false,
              trailing: _Stepper(
                value: '${wd.required}',
                lessLabel: l10n.redesignCreateFewer,
                moreLabel: l10n.redesignCreateMore,
                onLess: wd.required > 1 ? () => _touch(() => _duty[wd.weekday] = wd.required - 1) : null,
                onMore: () => _touch(() => _duty[wd.weekday] = wd.required + 1),
              ),
            ),
        ]),
      ],
      if (dates.length > 1 || holidayHits.isNotEmpty) ...[
        const SizedBox(height: 16),
        _Summary(text: _summary(l10n, locale, dates, holidayHits, holidays)),
      ],
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 20),
        child: Text(l10n.redesignCreateLaterHint, style: RdType.meta(p, size: 13)),
      ),
      RdPrimaryButton(
        label: l10n.redesignCreateSubmitMany(dates.length),
        icon: _saving ? null : Icons.add,
        onPressed: canSubmit ? () => _save(dates) : null,
      ),
    ]);
  }

  String _repeatLabel(AppLocalizations l10n, String locale) {
    final until = DateFormat.Md(locale).format(_until);
    return switch (_repeat) {
      RdRepeat.once => l10n.redesignCreateMoreDatesNone,
      RdRepeat.weekly => l10n.redesignCreateRepeatWeekly(DateFormat.E(locale).format(_date), until),
      RdRepeat.biweekly => l10n.redesignCreateRepeatBiweekly(until),
      RdRepeat.custom => l10n.redesignCreateRepeatCustom(_customDates.length - 1),
    };
  }

  String _summary(
    AppLocalizations l10n,
    String locale,
    List<DateTime> dates,
    List<DateTime> holidayHits,
    HolidayData holidays,
  ) {
    final parts = <String>[];
    if (dates.length > 1) {
      final fmt = DateFormat.Md(locale);
      final weekday = DateFormat.EEEE(locale).format(_date);
      final rule = switch (_repeat) {
        RdRepeat.weekly => ', ${l10n.redesignCreateSummaryWeekly(weekday)}',
        RdRepeat.biweekly => ', ${l10n.redesignCreateSummaryBiweekly(weekday)}',
        _ => '',
      };
      parts.add('${l10n.redesignCreateSummaryCount(dates.length)}: '
          '${l10n.redesignCreateSummaryRange(fmt.format(dates.first), fmt.format(dates.last))}$rule.');
    }
    if (holidayHits.isNotEmpty) {
      final names = {for (final d in holidayHits) rdHolidayOn(holidays, d)!}.join(', ');
      parts.add('${l10n.redesignCreateHolidayHits(holidayHits.length)}: $names.');
    }
    return parts.join(' ');
  }

  List<({int weekday, int count, int required})> _dutyWeekdays(AttendanceType type, List<DateTime> dates) {
    final counts = <int, int>{};
    for (final d in dates) {
      counts[d.weekday] = (counts[d.weekday] ?? 0) + 1;
    }
    final keys = counts.keys.toList()..sort();
    return [
      for (final wd in keys)
        (weekday: wd, count: counts[wd]!, required: _duty[wd] ?? type.dutyRequired ?? 1),
    ];
  }

  InputDecoration _inputDecoration(RdPalette p, String hint) => InputDecoration(
        isDense: true,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        contentPadding: const EdgeInsets.only(top: 4, bottom: 2),
        hintText: hint,
        hintStyle: TextStyle(color: p.text2),
      );
}

/// Scrolling content of the page (max width on tablets).
class _Body extends StatelessWidget {
  const _Body({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 32 + MediaQuery.paddingOf(context).bottom),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
            ),
          ),
        ],
      );
}

/// "Abbrechen · Neuer Termin · Anlegen".
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.cancel,
    required this.submit,
    required this.saving,
    required this.onCancel,
    required this.onSubmit,
  });

  final String title;
  final String cancel;
  final String submit;
  final bool saving;
  final VoidCallback? onCancel;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    Widget link(String label, VoidCallback? onTap, {bool bold = false}) => Semantics(
          button: true,
          enabled: onTap != null,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
                      color: onTap == null ? p.text2 : p.link,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
      child: Row(
        children: [
          link(cancel, onCancel),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.text),
              ),
            ),
          ),
          if (saving)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: p.primary),
              ),
            )
          else
            link(submit, onSubmit, bold: true),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
        child: Text(text, style: RdType.meta(context.rd, size: 13)),
      );
}

/// A text field row with a small label above ("Titel", "Ort").
class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: RdType.meta(context.rd, size: 12)),
            child,
          ],
        ),
      );
}

/// Grey value box (date, time) like the canvas.
class _ValueBox extends StatelessWidget {
  const _ValueBox(this.text, {this.onTap, this.semantics});

  final String text;
  final VoidCallback? onTap;
  final String? semantics;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final box = Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: p.track, borderRadius: BorderRadius.circular(8)),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 15, color: p.text, fontFeatures: const [FontFeature.tabularFigures()]),
      ),
    );
    if (onTap == null) return Flexible(child: box);
    return Semantics(
      button: true,
      label: semantics == null ? null : '$semantics $text',
      excludeSemantics: semantics != null,
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: box),
    );
  }
}

/// "− 2 Tage +".
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.lessLabel,
    required this.moreLabel,
    required this.onLess,
    required this.onMore,
  });

  final String value;
  final String lessLabel;
  final String moreLabel;
  final VoidCallback? onLess;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove),
          color: p.primary,
          tooltip: lessLabel,
          onPressed: onLess,
        ),
        Text(value, style: TextStyle(fontSize: 15, color: p.text, fontWeight: FontWeight.w600)),
        IconButton(
          icon: const Icon(Icons.add),
          color: p.primary,
          tooltip: moreLabel,
          onPressed: onMore,
        ),
      ],
    );
  }
}

/// "Wer ist eingeladen?": everyone or the type's groups, with the count of
/// persons the Termin is created for.
class _InvitedRow extends ConsumerWidget {
  const _InvitedRow({required this.type});

  final AttendanceType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final players = ref.watch(playersProvider).valueOrNull;
    final fields = ref.watch(personExtraFieldsProvider).valueOrNull ?? const [];
    final groups = ref.watch(groupsMapProvider).valueOrNull ?? const <int, String>{};
    final count = players == null ? '…' : '${rdInvitedPersons(players, type, fields).length}';
    final relevant = type.relevantGroups ?? const <int>[];
    final value = relevant.isEmpty
        ? l10n.redesignCreateInvitedAll(count)
        : l10n.redesignCreateInvitedGroups(
            [for (final id in relevant) if (groups[id] != null) groups[id]!].join(', '),
            count,
          );
    return RdListRow(
      title: l10n.redesignCreateInvited,
      subtitle: l10n.redesignCreateInvitedHint,
      value: value,
      showChevron: false,
    );
  }
}

/// A place used before ("Gemeindesaal"), fills the Ort field.
class _PlaceChip extends StatelessWidget {
  const _PlaceChip(this.place, {required this.onTap});

  final String place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Semantics(
      button: true,
      child: Material(
        color: p.track,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(place, style: TextStyle(fontSize: 13, color: p.text)),
            ),
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: p.soft, borderRadius: BorderRadius.circular(14)),
        child: Text(text, style: TextStyle(fontSize: 14, color: p.softText, height: 1.35)),
      ),
    );
  }
}
