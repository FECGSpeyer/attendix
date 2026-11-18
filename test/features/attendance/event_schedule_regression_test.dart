import 'dart:convert';

import 'package:attendix/core/config/supabase_config.dart';
import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/attendance_detail_providers.dart';
import 'package:attendix/core/providers/attendance_providers.dart';
import 'package:attendix/core/providers/attendance_type_providers.dart';
import 'package:attendix/core/providers/duty_providers.dart';
import 'package:attendix/core/providers/group_providers.dart';
import 'package:attendix/core/providers/plan_providers.dart';
import 'package:attendix/core/providers/player_absence_providers.dart';
import 'package:attendix/core/providers/profile_providers.dart';
import 'package:attendix/core/providers/shift_providers.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/data/models/person/person.dart';
import 'package:attendix/data/models/shift/shift_definition.dart';
import 'package:attendix/data/models/shift/shift_plan.dart';
import 'package:attendix/data/repositories/attendance_repository.dart';
import 'package:attendix/data/repositories/attendance_type_repository.dart';
import 'package:attendix/data/repositories/duty_repository.dart';
import 'package:attendix/data/repositories/player_absence_repository.dart';
import 'package:attendix/features/attendance/presentation/attendance_add_persons.dart';
import 'package:attendix/features/attendance/presentation/attendance_create_writes.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/test_helpers.dart';

class _AttendanceRepository extends Mock implements AttendanceRepository {}

class _TypeRepository extends Mock implements AttendanceTypeRepository {}

class _DutyRepository extends Mock implements DutyRepository {}

class _AbsenceRepository extends Mock implements PlayerAbsenceRepository {}

const _type = AttendanceType(
  id: 'probe',
  tenantId: 7,
  name: 'Probe',
  defaultStatus: AttendanceStatus.present,
  startTime: '19:00',
  endTime: '21:00',
);
const _shift = ShiftPlan(
  id: 'evening',
  name: 'Spätschicht',
  definition: [ShiftDefinition(startTime: '18:00', duration: 4)],
);
const _person = Person(
  id: 100,
  firstName: 'Ada',
  lastName: 'Beispiel',
  shiftId: 'evening',
  shiftStart: '2027-06-01',
);

