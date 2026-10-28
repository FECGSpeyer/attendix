import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/attendance_providers.dart';
import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/holiday_providers.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../../core/utils/shift_utils.dart';
import '../../../../core/providers/duty_providers.dart';
import '../../../../core/utils/duty_utils.dart';
import '../../../../core/constants/enums.dart';
import '../../../../data/models/duty/person_unavailability.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../widgets/multi_date_calendar.dart';
import '../widgets/songs_selection_sheet.dart';

/// Page for creating a new attendance with all Ionic-like features:
/// - Multi-date selection
/// - Holiday highlighting
/// - TypeInfo custom text
/// - All-day duration
/// - Songs/works selection with conductor
/// - Checklist from type
/// - Relevant groups filtering
/// - Shift-based auto-status
class AttendanceCreatePage extends ConsumerStatefulWidget {
  const AttendanceCreatePage({super.key});

  @override
  ConsumerState<AttendanceCreatePage> createState() =>
      _AttendanceCreatePageState();
}

class _AttendanceCreatePageState extends ConsumerState<AttendanceCreatePage> {
  // Multi-date selection (starts empty - user must actively select dates)
  List<DateTime> _selectedDates = [];

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
    // Automatically open calendar with today's date pre-selected
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pickDatesWithInitialSelection();
    });
  }

  @override
  void dispose() {
    _durationController.dispose();
    super.dispose();
  }

  /// Opens calendar dialog with today's date pre-selected
  Future<void> _pickDatesWithInitialSelection() async {
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day, 12);

    final result = await MultiDateCalendarDialog.show(
      context,
      initialDates: [normalizedToday], // Today pre-selected in calendar
    );

    if (result != null && mounted) {
      setState(() => _selectedDates = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final typesAsync = ref.watch(visibleAttendanceTypesProvider);
    final isAllDay = _selectedType?.allDay == true;
    final showSongs = _selectedType?.manageSongs == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Anwesenheit hinzufügen'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date picker (multi-select)
            _SectionCard(
              title: 'Datum *',
              trailing: IconButton(
                icon: const Icon(Icons.info_outline, size: 20),
                onPressed: _showHolidayInfo,
                tooltip: 'Feiertage anzeigen',
              ),
              child: ListTile(
                leading:
                    const Icon(Icons.calendar_today, color: AppColors.primary),
                title: Text(_getDateDisplayText()),
                subtitle: _selectedDates.isEmpty
                    ? const Text('Tippe hier um Datum auszuwählen',
                        style: TextStyle(color: AppColors.medium))
                    : null,
                trailing: const Icon(Icons.edit),
                onTap: _pickDates,
              ),
            ),

            const SizedBox(height: AppDimensions.paddingM),

            // Attendance type
            _SectionCard(
              title: 'Typ *',
              child: typesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppDimensions.paddingM),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingM),
                  child: Text('Fehler: $error'),
                ),
                data: (types) {
                  if (types.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(AppDimensions.paddingM),
                      child: Text('Keine Veranstaltungstypen konfiguriert'),
                    );
                  }
                  // Auto-select first type if none selected
                  if (_selectedType == null && types.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && _selectedType == null) {
                        _onTypeChanged(types.first);
                      }
                    });
                  }
                  return Column(
                    children: types
                        .map((type) => RadioListTile<AttendanceType>(
                              value: type,
                              groupValue: _selectedType,
                              onChanged: (value) {
                                if (value != null) _onTypeChanged(value);
                              },
                              title: Text(type.name),
                              subtitle: type.startTime != null && type.allDay != true
                                  ? Text(
                                      '${type.startTime} - ${type.endTime ?? '?'}')
                                  : type.allDay == true
                                      ? const Text('Ganztägig')
                                      : null,
                              secondary: type.color != null
                                  ? Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: ColorUtils.parseNamedColor(type.color),
                                        shape: BoxShape.circle,
                                      ),
                                    )
                                  : const Icon(Icons.event),
                            ))
                        .toList(),
                  );
                },
              ),
            ),

            const SizedBox(height: AppDimensions.paddingM),

            // All-day duration (only shown for all-day events)
            if (isAllDay) ...[
              _SectionCard(
                title: 'Dauer (in Tagen)',
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingM),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: '1',
                          ),
                          controller: _durationController,
                          onChanged: (value) {
                            final parsed = int.tryParse(value);
                            if (parsed != null && parsed > 0) {
                              setState(() => _durationDays = parsed);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        _durationDays == 1 ? 'Tag' : 'Tage',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.paddingM),
            ],

            // TypeInfo (custom display text)
            _SectionCard(
              title: 'Info-Text (optional)',
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: TextField(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'z.B. "Weihnachtskonzert 2026"',
                    helperText: 'Dieser Text wird anstelle des Typs angezeigt.',
                  ),
                  onChanged: (value) =>
                      setState(() => _typeInfo = value.isEmpty ? null : value),
                ),
              ),
            ),

            const SizedBox(height: AppDimensions.paddingM),

            // DUTY: persons needed per weekday (Dienst-Modus)
            if (_selectedType?.dutyMode == true && _selectedDates.isNotEmpty) ...[
              _SectionCard(
                title: 'Benötigte Personen',
                child: Column(
                  children: [
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
                                  : () => setState(() => _dutyRequiredByWeekday[wd.weekday] = wd.required - 1),
                            ),
                            Text('${wd.required}'),
                            IconButton(
                              icon: const Icon(Icons.add),
                              tooltip: 'Mehr',
                              onPressed: () => setState(() => _dutyRequiredByWeekday[wd.weekday] = wd.required + 1),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.paddingM),
            ],

            // Time range (only for non-all-day events)
            if (!isAllDay) ...[
              _SectionCard(
                title: 'Uhrzeit',
                child: Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        leading: const Icon(Icons.access_time,
                            color: AppColors.primary),
                        title: Text(_getDisplayStartTime()),
                        subtitle: const Text('Von'),
                        onTap: () => _pickTime(isStart: true),
                      ),
                    ),
                    const Icon(Icons.arrow_forward, color: AppColors.medium),
                    Expanded(
                      child: ListTile(
                        leading: const Icon(Icons.access_time_filled,
                            color: AppColors.primary),
                        title: Text(_getDisplayEndTime()),
                        subtitle: const Text('Bis'),
                        onTap: () => _pickTime(isStart: false),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.paddingM),
            ],

            // Songs selection (only if type.manageSongs)
            if (showSongs) ...[
              _SectionCard(
                title: 'Werke',
                trailing: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addSongs,
                  tooltip: 'Werk hinzufügen',
                ),
                child: _songEntries.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(AppDimensions.paddingM),
                        child: Text(
                          'Keine Werke ausgewählt',
                          style: TextStyle(color: AppColors.medium),
                        ),
                      )
                    : SelectedSongsList(
                        entries: _songEntries,
                        onEntriesChanged: (entries) {
                          setState(() => _songEntries = entries);
                        },
                      ),
              ),
              const SizedBox(height: AppDimensions.paddingM),
            ],

            // Notes
            _SectionCard(
              title: 'Notizen (optional)',
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: TextField(
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Besondere Hinweise...',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => _notes = value,
                ),
              ),
            ),

            const SizedBox(height: AppDimensions.paddingXL),

            // Summary (only shown when date and type are selected)
            _buildSummary(),

            // Create button at bottom
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isLoading || _selectedDates.isEmpty
                    ? null
                    : _createAttendances,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.add),
                label: Text(_selectedDates.length == 1
                    ? 'Termin hinzufügen'
                    : '${_selectedDates.length} Termine hinzufügen'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build summary section showing what will be created
  Widget _buildSummary() {
    if (_selectedDates.isEmpty || _selectedType == null) {
      return const SizedBox.shrink();
    }

    // Determine what will be displayed as the title in the attendance list
    final displayTitle = _typeInfo?.isNotEmpty == true ? _typeInfo! : _selectedType!.name;
    final typeColor = ColorUtils.parseNamedColor(_selectedType!.color);

    return Column(
      children: [
        _SectionCard(
          title: 'Vorschau (so wird es angezeigt)',
          child: Column(
            children: [
              // Preview card - mimics how it will look in the attendance list
              Container(
                margin: const EdgeInsets.all(AppDimensions.paddingM),
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: typeColor.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: typeColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _getDateDisplayText(),
                            style: TextStyle(
                              color: AppColors.dark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Title (typeInfo or type name)
                    Text(
                      displayTitle,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: typeColor,
                      ),
                    ),
                    // Show original type if typeInfo is set
                    if (_typeInfo?.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Typ: ${_selectedType!.name}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.medium,
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    // Time or all-day
                    Text(
                      _selectedType!.allDay != true
                          ? '${_getDisplayStartTime()} - ${_getDisplayEndTime()}'
                          : 'Ganztägig${_durationDays > 1 ? ' ($_durationDays Tage)' : ''}',
                      style: TextStyle(
                        color: AppColors.medium,
                      ),
                    ),
                    // Songs
                    if (_songEntries.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.music_note, size: 14, color: AppColors.tertiary),
                          const SizedBox(width: 4),
                          Text(
                            '${_songEntries.length} Werk${_songEntries.length == 1 ? '' : 'e'}',
                            style: const TextStyle(fontSize: 12, color: AppColors.tertiary),
                          ),
                        ],
                      ),
                    ],
                    // Notes preview
                    if (_notes?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.notes, size: 14, color: AppColors.medium),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _notes!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: AppColors.medium),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.paddingM),
      ],
    );
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

  String _getDateDisplayText() {
    if (_selectedDates.isEmpty) {
      return 'Kein Datum ausgewählt';
    } else if (_selectedDates.length == 1) {
      return DateFormat('EEEE, d. MMMM yyyy', 'de_DE')
          .format(_selectedDates.first);
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

  void _showHolidayInfo() {
    final holidaysAsync = ref.read(holidaysProvider);

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
          data: (holidays) => ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              // Header
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Feiertage & Ferien',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),

              // Public holidays
              if (holidays.publicHolidays.isNotEmpty) ...[
                const Text(
                  'Feiertage',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...holidays.publicHolidays
                    .where((h) => !h.isPast)
                    .take(10)
                    .map((h) => ListTile(
                          leading: Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: AppColors.danger,
                              shape: BoxShape.circle,
                            ),
                          ),
                          title: Text(h.name),
                          subtitle: Text(DateFormat('dd.MM.yyyy', 'de_DE')
                              .format(h.startDate)),
                          dense: true,
                        )),
                const SizedBox(height: 16),
              ],

              // School holidays
              if (holidays.schoolHolidays.isNotEmpty) ...[
                const Text(
                  'Schulferien',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...holidays.schoolHolidays
                    .where((h) => !h.isPast)
                    .take(10)
                    .map((h) => ListTile(
                          leading: Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: AppColors.medium,
                              shape: BoxShape.circle,
                            ),
                          ),
                          title: Text(h.name),
                          subtitle: Text(
                              '${DateFormat('dd.MM.yyyy', 'de_DE').format(h.startDate)} - ${DateFormat('dd.MM.yyyy', 'de_DE').format(h.endDate)}'),
                          dense: true,
                        )),
              ],

              if (holidays.publicHolidays.isEmpty &&
                  holidays.schoolHolidays.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Keine Feiertage konfiguriert.\n\nAktiviere "Feiertage anzeigen" in den Tenant-Einstellungen und wähle eine Region aus.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.medium),
                  ),
                ),
            ],
          ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte wähle mindestens ein Datum aus')),
      );
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

      final message = _selectedDates.length == 1
          ? 'Anwesenheit hinzugefügt'
          : '${_selectedDates.length} Anwesenheiten hinzugefügt';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );

      // Navigate to the last created attendance
      if (lastCreatedId != null) {
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
      'checklist': checklist,
      'created_by': supabase.auth.currentUser?.id,
      'save_in_history': true,
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.paddingM,
              AppDimensions.paddingS,
              AppDimensions.paddingS,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.medium,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}
