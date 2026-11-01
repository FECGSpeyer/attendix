import 'package:freezed_annotation/freezed_annotation.dart';

part 'plan.freezed.dart';
part 'plan.g.dart';

/// Reads values that may come back as String, int or double as String.
class PlanStringConverter implements JsonConverter<String, dynamic> {
  const PlanStringConverter();

  @override
  String fromJson(dynamic json) {
    if (json == null) return '';
    if (json is double && json == json.roundToDouble()) {
      return json.toInt().toString();
    }
    return json.toString();
  }

  @override
  dynamic toJson(String object) => object;
}

/// Reads ints that may be stored as String.
class PlanIntConverter implements JsonConverter<int?, dynamic> {
  const PlanIntConverter();

  @override
  int? fromJson(dynamic json) {
    if (json == null) return null;
    if (json is int) return json;
    if (json is double) return json.toInt();
    if (json is String) return int.tryParse(json);
    return null;
  }

  @override
  dynamic toJson(int? object) => object;
}

/// Reads bools that may be stored as String / int.
class PlanBoolConverter implements JsonConverter<bool, dynamic> {
  const PlanBoolConverter();

  @override
  bool fromJson(dynamic json) {
    if (json is bool) return json;
    if (json is String) return json.toLowerCase() == 'true';
    if (json is num) return json != 0;
    return false;
  }

  @override
  dynamic toJson(bool object) => object;
}

/// One row of an Ablaufplan (Ionic: `FieldSelection`).
///
/// Stored as JSON inside `attendance.plan.fields`, `attendance.extra_plans[].fields`,
/// `shared_plans.fields`, `tenant_groups.planning_templates/default_fields` and
/// `tenants.plan_block_templates`.
///
/// - Notes have an id containing `noteFld` and take no time.
/// - A Programmblock head has `isGroup = true` and `time = '0'`; its
///   Unterpunkte follow directly with `groupId` = head id.
@freezed
class PlanField with _$PlanField {
  @JsonSerializable(includeIfNull: false, explicitToJson: true)
  const factory PlanField({
    @PlanStringConverter() required String id,
    @PlanStringConverter() required String name,
    @PlanStringConverter() @Default('0') String time,
    String? conductor,
    String? currentTime,
    @PlanIntConverter() int? songId,
    String? info,

    /// Set when the field is an agenda item (TOP) of the team organisation.
    String? agendaItemId,

    /// Head of a Programmblock.
    @PlanBoolConverter() @Default(false) bool isGroup,

    /// Id of the Programmblock head this Unterpunkt belongs to.
    String? groupId,

    /// Legacy Flutter flag for notes (Ionic only uses the `noteFld` id prefix).
    @JsonKey(includeToJson: false) @PlanBoolConverter() @Default(false) bool isNote,

    /// Stable id of the row (Gemeinde App link); song rows reuse the song id
    /// as [id], which repeats (see `PlanBeamer.ensureFieldUids`).
    String? uid,

    /// "Beamer-Datei nötig", set only when switched by hand; otherwise
    /// derived from the row (see `PlanBeamer.needsBeamer`).
    bool? needsBeamer,

    /// SongBeamer file linked in the Gemeinde App.
    @BeamerFileConverter() BeamerFile? beamerFile,
  }) = _PlanField;

  factory PlanField.fromJson(Map<String, dynamic> json) =>
      _$PlanFieldFromJson(json);
}

/// SongBeamer file in the Gemeinde App's Mediathek, written by the Gemeinde
/// App (Ionic: `BeamerFile`). Attached to a plan row (`beamerFile`) or a
/// Werk (`songs.beamer_file`).
@freezed
class BeamerFile with _$BeamerFile {
  @JsonSerializable(includeIfNull: false)
  const factory BeamerFile({
    @Default('') String name,
    @Default('') String path,
    String? linkedAt,
  }) = _BeamerFile;

  factory BeamerFile.fromJson(Map<String, dynamic> json) =>
      _$BeamerFileFromJson(json);
}

/// Reads a [BeamerFile] leniently: anything but an object with a name is null.
class BeamerFileConverter implements JsonConverter<BeamerFile?, dynamic> {
  const BeamerFileConverter();

  @override
  BeamerFile? fromJson(dynamic json) {
    if (json is! Map) return null;
    final name = json['name'];
    if (name is! String || name.isEmpty) return null;
    return BeamerFile(
      name: name,
      path: json['path']?.toString() ?? '',
      linkedAt: json['linkedAt']?.toString(),
    );
  }

  @override
  dynamic toJson(BeamerFile? object) => object?.toJson();
}

/// A complete Ablaufplan (Ionic: `Plan`).
@freezed
class Plan with _$Plan {
  @JsonSerializable(includeIfNull: false, explicitToJson: true)
  const factory Plan({
    @PlanStringConverter() @Default('') String time,
    @PlanStringConverter() @Default('') String end,
    @Default(<PlanField>[]) List<PlanField> fields,
    String? title,

    /// Stable id of an additional plan (see `attendance.extra_plans`).
    String? id,

    /// Custom chip label.
    String? label,

    /// Day within a multi-day Termin, 0 = first day.
    @PlanIntConverter() int? day,
  }) = _Plan;

