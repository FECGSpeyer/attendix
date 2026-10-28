import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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
import '../../../../core/providers/duty_providers.dart';
import '../../../../core/utils/duty_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../core/constants/enums.dart';
import '../../../../data/models/duty/person_unavailability.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../widgets/multi_date_calendar.dart';
import '../widgets/songs_selection_sheet.dart';

/// UX_ATT: opens "Termin hinzufügen" as a sheet over the list (Ionic att-list
/// addAttModal, breakpoints [0, 0.8, 1], initial 0.8). Returns true when
/// Termine were created.
Future<bool> showAttendanceCreateSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 1,
      expand: false,
      snap: true,
      snapSizes: const [0.8],
      builder: (context, scrollController) => AttendanceCreatePage(
        asSheet: true,
        scrollController: scrollController,
      ),
    ),
  );
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
  });

  /// Shown via [showAttendanceCreateSheet]: pops with `true` after creating
  /// and stays on the list (Ionic), instead of opening the new Termin.
  final bool asSheet;
  final ScrollController? scrollController;

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
        _selectedDates.length > 1 ? 'Termine hinzufügen' : 'Termin hinzufügen';

    final body = ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _InsetGroup(children: [
          // Datum (Mehrfachauswahl möglich) + info button
          ListTile(
            title: const Text(
              'Datum (Mehrfachauswahl möglich)',
              style: TextStyle(fontSize: 12, color: AppColors.medium),
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
              tooltip: 'Veranstaltungstypen',
              onPressed: _showHolidayInfo,
            ),
            onTap: _onDateClick,
          ),
          // Typ (ion-select)
          ListTile(
            title: const Text('Typ'),
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
                  hint: const Text('Keine Veranstaltungstypen konfiguriert'),
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
                decoration: const InputDecoration(
                  labelText: 'Dauer (in Tagen)',
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
              decoration: const InputDecoration(
                labelText: 'Info-Text (optional)',
                helperText: 'Dieser Text wird anstelle des Typs angezeigt.',
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
                title: Text('Benötigte Personen · ${weekdayLongNames[wd.weekday - 1]}'),
                subtitle: Text('${wd.count} ${wd.count == 1 ? 'Termin' : 'Termine'}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      tooltip: 'Weniger',
                      onPressed: wd.required <= 1
                          ? null
                          : () => setState(
                              () => _dutyRequiredByWeekday[wd.weekday] = wd.required - 1),
                    ),
                    Text('${wd.required}'),
                    IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: 'Mehr',
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
                decoration: const InputDecoration(
                  labelText: 'Ort (für Navigation)',
                  hintText: 'z. B. Gemeindehaus, Musterstr. 1, 12345 Berlin',
                  border: InputBorder.none,
                ),
                onChanged: (value) =>
                    setState(() => _place = value.trim().isEmpty ? null : value.trim()),
              ),
            ),
          // Flutter-only: time range (Ionic takes the type's default times)
          if (!isAllDay)
            ListTile(
              title: const Text('Uhrzeit'),
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
              decoration: const InputDecoration(
                labelText: 'Notizen (optional)',
                border: InputBorder.none,
              ),
              onChanged: (value) => _notes = value,
            ),
          ),
        ]),

        // Werke (only if type.manageSongs)
        if (showSongs) ...[
          _InsetListHeader(
            title: 'Werke',
            trailing: IconButton(
              icon: const Icon(Icons.add),
              color: AppColors.primary,
              tooltip: 'Werk(e) hinzufügen',
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

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? null
          : AppColors.light,
      appBar: AppBar(
        title: const Text('Termin hinzufügen'),
        automaticallyImplyLeading: !widget.asSheet,
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? null
            : AppColors.light,
        actions: [
          if (widget.asSheet)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Schließen',
              onPressed: () => Navigator.of(context).pop(false),
            ),
        ],
      ),
      body: body,
    );
  }

  /// Ionic onDateClick: tapping the field while only today is selected
  /// deselects today first, then the date picker opens.
  Future<void> _onDateClick() async {
    final today = _today();
    if (_selectedDates.length == 1 &&
        DateUtils.isSameDay(_selectedDates.first, today)) {
      setState(() => _selectedDates = []);
      ToastHelper.showInfo(context, 'Das aktuelle Datum wurde deselektiert');
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
  /// Priority: 1. User-selected time, 2. Type default, 3. Tenant practice time, 4. Placeholder
  String _getDisplayStartTime() {
    if (_startTime != null) {
      return _formatTime(_startTime!);
    }
    // Fallback to tenant's practice start time
    final tenant = ref.read(currentTenantProvider);
    if (tenant?.practiceStart != null) {
      return tenant!.practiceStart!;
    }
    return 'Startzeit';
  }

  /// Get display text for end time
  /// Priority: 1. User-selected time, 2. Type default, 3. Tenant practice time, 4. Placeholder
  String _getDisplayEndTime() {
    if (_endTime != null) {
      return _formatTime(_endTime!);
    }
    // Fallback to tenant's practice end time
    final tenant = ref.read(currentTenantProvider);
    if (tenant?.practiceEnd != null) {
      return tenant!.practiceEnd!;
    }
    return 'Endzeit';
  }

  // UX_ATT: Ionic dateString ("dd.MM.yyyy" / attList.eventsSelected / noDate)
  String _getDateDisplayText() {
    if (_selectedDates.isEmpty) {
      return 'Kein Datum ausgewählt';
    } else if (_selectedDates.length == 1) {
      return DateFormat('dd.MM.yyyy', 'de_DE').format(_selectedDates.first);
    } else {
      return '${_selectedDates.length} Termine ausgewählt';
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
    final fmt = DateFormat('dd.MM.yyyy', 'de_DE');

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
          error: (e, _) => Center(child: Text('Fehler: $e')),
          data: (holidays) {
            final hasHolidays =
                holidays.publicHolidays.isNotEmpty || holidays.schoolHolidays.isNotEmpty;
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                header('Veranstaltungstypen'),
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
                        title: const Text('Feiertage des ausgewählten Bundeslandes'),
                      ),
                      ListTile(
                        dense: true,
                        leading: dot(AppColors.medium),
                        title: const Text('Ferien des ausgewählten Bundeslandes'),
                      ),
                    ],
                  ],
                ),
                header('Ferien'),
                for (final h in holidays.schoolHolidays.where((h) => !h.isPast))
                  ListTile(
                    dense: true,
                    title: Text('${fmt.format(h.startDate)} - ${fmt.format(h.endDate)}: ${h.name}'),
                  ),
                header('Feiertage'),
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
        const SnackBar(content: Text('Bitte wähle einen Veranstaltungstyp')),
      );
      return;
    }

    if (_selectedDates.isEmpty) {
      ToastHelper.showWarning(context, 'Bitte wähle mindestens ein Datum aus');
      return;
    }

    // BL-007: Validate that end time is after start time
    if (_startTime != null && _endTime != null) {
      final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
      final endMinutes = _endTime!.hour * 60 + _endTime!.minute;
      if (endMinutes <= startMinutes) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ende muss nach Beginn liegen')),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final tenant = ref.read(currentTenantProvider);

      if (tenant == null) throw Exception('Kein Tenant ausgewählt');

      int? lastCreatedId;

      // DUTY: "Regelmäßig verhindert" rules (never throws)
      _unavailability = await ref.read(dutyRepositoryWithTenantProvider).getUnavailabilityForTenant();

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
          ? 'Termin hinzugefügt'
          : 'Termine hinzugefügt';
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
        SnackBar(content: Text('Fehler: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<int> _createSingleAttendance(DateTime date) async {
    final supabase = ref.read(supabaseClientProvider);
    final tenant = ref.read(currentTenantProvider);
    final type = _selectedType!;

    // Normalize date to noon to avoid timezone issues
    final normalizedDate = DateTime(date.year, date.month, date.day, 12);
    final dateString = DateFormat('yyyy-MM-dd').format(normalizedDate);

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
          'dueDate': dueDate?.toIso8601String(),
        };
      }).toList();
    }

    // Resolve start/end times with fallbacks: user input > type default > tenant default
    final resolvedStartTime = _startTime != null
        ? _formatTime(_startTime!)
        : (type.startTime ?? tenant?.practiceStart);
    final resolvedEndTime = _endTime != null
        ? _formatTime(_endTime!)
        : (type.endTime ?? tenant?.practiceEnd);

    // INTEGRATION: new Termine of a type marked as default org plan are
    // org plans (Ionic attendance-create: is_org_plan = type.is_default_org_plan).
    var isOrgPlan = false;
    try {
      final planTypes = await ref.read(planAttendanceTypesProvider.future);
      isOrgPlan =
          planTypes.where((t) => t.id == type.id).firstOrNull?.isDefaultOrgPlan ?? false;
    } catch (_) {
      isOrgPlan = false;
    }

    // 1. Create the attendance record
    final response = await supabase.from('attendance').insert({
      'tenantId': tenant!.id,
      'date': dateString,
      'type_id': type.id,
      'type': type.name,
      'typeInfo': _typeInfo ?? type.name,
      'start_time': resolvedStartTime,
      'end_time': resolvedEndTime,
      'notes': _notes,
      'duration_days': type.allDay == true ? _durationDays : null,
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
    await _createPersonAttendancesForRelevant(attendanceId, normalizedDate);

    // 3. Create song history entries if songs were selected
    if (_songEntries.isNotEmpty) {
      await _createSongHistoryEntries(attendanceId, dateString);
    }

    return attendanceId;
  }

  /// Create PersonAttendance records for players based on relevant groups
  Future<void> _createPersonAttendancesForRelevant(
      int attendanceId, DateTime date) async {
    final supabase = ref.read(supabaseClientProvider);
    final tenant = ref.read(currentTenantProvider);
    final type = _selectedType!;

    if (tenant?.id == null) return;

    // Get all active players (not left, not pending, not paused)
    var query = supabase
        .from('player')
        .select('id, instrument, shift_id, shift_start, shift_name, additional_fields')
        .eq('tenantId', tenant!.id!)
        .isFilter('left', null) // null = not archived
        .isFilter('pending', false) // not pending
        .eq('paused', false); // not paused

    final players = await query;
    final playerList = players as List;
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

          // Get default value from tenant's additional_fields
          // Fix RT-001: Use firstOrNull instead of firstWhere with throwing orElse
          final fieldDef = tenant.additionalFields?.where(
            (f) => f.id == filterKey,
          ).firstOrNull;

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
      final shiftId = player['shift_id'] as String?;
      if (shiftId != null && type.allDay != true) {
        final result = ShiftUtils.getStatusByShift(
          shiftId: shiftId,
          attendanceDate: date,
          attendanceStart: type.startTime ?? '19:00',
          attendanceEnd: type.endTime ?? '21:00',
          defaultStatus: defaultStatus,
          shiftStart: player['shift_start'] as String?,
          shiftName: player['shift_name'] as String?,
        );

        status = result.status;
        notes = result.note;
      }

      // DUTY: "Regelmäßig verhindert" → Entschuldigt
      if (canExcuse) {
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
        'notes': notes.isNotEmpty ? notes : null,
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
    final supabase = ref.read(supabaseClientProvider);
    final tenant = ref.read(currentTenantProvider);

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
