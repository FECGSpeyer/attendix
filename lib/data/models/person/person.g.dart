// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'person.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PersonImpl _$$PersonImplFromJson(Map<String, dynamic> json) => _$PersonImpl(
  id: const _FlexibleIntConverter().fromJson(json['id']),
  createdAt:
      json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
  firstName: json['firstName'] as String? ?? '',
  lastName: json['lastName'] as String? ?? '',
  birthday: const _FlexibleStringConverter().fromJson(json['birthday']),
  joined: const _FlexibleStringConverter().fromJson(json['joined']),
  left: const _FlexibleStringConverter().fromJson(json['left']),
  email: const _FlexibleStringConverter().fromJson(json['email']),
  appId: const _FlexibleStringConverter().fromJson(json['appId']),
  notes: const _FlexibleStringConverter().fromJson(json['notes']),
  img: const _FlexibleStringConverter().fromJson(json['img']),
  telegramId: const _FlexibleStringConverter().fromJson(json['telegramId']),
  paused:
      json['paused'] == null
          ? false
          : const _FlexibleBoolConverter().fromJson(json['paused']),
  pausedUntil: const _FlexibleStringConverter().fromJson(json['paused_until']),
  tenantId: const _FlexibleIntConverter().fromJson(json['tenantId']),
  additionalFields: json['additional_fields'] as Map<String, dynamic>?,
  phone: const _FlexibleStringConverter().fromJson(json['phone']),
  shiftId: const _FlexibleStringConverter().fromJson(json['shift_id']),
  shiftStart: const _FlexibleStringConverter().fromJson(json['shift_start']),
  shiftName: const _FlexibleStringConverter().fromJson(json['shift_name']),
  pending:
      json['pending'] == null
          ? false
          : const _FlexibleBoolConverter().fromJson(json['pending']),
  selfRegister:
      json['self_register'] == null
          ? false
          : const _FlexibleBoolConverter().fromJson(json['self_register']),
  instrument: const _FlexibleIntConverter().fromJson(json['instrument']),
  hasTeacher:
      json['hasTeacher'] == null
          ? false
          : const _FlexibleBoolConverter().fromJson(json['hasTeacher']),
  playsSince: const _FlexibleStringConverter().fromJson(json['playsSince']),
  isLeader:
      json['isLeader'] == null
          ? false
          : const _FlexibleBoolConverter().fromJson(json['isLeader']),
  teacher: const _FlexibleIntConverter().fromJson(json['teacher']),
  isCritical:
      json['isCritical'] == null
          ? false
          : const _FlexibleBoolConverter().fromJson(json['isCritical']),
  criticalReason: const _FlexibleStringConverter().fromJson(
    json['criticalReason'],
  ),
  lastSolve: const _FlexibleStringConverter().fromJson(json['lastSolve']),
  correctBirthday:
      json['correctBirthday'] == null
          ? false
          : const _FlexibleBoolConverter().fromJson(json['correctBirthday']),
  history:
      json['history'] == null
          ? const []
          : const _HistoryListConverter().fromJson(json['history']),
  otherOrchestras: const _FlexibleStringListConverter().fromJson(
    json['otherOrchestras'],
  ),
  otherExercise: const _FlexibleStringConverter().fromJson(
    json['otherExercise'],
  ),
  testResult: const _FlexibleStringConverter().fromJson(json['testResult']),
  examinee:
      json['examinee'] == null
          ? false
          : const _FlexibleBoolConverter().fromJson(json['examinee']),
  range: const _FlexibleStringConverter().fromJson(json['range']),
  instruments: const _FlexibleStringConverter().fromJson(json['instruments']),
  parentId: const _FlexibleIntConverter().fromJson(json['parent_id']),
  legacyId: const _FlexibleIntConverter().fromJson(json['legacyId']),
  legacyConductorId: const _FlexibleIntConverter().fromJson(
    json['legacyConductorId'],
  ),
  globalPersonId: const _FlexibleStringConverter().fromJson(
    json['global_person_id'],
  ),
  sortOrder: const _FlexibleIntConverter().fromJson(json['sort_order']),
);

