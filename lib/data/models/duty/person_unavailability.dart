import 'package:freezed_annotation/freezed_annotation.dart';

part 'person_unavailability.freezed.dart';
part 'person_unavailability.g.dart';

/// "Regelmäßig verhindert": weekly rule of a person (table `person_unavailability`).
///
/// New Termine on a matching weekday get "Entschuldigt" automatically; duties
/// are not assigned to the person on those days.
@freezed
class PersonUnavailability with _$PersonUnavailability {
  const factory PersonUnavailability({
    String? id,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'created_by') String? createdBy,
    @JsonKey(name: 'tenant_id') required int tenantId,
    @JsonKey(name: 'person_id') required int personId,

    /// ISO weekdays 1 = Monday … 7 = Sunday
    @Default(<int>[]) List<int> weekdays,

    /// Empty = rule applies to all attendance types
    @JsonKey(name: 'type_ids') @Default(<String>[]) List<String> typeIds,
    @Default('') String reason,

    /// yyyy-MM-dd, null = unlimited
    @JsonKey(name: 'valid_until') String? validUntil,
  }) = _PersonUnavailability;

  factory PersonUnavailability.fromJson(Map<String, dynamic> json) =>
      _$PersonUnavailabilityFromJson(normalizeUnavailabilityJson(json));
}

/// Normalizes DB rows (smallint[] / uuid[] / nullable reason) for parsing.
Map<String, dynamic> normalizeUnavailabilityJson(Map<String, dynamic> json) {
  return {
    ...json,
    'weekdays': (json['weekdays'] as List?)
            ?.map((e) => e is num ? e.toInt() : int.tryParse('$e') ?? 0)
            .toList() ??
        <int>[],
    'type_ids': (json['type_ids'] as List?)?.map((e) => '$e').toList() ?? <String>[],
    'reason': json['reason'] ?? '',
  };
}