void main() {
  setUpAll(() => registerFallbackValue(<PersonAttendance>[]));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final scenario in [
    (
      name: 'a morning override does not overlap the evening shift',
      start: '10:00',
      end: '12:00',
      typeStart: '19:00',
      typeEnd: '21:00',
      allDay: false,
      status: AttendanceStatus.present,
      note: '',
    ),
    (
      name:
          'an evening override overlaps even when the type starts in the morning',
      start: '19:00',
      end: '21:00',
      typeStart: '09:00',
      typeEnd: '11:00',
      allDay: false,
      status: AttendanceStatus.excused,
      note: 'Schichtbedingt',
    ),
    (
      name: 'missing event hours still use the type hours',
      start: null,
      end: null,
      typeStart: '19:00',
      typeEnd: '21:00',
      allDay: false,
      status: AttendanceStatus.excused,
      note: 'Schichtbedingt',
    ),
    (
      name: 'all-day events retain the default status',
      start: '19:00',
      end: '21:00',
      typeStart: '19:00',
      typeEnd: '21:00',
      allDay: true,
      status: AttendanceStatus.present,
      note: '',
    ),
  ]) {
    testWidgets('adding a person: ${scenario.name}', (tester) async {
      final repo = _AttendanceRepository();
      List<PersonAttendance>? saved;
      when(() => repo.createPersonAttendances(any())).thenAnswer((
        invocation,
      ) async {
        saved = invocation.positionalArguments.single as List<PersonAttendance>;
      });
      final event = Attendance(
        id: 71,
        tenantId: 7,
        date: '2027-06-01T10:00:00Z',
        typeId: 'probe',
        startTime: scenario.start,
        endTime: scenario.end,
      );
      final type = _type.copyWith(
        startTime: scenario.typeStart,
        endTime: scenario.typeEnd,
        allDay: scenario.allDay,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            attendanceRepositoryWithTenantProvider.overrideWithValue(repo),
            allPersonsForAttendanceProvider.overrideWith(
              (ref) async => [_person],
            ),
            attendanceDetailProvider(71).overrideWith((ref) async => event),
            attendanceTypeForAttendanceProvider(
              71,
            ).overrideWith((ref) async => type),
            groupsProvider.overrideWith((ref) async => []),
            personExtraFieldsProvider.overrideWith((ref) async => []),
            shiftsProvider.overrideWith((ref) async => [_shift]),
          ],
          child: MaterialApp(
            theme: ThemeData(splashFactory: NoSplash.splashFactory),
            locale: const Locale('de'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(
              builder: (context, ref, _) {
                // The real detail page watches these while the sheet is open.
                ref.watch(attendanceDetailProvider(71));
                ref.watch(attendanceTypeForAttendanceProvider(71));
                ref.watch(allPersonsForAttendanceProvider);
                return Scaffold(
                  body: FilledButton(
                    key: const Key('add-person'),
                    onPressed:
                        () => addPersonsToAttendance(
                          context,
                          ref,
                          attendanceId: 71,
                          currentPersonIds: {},
                        ),
                    child: const Text('Person hinzufügen'),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add-person')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ada Beispiel'));
      await tester.pumpAndSettle();
      final submit = find.byType(FilledButton).last;
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(saved, hasLength(1));
      expect(saved!.single.personId, 100);
      expect(saved!.single.attendanceId, 71);
      expect(saved!.single.status, scenario.status);
      expect(saved!.single.notes, scenario.note);
      expect(tester.takeException(), isNull);
    });
  }

  for (final scenario in [
    (start: '10:15', expectedStart: '10:15', hour: 10, minute: 15),
    (start: '00:00', expectedStart: '00:00', hour: 0, minute: 0),
    (start: null, expectedStart: '19:00', hour: 19, minute: 0),
  ]) {
    test(
      'checklist due date follows the stored ${scenario.expectedStart} start',
      () async {
        final payload = await _createPayload(
          AttendanceCreateInput(
            type: _type.copyWith(
              checklist: const [
                ChecklistItem(
                  id: 'template',
                  text: 'Proberaum vorbereiten',
                  deadlineHours: 24,
                ),
                ChecklistItem(id: 'without-deadline', text: 'Noten mitbringen'),
              ],
            ),
            dates: [DateTime(2027, 6, 1)],
            startTime: scenario.start,
            endTime: '12:00',
          ),
        );
        expect(payload['tenantId'], 7);
        expect(payload['start_time'], scenario.expectedStart);
        final checklist =
            (payload['checklist'] as List).cast<Map<String, dynamic>>();
        expect(
          DateTime.parse(checklist.first['dueDate'] as String).toLocal(),
          DateTime(2027, 5, 31, scenario.hour, scenario.minute),
        );
        expect(checklist.last['dueDate'], isNull);
      },
    );
  }
}

Future<Map<String, dynamic>> _createPayload(AttendanceCreateInput input) async {
  Map<String, dynamic>? payload;
  final client = MockClient((request) async {
    const headers = {'content-type': 'application/json'};
    if (request.url.path.endsWith('/player') && request.method == 'GET') {
      return http.Response('[]', 200, request: request, headers: headers);
    }
    if (request.url.path.endsWith('/attendance') && request.method == 'POST') {
      payload = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        '{"id":71}',
        201,
        request: request,
        headers: headers,
      );
    }
    throw StateError(
      'Unexpected fixture request ${request.method} ${request.url}',
    );
  });
  final supabase = SupabaseClient(
    'http://127.0.0.1:9',
    'fixture-anon-key',
    httpClient: client,
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  final typeRepo = _TypeRepository();
  final dutyRepo = _DutyRepository();
  final absenceRepo = _AbsenceRepository();
  when(() => typeRepo.getCirclePersons()).thenAnswer((_) async => {});
  when(() => dutyRepo.getUnavailabilityForTenant()).thenAnswer((_) async => []);
  when(() => absenceRepo.getAbsencesForTenant()).thenAnswer((_) async => []);
  final container = createTestContainer(
    tenantId: 7,
    overrides: [
      supabaseClientProvider.overrideWithValue(supabase),
      attendanceTypeRepositoryWithTenantProvider.overrideWithValue(typeRepo),
      dutyRepositoryWithTenantProvider.overrideWithValue(dutyRepo),
      playerAbsenceRepositoryWithTenantProvider.overrideWithValue(absenceRepo),
      planAttendanceTypesProvider.overrideWith((ref) async => []),
      shiftsProvider.overrideWith((ref) async => []),
    ],
  );
  try {
    await AttendanceCreateWriter.withRead(container.read).create(input);
    return payload!;
  } finally {
    container.dispose();
    await supabase.dispose();
    client.close();
  }
}
