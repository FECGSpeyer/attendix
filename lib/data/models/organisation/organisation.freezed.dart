// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'organisation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Organisation _$OrganisationFromJson(Map<String, dynamic> json) {
  return _Organisation.fromJson(json);
}

/// @nodoc
mixin _$Organisation {
  int? get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;
  String get name =>
      throw _privateConstructorUsedError; // ORG_PLANS: Ablaufpläne / Org-Einstellungen (tenant_groups columns)
  @JsonKey(name: 'public_plan_key')
  String? get publicPlanKey => throw _privateConstructorUsedError;
  @JsonKey(name: 'logo_url')
  String? get logoUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'branding_text')
  String? get brandingText => throw _privateConstructorUsedError;
  @JsonKey(name: 'additional_fields')
  List<OrgExtraField>? get additionalFields =>
      throw _privateConstructorUsedError;
  @JsonKey(name: 'planning_templates')
  List<Plan>? get planningTemplates => throw _privateConstructorUsedError;
  @JsonKey(name: 'default_fields')
  List<PlanField>? get defaultFields => throw _privateConstructorUsedError;

  /// Serializes this Organisation to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Organisation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OrganisationCopyWith<Organisation> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OrganisationCopyWith<$Res> {
  factory $OrganisationCopyWith(
    Organisation value,
    $Res Function(Organisation) then,
  ) = _$OrganisationCopyWithImpl<$Res, Organisation>;
  @useResult
  $Res call({
    int? id,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    String name,
    @JsonKey(name: 'public_plan_key') String? publicPlanKey,
    @JsonKey(name: 'logo_url') String? logoUrl,
    @JsonKey(name: 'branding_text') String? brandingText,
    @JsonKey(name: 'additional_fields') List<OrgExtraField>? additionalFields,
    @JsonKey(name: 'planning_templates') List<Plan>? planningTemplates,
    @JsonKey(name: 'default_fields') List<PlanField>? defaultFields,
  });
}

