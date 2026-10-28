// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attendance.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AttendanceImpl _$$AttendanceImplFromJson(
  Map<String, dynamic> json,
) => _$AttendanceImpl(
  id: const _FlexibleIntConverter().fromJson(json['id']),
  tenantId: const _FlexibleIntConverter().fromJson(json['tenantId']),
  createdAt:
      json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
  createdBy: const _FlexibleStringConverter().fromJson(json['created_by']),
  date: json['date'] as String,
  type: const _FlexibleStringConverter().fromJson(json['type']),
  typeId: const _FlexibleStringConverter().fromJson(json['type_id']),
  saveInHistory:
      json['save_in_history'] == null
          ? false
          : const _FlexibleBoolConverter().fromJson(json['save_in_history']),
  percentage: (json['percentage'] as num?)?.toDouble(),
  excused: const _FlexibleStringListConverter().fromJson(json['excused']),
  typeInfo: const _FlexibleStringConverter().fromJson(json['typeInfo']),
  notes: const _FlexibleStringConverter().fromJson(json['notes']),
  img: const _FlexibleStringConverter().fromJson(json['img']),
  plan: json['plan'] as Map<String, dynamic>?,
  lateExcused: const _FlexibleStringListConverter().fromJson(
    json['lateExcused'],
  ),
  songs: const _FlexibleIntListConverter().fromJson(json['songs']),
  criticalPlayers: const _FlexibleIntListConverter().fromJson(
    json['criticalPlayers'],
  ),
  playerNotes: json['playerNotes'] as Map<String, dynamic>?,
  startTime: const _FlexibleStringConverter().fromJson(json['start_time']),
  endTime: const _FlexibleStringConverter().fromJson(json['end_time']),
  deadline: const _FlexibleStringConverter().fromJson(json['deadline']),
  durationDays: const _FlexibleIntConverter().fromJson(json['duration_days']),
  checklist:
      (json['checklist'] as List<dynamic>?)
          ?.map((e) => ChecklistItem.fromJson(e as Map<String, dynamic>))
          .toList(),
  conductors: const _FlexibleIntListConverter().fromJson(json['conductors']),
  players: json['players'] as Map<String, dynamic>?,
  sharePlan:
      json['share_plan'] == null
          ? false
          : const _FlexibleBoolConverter().fromJson(json['share_plan']),
  dutyRequired: const _FlexibleIntConverter().fromJson(json['duty_required']),
);

Map<String, dynamic> _$$AttendanceImplToJson(
  _$AttendanceImpl instance,
) => <String, dynamic>{
  'id': const _FlexibleIntConverter().toJson(instance.id),
  'tenantId': const _FlexibleIntConverter().toJson(instance.tenantId),
  'created_at': instance.createdAt?.toIso8601String(),
  'created_by': const _FlexibleStringConverter().toJson(instance.createdBy),
  'date': instance.date,
  'type': const _FlexibleStringConverter().toJson(instance.type),
  'type_id': const _FlexibleStringConverter().toJson(instance.typeId),
  'save_in_history': const _FlexibleBoolConverter().toJson(
    instance.saveInHistory,
  ),
  'percentage': instance.percentage,
  'excused': const _FlexibleStringListConverter().toJson(instance.excused),
  'typeInfo': const _FlexibleStringConverter().toJson(instance.typeInfo),
  'notes': const _FlexibleStringConverter().toJson(instance.notes),
  'img': const _FlexibleStringConverter().toJson(instance.img),
  'plan': instance.plan,
  'lateExcused': const _FlexibleStringListConverter().toJson(
    instance.lateExcused,
  ),
  'songs': const _FlexibleIntListConverter().toJson(instance.songs),
  'criticalPlayers': const _FlexibleIntListConverter().toJson(
    instance.criticalPlayers,
  ),
  'playerNotes': instance.playerNotes,
  'start_time': const _FlexibleStringConverter().toJson(instance.startTime),
  'end_time': const _FlexibleStringConverter().toJson(instance.endTime),
  'deadline': const _FlexibleStringConverter().toJson(instance.deadline),
  'duration_days': const _FlexibleIntConverter().toJson(instance.durationDays),
  'checklist': instance.checklist,
  'conductors': const _FlexibleIntListConverter().toJson(instance.conductors),
  'players': instance.players,
  'share_plan': const _FlexibleBoolConverter().toJson(instance.sharePlan),
  'duty_required': const _FlexibleIntConverter().toJson(instance.dutyRequired),
};

