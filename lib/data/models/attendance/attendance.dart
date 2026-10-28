import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../core/constants/enums.dart';

part 'attendance.freezed.dart';
part 'attendance.g.dart';

/// Custom converter for flexible int/string handling
class _FlexibleIntConverter implements JsonConverter<int?, dynamic> {
  const _FlexibleIntConverter();
  @override
  int? fromJson(dynamic json) {
    if (json == null) return null;
    if (json is int) return json;
    if (json is String) return int.tryParse(json);
    if (json is double) return json.toInt();
    return null;
  }
  @override
  dynamic toJson(int? object) => object;
}

/// Custom converter for flexible string handling
class _FlexibleStringConverter implements JsonConverter<String?, dynamic> {
  const _FlexibleStringConverter();
  @override
  String? fromJson(dynamic json) {
    if (json == null) return null;
    return json.toString();
  }
  @override
  dynamic toJson(String? object) => object;
}

/// Custom converter for flexible bool handling
class _FlexibleBoolConverter implements JsonConverter<bool, dynamic> {
  const _FlexibleBoolConverter();
  @override
  bool fromJson(dynamic json) {
    if (json == null) return false;
    if (json is bool) return json;
    if (json is int) return json != 0;
    if (json is String) return json.toLowerCase() == 'true' || json == '1';
    return false;
  }
  @override
  dynamic toJson(bool object) => object;
}

/// Custom converter for flexible AttendanceStatus handling (int or string)
class _FlexibleAttendanceStatusConverter implements JsonConverter<AttendanceStatus, dynamic> {
  const _FlexibleAttendanceStatusConverter();
  @override
  AttendanceStatus fromJson(dynamic json) {
    if (json == null) return AttendanceStatus.neutral;
    if (json is int) return AttendanceStatus.fromValue(json);
    if (json is String) {
      // Try to parse as integer first
      final intValue = int.tryParse(json);
      if (intValue != null) return AttendanceStatus.fromValue(intValue);
      // Try to match enum name
      return AttendanceStatus.values.firstWhere(
        (s) => s.name == json,
        orElse: () => AttendanceStatus.neutral,
      );
    }
    return AttendanceStatus.neutral;
  }
  @override
  dynamic toJson(AttendanceStatus status) => status.value;
}

/// Custom converter for List<AttendanceStatus> handling (DB stores as int[])
class _FlexibleAttendanceStatusListConverter
    implements JsonConverter<List<AttendanceStatus>?, dynamic> {
  const _FlexibleAttendanceStatusListConverter();

  @override
  List<AttendanceStatus>? fromJson(dynamic json) {
    if (json == null) return null;
    if (json is! List) return null;
    return json.map((e) {
      if (e is int) return AttendanceStatus.fromValue(e);
      if (e is String) {
        final intValue = int.tryParse(e);
        if (intValue != null) return AttendanceStatus.fromValue(intValue);
        return AttendanceStatus.values.firstWhere(
          (s) => s.name.toLowerCase() == e.toLowerCase(),
          orElse: () => AttendanceStatus.neutral,
        );
      }
      return AttendanceStatus.neutral;
    }).toList();
  }

  @override
  dynamic toJson(List<AttendanceStatus>? list) {
    return list?.map((s) => s.value).toList();
  }
}

/// Custom converter for List<int> that handles {} (empty object) as empty list
/// Database sometimes stores empty objects {} instead of empty arrays []
class _FlexibleIntListConverter implements JsonConverter<List<int>?, dynamic> {
  const _FlexibleIntListConverter();

  @override
  List<int>? fromJson(dynamic json) {
    if (json == null) return null;
    // Handle empty object {} as empty list
    if (json is Map) return [];
    if (json is! List) return null;
    return json.map((e) {
      if (e is int) return e;
      if (e is num) return e.toInt();
      if (e is String) return int.tryParse(e) ?? 0;
      return 0;
    }).toList();
  }

  @override
  dynamic toJson(List<int>? list) => list;
}

/// Custom converter for List<String> that handles {} (empty object) as empty list
class _FlexibleStringListConverter implements JsonConverter<List<String>?, dynamic> {
  const _FlexibleStringListConverter();