/// @nodoc
class _$OrganisationCopyWithImpl<$Res, $Val extends Organisation>
    implements $OrganisationCopyWith<$Res> {
  _$OrganisationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Organisation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? createdAt = freezed,
    Object? name = null,
    Object? publicPlanKey = freezed,
    Object? logoUrl = freezed,
    Object? brandingText = freezed,
    Object? additionalFields = freezed,
    Object? planningTemplates = freezed,
    Object? defaultFields = freezed,
  }) {
    return _then(
      _value.copyWith(
            id:
                freezed == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as int?,
            createdAt:
                freezed == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            name:
                null == name
                    ? _value.name
                    : name // ignore: cast_nullable_to_non_nullable
                        as String,
            publicPlanKey:
                freezed == publicPlanKey
                    ? _value.publicPlanKey
                    : publicPlanKey // ignore: cast_nullable_to_non_nullable
                        as String?,
            logoUrl:
                freezed == logoUrl
                    ? _value.logoUrl
                    : logoUrl // ignore: cast_nullable_to_non_nullable
                        as String?,
            brandingText:
                freezed == brandingText
                    ? _value.brandingText
                    : brandingText // ignore: cast_nullable_to_non_nullable
                        as String?,
            additionalFields:
                freezed == additionalFields
                    ? _value.additionalFields
                    : additionalFields // ignore: cast_nullable_to_non_nullable
                        as List<OrgExtraField>?,
            planningTemplates:
                freezed == planningTemplates
                    ? _value.planningTemplates
                    : planningTemplates // ignore: cast_nullable_to_non_nullable
                        as List<Plan>?,
            defaultFields:
                freezed == defaultFields
                    ? _value.defaultFields
                    : defaultFields // ignore: cast_nullable_to_non_nullable
                        as List<PlanField>?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$OrganisationImplCopyWith<$Res>
    implements $OrganisationCopyWith<$Res> {
  factory _$$OrganisationImplCopyWith(
    _$OrganisationImpl value,
    $Res Function(_$OrganisationImpl) then,
  ) = __$$OrganisationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int? id,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    String name,
    @JsonKey(name: 'public_plan_key') String? publicPlanKey,
    @JsonKey(name: 'logo_url') String? logoUrl,
    @JsonKey(name: 'branding_text') String? brandingText,
    @JsonKey(name: 'additional_fields') List<OrgExtraField>? additionalFields,
    @JsonKey(name: 'planning_templates') List<Plan>? planningTemplates,
    @JsonKey(name: 'default_fields') List<PlanField>? defaultFields,
  });
}

/// @nodoc
class __$$OrganisationImplCopyWithImpl<$Res>
    extends _$OrganisationCopyWithImpl<$Res, _$OrganisationImpl>
    implements _$$OrganisationImplCopyWith<$Res> {
  __$$OrganisationImplCopyWithImpl(
    _$OrganisationImpl _value,
    $Res Function(_$OrganisationImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Organisation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? createdAt = freezed,
    Object? name = null,
    Object? publicPlanKey = freezed,
    Object? logoUrl = freezed,
    Object? brandingText = freezed,
    Object? additionalFields = freezed,
    Object? planningTemplates = freezed,
    Object? defaultFields = freezed,
  }) {
    return _then(
      _$OrganisationImpl(
        id:
            freezed == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as int?,
        createdAt:
            freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        name:
            null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                    as String,
        publicPlanKey:
            freezed == publicPlanKey
                ? _value.publicPlanKey
                : publicPlanKey // ignore: cast_nullable_to_non_nullable
                    as String?,
        logoUrl:
            freezed == logoUrl
                ? _value.logoUrl
                : logoUrl // ignore: cast_nullable_to_non_nullable
                    as String?,
        brandingText:
            freezed == brandingText
                ? _value.brandingText
                : brandingText // ignore: cast_nullable_to_non_nullable
                    as String?,
        additionalFields:
            freezed == additionalFields
                ? _value._additionalFields
                : additionalFields // ignore: cast_nullable_to_non_nullable
                    as List<OrgExtraField>?,
        planningTemplates:
            freezed == planningTemplates
                ? _value._planningTemplates
                : planningTemplates // ignore: cast_nullable_to_non_nullable
                    as List<Plan>?,
        defaultFields:
            freezed == defaultFields
                ? _value._defaultFields
                : defaultFields // ignore: cast_nullable_to_non_nullable
                    as List<PlanField>?,
      ),
    );
  }
}

/// @nodoc

@JsonSerializable(explicitToJson: true)
class _$OrganisationImpl implements _Organisation {
  const _$OrganisationImpl({
    this.id,
    @JsonKey(name: 'created_at') this.createdAt,
    required this.name,
    @JsonKey(name: 'public_plan_key') this.publicPlanKey,
    @JsonKey(name: 'logo_url') this.logoUrl,
    @JsonKey(name: 'branding_text') this.brandingText,
    @JsonKey(name: 'additional_fields')
    final List<OrgExtraField>? additionalFields,
    @JsonKey(name: 'planning_templates') final List<Plan>? planningTemplates,
    @JsonKey(name: 'default_fields') final List<PlanField>? defaultFields,
  }) : _additionalFields = additionalFields,
       _planningTemplates = planningTemplates,
       _defaultFields = defaultFields;

  factory _$OrganisationImpl.fromJson(Map<String, dynamic> json) =>
      _$$OrganisationImplFromJson(json);

  @override
  final int? id;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @override
  final String name;
  // ORG_PLANS: Ablaufpläne / Org-Einstellungen (tenant_groups columns)
  @override
  @JsonKey(name: 'public_plan_key')
  final String? publicPlanKey;
  @override
  @JsonKey(name: 'logo_url')
  final String? logoUrl;
  @override
  @JsonKey(name: 'branding_text')
  final String? brandingText;
  final List<OrgExtraField>? _additionalFields;
  @override
  @JsonKey(name: 'additional_fields')
  List<OrgExtraField>? get additionalFields {
    final value = _additionalFields;
    if (value == null) return null;
    if (_additionalFields is EqualUnmodifiableListView)
      return _additionalFields;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  final List<Plan>? _planningTemplates;
  @override
  @JsonKey(name: 'planning_templates')
  List<Plan>? get planningTemplates {
    final value = _planningTemplates;
    if (value == null) return null;
    if (_planningTemplates is EqualUnmodifiableListView)
      return _planningTemplates;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  final List<PlanField>? _defaultFields;
  @override
  @JsonKey(name: 'default_fields')
  List<PlanField>? get defaultFields {
    final value = _defaultFields;
    if (value == null) return null;
    if (_defaultFields is EqualUnmodifiableListView) return _defaultFields;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  String toString() {
    return 'Organisation(id: $id, createdAt: $createdAt, name: $name, publicPlanKey: $publicPlanKey, logoUrl: $logoUrl, brandingText: $brandingText, additionalFields: $additionalFields, planningTemplates: $planningTemplates, defaultFields: $defaultFields)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OrganisationImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.publicPlanKey, publicPlanKey) ||
                other.publicPlanKey == publicPlanKey) &&
            (identical(other.logoUrl, logoUrl) || other.logoUrl == logoUrl) &&
            (identical(other.brandingText, brandingText) ||
                other.brandingText == brandingText) &&
            const DeepCollectionEquality().equals(
              other._additionalFields,
              _additionalFields,
            ) &&
            const DeepCollectionEquality().equals(
              other._planningTemplates,
              _planningTemplates,
            ) &&
            const DeepCollectionEquality().equals(
              other._defaultFields,
              _defaultFields,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    createdAt,
    name,
    publicPlanKey,
    logoUrl,
    brandingText,
    const DeepCollectionEquality().hash(_additionalFields),
    const DeepCollectionEquality().hash(_planningTemplates),
    const DeepCollectionEquality().hash(_defaultFields),
  );

  /// Create a copy of Organisation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OrganisationImplCopyWith<_$OrganisationImpl> get copyWith =>
      __$$OrganisationImplCopyWithImpl<_$OrganisationImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$OrganisationImplToJson(this);
  }
}

abstract class _Organisation implements Organisation {
  const factory _Organisation({
    final int? id,
    @JsonKey(name: 'created_at') final DateTime? createdAt,
    required final String name,
    @JsonKey(name: 'public_plan_key') final String? publicPlanKey,
    @JsonKey(name: 'logo_url') final String? logoUrl,
    @JsonKey(name: 'branding_text') final String? brandingText,
    @JsonKey(name: 'additional_fields')
    final List<OrgExtraField>? additionalFields,
    @JsonKey(name: 'planning_templates') final List<Plan>? planningTemplates,
    @JsonKey(name: 'default_fields') final List<PlanField>? defaultFields,
  }) = _$OrganisationImpl;

  factory _Organisation.fromJson(Map<String, dynamic> json) =
      _$OrganisationImpl.fromJson;

  @override
  int? get id;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;
  @override
  String get name; // ORG_PLANS: Ablaufpläne / Org-Einstellungen (tenant_groups columns)
  @override
  @JsonKey(name: 'public_plan_key')
  String? get publicPlanKey;
  @override
  @JsonKey(name: 'logo_url')
  String? get logoUrl;
  @override
  @JsonKey(name: 'branding_text')
  String? get brandingText;
  @override
  @JsonKey(name: 'additional_fields')
  List<OrgExtraField>? get additionalFields;
  @override
  @JsonKey(name: 'planning_templates')
  List<Plan>? get planningTemplates;
  @override
  @JsonKey(name: 'default_fields')
  List<PlanField>? get defaultFields;

  /// Create a copy of Organisation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OrganisationImplCopyWith<_$OrganisationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

TenantGroupTenant _$TenantGroupTenantFromJson(Map<String, dynamic> json) {
  return _TenantGroupTenant.fromJson(json);
}

/// @nodoc
mixin _$TenantGroupTenant {
  int? get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'tenant_id')
  int get tenantId => throw _privateConstructorUsedError;
  @JsonKey(name: 'tenant_group')
  int get tenantGroup => throw _privateConstructorUsedError;
  @JsonKey(name: 'tenant_group_data')
  Organisation? get tenantGroupData => throw _privateConstructorUsedError;
  Tenant? get tenant => throw _privateConstructorUsedError;

  /// Serializes this TenantGroupTenant to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TenantGroupTenant
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TenantGroupTenantCopyWith<TenantGroupTenant> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TenantGroupTenantCopyWith<$Res> {
  factory $TenantGroupTenantCopyWith(
    TenantGroupTenant value,
    $Res Function(TenantGroupTenant) then,
  ) = _$TenantGroupTenantCopyWithImpl<$Res, TenantGroupTenant>;
  @useResult
  $Res call({
    int? id,
    @JsonKey(name: 'tenant_id') int tenantId,
    @JsonKey(name: 'tenant_group') int tenantGroup,
    @JsonKey(name: 'tenant_group_data') Organisation? tenantGroupData,
    Tenant? tenant,
  });

  $OrganisationCopyWith<$Res>? get tenantGroupData;
  $TenantCopyWith<$Res>? get tenant;
}

/// @nodoc
class _$TenantGroupTenantCopyWithImpl<$Res, $Val extends TenantGroupTenant>
    implements $TenantGroupTenantCopyWith<$Res> {
  _$TenantGroupTenantCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TenantGroupTenant
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? tenantId = null,
    Object? tenantGroup = null,
    Object? tenantGroupData = freezed,
    Object? tenant = freezed,
  }) {
    return _then(
      _value.copyWith(
            id:
                freezed == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as int?,
            tenantId:
                null == tenantId
                    ? _value.tenantId
                    : tenantId // ignore: cast_nullable_to_non_nullable
                        as int,
            tenantGroup:
                null == tenantGroup
                    ? _value.tenantGroup
                    : tenantGroup // ignore: cast_nullable_to_non_nullable
                        as int,
            tenantGroupData:
                freezed == tenantGroupData
                    ? _value.tenantGroupData
                    : tenantGroupData // ignore: cast_nullable_to_non_nullable
                        as Organisation?,
            tenant:
                freezed == tenant
                    ? _value.tenant
                    : tenant // ignore: cast_nullable_to_non_nullable
                        as Tenant?,
          )
          as $Val,
    );
  }

  /// Create a copy of TenantGroupTenant
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $OrganisationCopyWith<$Res>? get tenantGroupData {
    if (_value.tenantGroupData == null) {
      return null;
    }

    return $OrganisationCopyWith<$Res>(_value.tenantGroupData!, (value) {
      return _then(_value.copyWith(tenantGroupData: value) as $Val);
    });
  }

  /// Create a copy of TenantGroupTenant
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $TenantCopyWith<$Res>? get tenant {
    if (_value.tenant == null) {
      return null;
    }

    return $TenantCopyWith<$Res>(_value.tenant!, (value) {
      return _then(_value.copyWith(tenant: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$TenantGroupTenantImplCopyWith<$Res>
    implements $TenantGroupTenantCopyWith<$Res> {
  factory _$$TenantGroupTenantImplCopyWith(
    _$TenantGroupTenantImpl value,
    $Res Function(_$TenantGroupTenantImpl) then,
  ) = __$$TenantGroupTenantImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int? id,
    @JsonKey(name: 'tenant_id') int tenantId,
    @JsonKey(name: 'tenant_group') int tenantGroup,
    @JsonKey(name: 'tenant_group_data') Organisation? tenantGroupData,
    Tenant? tenant,
  });

  @override
  $OrganisationCopyWith<$Res>? get tenantGroupData;
  @override
  $TenantCopyWith<$Res>? get tenant;
}

/// @nodoc
class __$$TenantGroupTenantImplCopyWithImpl<$Res>
    extends _$TenantGroupTenantCopyWithImpl<$Res, _$TenantGroupTenantImpl>
    implements _$$TenantGroupTenantImplCopyWith<$Res> {
  __$$TenantGroupTenantImplCopyWithImpl(
    _$TenantGroupTenantImpl _value,
    $Res Function(_$TenantGroupTenantImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TenantGroupTenant
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? tenantId = null,
    Object? tenantGroup = null,
    Object? tenantGroupData = freezed,
    Object? tenant = freezed,
  }) {
    return _then(
      _$TenantGroupTenantImpl(
        id:
            freezed == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as int?,
        tenantId:
            null == tenantId
                ? _value.tenantId
                : tenantId // ignore: cast_nullable_to_non_nullable
                    as int,
        tenantGroup:
            null == tenantGroup
                ? _value.tenantGroup
                : tenantGroup // ignore: cast_nullable_to_non_nullable
                    as int,
        tenantGroupData:
            freezed == tenantGroupData
                ? _value.tenantGroupData
                : tenantGroupData // ignore: cast_nullable_to_non_nullable
                    as Organisation?,
        tenant:
            freezed == tenant
                ? _value.tenant
                : tenant // ignore: cast_nullable_to_non_nullable
                    as Tenant?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TenantGroupTenantImpl implements _TenantGroupTenant {
  const _$TenantGroupTenantImpl({
    this.id,
    @JsonKey(name: 'tenant_id') required this.tenantId,
    @JsonKey(name: 'tenant_group') required this.tenantGroup,
    @JsonKey(name: 'tenant_group_data') this.tenantGroupData,
    this.tenant,
  });

  factory _$TenantGroupTenantImpl.fromJson(Map<String, dynamic> json) =>
      _$$TenantGroupTenantImplFromJson(json);

  @override
  final int? id;
  @override
  @JsonKey(name: 'tenant_id')
  final int tenantId;
  @override
  @JsonKey(name: 'tenant_group')
  final int tenantGroup;
  @override
  @JsonKey(name: 'tenant_group_data')
  final Organisation? tenantGroupData;
  @override
  final Tenant? tenant;

  @override
  String toString() {
    return 'TenantGroupTenant(id: $id, tenantId: $tenantId, tenantGroup: $tenantGroup, tenantGroupData: $tenantGroupData, tenant: $tenant)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TenantGroupTenantImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.tenantId, tenantId) ||
                other.tenantId == tenantId) &&
            (identical(other.tenantGroup, tenantGroup) ||
                other.tenantGroup == tenantGroup) &&
            (identical(other.tenantGroupData, tenantGroupData) ||
                other.tenantGroupData == tenantGroupData) &&
            (identical(other.tenant, tenant) || other.tenant == tenant));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    tenantId,
    tenantGroup,
    tenantGroupData,
    tenant,
  );

  /// Create a copy of TenantGroupTenant
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TenantGroupTenantImplCopyWith<_$TenantGroupTenantImpl> get copyWith =>
      __$$TenantGroupTenantImplCopyWithImpl<_$TenantGroupTenantImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$TenantGroupTenantImplToJson(this);
  }
}

abstract class _TenantGroupTenant implements TenantGroupTenant {
  const factory _TenantGroupTenant({
    final int? id,
    @JsonKey(name: 'tenant_id') required final int tenantId,
    @JsonKey(name: 'tenant_group') required final int tenantGroup,
    @JsonKey(name: 'tenant_group_data') final Organisation? tenantGroupData,
    final Tenant? tenant,
  }) = _$TenantGroupTenantImpl;

  factory _TenantGroupTenant.fromJson(Map<String, dynamic> json) =
      _$TenantGroupTenantImpl.fromJson;

  @override
  int? get id;
  @override
  @JsonKey(name: 'tenant_id')
  int get tenantId;
  @override
  @JsonKey(name: 'tenant_group')
  int get tenantGroup;
  @override
  @JsonKey(name: 'tenant_group_data')
  Organisation? get tenantGroupData;
  @override
  Tenant? get tenant;

  /// Create a copy of TenantGroupTenant
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TenantGroupTenantImplCopyWith<_$TenantGroupTenantImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
