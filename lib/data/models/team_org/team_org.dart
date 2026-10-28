import 'package:freezed_annotation/freezed_annotation.dart';

part 'team_org.freezed.dart';
part 'team_org.g.dart';

/// Teamorganisation models (Ionic: AgendaItem, Task, Protocol).
///
/// Tables: `agenda_items`, `tasks`, `protocols` (snake_case columns,
/// tenant column is `tenant_id`). See supabase/sql/team_org_v2_schema.sql.

/// Field id of the agenda marker inside a plan (Ionic AGENDA_ITEMS_PLACEHOLDER_ID).
const String agendaItemsPlaceholderId = 'agenda-items-placeholder';

/// Protocol section key of the general notes (Ionic PROTOCOL_GENERAL_SECTION_ID).
const String protocolGeneralSectionId = '__general__';

int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

String? _toStr(dynamic v) => v?.toString();

/// Joined person (player) reference: `player!responsible_person_id(id, firstName, lastName)`.
@freezed
class PersonRef with _$PersonRef {
  const factory PersonRef({
    @JsonKey(fromJson: _toInt) int? id,
    String? firstName,
    String? lastName,
  }) = _PersonRef;

  factory PersonRef.fromJson(Map<String, dynamic> json) => _$PersonRefFromJson(json);
}

extension PersonRefX on PersonRef? {
  /// "Vorname Nachname" (empty when unknown).
  String get fullName {
    final p = this;
    if (p == null) return '';
    return '${p.firstName ?? ''} ${p.lastName ?? ''}'.trim();
  }

  String get initials {
    final p = this;
    final a = (p?.firstName ?? '').trim();
    final b = (p?.lastName ?? '').trim();
    return '${a.isNotEmpty ? a[0] : ''}${b.isNotEmpty ? b[0] : ''}'.toUpperCase();
  }
}

/// Topic (Thema) in the Themenspeicher, or a member's suggestion.
@freezed
class AgendaItem with _$AgendaItem {
  const factory AgendaItem({
    String? id,
    @JsonKey(name: 'tenant_id', fromJson: _toInt) int? tenantId,
    @Default('') String title,
    String? description,

    /// open | completed | dropped
    @Default('open') String status,

    /// low | medium | high
    @Default('medium') String priority,
    @JsonKey(name: 'responsible_person_id', fromJson: _toInt) int? responsiblePersonId,
    @JsonKey(name: 'default_duration', fromJson: _toInt) int? defaultDuration,
    @JsonKey(name: 'proposed_by', fromJson: _toInt) int? proposedBy,

    /// null | pending | accepted | rejected
    @JsonKey(name: 'proposal_status') String? proposalStatus,
    @JsonKey(name: 'decision_note') String? decisionNote,
    @JsonKey(name: 'created_at', fromJson: _toStr) String? createdAt,
    @JsonKey(name: 'created_by') String? createdBy,
    @JsonKey(name: 'responsible_person') PersonRef? responsiblePerson,
    PersonRef? proposer,
  }) = _AgendaItem;

  factory AgendaItem.fromJson(Map<String, dynamic> json) => _$AgendaItemFromJson(json);
}

/// One row of the RPC `get_agenda_item_history`.
@freezed
class AgendaItemHistoryEntry with _$AgendaItemHistoryEntry {
  const factory AgendaItemHistoryEntry({
    @JsonKey(name: 'attendance_id', fromJson: _toInt) int? attendanceId,
    @JsonKey(fromJson: _toStr) String? date,
    @JsonKey(name: 'type_id') String? typeId,
    @JsonKey(name: 'type_info') String? typeInfo,
    @JsonKey(name: 'field_id') String? fieldId,

    /// discussed | decided | postponed
    String? outcome,
    @JsonKey(name: 'protocol_status') String? protocolStatus,
  }) = _AgendaItemHistoryEntry;

  factory AgendaItemHistoryEntry.fromJson(Map<String, dynamic> json) =>
      _$AgendaItemHistoryEntryFromJson(json);
}

/// Joined topic reference of a task.
@freezed
class AgendaItemRef with _$AgendaItemRef {
  const factory AgendaItemRef({
    String? id,
    String? title,
  }) = _AgendaItemRef;

  factory AgendaItemRef.fromJson(Map<String, dynamic> json) => _$AgendaItemRefFromJson(json);
}

/// Joined attendance reference (`attendance!attendance_id(id, date, typeInfo, type_id)`).
@freezed
class AttendanceRef with _$AttendanceRef {
  const factory AttendanceRef({
    @JsonKey(fromJson: _toInt) int? id,
    @JsonKey(fromJson: _toStr) String? date,
    String? typeInfo,
    @JsonKey(name: 'type_id') String? typeId,
  }) = _AttendanceRef;

  factory AttendanceRef.fromJson(Map<String, dynamic> json) => _$AttendanceRefFromJson(json);
}

/// Aufgabe (table `tasks`).
@freezed
class TeamTask with _$TeamTask {
  const factory TeamTask({
    String? id,
    @JsonKey(name: 'tenant_id', fromJson: _toInt) int? tenantId,
    @Default('') String title,
    String? description,
    @JsonKey(name: 'responsible_person_id', fromJson: _toInt) int? responsiblePersonId,

    /// low | medium | high
    @Default('medium') String priority,

    /// YYYY-MM-DD
    @JsonKey(name: 'due_date') String? dueDate,

    /// open | in_progress | completed
    @Default('open') String status,
    @JsonKey(name: 'agenda_item_id') String? agendaItemId,
    @JsonKey(name: 'protocol_id') String? protocolId,
    @JsonKey(name: 'attendance_id', fromJson: _toInt) int? attendanceId,
    @JsonKey(name: 'created_at', fromJson: _toStr) String? createdAt,
    @JsonKey(name: 'updated_at', fromJson: _toStr) String? updatedAt,
    @JsonKey(name: 'completed_at', fromJson: _toStr) String? completedAt,
    @JsonKey(name: 'responsible_person') PersonRef? responsiblePerson,
    @JsonKey(name: 'agenda_item') AgendaItemRef? agendaItem,
    AttendanceRef? attendance,
  }) = _TeamTask;