  @override
  List<String>? fromJson(dynamic json) {
    if (json == null) return null;
    // Handle empty object {} as empty list
    if (json is Map) return [];
    if (json is! List) return null;
    return json.map((e) => e.toString()).toList();
  }

  @override
  dynamic toJson(List<String>? list) => list;
}

/// Attendance model
@freezed
class Attendance with _$Attendance {
  const factory Attendance({
    @_FlexibleIntConverter() int? id,
    @_FlexibleIntConverter() int? tenantId,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'created_by') @_FlexibleStringConverter() String? createdBy,
    required String date,
    @_FlexibleStringConverter() String? type,
    @JsonKey(name: 'type_id') @_FlexibleStringConverter() String? typeId,
    @JsonKey(name: 'save_in_history') @_FlexibleBoolConverter() @Default(false) bool saveInHistory,
    double? percentage,
    @_FlexibleStringListConverter() List<String>? excused,
    @_FlexibleStringConverter() String? typeInfo,
    @_FlexibleStringConverter() String? notes,
    @_FlexibleStringConverter() String? img,
    Map<String, dynamic>? plan,
    @_FlexibleStringListConverter() List<String>? lateExcused,
    @_FlexibleIntListConverter() List<int>? songs,
    @_FlexibleIntListConverter() List<int>? criticalPlayers,
    Map<String, dynamic>? playerNotes,
    @JsonKey(name: 'start_time') @_FlexibleStringConverter() String? startTime,
    @JsonKey(name: 'end_time') @_FlexibleStringConverter() String? endTime,
    @_FlexibleStringConverter() String? deadline,
    @JsonKey(name: 'duration_days') @_FlexibleIntConverter() int? durationDays,
    List<ChecklistItem>? checklist,
    // Fields from Ionic that were missing
    @_FlexibleIntListConverter() List<int>? conductors,
    Map<String, dynamic>? players,
    @JsonKey(name: 'share_plan') @_FlexibleBoolConverter() @Default(false) bool sharePlan,
    // ATTENDANCE_SIGNOUT: place, files folder, description & attachment
    @_FlexibleStringConverter() String? place,
    @JsonKey(name: 'files_folder') @_FlexibleStringConverter() String? filesFolder,
    @_FlexibleStringConverter() String? description,
    @JsonKey(name: 'attachment_url') @_FlexibleStringConverter() String? attachmentUrl,
    @JsonKey(name: 'attachment_name') @_FlexibleStringConverter() String? attachmentName,
  }) = _Attendance;

  factory Attendance.fromJson(Map<String, dynamic> json) =>
      _$AttendanceFromJson(json);
}

/// Person's attendance record
@freezed
class PersonAttendance with _$PersonAttendance {
  const factory PersonAttendance({
    @_FlexibleStringConverter() String? id,
    @JsonKey(name: 'attendance_id') @_FlexibleIntConverter() int? attendanceId,
    @JsonKey(name: 'person_id') @_FlexibleIntConverter() int? personId,
    @_FlexibleAttendanceStatusConverter() @Default(AttendanceStatus.neutral) AttendanceStatus status,
    @_FlexibleStringConverter() String? notes,
    @_FlexibleStringConverter() String? firstName,
    @_FlexibleStringConverter() String? lastName,
    @_FlexibleStringConverter() String? img,
    @_FlexibleIntConverter() int? instrument,
    @_FlexibleStringConverter() String? groupName,
    @_FlexibleStringConverter() String? joined,
    @_FlexibleStringConverter() String? date,
    @_FlexibleStringConverter() String? text,
    @_FlexibleStringConverter() String? title,
    @JsonKey(name: 'changed_by') @_FlexibleStringConverter() String? changedBy,
    @JsonKey(name: 'changed_at') @_FlexibleStringConverter() String? changedAt,
    @JsonKey(name: 'type_id') @_FlexibleStringConverter() String? typeId,
    @_FlexibleBoolConverter() @Default(false) bool highlight,
    @_FlexibleStringConverter() String? left,
    @_FlexibleBoolConverter() @Default(false) bool paused,
    // ATTENDANCE_SIGNOUT: answers to the attendance type's registration fields
    @JsonKey(name: 'registration_answers') Map<String, dynamic>? registrationAnswers,
  }) = _PersonAttendance;

