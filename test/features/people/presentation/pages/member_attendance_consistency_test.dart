import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/attendance_rate_filter_providers.dart';
import 'package:attendix/core/providers/attendance_type_providers.dart';
import 'package:attendix/core/providers/player_providers.dart';
import 'package:attendix/core/providers/realtime_providers.dart';
import 'package:attendix/core/providers/person_detail_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/member_attendance_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  MemberAttendanceFixture fixture(
    List<Map<String, dynamic>> rows, {
    Role role = Role.viewer,
  }) {
    final result = MemberAttendanceFixture(rows: rows, role: role);
    addTearDown(result.dispose);
    return result;
  }

  group('member list and person detail attendance', () {
    test(
      'includes a counted event exactly at the season start in both views',
      () async {
        final data = fixture([
          memberAttendanceRow(
            id: 1,
            date: '2025-09-01T00:00:00Z',
            status: AttendanceStatus.present,
          ),
          memberAttendanceRow(
            id: 2,
            date: '2026-01-10T12:00:00Z',
            status: AttendanceStatus.absent,
          ),
        ]);
        final container = data.createContainer();
        addTearDown(container.dispose);

        final list = await container.read(
          listAttendancePercentagesProvider.future,
        );
        final detail = await container.read(
          personAttendanceStatsProvider(100).future,
        );
        expect(list[100], 50);
        expect(detail['percentage'], 50);
        expect(detail['counted'], 2);
      },
    );

    test(
      'an empty duty assignment does not lower the person detail rate',
      () async {
        final data = fixture([
          memberAttendanceRow(
            id: 1,
            date: '2026-01-10T12:00:00Z',
            status: AttendanceStatus.present,
          ),
          memberAttendanceRow(
            id: 2,
            date: '2026-01-17T12:00:00Z',
            status: AttendanceStatus.absent,
            typeId: 'dienst',
            dutyState: '',
          ),
        ]);
        final container = data.createContainer();
        addTearDown(container.dispose);

        expect(
          (await container.read(listAttendancePercentagesProvider.future))[100],
          100,
        );
        final detail = await container.read(
          personAttendanceStatsProvider(100).future,
        );
        expect(detail['percentage'], 100);
        expect(detail['counted'], 1);
        expect(detail['total'], 2);
      },
    );

    test(
      'person statistics count all pages beyond the PostgREST default cap',
      () async {
        final data = fixture([
          for (var id = 0; id < 1200; id++)
            memberAttendanceRow(
              id: id,
              date: '2026-01-10T12:00:00Z',
              status:
                  id < 1000
                      ? AttendanceStatus.absent
                      : AttendanceStatus.present,
            ),
        ]);
        final container = data.createContainer();
        addTearDown(container.dispose);

        expect(
          (await container.read(listAttendancePercentagesProvider.future))[100],
          17,
        );
        final detail = await container.read(
          personAttendanceStatsProvider(100).future,
        );
        expect(detail['counted'], 1200);
        expect(detail['attended'], 200);
        expect(detail['percentage'], 17);
      },
    );

    test(
      'person history includes the final page and keeps every page tenant-bound',
      () async {
        final data = fixture([
          for (var id = 0; id < 1200; id++)
            memberAttendanceRow(
              id: id,
              date: '2026-01-10T12:00:00Z',
              status: AttendanceStatus.present,
            ),
          memberAttendanceRow(
            id: 9999,
            date: '2026-02-01T12:00:00Z',
            status: AttendanceStatus.absent,
            tenantId: 8,
          ),
          memberAttendanceRow(
            id: 9998,
            date: '2026-02-01T12:00:00Z',
            status: AttendanceStatus.absent,
            personId: 200,
          ),
        ]);
        final container = data.createContainer();
        addTearDown(container.dispose);

        final history = await container.read(personHistoryProvider(100).future);
        expect(history, hasLength(1200));
        final queries = data.requests.where(
          (request) => request.url.pathSegments.last == 'person_attendances',
        );
        expect(
          queries.map((request) => request.url.queryParameters['offset']),
          ['0', '1000'],
        );
        for (final request in queries) {
          expect(request.url.queryParameters['attendance.tenantId'], 'eq.7');
          expect(request.url.queryParameters['person_id'], 'eq.100');
          expect(request.url.queryParameters['order'], 'id.asc.nullslast');
        }
      },
    );

    test(
      'attendance changes refresh cached person statistics with the member list',
      () async {
        final data = fixture([
          memberAttendanceRow(
            id: 1,
            date: '2026-01-10T12:00:00Z',
            status: AttendanceStatus.absent,
          ),
        ]);
        final container = data.createContainer();
        addTearDown(container.dispose);
        expect(
          (await container.read(listAttendancePercentagesProvider.future))[100],
          0,
        );
        expect(
          (await container.read(
            personAttendanceStatsProvider(100).future,
          ))['percentage'],
          0,
        );

        data.rows = [
          memberAttendanceRow(
            id: 1,
            date: '2026-01-10T12:00:00Z',
            status: AttendanceStatus.present,
          ),
        ];
        container.read(attendanceRefetchCounter.notifier).state++;
        await container.pump();

        expect(
          (await container.read(listAttendancePercentagesProvider.future))[100],
          100,
        );
        expect(
          (await container.read(
            personAttendanceStatsProvider(100).future,
          ))['percentage'],
          100,
        );
      },
    );

    test(
      'attendance changes refresh the cached status tiles on the person page',
      () async {
        final data = fixture([
          memberAttendanceRow(
            id: 1,
            date: '2026-01-10T12:00:00Z',
            status: AttendanceStatus.absent,
          ),
        ]);
        final container = data.createContainer();
        addTearDown(container.dispose);
        expect(
          (await container.read(
            personHistoryProvider(100).future,
          )).single['status'],
          4,
        );

        data.rows = [
          memberAttendanceRow(
            id: 1,
            date: '2026-01-10T12:00:00Z',
            status: AttendanceStatus.present,
          ),
        ];
        container.read(attendanceRefetchCounter.notifier).state++;
        await container.pump();

        expect(
          (await container.read(
            personHistoryProvider(100).future,
          )).single['status'],
          1,
        );
      },
    );

    test(
      'changing which event types count refreshes the cached person rate',
      () async {
        final data = fixture([
          memberAttendanceRow(
            id: 1,
            date: '2026-01-10T12:00:00Z',
            status: AttendanceStatus.present,
          ),
          memberAttendanceRow(
            id: 2,
            date: '2026-01-17T12:00:00Z',
            status: AttendanceStatus.absent,
            typeId: 'konzert',
          ),
        ]);
        final container = data.createContainer();
        addTearDown(container.dispose);
        expect(
          (await container.read(listAttendancePercentagesProvider.future))[100],
          50,
        );
        expect(
          (await container.read(
            personAttendanceStatsProvider(100).future,
          ))['percentage'],
          50,
        );

        data.types = [
          for (final type in data.types)
            type.id == 'konzert'
                ? type.copyWith(includeInAverage: false)
                : type,
        ];
        container.invalidate(attendanceTypesProvider);
        await container.read(attendanceTypesProvider.future);
        await container.pump();

        expect(
          (await container.read(listAttendancePercentagesProvider.future))[100],
          100,
        );
        expect(
          (await container.read(
            personAttendanceStatsProvider(100).future,
          ))['percentage'],
          100,
        );
      },
    );

    test(
      'role changes remove archived events from the cached person rate',
      () async {
        final data = fixture([
          memberAttendanceRow(
            id: 1,
            date: '2026-01-10T12:00:00Z',
            status: AttendanceStatus.present,
          ),
          memberAttendanceRow(
            id: 2,
            date: '2026-01-17T12:00:00Z',
            status: AttendanceStatus.absent,
            archived: true,
          ),
        ], role: Role.admin);
        final container = data.createContainer();
        addTearDown(container.dispose);
        expect(
          (await container.read(listAttendancePercentagesProvider.future))[100],
          50,
        );
        expect(
          (await container.read(
            personAttendanceStatsProvider(100).future,
          ))['percentage'],
          50,
        );

        container.read(memberFixtureRoleProvider.notifier).state = Role.viewer;
        await container.pump();

        expect(
          (await container.read(listAttendancePercentagesProvider.future))[100],
          100,
        );
        expect(
          (await container.read(
            personAttendanceStatsProvider(100).future,
          ))['percentage'],
          100,
        );
      },
    );

    test(
      'role changes remove archived events from cached person history',
      () async {
        final data = fixture([
          memberAttendanceRow(
            id: 1,
            date: '2026-01-10T12:00:00Z',
            status: AttendanceStatus.present,
          ),
          memberAttendanceRow(
            id: 2,
            date: '2026-01-17T12:00:00Z',
            status: AttendanceStatus.absent,
            archived: true,
          ),
        ], role: Role.admin);
        final container = data.createContainer();
        addTearDown(container.dispose);
        expect(
          await container.read(personHistoryProvider(100).future),
          hasLength(2),
        );

        container.read(memberFixtureRoleProvider.notifier).state = Role.viewer;
        await container.pump();

        final history = await container.read(personHistoryProvider(100).future);
        expect(history, hasLength(1));
        expect(history.single['attendanceId'], 1);
      },
    );

    test(
      'an explicit list event-type filter remains separate from the season detail',
      () async {
        final data = fixture([
          memberAttendanceRow(
            id: 1,
            date: '2026-01-10T12:00:00Z',
            status: AttendanceStatus.present,
          ),
          memberAttendanceRow(
            id: 2,
            date: '2026-01-17T12:00:00Z',
            status: AttendanceStatus.absent,
            typeId: 'konzert',
          ),
        ]);
        final container = data.createContainer();
        addTearDown(container.dispose);
        container
            .read(attendanceRateFilterProvider.notifier)
            .state = const AttendanceRateFilter(typeId: 'probe');

        expect(
          (await container.read(listAttendancePercentagesProvider.future))[100],
          100,
        );
        expect(
          (await container.read(
            personAttendanceStatsProvider(100).future,
          ))['percentage'],
          50,
        );
      },
    );

    test(
      'list and detail share status and tenant shift-excuse semantics',
      () async {
        for (final setting in const {false: 50, true: 67}.entries) {
          final data = MemberAttendanceFixture(
            tenant: memberFixtureTenant.copyWith(
              shiftExcusedAsPresent: setting.key,
            ),
            rows: [
              for (final status in AttendanceStatus.values)
                memberAttendanceRow(
                  id: status.value,
                  date: '2026-01-10T12:00:00Z',
                  status: status,
                  notes:
                      status == AttendanceStatus.excused
                          ? 'Schichtbedingt'
                          : null,
                ),
            ],
          );
          addTearDown(data.dispose);
          final container = data.createContainer();
          addTearDown(container.dispose);
          expect(
            (await container.read(
              listAttendancePercentagesProvider.future,
            ))[100],
            setting.value,
          );
          expect(
            (await container.read(
              personAttendanceStatsProvider(100).future,
            ))['percentage'],
            setting.value,
          );
        }
      },
    );

    test(
      'person statistics exclude other tenants and other members on every page',
      () async {
        final data = fixture([
          memberAttendanceRow(
            id: 1,
            date: '2026-01-10T12:00:00Z',
            status: AttendanceStatus.present,
          ),
          memberAttendanceRow(
            id: 2,
            date: '2026-01-10T12:00:00Z',
            status: AttendanceStatus.absent,
            tenantId: 8,
          ),
          memberAttendanceRow(
            id: 3,
            date: '2026-01-10T12:00:00Z',
            status: AttendanceStatus.absent,
            personId: 200,
          ),
        ]);
        final container = data.createContainer();
        addTearDown(container.dispose);
        final detail = await container.read(
          personAttendanceStatsProvider(100).future,
        );
        expect(detail['counted'], 1);
        expect(detail['percentage'], 100);
        final queries = data.requests.where(
          (request) => request.url.pathSegments.last == 'person_attendances',
        );
        for (final request in queries) {
          expect(request.url.queryParameters['attendance.tenantId'], 'eq.7');
          expect(request.url.queryParameters['person_id'], 'eq.100');
        }
      },
    );

    test(
      'list percentage matches detail cutoff for upcoming events today',
      () async {
        final upcoming =
            DateTime.now()
                .add(const Duration(hours: 4))
                .toUtc()
                .toIso8601String();
        final data = MemberAttendanceFixture(
          rows: [
            memberAttendanceRow(
              id: 1,
              date: '2026-01-10T12:00:00Z',
              status: AttendanceStatus.present,
            ),
            memberAttendanceRow(
              id: 2,
              date: upcoming,
              status: AttendanceStatus.absent,
            ),
          ],
        );
        addTearDown(data.dispose);
        final container = data.createContainer();
        addTearDown(container.dispose);
        expect(
          (await container.read(
            listAttendancePercentagesProvider.future,
          ))[100],
          100,
        );
        expect(
          (await container.read(
            personAttendanceStatsProvider(100).future,
          ))['percentage'],
          100,
        );
      },
    );

    test(
      'direct history date filtering applies to every pagination request',
      () async {
        final data = fixture([
          for (var id = 0; id < 1200; id++)
            memberAttendanceRow(
              id: id,
              date: '2026-01-10T12:00:00Z',
              status: AttendanceStatus.present,
            ),
          memberAttendanceRow(
            id: 5000,
            date: '2025-12-10T12:00:00Z',
            status: AttendanceStatus.absent,
          ),
        ]);
        final container = data.createContainer();
        addTearDown(container.dispose);
        final rows = await container
            .read(playerRepositoryWithTenantProvider)
            .getPersonAttendanceHistoryRows(100, fromDate: '2026-01-01');
        expect(rows, hasLength(1200));
        expect(
          data.requests.every(
            (request) =>
                request.url.queryParameters['attendance.date'] ==
                'gte.2026-01-01',
          ),
          isTrue,
        );
      },
    );
  });
}
