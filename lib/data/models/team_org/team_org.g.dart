// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'team_org.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PersonRefImpl _$$PersonRefImplFromJson(Map<String, dynamic> json) =>
    _$PersonRefImpl(
      id: _toInt(json['id']),
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
    );

Map<String, dynamic> _$$PersonRefImplToJson(_$PersonRefImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'firstName': instance.firstName,
      'lastName': instance.lastName,
    };

_$AgendaItemImpl _$$AgendaItemImplFromJson(Map<String, dynamic> json) =>
    _$AgendaItemImpl(
      id: json['id'] as String?,
      tenantId: _toInt(json['tenant_id']),
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'open',
      priority: json['priority'] as String? ?? 'medium',
      responsiblePersonId: _toInt(json['responsible_person_id']),
      defaultDuration: _toInt(json['default_duration']),
      proposedBy: _toInt(json['proposed_by']),
      proposalStatus: json['proposal_status'] as String?,
      decisionNote: json['decision_note'] as String?,
      createdAt: _toStr(json['created_at']),
      createdBy: json['created_by'] as String?,
      responsiblePerson:
          json['responsible_person'] == null
              ? null
              : PersonRef.fromJson(
                json['responsible_person'] as Map<String, dynamic>,
              ),
      proposer:
          json['proposer'] == null
              ? null
              : PersonRef.fromJson(json['proposer'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$AgendaItemImplToJson(_$AgendaItemImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenant_id': instance.tenantId,
      'title': instance.title,
      'description': instance.description,
      'status': instance.status,
      'priority': instance.priority,
      'responsible_person_id': instance.responsiblePersonId,
      'default_duration': instance.defaultDuration,
      'proposed_by': instance.proposedBy,
      'proposal_status': instance.proposalStatus,
      'decision_note': instance.decisionNote,
      'created_at': instance.createdAt,
      'created_by': instance.createdBy,
      'responsible_person': instance.responsiblePerson,
      'proposer': instance.proposer,
    };

_$AgendaItemHistoryEntryImpl _$$AgendaItemHistoryEntryImplFromJson(
  Map<String, dynamic> json,
) => _$AgendaItemHistoryEntryImpl(
  attendanceId: _toInt(json['attendance_id']),
  date: _toStr(json['date']),
  typeId: json['type_id'] as String?,
  typeInfo: json['type_info'] as String?,
  fieldId: json['field_id'] as String?,
  outcome: json['outcome'] as String?,
  protocolStatus: json['protocol_status'] as String?,
);

Map<String, dynamic> _$$AgendaItemHistoryEntryImplToJson(
  _$AgendaItemHistoryEntryImpl instance,
) => <String, dynamic>{
  'attendance_id': instance.attendanceId,
  'date': instance.date,
  'type_id': instance.typeId,
  'type_info': instance.typeInfo,
  'field_id': instance.fieldId,
  'outcome': instance.outcome,
  'protocol_status': instance.protocolStatus,
};

_$AgendaItemRefImpl _$$AgendaItemRefImplFromJson(Map<String, dynamic> json) =>
    _$AgendaItemRefImpl(
      id: json['id'] as String?,
      title: json['title'] as String?,
    );

Map<String, dynamic> _$$AgendaItemRefImplToJson(_$AgendaItemRefImpl instance) =>
    <String, dynamic>{'id': instance.id, 'title': instance.title};

_$AttendanceRefImpl _$$AttendanceRefImplFromJson(Map<String, dynamic> json) =>
    _$AttendanceRefImpl(
      id: _toInt(json['id']),
      date: _toStr(json['date']),
      typeInfo: json['typeInfo'] as String?,
      typeId: json['type_id'] as String?,
    );

Map<String, dynamic> _$$AttendanceRefImplToJson(_$AttendanceRefImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'date': instance.date,
      'typeInfo': instance.typeInfo,
      'type_id': instance.typeId,
    };

_$TeamTaskImpl _$$TeamTaskImplFromJson(
  Map<String, dynamic> json,
) => _$TeamTaskImpl(
  id: json['id'] as String?,
  tenantId: _toInt(json['tenant_id']),
  title: json['title'] as String? ?? '',
  description: json['description'] as String?,
  responsiblePersonId: _toInt(json['responsible_person_id']),
  priority: json['priority'] as String? ?? 'medium',
  dueDate: json['due_date'] as String?,
  status: json['status'] as String? ?? 'open',
  agendaItemId: json['agenda_item_id'] as String?,
  protocolId: json['protocol_id'] as String?,
  attendanceId: _toInt(json['attendance_id']),
  createdAt: _toStr(json['created_at']),
  updatedAt: _toStr(json['updated_at']),
  completedAt: _toStr(json['completed_at']),
  responsiblePerson:
      json['responsible_person'] == null
          ? null
          : PersonRef.fromJson(
            json['responsible_person'] as Map<String, dynamic>,
          ),
  agendaItem:
      json['agenda_item'] == null
          ? null
          : AgendaItemRef.fromJson(json['agenda_item'] as Map<String, dynamic>),
  attendance:
      json['attendance'] == null
          ? null
          : AttendanceRef.fromJson(json['attendance'] as Map<String, dynamic>),
);

Map<String, dynamic> _$$TeamTaskImplToJson(_$TeamTaskImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenant_id': instance.tenantId,
      'title': instance.title,
      'description': instance.description,
      'responsible_person_id': instance.responsiblePersonId,
      'priority': instance.priority,
      'due_date': instance.dueDate,
      'status': instance.status,
      'agenda_item_id': instance.agendaItemId,
      'protocol_id': instance.protocolId,
      'attendance_id': instance.attendanceId,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'completed_at': instance.completedAt,
      'responsible_person': instance.responsiblePerson,
      'agenda_item': instance.agendaItem,
      'attendance': instance.attendance,
    };

_$ProtocolImpl _$$ProtocolImplFromJson(
  Map<String, dynamic> json,
) => _$ProtocolImpl(
  id: json['id'] as String?,
  attendanceId: _toInt(json['attendance_id']),
  tenantId: _toInt(json['tenant_id']),
  content:
      json['content'] as Map<String, dynamic>? ?? const <String, dynamic>{},
  outcomes:
      json['outcomes'] as Map<String, dynamic>? ?? const <String, dynamic>{},
  status: json['status'] as String? ?? 'draft',
  createdAt: _toStr(json['created_at']),
  updatedAt: _toStr(json['updated_at']),
  publishedAt: _toStr(json['published_at']),
  publishedBy: json['published_by'] as String?,
  attendance:
      json['attendance'] == null
          ? null
          : AttendanceRef.fromJson(json['attendance'] as Map<String, dynamic>),
);

Map<String, dynamic> _$$ProtocolImplToJson(_$ProtocolImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'attendance_id': instance.attendanceId,
      'tenant_id': instance.tenantId,
      'content': instance.content,
      'outcomes': instance.outcomes,
      'status': instance.status,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'published_at': instance.publishedAt,
      'published_by': instance.publishedBy,
      'attendance': instance.attendance,
    };

_$ProtocolTypeImpl _$$ProtocolTypeImplFromJson(Map<String, dynamic> json) =>
    _$ProtocolTypeImpl(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      enableProtocol: json['enable_protocol'] as bool? ?? false,
      relevantGroups:
          (json['relevant_groups'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList(),
      agendaDefaultDuration: _toInt(json['agenda_default_duration']),
      suggestPostponed: json['suggest_postponed'] as bool? ?? true,
      defaultPlan: json['default_plan'] as Map<String, dynamic>?,
      startTime: json['start_time'] as String?,
    );

Map<String, dynamic> _$$ProtocolTypeImplToJson(_$ProtocolTypeImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'enable_protocol': instance.enableProtocol,
      'relevant_groups': instance.relevantGroups,
      'agenda_default_duration': instance.agendaDefaultDuration,
      'suggest_postponed': instance.suggestPostponed,
      'default_plan': instance.defaultPlan,
      'start_time': instance.startTime,
    };