  factory PersonAttendance.fromJson(Map<String, dynamic> json) =>
      _$PersonAttendanceFromJson(json);
}

/// Checklist item for attendance
@freezed
class ChecklistItem with _$ChecklistItem {
  const factory ChecklistItem({
    required String id,
    required String text,
    @_FlexibleIntConverter() int? deadlineHours,
    @_FlexibleBoolConverter() @Default(false) bool completed,
    @_FlexibleStringConverter() String? dueDate,
  }) = _ChecklistItem;

  factory ChecklistItem.fromJson(Map<String, dynamic> json) =>
      _$ChecklistItemFromJson(json);
}

/// Attendance type configuration
@freezed
class AttendanceType with _$AttendanceType {
  const factory AttendanceType({
    @_FlexibleStringConverter() String? id,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    required String name,
    @JsonKey(name: 'default_status') @_FlexibleAttendanceStatusConverter() @Default(AttendanceStatus.neutral) AttendanceStatus defaultStatus,
    @JsonKey(name: 'available_statuses') @_FlexibleAttendanceStatusListConverter() List<AttendanceStatus>? availableStatuses,
    @JsonKey(name: 'default_plan') Map<String, dynamic>? defaultPlan,
    @JsonKey(name: 'tenant_id') @_FlexibleIntConverter() int? tenantId,
    @JsonKey(name: 'relevant_groups') List<int>? relevantGroups,
    @JsonKey(name: 'start_time') @_FlexibleStringConverter() String? startTime,
    @JsonKey(name: 'end_time') @_FlexibleStringConverter() String? endTime,
    @JsonKey(name: 'manage_songs') @_FlexibleBoolConverter() @Default(false) bool manageSongs,
    @_FlexibleIntConverter() int? index,
    @_FlexibleBoolConverter() @Default(true) bool visible,
    @_FlexibleStringConverter() String? color,
    @_FlexibleBoolConverter() @Default(false) bool highlight,
    @JsonKey(name: 'hide_name') @_FlexibleBoolConverter() @Default(false) bool hideName,
    @JsonKey(name: 'include_in_average') @_FlexibleBoolConverter() @Default(true) bool includeInAverage,
    @JsonKey(name: 'all_day') @_FlexibleBoolConverter() @Default(false) bool allDay,
    @JsonKey(name: 'duration_days') @_FlexibleIntConverter() int? durationDays,
    @_FlexibleBoolConverter() @Default(false) bool notification,
    List<int>? reminders,
    @JsonKey(name: 'additional_fields_filter') Map<String, dynamic>? additionalFieldsFilter,
    List<ChecklistItem>? checklist,
    // Field from Ionic that was missing
    @JsonKey(name: 'planning_title') @_FlexibleStringConverter() String? planningTitle,
    // ATTENDANCE_SIGNOUT: place/navigation and registration fields per type
    @JsonKey(name: 'place_enabled') @_FlexibleBoolConverter() @Default(false) bool placeEnabled,
    @JsonKey(name: 'registration_fields') List<RegistrationField>? registrationFields,
  }) = _AttendanceType;

  factory AttendanceType.fromJson(Map<String, dynamic> json) =>
      _$AttendanceTypeFromJson(json);
}

/// Type of a registration field (Anmeldefeld) of an attendance type.
/// Stored as string in `attendance_types.registration_fields` (jsonb).
abstract final class RegistrationFieldType {
  static const text = 'text';
  static const boolean = 'boolean';
  static const select = 'select';
  static const multiSelect = 'multi_select';

  /// German label shown in settings
  static String label(String type) {
    switch (type) {
      case text:
        return 'Text';
      case boolean:
        return 'Ja / Nein';
      case select:
        return 'Einzelauswahl';
      case multiSelect:
        return 'Mehrfachauswahl';
      default:
        return type;
    }
  }
}

