import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/attendance_providers.dart';
import 'package:attendix/core/providers/realtime_providers.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/data/repositories/attendance_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _AttendanceRepository extends Mock implements AttendanceRepository {}

void main() {
  setUpAll(() => registerFallbackValue(<int>[]));

  for (final status in [AttendanceStatus.absent, AttendanceStatus.present]) {
    final percentage = status == AttendanceStatus.absent ? 0.0 : 100.0;
    test(
      'counts reload after removal with an unchanged $percentage% rate',
      () async {
        final repo = _AttendanceRepository();
        when(() => repo.hasTenantId).thenReturn(true);
        var rows = [
          PersonAttendance(
            id: 'first',
            personId: 1,
            attendanceId: 71,
            status: status,
          ),
          PersonAttendance(
            id: 'second',
            personId: 2,
            attendanceId: 71,
            status: status,
          ),
        ];
        when(
          () => repo.getPersonAttendancesForAttendances([71]),
        ).thenAnswer((_) async => [...rows]);
        final event = Attendance(
          id: 71,
          tenantId: 7,
          date: '2026-11-10',
          percentage: percentage,
        );
        final container = ProviderContainer(
          overrides: [
            attendanceRepositoryWithTenantProvider.overrideWithValue(repo),
            realtimeAttendanceListProvider.overrideWith((ref) async {
              ref.watch(attendanceRefetchCounter);
              return [event];
            }),
          ],
        );
        addTearDown(container.dispose);
        container.listen(realtimeAttendanceListProvider, (_, __) {});
        final provider = attendanceListStatusCountsProvider('71');
        container.listen(provider, (_, __) {});
        await container.read(realtimeAttendanceListProvider.future);
        await container.pump();
        expect((await container.read(provider.future))[71]!.total, 2);

        rows = rows.sublist(0, 1);
        container.read(attendanceRefetchCounter.notifier).state++;
        await container.read(realtimeAttendanceListProvider.future);
        await container.pump();
        final after = (await container.read(provider.future))[71]!;
        expect(
          after.total,
          1,
          reason: 'The visible denominator follows membership.',
        );
        expect(after.present, status == AttendanceStatus.present ? 1 : 0);
        expect(after.absent, status == AttendanceStatus.absent ? 1 : 0);
      },
    );
  }
}