_$PersonAttendanceImpl _$$PersonAttendanceImplFromJson(
  Map<String, dynamic> json,
) => _$PersonAttendanceImpl(
  id: const _FlexibleStringConverter().fromJson(json['id']),
  attendanceId: const _FlexibleIntConverter().fromJson(json['attendance_id']),
  personId: const _FlexibleIntConverter().fromJson(json['person_id']),
  status:
      json['status'] == null
          ? AttendanceStatus.neutral
          : const _FlexibleAttendanceStatusConverter().fromJson(json['status']),
  notes: const _FlexibleStringConverter().fromJson(json['notes']),
  firstName: const _FlexibleStringConverter().fromJson(json['firstName']),
  lastName: const _FlexibleStringConverter().fromJson(json['lastName']),
  img: const _FlexibleStringConverter().fromJson(json['img']),
  instrument: const _FlexibleIntConverter().fromJson(json['instrument']),
  groupName: const _FlexibleStringConverter().fromJson(json['groupName']),
  joined: const _FlexibleStringConverter().fromJson(json['joined']),
  date: const _FlexibleStringConverter().fromJson(json['date']),
  text: const _FlexibleStringConverter().fromJson(json['text']),
  title: const _FlexibleStringConverter().fromJson(json['title']),
  changedBy: const _FlexibleStringConverter().fromJson(json['changed_by']),
  changedAt: const _FlexibleStringConverter().fromJson(json['changed_at']),
  typeId: const _FlexibleStringConverter().fromJson(json['type_id']),
  highlight:
      json['highlight'] == null
          ? false
          : const _FlexibleBoolConverter().fromJson(json['highlight']),
  left: const _FlexibleStringConverter().fromJson(json['left']),
  paused:
      json['paused'] == null
          ? false
          : const _FlexibleBoolConverter().fromJson(json['paused']),
  dutyState: const _FlexibleStringConverter().fromJson(json['duty_state']),
  dutyAssignedBy: const _FlexibleStringConverter().fromJson(
    json['duty_assigned_by'],
  ),
  dutyAssignedAt: const _FlexibleStringConverter().fromJson(
    json['duty_assigned_at'],
  ),
);

Map<String, dynamic> _$$PersonAttendanceImplToJson(
  _$PersonAttendanceImpl instance,
) => <String, dynamic>{
  'id': const _FlexibleStringConverter().toJson(instance.id),
  'attendance_id': const _FlexibleIntConverter().toJson(instance.attendanceId),
  'person_id': const _FlexibleIntConverter().toJson(instance.personId),
  'status': const _FlexibleAttendanceStatusConverter().toJson(instance.status),
  'notes': const _FlexibleStringConverter().toJson(instance.notes),
  'firstName': const _FlexibleStringConverter().toJson(instance.firstName),
  'lastName': const _FlexibleStringConverter().toJson(instance.lastName),
  'img': const _FlexibleStringConverter().toJson(instance.img),
  'instrument': const _FlexibleIntConverter().toJson(instance.instrument),
  'groupName': const _FlexibleStringConverter().toJson(instance.groupName),
  'joined': const _FlexibleStringConverter().toJson(instance.joined),
  'date': const _FlexibleStringConverter().toJson(instance.date),
  'text': const _FlexibleStringConverter().toJson(instance.text),
  'title': const _FlexibleStringConverter().toJson(instance.title),
  'changed_by': const _FlexibleStringConverter().toJson(instance.changedBy),
  'changed_at': const _FlexibleStringConverter().toJson(instance.changedAt),
  'type_id': const _FlexibleStringConverter().toJson(instance.typeId),
  'highlight': const _FlexibleBoolConverter().toJson(instance.highlight),
  'left': const _FlexibleStringConverter().toJson(instance.left),
  'paused': const _FlexibleBoolConverter().toJson(instance.paused),
  'duty_state': const _FlexibleStringConverter().toJson(instance.dutyState),
  'duty_assigned_by': const _FlexibleStringConverter().toJson(
    instance.dutyAssignedBy,
  ),
  'duty_assigned_at': const _FlexibleStringConverter().toJson(
    instance.dutyAssignedAt,
  ),
};

_$ChecklistItemImpl _$$ChecklistItemImplFromJson(Map<String, dynamic> json) =>
    _$ChecklistItemImpl(
      id: json['id'] as String,
      text: json['text'] as String,
      deadlineHours: const _FlexibleIntConverter().fromJson(
        json['deadlineHours'],
      ),
      completed:
          json['completed'] == null
              ? false
              : const _FlexibleBoolConverter().fromJson(json['completed']),
      dueDate: const _FlexibleStringConverter().fromJson(json['dueDate']),
    );

Map<String, dynamic> _$$ChecklistItemImplToJson(
  _$ChecklistItemImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'text': instance.text,
  'deadlineHours': const _FlexibleIntConverter().toJson(instance.deadlineHours),
  'completed': const _FlexibleBoolConverter().toJson(instance.completed),
  'dueDate': const _FlexibleStringConverter().toJson(instance.dueDate),
};

