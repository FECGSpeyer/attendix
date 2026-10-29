import 'package:flutter/foundation.dart';

import '../attendance/attendance.dart';

/// Termin with its person attendances and all Ablaufpläne, as needed by the
/// "Termine" and "Aktueller Ablaufplan" dashboard cards.
///
/// `extraPlans` mirrors Ionic `attendance.extra_plans` (further plans of a
/// multi-day Termin); it is read from the raw row because the shared
/// [Attendance] model does not carry it. Immutable value holder; not
/// serialised, therefore no Freezed code generation needed.
@immutable
class DashboardEvent {
  const DashboardEvent({
    required this.attendance,
    this.persons = const [],
    this.extraPlans = const [],
  });

  final Attendance attendance;
  final List<PersonAttendance> persons;
  final List<Map<String, dynamic>> extraPlans;
}
