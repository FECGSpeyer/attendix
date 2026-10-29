import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;
import 'package:uuid/uuid.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/constants/enums.dart';
import '../../../core/providers/attendance_providers.dart';
import '../../../core/providers/duty_providers.dart';
import '../../../core/providers/plan_providers.dart';
import '../../../core/providers/player_absence_providers.dart';
import '../../../core/providers/profile_providers.dart';
import '../../../core/providers/shift_providers.dart';
import '../../../core/providers/song_providers.dart';
import '../../../core/providers/tenant_providers.dart';
import '../../../core/utils/attendance_logic_utils.dart';
import '../../../core/utils/duty_utils.dart';
import '../../../core/utils/shift_utils.dart';
import '../../../data/models/attendance/attendance.dart';
import '../../../data/models/duty/person_unavailability.dart';
import '../../../data/models/player_absence/player_absence.dart';
import '../../../data/models/shift/shift_plan.dart';
import '../../../data/models/tenant/tenant.dart';
import '../../../data/repositories/duty_repository.dart';
import '../../../data/repositories/player_absence_repository.dart';
import '../../../data/repositories/profile_repository.dart' show ProfileExtraField;
import 'widgets/songs_selection_sheet.dart' show SongHistoryEntry;

/// What "Termin(e) hinzufügen" creates: one Termin of [type] for every day
/// in [dates]. Shared by the Termin sheet and the new design.
class AttendanceCreateInput {
  const AttendanceCreateInput({
    required this.type,
    required this.dates,
    this.typeInfo,
    this.startTime,
    this.endTime,
    this.durationDays = 1,
    this.place,
    this.songEntries = const [],
    this.dutyRequiredByWeekday = const {},
    this.deadlineFor,
  });

  final AttendanceType type;
  final List<DateTime> dates;

  /// Text shown instead of the type name (Ionic typeInfo).
  final String? typeInfo;

  /// 'HH:mm'; null = the type's time.
  final String? startTime;
  final String? endTime;

  /// Days of an all-day Termin (ignored for other types).
  final int durationDays;

  /// Only stored for types with place_enabled.
  final String? place;
  final List<SongHistoryEntry> songEntries;

  /// DUTY: persons needed per ISO weekday (Dienst-Modus).
  final Map<int, int> dutyRequiredByWeekday;

  /// Signout deadline of the Termin on the given day (local noon);
  /// null or a null result = no deadline (Ionic default).
  final DateTime? Function(DateTime day)? deadlineFor;

  int dutyRequiredFor(DateTime date) =>
      dutyRequiredByWeekday[date.weekday] ?? type.dutyRequired ?? 1;
}

/// Creates Termine like Ionic addAttendance: the attendance row, the
/// person_attendances of the invited persons (planned absences, shifts,
/// "Regelmäßig verhindert") and the song history. Client, tenant and
/// repositories are bound on construction, so construct it before the
/// first await (UI_TENANT_HOIST). The caller checks the create permission
/// (confirmCanCreateAttendance) before [create].
class AttendanceCreateWriter {
  AttendanceCreateWriter(WidgetRef ref)
      : _ref = ref,
        _saveTenant = ref.read(currentTenantProvider),
        _saveClient = ref.read(supabaseClientProvider),
        _dutyRepo = ref.read(dutyRepositoryWithTenantProvider),
        _playerAbsenceRepo = ref.read(playerAbsenceRepositoryWithTenantProvider);

  final WidgetRef _ref;
  final Tenant? _saveTenant;

  /// The tenant the Termine are created in (bound on construction).
  Tenant? get tenant => _saveTenant;
  final SupabaseClient _saveClient;
  final DutyRepository _dutyRepo;
  final PlayerAbsenceRepository _playerAbsenceRepo;

  Set<Object?> _orgPlanTypeIds = const {};
  List<PersonUnavailability> _unavailability = const [];
  // LOGIC_ATT: loaded before the Termine are created (Ionic addAttendance)
  List<PlayerAbsence> _absences = const [];
  List<ShiftPlan> _shifts = const [];
  List<ProfileExtraField> _extraFields = const [];

  /// Creates one Termin per day of [input] and returns their ids in the
  /// same order. Throws on the first failed write.
  Future<List<int>> create(AttendanceCreateInput input) async {
    if (_saveTenant == null) throw StateError('No tenant selected');
    try {
      final planTypes = await _ref.read(planAttendanceTypesProvider.future);
      _orgPlanTypeIds = {
        for (final t in planTypes)
          if (t.isDefaultOrgPlan) t.id,
      };
    } catch (_) {
      _orgPlanTypeIds = const {};
    }

    // DUTY: "Regelmäßig verhindert" rules (never throws)
    _unavailability = await _dutyRepo.getUnavailabilityForTenant();

    // LOGIC_ATT: planned absences (Ionic getPlayerAbsencesForTenant, non-fatal)
    try {
      _absences = await _playerAbsenceRepo.getAbsencesForTenant();
    } catch (_) {
      _absences = const [];
    }
    // LOGIC_ATT: shift plans (Ionic db.shifts()) for the shift excuse
    try {
      _shifts = await _ref.read(shiftsProvider.future);
    } catch (_) {
      _shifts = const [];
    }
    // LOGIC_ATT: organisation + tenant extra fields (Ionic getPersonExtraFields)
    try {
      _extraFields = await _ref.read(personExtraFieldsProvider.future);
    } catch (_) {
      _extraFields = const [];
    }

    final ids = <int>[];
    for (final date in input.dates) {
      ids.add(await _createSingleAttendance(input, date));
    }
    return ids;
  }

