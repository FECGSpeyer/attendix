import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../core/constants/enums.dart';

part 'person.freezed.dart';
part 'person.g.dart';

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

/// Custom converter for flexible list of strings handling
class _FlexibleStringListConverter implements JsonConverter<List<String>?, dynamic> {
  const _FlexibleStringListConverter();
  @override
  List<String>? fromJson(dynamic json) {
    if (json == null) return null;
    if (json is List) {
      return json.map((e) => e.toString()).toList();
    }
    return null;
  }
  @override
  dynamic toJson(List<String>? object) => object;
}

/// Custom converter for history list
class _HistoryListConverter implements JsonConverter<List<PlayerHistoryEntry>, dynamic> {
  const _HistoryListConverter();
  @override
  List<PlayerHistoryEntry> fromJson(dynamic json) {
    if (json == null) return [];
    if (json is List) {
      return json
          .map((e) => PlayerHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }
  @override
  dynamic toJson(List<PlayerHistoryEntry> object) =>
      object.map((e) => e.toJson()).toList();
}

/// Person model - represents a member (player/conductor/viewer/parent)
/// Based on TypeScript Player interface from Ionic project
@freezed
class Person with _$Person {
  const factory Person({
    // Base Person fields
    @_FlexibleIntConverter() int? id,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @Default('') String firstName,
    @Default('') String lastName,
    @_FlexibleStringConverter() String? birthday,
    @_FlexibleStringConverter() String? joined,
    @_FlexibleStringConverter() String? left,
    @_FlexibleStringConverter() String? email,
    @_FlexibleStringConverter() String? appId,
    @_FlexibleStringConverter() String? notes,
    @_FlexibleStringConverter() String? img,
    @_FlexibleStringConverter() String? telegramId,
    @_FlexibleBoolConverter() @Default(false) bool paused,
    @JsonKey(name: 'paused_until') @_FlexibleStringConverter() String? pausedUntil,
    @_FlexibleIntConverter() int? tenantId,
    @JsonKey(name: 'additional_fields') Map<String, dynamic>? additionalFields,
    @_FlexibleStringConverter() String? phone,
    @JsonKey(name: 'shift_id') @_FlexibleStringConverter() String? shiftId,
    @JsonKey(name: 'shift_start') @_FlexibleStringConverter() String? shiftStart,
    @JsonKey(name: 'shift_name') @_FlexibleStringConverter() String? shiftName,
    @_FlexibleBoolConverter() @Default(false) bool pending,
    @JsonKey(name: 'self_register') @_FlexibleBoolConverter() @Default(false) bool selfRegister,
    
    // Player extension fields
    @_FlexibleIntConverter() int? instrument,
    @_FlexibleBoolConverter() @Default(false) bool hasTeacher,
    @_FlexibleStringConverter() String? playsSince,
    @_FlexibleBoolConverter() @Default(false) bool isLeader,
    @_FlexibleIntConverter() int? teacher,
    @_FlexibleBoolConverter() @Default(false) bool isCritical,
    @_FlexibleStringConverter() String? criticalReason,
    @_FlexibleStringConverter() String? lastSolve,
    @_FlexibleBoolConverter() @Default(false) bool correctBirthday,
    @_HistoryListConverter() @Default([]) List<PlayerHistoryEntry> history,
    @_FlexibleStringListConverter() List<String>? otherOrchestras,
    @_FlexibleStringConverter() String? otherExercise,
    @_FlexibleStringConverter() String? testResult,
    @_FlexibleBoolConverter() @Default(false) bool examinee,
    @_FlexibleStringConverter() String? range,
    @_FlexibleStringConverter() String? instruments,
    @JsonKey(name: 'parent_id') @_FlexibleIntConverter() int? parentId,
    @_FlexibleIntConverter() int? legacyId,
    @_FlexibleIntConverter() int? legacyConductorId,
    // SETTINGS_EXT: Verknüpfung über Instanzen hinweg (Personen verknüpfen).
    // Nicht in toJson, damit generische Updates den Wert nie überschreiben.
    @JsonKey(name: 'global_person_id', includeToJson: false)
    @_FlexibleStringConverter() String? globalPersonId,
    
    // Computed/transient fields (not in DB, used for display)
    @JsonKey(includeFromJson: false, includeToJson: false)
    @_FlexibleStringConverter() String? groupName,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @_FlexibleStringConverter() String? teacherName,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @_FlexibleStringConverter() String? criticalReasonText,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @_FlexibleIntConverter() int? percentage,
  }) = _Person;

  factory Person.fromJson(Map<String, dynamic> json) => _$PersonFromJson(json);
}

/// Player history entry - stored as JSON array in player.history column
@freezed
class PlayerHistoryEntry with _$PlayerHistoryEntry {
  const factory PlayerHistoryEntry({
    @_FlexibleStringConverter() required String? date,
    @_FlexibleStringConverter() required String? text,
    @_FlexibleIntConverter() required int? type,
  }) = _PlayerHistoryEntry;

  factory PlayerHistoryEntry.fromJson(Map<String, dynamic> json) =>
      _$PlayerHistoryEntryFromJson(json);
}

/// Extension for Person
extension PersonExtension on Person {
  /// Full name
  String get fullName => '$firstName $lastName';
  
  /// Display name (last name, first name)
  String get displayName => '$lastName, $firstName';
  
  /// Initials
  String get initials {
    final first = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final last = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return '$first$last';
  }
  
  /// Check if critical
  bool get critical => isCritical;
  
  /// Check if archived (left is not null)
  bool get archived => left != null;
  
  /// Check if person is active (not left, not paused)
  bool get isActive => left == null && !paused;
  
  /// Check if currently paused
  bool get isCurrentlyPaused {
    if (!paused) return false;
    if (pausedUntil == null) return true;
    final pauseDate = DateTime.tryParse(pausedUntil!);
    if (pauseDate == null) return true;
    return DateTime.now().isBefore(pauseDate);
  }

  /// Image URL
  String? get imageUrl => img;
}

/// Extension for PlayerHistoryEntry
extension PlayerHistoryEntryExtension on PlayerHistoryEntry {
  PlayerHistoryType get typeEnum => PlayerHistoryType.fromValue(type ?? 0);
  
  String get typeLabel {
    switch (typeEnum) {
      case PlayerHistoryType.paused:
        return 'Pausiert';
      case PlayerHistoryType.unexcused:
        return 'Unentschuldigt';
      case PlayerHistoryType.criticalPerson:
        return 'Kritisch markiert';
      case PlayerHistoryType.attendance:
        return 'Anwesenheit';
      case PlayerHistoryType.notes:
        return 'Notiz';
      case PlayerHistoryType.unpaused:
        return 'Pause beendet';
      case PlayerHistoryType.instrumentChange:
        return 'Instrumentenwechsel';
      case PlayerHistoryType.archived:
        return 'Archiviert';
      case PlayerHistoryType.returned:
        return 'Zurückgekehrt';
      case PlayerHistoryType.transferredFrom:
        return 'Übertragen von';
      case PlayerHistoryType.transferredTo:
        return 'Übertragen an';
      case PlayerHistoryType.copiedFrom:
        return 'Kopiert von';
      case PlayerHistoryType.copiedTo:
        return 'Kopiert an';
      case PlayerHistoryType.approved:
        return 'Genehmigt';
      case PlayerHistoryType.declined:
        return 'Abgelehnt';
      case PlayerHistoryType.other:
        return 'Sonstiges';
    }
  }
}