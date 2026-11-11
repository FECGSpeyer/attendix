import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart' show currentAuthUserIdProvider;
import '../utils/attendance_rate_filter.dart';
import 'attendance_providers.dart';
import 'tenant_providers.dart';

export '../utils/attendance_rate_filter.dart';

/// "Anwesenheit zählen" of the people list (old and new design share it).
/// Kept while the app runs; another group or account starts with the
/// classic season rate.
final attendanceRateFilterProvider = StateProvider<AttendanceRateFilter>((ref) {
  ref.watch(currentTenantIdProvider);
  ref.watch(currentAuthUserIdProvider);
  return const AttendanceRateFilter();
});

/// Percentages the people list shows: the season rate, or the rate of the
/// chosen period / Terminart.
final listAttendancePercentagesProvider = FutureProvider<Map<int, int>>((ref) async {
  final filter = ref.watch(attendanceRateFilterProvider);
  if (filter.isDefault) return ref.watch(playerAttendancePercentagesProvider.future);
  return loadAttendancePercentages(
    ref,
    from: ratePeriodStart(filter, DateTime.now()),
    to: ratePeriodEnd(filter),
    typeId: filter.typeId,
  );
});