  factory Plan.fromJson(Map<String, dynamic> json) => _$PlanFromJson(json);
}

/// Saved Programmblock (head first, then its Unterpunkte) stored in
/// `tenants.plan_block_templates`.
@freezed
class PlanBlockTemplate with _$PlanBlockTemplate {
  @JsonSerializable(includeIfNull: false, explicitToJson: true)
  const factory PlanBlockTemplate({
    required String id,
    required String name,
    @Default(<PlanField>[]) List<PlanField> fields,
  }) = _PlanBlockTemplate;

  factory PlanBlockTemplate.fromJson(Map<String, dynamic> json) =>
      _$PlanBlockTemplateFromJson(json);
}

/// Ad-hoc plan shared via `/plan?key=…` (table `shared_plans`).
@freezed
class SharedPlan with _$SharedPlan {
  @JsonSerializable(includeIfNull: false, explicitToJson: true)
  const factory SharedPlan({
    required String id,
    @JsonKey(name: 'edit_key') required String editKey,
    @JsonKey(name: 'plan_title') String? planTitle,
    String? date,
    String? time,
    @JsonKey(name: 'end_time') String? endTime,
    @Default(<PlanField>[]) List<PlanField> fields,
    @JsonKey(name: 'branding_id') String? brandingId,
    @JsonKey(name: 'creator_user_id') String? creatorUserId,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'org_id') @PlanIntConverter() int? orgId,
  }) = _SharedPlan;

  factory SharedPlan.fromJson(Map<String, dynamic> json) =>
      _$SharedPlanFromJson(json);
}

/// The plan related columns of an `attendance` row.
///
/// Loaded by `PlanRepository` with an explicit column list so the planning
/// features don't depend on the (shared) `Attendance` model.
@freezed
class PlanAttendance with _$PlanAttendance {
  @JsonSerializable(includeIfNull: false, explicitToJson: true)
  const factory PlanAttendance({
    @PlanIntConverter() required int? id,
    @PlanIntConverter() int? tenantId,
    @Default('') String date,
    @JsonKey(name: 'duration_days') @PlanIntConverter() int? durationDays,
    Plan? plan,
    @JsonKey(name: 'extra_plans') List<Plan>? extraPlans,
    @JsonKey(name: 'type_id') String? typeId,
    String? typeInfo,
    String? type,
    @JsonKey(name: 'start_time') String? startTime,
    String? notes,
    @JsonKey(name: 'share_plan') @PlanBoolConverter() @Default(false) bool sharePlan,
    @JsonKey(name: 'is_org_plan') @PlanBoolConverter() @Default(false) bool isOrgPlan,
    @JsonKey(name: 'share_key') String? shareKey,
    @JsonKey(name: 'share_edit_key') String? shareEditKey,

    /// Display name of the owning instance (org plans only, not a column).
    @JsonKey(includeFromJson: false, includeToJson: false) String? tenantName,
  }) = _PlanAttendance;

  factory PlanAttendance.fromJson(Map<String, dynamic> json) =>
      _$PlanAttendanceFromJson(json);
}

/// Attendance type settings relevant for planning (subset of `attendance_types`).
@freezed
class PlanAttendanceType with _$PlanAttendanceType {
  @JsonSerializable(includeIfNull: false, explicitToJson: true)
  const factory PlanAttendanceType({
    required String id,
    @Default('') String name,
    @JsonKey(name: 'default_plan') Plan? defaultPlan,
    @JsonKey(name: 'start_time') String? startTime,
    @JsonKey(name: 'planning_title') String? planningTitle,
    @JsonKey(name: 'planning_prefix_instance_name') @PlanBoolConverter() @Default(false) bool planningPrefixInstanceName,
    @JsonKey(name: 'is_default_org_plan') @PlanBoolConverter() @Default(false) bool isDefaultOrgPlan,
  }) = _PlanAttendanceType;

  factory PlanAttendanceType.fromJson(Map<String, dynamic> json) =>
      _$PlanAttendanceTypeFromJson(json);
}

/// Org-wide person extra field (`tenant_groups.additional_fields`).
@freezed
class OrgExtraField with _$OrgExtraField {
  @JsonSerializable(includeIfNull: false, explicitToJson: true)
  const factory OrgExtraField({
    required String id,
    required String name,
    @Default('text') String type,
    dynamic defaultValue,
    @Default(<String>[]) List<String> options,
    @Default(false) bool visibleToPlayers,
    @Default(false) bool editableByPlayers,
    @Default('chip') String displayMode,
  }) = _OrgExtraField;

  factory OrgExtraField.fromJson(Map<String, dynamic> json) =>
      _$OrgExtraFieldFromJson(json);
}
