import '../../data/models/attendance/attendance.dart';

/// Average attendance percentage over all attendances whose type has
/// `include_in_average = true`. Attendances with an unknown type are excluded
/// (Ionic: `type?.include_in_average`).
int calculateAveragePercentage(
  List<Attendance> attendances,
  List<AttendanceType> types,
) {
  final includedTypeIds = types
      .where((t) => t.includeInAverage && t.id != null)
      .map((t) => t.id!)
      .toSet();
  final relevant = attendances
      .where((a) => a.typeId != null && includedTypeIds.contains(a.typeId))
      .toList();
  if (relevant.isEmpty) return 0;
  final sum = relevant.fold<double>(0, (acc, a) => acc + (a.percentage ?? 0));
  return (sum / relevant.length).round();
}