_$AttendanceTypeImpl _$$AttendanceTypeImplFromJson(
  Map<String, dynamic> json,
) => _$AttendanceTypeImpl(
  id: const _FlexibleStringConverter().fromJson(json['id']),
  createdAt:
      json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
  name: json['name'] as String,
  defaultStatus:
      json['default_status'] == null
          ? AttendanceStatus.neutral
          : const _FlexibleAttendanceStatusConverter().fromJson(
            json['default_status'],
          ),
  availableStatuses: const _FlexibleAttendanceStatusListConverter().fromJson(
    json['available_statuses'],
  ),
  defaultPlan: json['default_plan'] as Map<String, dynamic>?,
  tenantId: const _FlexibleIntConverter().fromJson(json['tenant_id']),
  relevantGroups:
      (json['relevant_groups'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
  startTime: const _FlexibleStringConverter().fromJson(json['start_time']),
  endTime: const _FlexibleStringConverter().fromJson(json['end_time']),
  manageSongs:
      json['manage_songs'] == null
          ? false
          : const _FlexibleBoolConverter().fromJson(json['manage_songs']),
  index: const _FlexibleIntConverter().fromJson(json['index']),
  visible:
      json['visible'] == null
          ? true
          : const _FlexibleBoolConverter().fromJson(json['visible']),
  color: const _FlexibleStringConverter().fromJson(json['color']),
  highlight:
      json['highlight'] == null
          ? false
          : const _FlexibleBoolConverter().fromJson(json['highlight']),
  hideName:
      json['hide_name'] == null
          ? false
          : const _FlexibleBoolConverter().fromJson(json['hide_name']),
  includeInAverage:
      json['include_in_average'] == null
          ? true
          : const _FlexibleBoolConverter().fromJson(json['include_in_average']),
  allDay:
      json['all_day'] == null
          ? false
          : const _FlexibleBoolConverter().fromJson(json['all_day']),
  durationDays: const _FlexibleIntConverter().fromJson(json['duration_days']),
  notification:
      json['notification'] == null
          ? false
          : const _FlexibleBoolConverter().fromJson(json['notification']),
  reminders:
      (json['reminders'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
  additionalFieldsFilter:
      json['additional_fields_filter'] as Map<String, dynamic>?,
  checklist:
      (json['checklist'] as List<dynamic>?)
          ?.map((e) => ChecklistItem.fromJson(e as Map<String, dynamic>))
          .toList(),
  planningTitle: const _FlexibleStringConverter().fromJson(
    json['planning_title'],
  ),
  dutyMode:
      json['duty_mode'] == null
          ? false
          : const _FlexibleBoolConverter().fromJson(json['duty_mode']),
  dutyRequired: const _FlexibleIntConverter().fromJson(json['duty_required']),
  dutySelfSignup: json['duty_self_signup'] as bool? ?? true,
  dutyConfirmReminderDays: const _FlexibleIntConverter().fromJson(
    json['duty_confirm_reminder_days'],
  ),
  dutyNotifyUnderstaffed: json['duty_notify_understaffed'] as bool? ?? true,
  dutyUrgentHours: const _FlexibleIntConverter().fromJson(
    json['duty_urgent_hours'],
  ),
);

Map<String, dynamic> _$$AttendanceTypeImplToJson(
  _$AttendanceTypeImpl instance,
) => <String, dynamic>{
  'id': const _FlexibleStringConverter().toJson(instance.id),
  'created_at': instance.createdAt?.toIso8601String(),
  'name': instance.name,
  'default_status': const _FlexibleAttendanceStatusConverter().toJson(
    instance.defaultStatus,
  ),
  'available_statuses': const _FlexibleAttendanceStatusListConverter().toJson(
    instance.availableStatuses,
  ),
  'default_plan': instance.defaultPlan,
  'tenant_id': const _FlexibleIntConverter().toJson(instance.tenantId),
  'relevant_groups': instance.relevantGroups,
  'start_time': const _FlexibleStringConverter().toJson(instance.startTime),
  'end_time': const _FlexibleStringConverter().toJson(instance.endTime),
  'manage_songs': const _FlexibleBoolConverter().toJson(instance.manageSongs),
  'index': const _FlexibleIntConverter().toJson(instance.index),
  'visible': const _FlexibleBoolConverter().toJson(instance.visible),
  'color': const _FlexibleStringConverter().toJson(instance.color),
  'highlight': const _FlexibleBoolConverter().toJson(instance.highlight),
  'hide_name': const _FlexibleBoolConverter().toJson(instance.hideName),
  'include_in_average': const _FlexibleBoolConverter().toJson(
    instance.includeInAverage,
  ),
  'all_day': const _FlexibleBoolConverter().toJson(instance.allDay),
  'duration_days': const _FlexibleIntConverter().toJson(instance.durationDays),
  'notification': const _FlexibleBoolConverter().toJson(instance.notification),
  'reminders': instance.reminders,
  'additional_fields_filter': instance.additionalFieldsFilter,
  'checklist': instance.checklist,
  'planning_title': const _FlexibleStringConverter().toJson(
    instance.planningTitle,
  ),
  'duty_mode': const _FlexibleBoolConverter().toJson(instance.dutyMode),
  'duty_required': const _FlexibleIntConverter().toJson(instance.dutyRequired),
  'duty_self_signup': instance.dutySelfSignup,
  'duty_confirm_reminder_days': const _FlexibleIntConverter().toJson(
    instance.dutyConfirmReminderDays,
  ),
  'duty_notify_understaffed': instance.dutyNotifyUnderstaffed,
  'duty_urgent_hours': const _FlexibleIntConverter().toJson(
    instance.dutyUrgentHours,
  ),
};
