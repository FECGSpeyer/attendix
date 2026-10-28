import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;
import 'package:uuid/uuid.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/attendance_providers.dart';
import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/holiday_providers.dart';
import '../../../../core/providers/plan_providers.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../../core/utils/shift_utils.dart';
import '../../../../core/utils/attendance_logic_utils.dart';
import '../../../../core/providers/player_absence_providers.dart';
import '../../../../core/providers/profile_providers.dart';
import '../../../../core/providers/role_permission_providers.dart';
import '../../../../core/providers/shift_providers.dart';
import '../../../../data/models/player_absence/player_absence.dart';
import '../../../../data/models/shift/shift_plan.dart';
import '../../../../data/repositories/profile_repository.dart' show ProfileExtraField;
import '../../../../core/providers/duty_providers.dart';
import '../../../../core/utils/duty_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../core/constants/enums.dart';
import '../../../../data/models/duty/person_unavailability.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../widgets/multi_date_calendar.dart';
import '../widgets/songs_selection_sheet.dart';
import '../../../../core/utils/demo_guard.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';

/// UX_ATT: opens "Termin hinzufügen" as a sheet over the list (Ionic att-list
/// addAttModal, breakpoints [0, 0.8, 1], initial 0.8). Returns true when
/// Termine were created.
Future<bool> showAttendanceCreateSheet(BuildContext context) async {
  // While saving, the sheet must not be dismissed (drag, barrier, back).
  final saving = ValueNotifier<bool>(false);
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (context) => ValueListenableBuilder<bool>(
      valueListenable: saving,
      builder: (context, isSaving, _) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.4,
        maxChildSize: 1,
        expand: false,
        snap: true,
        snapSizes: const [0.8],
        shouldCloseOnMinExtent: !isSaving,
        builder: (context, scrollController) => AttendanceCreatePage(
          asSheet: true,
          scrollController: scrollController,
          savingNotifier: saving,
        ),
      ),
    ),
  );
  saving.dispose();
  return result ?? false;
}

/// Page for creating a new attendance with all Ionic-like features:
/// - Multi-date selection
/// - Holiday highlighting
/// - TypeInfo custom text
/// - All-day duration
/// - Songs/works selection with conductor
/// - Checklist from type
/// - Relevant groups filtering
/// - Shift-based auto-status
///
/// UX_ATT: layout mirrors the Ionic addAttModal (inset grouped list:
/// Datum, Typ, Dauer, Info-Text, Benötigte Personen, Ort, Werke, primary
/// "Termin(e) hinzufügen" row). Uhrzeit and Notizen are Flutter-only extras
/// and sit at the end of the first group.
class AttendanceCreatePage extends ConsumerStatefulWidget {
  const AttendanceCreatePage({
    super.key,
    this.asSheet = false,
    this.scrollController,
    this.savingNotifier,
  });

  /// Shown via [showAttendanceCreateSheet]: pops with `true` after creating
  /// and stays on the list (Ionic), instead of opening the new Termin.
  final bool asSheet;
  final ScrollController? scrollController;

  /// Set while saving so the hosting sheet blocks drag-to-close.
  final ValueNotifier<bool>? savingNotifier;

  @override
  ConsumerState<AttendanceCreatePage> createState() =>
      _AttendanceCreatePageState();
}

