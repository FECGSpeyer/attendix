import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../l10n/l10n.dart';

part 'shift_definition.freezed.dart';
part 'shift_definition.g.dart';

/// A single segment/block of a shift definition
/// Defines the time, duration and whether the employee is free
@freezed
class ShiftDefinition with _$ShiftDefinition {
  const factory ShiftDefinition({
    int? id,
    @JsonKey(name: 'start_time') @Default('08:00') String startTime,
    @Default(8.0) double duration,
    @Default(false) bool free,
    @JsonKey(name: 'index') @Default(0) int index,
    @JsonKey(name: 'repeat_count') @Default(1) int repeatCount,
  }) = _ShiftDefinition;

  factory ShiftDefinition.fromJson(Map<String, dynamic> json) =>
      _$ShiftDefinitionFromJson(json);
}

/// Extension methods for ShiftDefinition
extension ShiftDefinitionExtension on ShiftDefinition {
  /// Calculate the end time based on start time and duration
  String get endTime {
    final parts = startTime.split(':');
    if (parts.length < 2) return startTime;

    final startHour = int.tryParse(parts[0]) ?? 0;
    final startMinute = int.tryParse(parts[1]) ?? 0;

    final totalMinutes = startHour * 60 + startMinute + (duration * 60).toInt();
    final endHour = (totalMinutes ~/ 60) % 24;
    final endMinute = totalMinutes % 60;

    return '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';
  }

  /// Display text for the shift segment
  String get displayText {
    if (free) {
      return l10nWithoutContext.coreFlutterShiftFreeRange(startTime, endTime);
    }
    return l10nWithoutContext.coreFlutterShiftWorkRange(startTime, endTime, duration);
  }
}