  /// Refreshes the Termin lists and the song history after [create].
  static void invalidateAfterCreate(WidgetRef ref, AttendanceCreateInput input) {
    ref.invalidate(attendancesProvider);
    ref.invalidate(upcomingAttendancesProvider);
    if (input.songEntries.isEmpty) return;
    ref.invalidate(songHistoryProvider(null));
    for (final entry in input.songEntries) {
      ref.invalidate(songHistoryProvider(entry.songId));
    }
  }

  Future<int> _createSingleAttendance(AttendanceCreateInput input, DateTime date) async {
    final supabase = _saveClient;
    final tenant = _saveTenant!;
    final type = input.type;

    // Normalize date to noon to avoid timezone issues (Ionic
    // createAttendanceForType: local 12:00 stored as ISO/UTC).
    final normalizedDate = DateTime(date.year, date.month, date.day, 12);
    final dateString = normalizedDate.toUtc().toIso8601String();

    // Prepare checklist from type
    List<Map<String, dynamic>>? checklist;
    if (type.checklist != null && type.checklist!.isNotEmpty) {
      // RT-003: Safe time parsing
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
          dueDate = eventDateTime.subtract(Duration(hours: item.deadlineHours!));
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
    final resolvedStartTime = input.startTime ?? type.startTime;
    final resolvedEndTime = input.endTime ?? type.endTime;

    // INTEGRATION: new Termine of a type marked as default org plan are
    // org plans (Ionic attendance-create: is_org_plan = type.is_default_org_plan).
    final isOrgPlan = _orgPlanTypeIds.contains(type.id);
    final deadline = input.deadlineFor?.call(normalizedDate);

    // 1. Create the attendance record
    final response = await supabase.from('attendance').insert({
      'tenantId': tenant.id,
      'date': dateString,
      'type_id': type.id,
      // Ionic attendance-create: typeInfo ?? '' (hide_name types)
      'typeInfo': input.typeInfo ?? '',
      'start_time': resolvedStartTime,
      'end_time': resolvedEndTime,
      'notes': '', // Ionic addAttendance: this.notes is reset to ''
      // Ionic: options.durationDays ?? (all_day ? duration_days : 1)
      'duration_days': type.allDay == true ? input.durationDays : 1,
      // ATT_DETAIL: place only for types with place_enabled
      'place': type.placeEnabled ? input.place : null,
      'checklist': checklist,
      // PARITY_A (D9): Ionic createAttendanceForType writes no created_by.
      'save_in_history': true,
      'is_org_plan': isOrgPlan,
      // DUTY: only stored when it differs from the type default
      if (type.dutyMode && input.dutyRequiredFor(normalizedDate) != type.dutyRequired)
        'duty_required': input.dutyRequiredFor(normalizedDate),
      // REDESIGN: Abmeldeschluss chosen while creating (none = Ionic)
      if (deadline != null) 'deadline': deadline.toUtc().toIso8601String(),
    }).select().single();

    final attendanceId = response['id'] as int;

    // 2. Create PersonAttendance records for relevant players
    await _createPersonAttendancesForRelevant(
      type,
      attendanceId,
      normalizedDate,
      startTime: resolvedStartTime,
      endTime: resolvedEndTime,
    );

    // 3. Create song history entries if songs were selected
    if (input.songEntries.isNotEmpty) {
      // PARITY_A (D12): Ionic att-list addAttendance writes the picked
      // ion-datetime value (presentation="date" → 'YYYY-MM-DD'), not the
      // noon-normalized attendance date.
      await _createSongHistoryEntries(input.songEntries,
          attendanceId, DateFormat('yyyy-MM-dd').format(date));
    }

    return attendanceId;
  }

  /// Create PersonAttendance records for players based on relevant groups
  Future<void> _createPersonAttendancesForRelevant(
    AttendanceType type,
    int attendanceId,
    DateTime date, {
    String? startTime,
    String? endTime,
  }) async {
    final supabase = _saveClient;
    final tenant = _saveTenant!;

    if (tenant.id == null) return;

    // Get all active players (not left, not pending). Paused persons are
    // dropped below like Ionic (`if (player.paused)`), so paused = NULL
    // still counts as not paused.
    final players = await supabase
        .from('player')
        .select('id, instrument, paused, shift_id, shift_start, shift_name, additional_fields')
        .eq('tenantId', tenant.id!)
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
        if (playerInstrument == null || !relevantGroups.contains(playerInstrument)) {
          return false;
        }
      }

      // Filter by additional_fields_filter if set
      if (additionalFieldsFilter != null) {
        final filterKey = additionalFieldsFilter['key'] as String?;
        final filterOption = additionalFieldsFilter['option'];

        if (filterKey != null && filterOption != null) {
          final playerAdditionalFields = player['additional_fields'] as Map<String, dynamic>?;
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

  /// Create song history entries for the attendance
  Future<void> _createSongHistoryEntries(
      List<SongHistoryEntry> songEntries, int attendanceId, String dateString) async {
    final supabase = _saveClient;
    final tenant = _saveTenant!;

    if (tenant.id == null) return;

    final entries = songEntries.map((entry) {
      return {
        // Ionic History columns: songId (camelCase), person_id,
        // otherConductor, visible. conductorName is not a column.
        'songId': entry.songId,
        'attendance_id': attendanceId,
        'date': dateString,
        'tenantId': tenant.id,
        'person_id': entry.otherConductor?.isNotEmpty == true ? null : entry.conductorId,
        'otherConductor': entry.otherConductor,
        'visible': true,
      };
    }).toList();

    if (entries.isNotEmpty) {
      await supabase.from('history').insert(entries);
    }
  }

  static ({int hour, int minute})? _parseTime(String time) {
    final parts = time.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return (hour: hour, minute: minute);
  }
}