  factory TeamTask.fromJson(Map<String, dynamic> json) => _$TeamTaskFromJson(json);
}

/// Protokoll (table `protocols`, max. one per attendance).
@freezed
class Protocol with _$Protocol {
  const factory Protocol({
    String? id,
    @JsonKey(name: 'attendance_id', fromJson: _toInt) int? attendanceId,
    @JsonKey(name: 'tenant_id', fromJson: _toInt) int? tenantId,

    /// Tiptap JSON doc per plan field id (+ `__general__`).
    @Default(<String, dynamic>{}) Map<String, dynamic> content,

    /// Outcome per field id: discussed | decided | postponed
    @Default(<String, dynamic>{}) Map<String, dynamic> outcomes,

    /// draft | published
    @Default('draft') String status,
    @JsonKey(name: 'created_at', fromJson: _toStr) String? createdAt,
    @JsonKey(name: 'updated_at', fromJson: _toStr) String? updatedAt,
    @JsonKey(name: 'published_at', fromJson: _toStr) String? publishedAt,
    @JsonKey(name: 'published_by') String? publishedBy,
    AttendanceRef? attendance,
  }) = _Protocol;

  factory Protocol.fromJson(Map<String, dynamic> json) => _$ProtocolFromJson(json);
}

/// Protocol-relevant subset of an attendance type (`attendance_types`).
@freezed
class ProtocolType with _$ProtocolType {
  const factory ProtocolType({
    required String id,
    @Default('') String name,
    @JsonKey(name: 'enable_protocol') @Default(false) bool enableProtocol,
    @JsonKey(name: 'relevant_groups') List<int>? relevantGroups,
    @JsonKey(name: 'agenda_default_duration', fromJson: _toInt) int? agendaDefaultDuration,
    @JsonKey(name: 'suggest_postponed') @Default(true) bool suggestPostponed,
    @JsonKey(name: 'default_plan') Map<String, dynamic>? defaultPlan,
    @JsonKey(name: 'start_time') String? startTime,
  }) = _ProtocolType;

  factory ProtocolType.fromJson(Map<String, dynamic> json) => _$ProtocolTypeFromJson(json);
}

/// Attendance (Termin) as needed by the protocol page and the planning of topics.
class ProtocolAttendance {
  ProtocolAttendance({
    required this.id,
    required this.date,
    this.typeId,
    this.typeInfo,
    this.startTime,
    this.endTime,
    this.plan,
    this.persons = const [],
  });

  final int id;
  final String date;
  final String? typeId;
  final String? typeInfo;
  final String? startTime;
  final String? endTime;
  final Map<String, dynamic>? plan;
  final List<ProtocolAttendee> persons;

  List<Map<String, dynamic>> get fields {
    final raw = plan?['fields'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  ProtocolAttendance copyWith({Map<String, dynamic>? plan, String? date}) => ProtocolAttendance(
        id: id,
        date: date ?? this.date,
        typeId: typeId,
        typeInfo: typeInfo,
        startTime: startTime,
        endTime: endTime,
        plan: plan ?? this.plan,
        persons: persons,
      );

  factory ProtocolAttendance.fromJson(Map<String, dynamic> json) {
    final persons = (json['persons'] as List?) ?? const [];
    return ProtocolAttendance(
      id: _toInt(json['id']) ?? 0,
      date: json['date']?.toString() ?? '',
      typeId: json['type_id']?.toString(),
      typeInfo: json['typeInfo']?.toString(),
      startTime: json['start_time']?.toString(),
      endTime: json['end_time']?.toString(),
      plan: json['plan'] is Map ? Map<String, dynamic>.from(json['plan'] as Map) : null,
      persons: persons
          .whereType<Map>()
          .map((e) => ProtocolAttendee.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

/// Person of an attendance (person_attendances + joined player name).
class ProtocolAttendee {
  ProtocolAttendee({
    required this.id,
    this.personId,
    required this.status,
    this.notes,
    this.firstName = '',
    this.lastName = '',
  });

  final String id;
  final int? personId;

  /// AttendanceStatus value (0 neutral, 1 present, 2 excused, 3 late, 4 absent, 5 lateExcused).
  final int status;
  final String? notes;
  final String firstName;
  final String lastName;

  String get name => '$firstName $lastName'.trim();

  factory ProtocolAttendee.fromJson(Map<String, dynamic> json) {
    final person = json['person'] is Map ? Map<String, dynamic>.from(json['person'] as Map) : null;
    return ProtocolAttendee(
      id: (json['id'] ?? json['person_id'] ?? '').toString(),
      personId: _toInt(json['person_id']),
      status: _toInt(json['status']) ?? 0,
      notes: json['notes']?.toString(),
      firstName: (person?['firstName'] ?? json['firstName'] ?? '').toString(),
      lastName: (person?['lastName'] ?? json['lastName'] ?? '').toString(),
    );
  }
}