Map<String, dynamic> _$$PersonImplToJson(
  _$PersonImpl instance,
) => <String, dynamic>{
  'id': const _FlexibleIntConverter().toJson(instance.id),
  'created_at': instance.createdAt?.toIso8601String(),
  'firstName': instance.firstName,
  'lastName': instance.lastName,
  'birthday': const _FlexibleStringConverter().toJson(instance.birthday),
  'joined': const _FlexibleStringConverter().toJson(instance.joined),
  'left': const _FlexibleStringConverter().toJson(instance.left),
  'email': const _FlexibleStringConverter().toJson(instance.email),
  'appId': const _FlexibleStringConverter().toJson(instance.appId),
  'notes': const _FlexibleStringConverter().toJson(instance.notes),
  'img': const _FlexibleStringConverter().toJson(instance.img),
  'telegramId': const _FlexibleStringConverter().toJson(instance.telegramId),
  'paused': const _FlexibleBoolConverter().toJson(instance.paused),
  'paused_until': const _FlexibleStringConverter().toJson(instance.pausedUntil),
  'tenantId': const _FlexibleIntConverter().toJson(instance.tenantId),
  'additional_fields': instance.additionalFields,
  'phone': const _FlexibleStringConverter().toJson(instance.phone),
  'shift_id': const _FlexibleStringConverter().toJson(instance.shiftId),
  'shift_start': const _FlexibleStringConverter().toJson(instance.shiftStart),
  'shift_name': const _FlexibleStringConverter().toJson(instance.shiftName),
  'pending': const _FlexibleBoolConverter().toJson(instance.pending),
  'self_register': const _FlexibleBoolConverter().toJson(instance.selfRegister),
  'instrument': const _FlexibleIntConverter().toJson(instance.instrument),
  'hasTeacher': const _FlexibleBoolConverter().toJson(instance.hasTeacher),
  'playsSince': const _FlexibleStringConverter().toJson(instance.playsSince),
  'isLeader': const _FlexibleBoolConverter().toJson(instance.isLeader),
  'teacher': const _FlexibleIntConverter().toJson(instance.teacher),
  'isCritical': const _FlexibleBoolConverter().toJson(instance.isCritical),
  'criticalReason': const _FlexibleStringConverter().toJson(
    instance.criticalReason,
  ),
  'lastSolve': const _FlexibleStringConverter().toJson(instance.lastSolve),
  'correctBirthday': const _FlexibleBoolConverter().toJson(
    instance.correctBirthday,
  ),
  'history': const _HistoryListConverter().toJson(instance.history),
  'otherOrchestras': const _FlexibleStringListConverter().toJson(
    instance.otherOrchestras,
  ),
  'otherExercise': const _FlexibleStringConverter().toJson(
    instance.otherExercise,
  ),
  'testResult': const _FlexibleStringConverter().toJson(instance.testResult),
  'examinee': const _FlexibleBoolConverter().toJson(instance.examinee),
  'range': const _FlexibleStringConverter().toJson(instance.range),
  'instruments': const _FlexibleStringConverter().toJson(instance.instruments),
  'parent_id': const _FlexibleIntConverter().toJson(instance.parentId),
  'legacyId': const _FlexibleIntConverter().toJson(instance.legacyId),
  'legacyConductorId': const _FlexibleIntConverter().toJson(
    instance.legacyConductorId,
  ),
  if (const _FlexibleStringConverter().toJson(instance.globalPersonId)
      case final value?)
    'global_person_id': value,
  if (const _FlexibleIntConverter().toJson(instance.sortOrder) case final value?)
    'sort_order': value,
};

_$PlayerHistoryEntryImpl _$$PlayerHistoryEntryImplFromJson(
  Map<String, dynamic> json,
) => _$PlayerHistoryEntryImpl(
  date: const _FlexibleStringConverter().fromJson(json['date']),
  text: const _FlexibleStringConverter().fromJson(json['text']),
  type: const _FlexibleIntConverter().fromJson(json['type']),
);

Map<String, dynamic> _$$PlayerHistoryEntryImplToJson(
  _$PlayerHistoryEntryImpl instance,
) => <String, dynamic>{
  'date': const _FlexibleStringConverter().toJson(instance.date),
  'text': const _FlexibleStringConverter().toJson(instance.text),
  'type': const _FlexibleIntConverter().toJson(instance.type),
};
