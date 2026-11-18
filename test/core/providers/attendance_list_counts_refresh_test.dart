import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/attendance_providers.dart';
import 'package:attendix/core/providers/realtime_providers.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/data/repositories/attendance_repository.dart';
import 'package:attendix/features/attendance/presentation/pages/attendance_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../golden/support/golden_harness.dart';
import '../../golden/support/golden_world.dart';

class _AttendanceRepository extends Mock implements AttendanceRepository {}

void main() {
  setUpAll(() => registerFallbackValue(<int>[]));

  testWidgets(
    'classic return refreshes unchanged counts, including the last removal',
    (tester) async {
      final repo = _AttendanceRepository();
      when(() => repo.hasTenantId).thenReturn(true);
      var rows = [
        const PersonAttendance(
          id: 'first',
          personId: 1,
          attendanceId: 71,
          status: AttendanceStatus.absent,
        ),
        const PersonAttendance(
          id: 'second',
          personId: 2,
          attendanceId: 71,
          status: AttendanceStatus.absent,
        ),
      ];
      when(
        () => repo.getPersonAttendancesForAttendances([71]),
      ).thenAnswer((_) async => [...rows]);
      const event = Attendance(
        id: 71,
        tenantId: 7,
        date: '2026-01-10',
        typeInfo: 'Zählerprüfung',
        percentage: 0,
      );
      await pumpGolden(
        tester,
        const AttendanceListPage(),
        look: GoldenLook.classicIos,
        path: '/attendance',
        size: const Size(900, 800),
        overrides: [
          ...worldOverrides(),
          attendanceRepositoryWithTenantProvider.overrideWithValue(repo),
          realtimeAttendanceListProvider.overrideWith((ref) async {
            ref.watch(attendanceRefetchCounter);
            return [event];
          }),
        ],
      );
      expect(
        find.textContaining('0 von 2 anwesend'),
        findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data ?? t.textSpan?.toPlainText())
            .join(' | '),
      );
      for (final remaining in [1, 0]) {
        await tester.tap(find.text('Zählerprüfung'));
        await settle(tester);
        final detail = find.text('/attendance/71');
        expect(detail, findsOneWidget);
        rows = rows.take(remaining).toList();
        GoRouter.of(tester.element(detail)).pop();
        await settle(tester);
        if (remaining == 0) {
          expect(find.textContaining('anwesend'), findsNothing);
          final container = ProviderScope.containerOf(
            tester.element(find.byType(AttendanceListPage)),
          );
          expect(
            container
                .read(attendanceListStatusCountsProvider('71'))
                .value![71]!
                .total,
            0,
          );
        } else {
          expect(
            find.textContaining('0 von $remaining anwesend'),
            findsOneWidget,
          );
        }
      }
    },
  );

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