class _AttendanceCreatePageState extends ConsumerState<AttendanceCreatePage> {
  // Multi-date selection (Ionic: today is pre-selected)
  List<DateTime> _selectedDates = [_today()];

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 12);
  }

  // Type selection
  AttendanceType? _selectedType;

  // Times
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  // TypeInfo (custom display text)
  String? _typeInfo;

  // All-day duration
  int _durationDays = 1;
  // FN-003: Duration controller as state variable to prevent memory leak
  late final TextEditingController _durationController;

  // Notes
  String? _notes;

  // ATT_DETAIL: place for navigation (types with place_enabled)
  String? _place;

  // Songs selection (if type.manageSongs)
  List<SongHistoryEntry> _songEntries = [];

  // Loading state
  bool _isLoading = false;

  // DUTY: persons needed per ISO weekday (Dienst-Modus), unavailability rules
  Map<int, int> _dutyRequiredByWeekday = {};
  List<PersonUnavailability> _unavailability = [];
  // LOGIC_ATT: loaded in _createAttendances (Ionic addAttendance)
  List<PlayerAbsence> _absences = const [];
  List<ShiftPlan> _shifts = const [];
  List<ProfileExtraField> _extraFields = const [];

  @override
  void initState() {
    super.initState();
    _durationController = TextEditingController(text: '$_durationDays');
  }

  @override
  void dispose() {
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final typesAsync = ref.watch(visibleAttendanceTypesProvider);
    final isAllDay = _selectedType?.allDay == true;
    final showSongs = _selectedType?.manageSongs == true;
    final types = typesAsync.valueOrNull ?? const <AttendanceType>[];

    // Auto-select first visible type (Ionic type_id = first visible type)
    if (_selectedType == null && types.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedType == null) _onTypeChanged(types.first);
      });
    }

    final canSubmit = !_isLoading && _selectedDates.isNotEmpty;
    final submitLabel =
        _selectedDates.length > 1 ? context.l10n.attListAddEvents : context.l10n.attListAddEvent;

    final body = ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _InsetGroup(children: [
          // Datum (Mehrfachauswahl möglich) + info button
          ListTile(
            title: Text(
              context.l10n.attListDateMulti,
              style: const TextStyle(fontSize: 12, color: AppColors.medium),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _getDateDisplayText(),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.info_outline),
              color: AppColors.primary,
              tooltip: context.l10n.attListEventTypes,
              onPressed: _showHolidayInfo,
            ),
            onTap: _onDateClick,
          ),
          // Typ (ion-select)
          ListTile(
            title: Text(context.l10n.attListType),
            trailing: typesAsync.when(
              loading: () => const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (e, _) => const Icon(Icons.error_outline, color: AppColors.danger),
              data: (types) => DropdownButtonHideUnderline(
                child: DropdownButton<AttendanceType>(
                  value: types.contains(_selectedType) ? _selectedType : null,
                  hint: Text(context.l10n.attendanceFlutterNoEventTypes),
                  alignment: AlignmentDirectional.centerEnd,
                  items: [
                    for (final type in types)
                      DropdownMenuItem(value: type, child: Text(type.name)),
                  ],
                  onChanged: (value) {
                    if (value != null) _onTypeChanged(value);
                  },
                ),
              ),
            ),
          ),
          if (isAllDay)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                keyboardType: TextInputType.number,
                controller: _durationController,
                decoration: InputDecoration(
                  labelText: context.l10n.attListDurationDays,
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  final parsed = int.tryParse(value);
                  if (parsed != null && parsed > 0) {
                    setState(() => _durationDays = parsed);
                  }
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              textCapitalization: TextCapitalization.sentences,
              maxLines: null,
              decoration: InputDecoration(
                labelText: context.l10n.attListInfoText,
                helperText: context.l10n.attListInfoTextHelper,
                border: InputBorder.none,
              ),
              onChanged: (value) =>
                  setState(() => _typeInfo = value.isEmpty ? null : value),
            ),
          ),
          // DUTY: persons needed per weekday (Dienst-Modus)
          if (_selectedType?.dutyMode == true)
            for (final wd in _dutyWeekdays())
              ListTile(
                title: Text(context.l10n.attListNeededPeople(DateFormat('EEEE', currentIntlLocale()).format(DateTime(2024, 1, wd.weekday)))),
                subtitle: Text(context.l10n.attendanceFlutterEventsCount(wd.count)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      tooltip: context.l10n.attListLess,
                      onPressed: wd.required <= 1
                          ? null
                          : () => setState(
                              () => _dutyRequiredByWeekday[wd.weekday] = wd.required - 1),
                    ),
                    Text('${wd.required}'),
                    IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: context.l10n.attListMore,
                      onPressed: () => setState(
                          () => _dutyRequiredByWeekday[wd.weekday] = wd.required + 1),
                    ),
                  ],
                ),
              ),
          // ATT_DETAIL: "Ort (für Navigation)" for types with place_enabled
          if (_selectedType?.placeEnabled == true)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                textCapitalization: TextCapitalization.sentences,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: context.l10n.attListPlace,
                  hintText: context.l10n.attListPlacePlaceholder,
                  border: InputBorder.none,
                ),
                onChanged: (value) =>
                    setState(() => _place = value.trim().isEmpty ? null : value.trim()),
              ),
            ),
          // Flutter-only: time range (Ionic takes the type's default times)
          if (!isAllDay)
            ListTile(
              title: Text(context.l10n.exportTime),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => _pickTime(isStart: true),
                    child: Text(_getDisplayStartTime()),
                  ),
                  const Text('–'),
                  TextButton(
                    onPressed: () => _pickTime(isStart: false),
                    child: Text(_getDisplayEndTime()),
                  ),
                ],
              ),
            ),
          // Flutter-only: notes
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: context.l10n.attendanceFlutterNotesOptional,
                border: InputBorder.none,
              ),
              onChanged: (value) => _notes = value,
            ),
          ),
        ]),

        // Werke (only if type.manageSongs)
        if (showSongs) ...[
          _InsetListHeader(
            title: context.l10n.attListSongs,
            trailing: IconButton(
              icon: const Icon(Icons.add),
              color: AppColors.primary,
              tooltip: context.l10n.attListAddSongs,
              onPressed: _addSongs,
            ),
          ),
          _InsetGroup(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              SelectedSongsList(
                entries: _songEntries,
                onEntriesChanged: (entries) => setState(() => _songEntries = entries),
              ),
            ],
          ),
        ],

        // Primary "Termin(e) hinzufügen" row (Ionic ion-item color="primary")
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Material(
            color: canSubmit ? AppColors.primary : AppColors.primary.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: canSubmit ? _createAttendances : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        submitLabel,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                    if (_isLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );

    // No back/barrier dismissal while the Termine are being created.
    return PopScope(
      canPop: !_isLoading,
      child: Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? null
            : AppColors.light,
        appBar: AppBar(
          title: Text(context.l10n.attListAddEvent),
          automaticallyImplyLeading: !widget.asSheet,
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? null
              : AppColors.light,
          actions: [
            if (widget.asSheet)
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: context.l10n.commonClose,
                onPressed: _isLoading
                    ? null
                    : () => Navigator.of(context).pop(false),
              ),
          ],
        ),
        body: body,
      ),
    );
  }

  /// Ionic onDateClick: tapping the field while only today is selected
  /// deselects today first, then the date picker opens.
  Future<void> _onDateClick() async {
    final today = _today();
    if (_selectedDates.length == 1 &&
        DateUtils.isSameDay(_selectedDates.first, today)) {
      setState(() => _selectedDates = []);
      ToastHelper.showInfo(context, context.l10n.attListTodayDeselected);
    }
    await _pickDates();
  }

  void _onTypeChanged(AttendanceType type) {
    setState(() {
      _selectedType = type;
      _dutyRequiredByWeekday = {}; // DUTY
      // Set default times from type (always overwrite to match type defaults)
      _startTime = type.startTime != null ? _parseTime(type.startTime!) : null;
      _endTime = type.endTime != null ? _parseTime(type.endTime!) : null;
      // Set default duration for all-day events
      if (type.allDay == true) {
        _durationDays = type.durationDays ?? 1;
        // FN-003: Sync controller text with state
        _durationController.text = '$_durationDays';
      }
    });
  }

  /// Get display text for start time
  /// Priority: 1. User-selected time (initialised from the type), 2. Placeholder
  String _getDisplayStartTime() {
    if (_startTime != null) {
      return _formatTime(_startTime!);
    }
    // LOGIC_ATT: no tenant practice-time fallback (Ionic uses type times only)
    return context.l10n.shiftsStartTime;
  }

  /// Get display text for end time
  /// Priority: 1. User-selected time (initialised from the type), 2. Placeholder
  String _getDisplayEndTime() {
    if (_endTime != null) {
      return _formatTime(_endTime!);
    }
    // LOGIC_ATT: no tenant practice-time fallback (Ionic uses type times only)
    return context.l10n.attendanceFlutterEndTime;
  }

  // UX_ATT: Ionic dateString ("dd.MM.yyyy" / attList.eventsSelected / noDate)
  String _getDateDisplayText() {
    if (_selectedDates.isEmpty) {
      return context.l10n.attListNoDate;
    } else if (_selectedDates.length == 1) {
      return DateFormat(dateFmt()).format(_selectedDates.first);
    } else {
      return context.l10n.attListEventsSelected(_selectedDates.length);
    }
  }

  Future<void> _pickDates() async {
    final result = await MultiDateCalendarDialog.show(
      context,
      initialDates: _selectedDates,
    );

    if (result != null) {
      setState(() => _selectedDates = result);
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final time = await showTimePicker(
      context: context,
      initialTime: isStart
          ? (_startTime ?? const TimeOfDay(hour: 19, minute: 0))
          : (_endTime ?? const TimeOfDay(hour: 21, minute: 0)),
    );
    if (time != null) {
      setState(() {
        if (isStart) {
          _startTime = time;
        } else {
          _endTime = time;
        }
      });
    }
  }

  Future<void> _addSongs() async {
    final result = await SongsSelectionSheet.show(
      context,
      existingEntries: _songEntries,
    );

    if (result != null) {
      setState(() => _songEntries = result);
    }
  }

  // UX_ATT: Ionic info modal (breakpoint 0.5): Veranstaltungstypen legend,
  // then Ferien and Feiertage.
  void _showHolidayInfo() {
    final holidaysAsync = ref.read(holidaysProvider);
    final types = ref.read(attendanceTypesProvider).valueOrNull ?? const <AttendanceType>[];
    Widget dot(Color color) => Icon(Icons.circle, size: 18, color: color);
    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
          child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        );
    final fmt = DateFormat(dateFmt());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => holidaysAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(context.l10n.attendanceFlutterErrorWith(friendlyErrorMessage(e)))),
          data: (holidays) {
            final hasHolidays =
                holidays.publicHolidays.isNotEmpty || holidays.schoolHolidays.isNotEmpty;
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                header(context.l10n.attListEventTypes),
                _InsetGroup(
                  margin: EdgeInsets.zero,
                  children: [
                    for (final type in types)
                      ListTile(
                        dense: true,
                        leading: dot(ColorUtils.parseNamedColor(type.color)),
                        title: Text(type.name),
                      ),
                    if (hasHolidays) ...[
                      ListTile(
                        dense: true,
                        leading: dot(AppColors.danger),
                        title: Text(context.l10n.attListHolidaysOfState),
                      ),
                      ListTile(
                        dense: true,
                        leading: dot(AppColors.medium),
                        title: Text(context.l10n.attListSchoolHolidaysOfState),
                      ),
                    ],
                  ],
                ),
                header(context.l10n.attListSchoolHolidays),
                for (final h in holidays.schoolHolidays.where((h) => !h.isPast))
                  ListTile(
                    dense: true,
                    title: Text('${fmt.format(h.startDate)} - ${fmt.format(h.endDate)}: ${h.name}'),
                  ),
                header(context.l10n.attListHolidays),
                for (final h in holidays.publicHolidays.where((h) => !h.isPast))
                  ListTile(
                    dense: true,
                    title: Text('${fmt.format(h.startDate)}: ${h.name}'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _createAttendances() async {
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.attendanceFlutterChooseType)),
      );
      return;
    }

    if (_selectedDates.isEmpty) {
      ToastHelper.showWarning(context, context.l10n.attListChooseOneDate);
      return;
    }

    // BL-007: Validate that end time is after start time
    if (_startTime != null && _endTime != null) {
      final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
      final endMinutes = _endTime!.hour * 60 + _endTime!.minute;
      if (endMinutes <= startMinutes) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.attendanceFlutterEndAfterStart)),
        );
        return;
      }
    }

    if (DemoGuard.blocked()) return; // DEMO_GUARD

    // SOL_FIX2: enforce the resolved create permission in the write path
    // (helpers: role permission attendance_create, freshly loaded; any
    // loading error denies).
    final mayCreate = await confirmCanCreateAttendance(
      () => ref.read(canCreateAttendanceConfirmedProvider.future),
    );
    if (!mounted) return;
    if (!mayCreate) {
      ToastHelper.showError(context, context.l10n.attendanceFlutterNoPermission);
      return;
    }

    setState(() => _isLoading = true);
    widget.savingNotifier?.value = true;

    try {
      final tenant = ref.read(currentTenantProvider);

      if (tenant == null) throw Exception(context.l10n.historyFlutterNoTenant);

      // Read everything from ref before the loop (no ref use across awaits).
      _saveClient = ref.read(supabaseClientProvider);
      _saveTenant = tenant;
      try {
        final planTypes = await ref.read(planAttendanceTypesProvider.future);
        _orgPlanTypeIds = {
          for (final t in planTypes)
            if (t.isDefaultOrgPlan) t.id,
        };
      } catch (_) {
        _orgPlanTypeIds = const {};
      }

      int? lastCreatedId;

      // DUTY: "Regelmäßig verhindert" rules (never throws)
      _unavailability = await ref.read(dutyRepositoryWithTenantProvider).getUnavailabilityForTenant();

      // LOGIC_ATT: planned absences (Ionic getPlayerAbsencesForTenant, non-fatal)
      try {
        _absences = await ref.read(playerAbsenceRepositoryWithTenantProvider).getAbsencesForTenant();
      } catch (_) {
        _absences = const [];
      }
      // LOGIC_ATT: shift plans (Ionic db.shifts()) for the shift excuse
      try {
        _shifts = await ref.read(shiftsProvider.future);
      } catch (_) {
        _shifts = const [];
      }
      // LOGIC_ATT: organisation + tenant extra fields (Ionic getPersonExtraFields)
      try {
        _extraFields = await ref.read(personExtraFieldsProvider.future);
      } catch (_) {
        _extraFields = const [];
      }

      // Create attendance for each selected date
      for (final date in _selectedDates) {
        final attendanceId = await _createSingleAttendance(date);
        lastCreatedId = attendanceId;
      }

      if (!mounted) return;

      // Invalidate attendance providers so lists are refreshed
      ref.invalidate(attendancesProvider);
      ref.invalidate(upcomingAttendancesProvider);

      // UX_ATT: Ionic toasts attList.eventAdded / eventsAdded
      final message = _selectedDates.length == 1
          ? context.l10n.attListEventAdded
          : context.l10n.attListEventsAdded;
      ToastHelper.showSuccess(context, message);

      // UX_ATT: as sheet (Ionic) dismiss and stay on the list
      if (widget.asSheet) {
        Navigator.of(context).pop(true);
      } else if (lastCreatedId != null) {
        // Navigate to the last created attendance
        context.go('/attendance/$lastCreatedId');
      } else {
        context.pop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.attendanceFlutterErrorWith(friendlyErrorMessage(e)))),
      );
    } finally {
      widget.savingNotifier?.value = false;
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Captured in _save before creating the Termine.
  SupabaseClient? _saveClient;
  Tenant? _saveTenant;
  Set<Object?> _orgPlanTypeIds = const {};

  Future<int> _createSingleAttendance(DateTime date) async {
    final supabase = _saveClient!;
    final tenant = _saveTenant;
    final type = _selectedType!;

    // Normalize date to noon to avoid timezone issues (Ionic
    // createAttendanceForType: local 12:00 stored as ISO/UTC).
    final normalizedDate = DateTime(date.year, date.month, date.day, 12);
    final dateString = normalizedDate.toUtc().toIso8601String();

    // Prepare checklist from type
    List<Map<String, dynamic>>? checklist;
    if (type.checklist != null && type.checklist!.isNotEmpty) {
      // RT-003: Safe time parsing - use existing _parseTime method
      final parsedTime = type.startTime != null ? _parseTime(type.startTime!) : null;
      final eventDateTime = DateTime(
        normalizedDate.year,
        normalizedDate.month,
        normalizedDate.day,
        parsedTime?.hour ?? 19,
        parsedTime?.minute ?? 0,
      );

      checklist = type.checklist!.map((item) {
        DateTime? dueDate;
        if (item.deadlineHours != null) {
          dueDate =
              eventDateTime.subtract(Duration(hours: item.deadlineHours!));
        }

        return {
          'id': const Uuid().v4(),
          'text': item.text,
          'deadlineHours': item.deadlineHours,
          'completed': false,
          // Ionic: dayjs(...).toISOString() (UTC with Z)
          'dueDate': dueDate?.toUtc().toIso8601String(),
        };
      }).toList();
    }

    // Start/end: user input (Flutter-only field) > type times (Ionic uses
    // the type times only, no tenant fallback).
    final resolvedStartTime = _startTime != null ? _formatTime(_startTime!) : type.startTime;
    final resolvedEndTime = _endTime != null ? _formatTime(_endTime!) : type.endTime;

    // INTEGRATION: new Termine of a type marked as default org plan are
    // org plans (Ionic attendance-create: is_org_plan = type.is_default_org_plan).
    final isOrgPlan = _orgPlanTypeIds.contains(type.id);

    // 1. Create the attendance record
    final response = await supabase.from('attendance').insert({
      'tenantId': tenant!.id,
      'date': dateString,
      'type_id': type.id,
      // Ionic attendance-create: typeInfo ?? '' (hide_name types)
      'typeInfo': _typeInfo ?? '',
      'start_time': resolvedStartTime,
      'end_time': resolvedEndTime,
      'notes': _notes ?? '',
      // Ionic: options.durationDays ?? (all_day ? duration_days : 1)
      'duration_days': type.allDay == true ? _durationDays : 1,
      // ATT_DETAIL: place only for types with place_enabled
      'place': type.placeEnabled ? _place : null,
      'checklist': checklist,
      'created_by': supabase.auth.currentUser?.id,
      'save_in_history': true,
      'is_org_plan': isOrgPlan,
      // DUTY: only stored when it differs from the type default
      if (type.dutyMode && _dutyRequiredFor(normalizedDate) != type.dutyRequired)
        'duty_required': _dutyRequiredFor(normalizedDate),
    }).select().single();

    final attendanceId = response['id'] as int;

    // 2. Create PersonAttendance records for relevant players
    await _createPersonAttendancesForRelevant(
      attendanceId,
      normalizedDate,
      startTime: resolvedStartTime,
      endTime: resolvedEndTime,
    );

    // 3. Create song history entries if songs were selected
    if (_songEntries.isNotEmpty) {
      await _createSongHistoryEntries(attendanceId, dateString);
    }

    return attendanceId;
  }

  /// Create PersonAttendance records for players based on relevant groups
  Future<void> _createPersonAttendancesForRelevant(
    int attendanceId,
    DateTime date, {
    String? startTime,
    String? endTime,
  }) async {
    final supabase = _saveClient!;
    final tenant = _saveTenant;
    final type = _selectedType!;

    if (tenant?.id == null) return;

    // Get all active players (not left, not pending). Paused persons are
    // dropped below like Ionic (`if (player.paused)`), so paused = NULL
    // still counts as not paused.
    final players = await supabase
        .from('player')
        .select('id, instrument, paused, shift_id, shift_start, shift_name, additional_fields')
        .eq('tenantId', tenant!.id!)
        .isFilter('left', null) // null = not archived
        .isFilter('pending', false); // not pending

    final playerList = (players as List).where((p) => p['paused'] != true).toList();
    if (playerList.isEmpty) return;

    // Get default status from attendance type
    // DUTY: nobody is expected until assigned → Neutral for duty types
    final defaultStatus = type.dutyMode ? AttendanceStatus.neutral : type.defaultStatus;
    final canExcuse = type.availableStatuses?.contains(AttendanceStatus.excused) ?? true;

    // Filter players based on relevant_groups
    final relevantGroups = type.relevantGroups;
    final additionalFieldsFilter = type.additionalFieldsFilter;

    final filteredPlayers = playerList.where((player) {
      // Filter by relevant_groups if set
      if (relevantGroups != null && relevantGroups.isNotEmpty) {
        final playerInstrument = player['instrument'] as int?;
        if (playerInstrument == null ||
            !relevantGroups.contains(playerInstrument)) {
          return false;
        }
      }

      // Filter by additional_fields_filter if set
      if (additionalFieldsFilter != null) {
        final filterKey = additionalFieldsFilter['key'] as String?;
        final filterOption = additionalFieldsFilter['option'];

        if (filterKey != null && filterOption != null) {
          final playerAdditionalFields =
              player['additional_fields'] as Map<String, dynamic>?;
          final playerValue = playerAdditionalFields?[filterKey];

          // LOGIC_ATT: organisation + tenant fields (Ionic getPersonExtraFields)
          final fieldDef = _extraFields.where((f) => f.id == filterKey).firstOrNull;

          // If field definition not found (e.g., deleted), include player
          if (fieldDef == null) return true;

          final defaultValue = fieldDef.defaultValue;

          final effectiveValue = playerValue ?? defaultValue;
          if (effectiveValue != filterOption) {
            return false;
          }
        }
      }

      return true;
    }).toList();

    if (filteredPlayers.isEmpty) return;

    // Create PersonAttendance records with optional shift-based status
    final records = <Map<String, dynamic>>[];
    for (final player in filteredPlayers) {
      var status = defaultStatus;
      var notes = '';

      // Apply shift-based status if player has shift and not all-day event
      final shiftId = player['shift_id']?.toString();
      if (shiftId != null && shiftId.isNotEmpty && type.allDay != true) {
        final result = ShiftUtils.statusByShiftOrDefault(
          shift: ShiftUtils.findShift(_shifts, shiftId),
          attendanceDate: date,
          attendanceStart: startTime ?? '19:00',
          attendanceEnd: endTime ?? '21:00',
          defaultStatus: status,
          shiftStart: player['shift_start']?.toString(),
          shiftName: player['shift_name']?.toString(),
        );

        status = result.status;
        notes = result.note;
      }

      // LOGIC_ATT: planned absence on the day → Entschuldigt + reason
      // (Ionic createAttendanceForType), else "Regelmäßig verhindert".
      final personId = (player['id'] as num).toInt();
      final absence = absenceOnDay(_absences, personId, date);
      if (absence != null) {
        status = AttendanceStatus.excused;
        notes = absence.reason;
      } else if (canExcuse) {
        final rule = matchingUnavailability(
            _unavailability, player['id'] as int, date.toIso8601String(), type.id);
        if (rule != null) {
          status = AttendanceStatus.excused;
          notes = unavailabilityNote(rule);
        }
      }

      records.add({
        'attendance_id': attendanceId,
        'person_id': player['id'],
        'status': status.value,
        'notes': notes,
      });
    }

    // Batch insert all records
    await supabase.from('person_attendances').insert(records);
  }

  // DUTY: weekdays of the selected dates with count and persons needed
  List<({int weekday, int count, int required})> _dutyWeekdays() {
    final counts = <int, int>{};
    for (final d in _selectedDates) {
      counts[d.weekday] = (counts[d.weekday] ?? 0) + 1;
    }
    final keys = counts.keys.toList()..sort();
    return [
      for (final wd in keys)
        (
          weekday: wd,
          count: counts[wd]!,
          required: _dutyRequiredByWeekday[wd] ?? _selectedType?.dutyRequired ?? 1,
        ),
    ];
  }

  int _dutyRequiredFor(DateTime date) =>
      _dutyRequiredByWeekday[date.weekday] ?? _selectedType?.dutyRequired ?? 1;

  /// Create song history entries for the attendance
  Future<void> _createSongHistoryEntries(
      int attendanceId, String dateString) async {
    final supabase = _saveClient!;
    final tenant = _saveTenant;

    if (tenant?.id == null) return;

    final entries = _songEntries.map((entry) {
      return {
        // Ionic History columns: songId (camelCase), person_id,
        // otherConductor, visible. conductorName is not a column.
        'songId': entry.songId,
        'attendance_id': attendanceId,
        'date': dateString,
        'tenantId': tenant!.id,
        'person_id':
            entry.otherConductor?.isNotEmpty == true ? null : entry.conductorId,
        'otherConductor': entry.otherConductor,
        'visible': true,
      };
    }).toList();

    if (entries.isNotEmpty) {
      await supabase.from('history').insert(entries);
    }

    // Invalidate song history providers
    if (!mounted) return;
    ref.invalidate(songHistoryProvider(null));
    for (final entry in _songEntries) {
      ref.invalidate(songHistoryProvider(entry.songId));
    }
  }

  TimeOfDay? _parseTime(String time) {
    final parts = time.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

/// UX_ATT: Ionic `ion-list inset` group – rounded card with dividers.
class _InsetGroup extends StatelessWidget {
  const _InsetGroup({
    required this.children,
    this.margin = const EdgeInsets.all(16),
  });

  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(const Divider(height: 1, indent: 16));
      rows.add(children[i]);
    }
    return Card(
      margin: margin,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }
}

/// UX_ATT: Ionic `ion-list-header` with an optional trailing button.
class _InsetListHeader extends StatelessWidget {
  const _InsetListHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