/// Registration field (Anmeldefeld) asked when a person signs in to a Termin.
@freezed
class RegistrationField with _$RegistrationField {
  const factory RegistrationField({
    required String id,
    @Default('') String label,
    @Default(RegistrationFieldType.text) String type,
    List<String>? options,
  }) = _RegistrationField;

  factory RegistrationField.fromJson(Map<String, dynamic> json) =>
      _$RegistrationFieldFromJson(json);
}

/// Extension for Attendance
extension AttendanceExtension on Attendance {
  /// Formatted date
  String get formattedDate {
    final dateObj = DateTime.tryParse(date);
    if (dateObj == null) return date;
    return '${dateObj.day.toString().padLeft(2, '0')}.${dateObj.month.toString().padLeft(2, '0')}.${dateObj.year}';
  }

  /// Weekday name
  String get weekdayName {
    final dateObj = DateTime.tryParse(date);
    if (dateObj == null) return '';
    const weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    return weekdays[dateObj.weekday - 1];
  }

  /// Is today
  bool get isToday {
    final dateObj = DateTime.tryParse(date);
    if (dateObj == null) return false;
    final today = DateTime.now();
    return dateObj.year == today.year &&
        dateObj.month == today.month &&
        dateObj.day == today.day;
  }

  /// Maps internal type values to display names
  String _formatTypeForDisplay(String type) {
    switch (type.toLowerCase()) {
      case 'uebung':
        return 'Probe';
      case 'vortrag':
        return 'Vortrag';
      default:
        // Capitalize first letter for unknown types
        return type.isNotEmpty
            ? '${type[0].toUpperCase()}${type.substring(1)}'
            : type;
    }
  }

  /// Display title (like Ionic app logic)
  /// Returns formatted title: "Wochentag, DD.MM.YYYY | typeInfo/Typ-Name"
  ///
  /// Logic:
  /// 1. If typeInfo is set and not empty → "Datum | typeInfo"
  /// 2. If hideName=true (e.g. Probe) → only date
  /// 3. Otherwise → "Datum | Typ-Name"
  String getDisplayTitle(AttendanceType? attendanceType) {
    // 1. If typeInfo is set and not empty, show it
    if (typeInfo != null && typeInfo!.isNotEmpty) {
      return '$weekdayName, $formattedDate | $typeInfo';
    }

    // 2. If hideName=true (e.g. for "Probe"), show only date
    if (attendanceType?.hideName == true) {
      return '$weekdayName, $formattedDate';
    }

    // 3. Otherwise show "Datum | Typ-Name"
    final typeName = attendanceType?.name ?? (type != null ? _formatTypeForDisplay(type!) : 'Anwesenheit');
    return '$weekdayName, $formattedDate | $typeName';
  }

  /// Simple display title without AttendanceType
  /// Uses type field as fallback (mapped to display name)
  String get displayTitle {
    if (typeInfo != null && typeInfo!.isNotEmpty) {
      return typeInfo!;
    }
    return type != null ? _formatTypeForDisplay(type!) : 'Anwesenheit';
  }
}

/// Extension for PersonAttendance
extension PersonAttendanceExtension on PersonAttendance {
  /// Full name
  String get fullName {
    final first = firstName ?? '';
    final last = lastName ?? '';
    return '$first $last'.trim();
  }

  /// Status label
  String get statusLabel {
    switch (status) {
      case AttendanceStatus.present:
        return 'Anwesend';
      case AttendanceStatus.absent:
        return 'Abwesend';
      case AttendanceStatus.excused:
        return 'Entschuldigt';
      case AttendanceStatus.late:
        return 'Verspätet';
      case AttendanceStatus.lateExcused:
        return 'Verspätet (entsch.)';
      case AttendanceStatus.neutral:
        return 'Unbekannt';
    }
  }

  /// Check if person is archived (left the organization)
  bool get isArchived => left != null && left!.isNotEmpty;

  /// Check if person is active (not archived and not paused)
  bool get isActive => !isArchived && !paused;
}