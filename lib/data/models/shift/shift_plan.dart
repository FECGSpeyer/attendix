import 'package:freezed_annotation/freezed_annotation.dart';

import 'shift_definition.dart';
import 'shift_instance.dart';

part 'shift_plan.freezed.dart';
part 'shift_plan.g.dart';

/// Converter for list of ShiftDefinition stored as JSON
class _ShiftDefinitionListConverter
    implements JsonConverter<List<ShiftDefinition>, dynamic> {
  const _ShiftDefinitionListConverter();

  @override
  List<ShiftDefinition> fromJson(dynamic json) {
    if (json == null) return [];
    if (json is List) {
      final indexed = [
        for (var i = 0; i < json.length; i++)
          (pos: i, def: ShiftDefinition.fromJson(json[i] as Map<String, dynamic>)),
      ];
      // Ionic loadShifts: definition.sort((a, b) => a.index - b.index);
      // stable, so equal indexes keep their stored order.
      indexed.sort((a, b) {
        final c = a.def.index.compareTo(b.def.index);
        return c != 0 ? c : a.pos.compareTo(b.pos);
      });
      return [for (final e in indexed) e.def];
    }
    return [];
  }

  @override
  dynamic toJson(List<ShiftDefinition> object) =>
      object.map((e) => e.toJson()).toList();
}

/// Converter for list of ShiftInstance stored as JSON
class _ShiftInstanceListConverter
    implements JsonConverter<List<ShiftInstance>, dynamic> {
  const _ShiftInstanceListConverter();

  @override
  List<ShiftInstance> fromJson(dynamic json) {
    if (json == null) return [];
    if (json is List) {
      return json
          .map((e) => ShiftInstance.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  @override
  dynamic toJson(List<ShiftInstance> object) =>
      object.map((e) => e.toJson()).toList();
}

/// A shift plan containing definition segments and optional fixed shifts
/// Used to automatically calculate attendance status based on work schedules
@freezed
class ShiftPlan with _$ShiftPlan {
  const factory ShiftPlan({
    String? id,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    required String name,
    @Default('') String description,
    @JsonKey(name: 'tenant_id') int? tenantId,
    @_ShiftDefinitionListConverter()
    @Default([])
    List<ShiftDefinition> definition,
    @_ShiftInstanceListConverter() @Default([]) List<ShiftInstance> shifts,
  }) = _ShiftPlan;

  factory ShiftPlan.fromJson(Map<String, dynamic> json) =>
      _$ShiftPlanFromJson(json);
}

/// Extension methods for ShiftPlan
extension ShiftPlanExtension on ShiftPlan {
  /// Calculate the total cycle length in days
  int get cycleLengthDays {
    if (definition.isEmpty) return 1;
    return definition.fold(0, (sum, def) => sum + def.repeatCount);
  }

  /// Check if this shift plan has any free segments
  bool get hasFreeDays {
    return definition.any((def) => def.free);
  }

  /// Check if this shift plan uses fixed named shifts
  bool get hasNamedShifts => shifts.isNotEmpty;

  /// Get the shift segment for a given day in the cycle (0-indexed)
  ShiftDefinition? getSegmentForDay(int dayInCycle) {
    if (definition.isEmpty) return null;

    int currentDay = 0;
    for (final segment in definition) {
      final segmentEnd = currentDay + segment.repeatCount;
      if (dayInCycle >= currentDay && dayInCycle < segmentEnd) {
        return segment;
      }
      currentDay = segmentEnd;
    }
    return null;
  }

  /// Calculate which day in the cycle a given date falls on
  int getDayInCycle(DateTime date, DateTime startDate) {
    final daysSinceStart = date.difference(startDate).inDays;
    if (daysSinceStart < 0) return 0;
    return daysSinceStart % cycleLengthDays;
  }

  /// Check if a person is working on a given date
  bool isWorkingOn(DateTime date, DateTime shiftStartDate) {
    final dayInCycle = getDayInCycle(date, shiftStartDate);
    final segment = getSegmentForDay(dayInCycle);
    return segment != null && !segment.free;
  }

  /// Get the shift name for a date (if using fixed shifts)
  String? getShiftNameForDate(DateTime date) {
    final dateStr = date.toIso8601String().split('T')[0];
    for (final shift in shifts) {
      if (shift.date == dateStr) {
        return shift.name;
      }
    }
    return null;
  }
}
