// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'person_unavailability.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PersonUnavailabilityImpl _$$PersonUnavailabilityImplFromJson(
  Map<String, dynamic> json,
) => _$PersonUnavailabilityImpl(
  id: json['id'] as String?,
  createdAt: json['created_at'] as String?,
  createdBy: json['created_by'] as String?,
  tenantId: (json['tenant_id'] as num).toInt(),
  personId: (json['person_id'] as num).toInt(),
  weekdays:
      (json['weekdays'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const <int>[],
  typeIds:
      (json['type_ids'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  reason: json['reason'] as String? ?? '',
  validUntil: json['valid_until'] as String?,
);

Map<String, dynamic> _$$PersonUnavailabilityImplToJson(
  _$PersonUnavailabilityImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'created_at': instance.createdAt,
  'created_by': instance.createdBy,
  'tenant_id': instance.tenantId,
  'person_id': instance.personId,
  'weekdays': instance.weekdays,
  'type_ids': instance.typeIds,
  'reason': instance.reason,
  'valid_until': instance.validUntil,
};
