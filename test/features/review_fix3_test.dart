// REVIEW_FIX3: fixes for the wave-7 review findings (review-w7.md #1–#10).
import 'dart:io';

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/attendance_providers.dart';
import 'package:attendix/core/providers/attendance_type_providers.dart';
import 'package:attendix/core/providers/parent_providers.dart';
import 'package:attendix/core/providers/realtime_providers.dart';
import 'package:attendix/core/providers/user_registration_providers.dart';
import 'package:attendix/core/providers/viewer_providers.dart';
import 'package:attendix/core/utils/attendance_percentage_utils.dart';
import 'package:attendix/core/utils/dashboard_logic.dart';
import 'package:attendix/core/utils/demo_guard.dart';
import 'package:attendix/core/utils/statistics_utils.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/data/models/parent/parent_model.dart';
import 'package:attendix/data/models/viewer/viewer.dart';
import 'package:attendix/data/repositories/attendance_repository.dart';
import 'package:attendix/data/repositories/attendance_type_repository.dart';
import 'package:attendix/data/repositories/parent_repository.dart';
import 'package:attendix/data/repositories/user_registration_repository.dart';
import 'package:attendix/data/repositories/viewer_repository.dart';
import 'package:attendix/features/registration/data/providers/registration_providers.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTypeRepo extends Mock implements AttendanceTypeRepository {}

class _MockAttendanceRepo extends Mock implements AttendanceRepository {}

class _MockRegistrationRepo extends Mock implements UserRegistrationRepository {}

class _MockViewerRepo extends Mock implements ViewerRepository {}

class _MockParentRepo extends Mock implements ParentRepository {}

String _read(String path) => File(path).readAsStringSync();

void main() {
  setUpAll(() {
    registerFallbackValue(const Viewer(appId: '', email: '', firstName: '', lastName: ''));
    registerFallbackValue(const ParentModel(appId: '', email: '', firstName: '', lastName: ''));
    registerFallbackValue(Role.none);
  });

  // ---------------------------------------------------------------------------
  // #1 (Medium) self registration backfill uses the stored row
  // ---------------------------------------------------------------------------
  group('#1 registration backfill (Ionic addPlayerToAttendancesByDate(data))', () {
    test('backfill person carries the registrant\'s additional_fields and joined', () {
      final row = buildRegistrationPlayerData(
        tenantId: 7,
        appId: 'u1',
        formData: RegistrationFormData(
          firstName: 'Max',
          lastName: 'Muster',
          groupId: 3,
          additionalFields: {'voice': 'alto', 'member': false},
        ),
        email: 'max@example.com',
        pending: false,
        hasBirthDate: false,
        phone: null,
        todayIso: '2026-10-28',
      )..['id'] = 99;
      final person = registrationBackfillPerson(row);
      expect(person.id, 99);
      expect(person.tenantId, 7);
      expect(person.instrument, 3);
      expect(person.additionalFields, {'voice': 'alto', 'member': false});
      expect(person.joined, '2026-10-28');
    });

    test('source: re-reads the stored row and calls addPlayerToAttendancesByDate', () {
      final src = _read('lib/features/registration/data/providers/registration_providers.dart');
      final start = src.indexOf('if (!pending) {');
      final block = src.substring(start, src.indexOf('return RegistrationResult.success(', start));
      expect(block, contains(".select('*')"));
      expect(block, contains(".eq('id', playerId)"));
      expect(block, contains(".eq('tenantId', tenantId)"));
      expect(block, contains('addPlayerToAttendancesByDate(registrationBackfillPerson(storedRow))'));
      expect(block, isNot(contains('addToUpcomingAttendances(Person(')));
    });
  });

  // ---------------------------------------------------------------------------
  // #2 (Medium) attendance DELETE listener only for loaded ids
  // ---------------------------------------------------------------------------
  group('#2 attendance realtime DELETE filtering', () {
    test('isRelevantAttendanceDelete', () {
      expect(isRelevantAttendanceDelete({'id': 5}, {1, 5}), isTrue);
      expect(isRelevantAttendanceDelete({'id': 6}, {1, 5}), isFalse,
          reason: 'other tenant\'s delete must not refetch');
      expect(isRelevantAttendanceDelete({'id': 6}, null), isTrue,
          reason: 'list not loaded yet');
      expect(isRelevantAttendanceDelete(const {}, {1}), isFalse);
      expect(isRelevantAttendanceDelete({'id': 5.0}, {5}), isTrue);
    });

    test('source: the unfiltered DELETE callback checks the loaded ids', () {
      final src = _read('lib/core/providers/realtime_providers.dart');
      final del = src.indexOf('event: PostgresChangeEvent.delete,\n        schema: \'public\',\n        table: \'attendance\',');
      expect(del, greaterThan(-1));
      final cb = src.substring(del, src.indexOf('.onPostgresChanges(', del));
      expect(cb, contains('isRelevantAttendanceDelete('));
      expect(cb, contains('ref.read(loadedAttendanceIdsProvider).ids'));
      expect(cb, isNot(contains('callback: onChanged,')));
      // The list records its ids after loading.
      expect(src, contains('ref.read(loadedAttendanceIdsProvider).ids =\n'));
    });
  });

  // ---------------------------------------------------------------------------
  // #3 type save vs. follow-up update
  // ---------------------------------------------------------------------------
  group('#3 AttendanceTypeNotifier.updateType', () {
    late _MockTypeRepo typeRepo;
    late _MockAttendanceRepo attRepo;
    late ProviderContainer container;
    const saved = AttendanceType(id: 't1', name: 'Probe');

    setUp(() {
      typeRepo = _MockTypeRepo();
      attRepo = _MockAttendanceRepo();
      container = ProviderContainer(overrides: [
        attendanceTypeRepositoryWithTenantProvider.overrideWithValue(typeRepo),
        attendanceRepositoryWithTenantProvider.overrideWithValue(attRepo),
      ]);
    });
    tearDown(() => container.dispose());

    // DB_FIX: like Ionic, saving a type never rewrites existing Termine.
    test('saving times returns the type and leaves Termine untouched',
        () async {
      when(() => typeRepo.updateType('t1', any())).thenAnswer((_) async => saved);
      final result = await container
          .read(attendanceTypeNotifierProvider.notifier)
          .updateType('t1', {'start_time': '19:00', 'end_time': '21:00'});
      expect(result, saved);
      verifyZeroInteractions(attRepo);
    });

    test('failed save returns null without follow-up', () async {
      when(() => typeRepo.updateType('t1', any())).thenAnswer((_) async => null);
      final result = await container
          .read(attendanceTypeNotifierProvider.notifier)
          .updateType('t1', {'start_time': '19:00'});
      expect(result, isNull);
      verifyZeroInteractions(attRepo);
    });

    test('DemoModeException is rethrown', () async {
      when(() => typeRepo.updateType('t1', any()))
          .thenThrow(const DemoModeException('updateType'));
      expect(
        () => container.read(attendanceTypeNotifierProvider.notifier).updateType('t1', {}),
        throwsA(isA<DemoModeException>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // #4 / #5 / #6 cleanups
  // ---------------------------------------------------------------------------
  test('#4 DutyRepository.decline is gone (Kann nicht = signOut)', () {
    expect(_read('lib/data/repositories/duty_repository.dart'),
        isNot(contains('Future<void> decline(')));
  });

  test('#5 no stale localeProvider watches in statistics providers', () {
    expect(_read('lib/core/providers/statistics_providers.dart'),
        isNot(contains('localeProvider')));
  });

  test('#6 CopyToTenantSheet keeps its own doc comment', () {
    expect(_read('lib/features/songs/presentation/widgets/copy_to_tenant_sheet.dart'),
        contains('/// Sheet for copying a song to another tenant\nclass CopyToTenantSheet'));
  });

  // ---------------------------------------------------------------------------
  // #7 one implementation per helper
  // ---------------------------------------------------------------------------
  group('#7 consolidated helpers', () {
    test('single getCurrentAttDate / isWorkExcused / connectivity check', () {
      expect(_read('lib/core/providers/plan_providers.dart'),
          allOf(isNot(contains('planAttendancesSince')),
              contains('attendanceListStartDate(seasonStart)')));
      expect(_read('lib/core/utils/shift_utils.dart'),
          isNot(contains('static bool isWorkExcused(')));
      expect(_read('lib/core/utils/dashboard_logic.dart'),
          isNot(contains('bool isWorkExcused(')));
      final song = _read('lib/data/repositories/song_repository.dart');
      expect(song, isNot(contains('Connectivity()')));
      expect(song, contains('ref.read(connectivityCheckProvider)()'));
      final player = _read('lib/data/repositories/player_repository.dart');
      final create = player.substring(player.indexOf('Future<Person> createPlayer('),
          player.indexOf('Future<Person> addPlayer('));
      expect(create, contains('_personInsertData(player)'));
      expect(create, isNot(contains("data.remove('groupName')")));
    });

    PersonAttendance pa(AttendanceStatus s, {String? notes, String? duty, int att = 1}) =>
        PersonAttendance(attendanceId: att, status: s, notes: notes, dutyState: duty);

    test('dashboard / stats / list percentages agree', () {
      final rows = [
        pa(AttendanceStatus.present),
        pa(AttendanceStatus.late),
        pa(AttendanceStatus.excused, notes: 'Schichtbedingt'),
        pa(AttendanceStatus.absent),
      ];
      final maps = [
        for (final r in rows)
          {'status': r.status.value, 'notes': r.notes, 'duty_state': r.dutyState}
      ];
      const type = AttendanceType(id: 'n', name: 'Probe');
      for (final shift in [false, true]) {
        final list = attendanceListPercentage(maps, type, shiftExcusedAsPresent: shift);
        final dash = attendancePercentage(rows, shiftExcusedAsPresent: shift);
        final stats = recomputeAttendancePercentages(
          const [Attendance(id: 1, date: '2026-01-01', typeId: 'n')],
          rows,
          const [type],
          shiftExcusedAsPresent: shift,
        ).single.percentage;
        expect(list, shift ? 75 : 50);
        expect(dash, list!.round());
        expect(stats, list);
      }
    });

    test('duty Termin without assignees: list null, stats 0 (unchanged)', () {
      const duty = AttendanceType(id: 'd', name: 'Dienst', dutyMode: true);
      final rows = [pa(AttendanceStatus.present)];
      expect(attendanceRowsPercentage(rows.map(attendanceCountRowOf), duty), isNull);
      expect(
        recomputeAttendancePercentages(
          const [Attendance(id: 1, date: '2026-01-01', typeId: 'd')],
          rows,
          const [duty],
        ).single.percentage,
        0,
      );
      expect(attendancePercentage(const []), 0);
    });
  });

  // ---------------------------------------------------------------------------
  // #8 shared invite flow
  // ---------------------------------------------------------------------------
  group('#8 Viewer/Parent invite (Ionic db.createViewer / createParent)', () {
    late _MockRegistrationRepo registration;
    late _MockViewerRepo viewers;
    late _MockParentRepo parents;
    late ProviderContainer container;

    setUp(() {
      registration = _MockRegistrationRepo();
      viewers = _MockViewerRepo();
      parents = _MockParentRepo();
      container = ProviderContainer(overrides: [
        userRegistrationRepositoryWithTenantProvider.overrideWithValue(registration),
        viewerRepositoryWithTenantProvider.overrideWithValue(viewers),
        parentRepositoryWithTenantProvider.overrideWithValue(parents),
      ]);
      when(() => registration.registerUser(
            email: any(named: 'email'),
            name: any(named: 'name'),
            role: any(named: 'role'),
          )).thenAnswer((_) async => 'uid-1');
      when(() => registration.linkParentToTenantUser(any(), any()))
          .thenAnswer((_) async {});
    });
    tearDown(() => container.dispose());

    test('viewer: registerUser then viewers row with the appId', () async {
      when(() => viewers.createViewer(any())).thenAnswer(
          (inv) async => (inv.positionalArguments.first as Viewer).copyWith(id: 4));
      final v = await container.read(viewerNotifierProvider.notifier).invite(
            email: ' a@b.de ',
            firstName: 'Ann',
            lastName: 'B',
          );
      expect(v.appId, 'uid-1');
      expect(v.email, 'a@b.de');
      verify(() => registration.registerUser(
          email: 'a@b.de', name: 'Ann', role: Role.viewer)).called(1);
    });

    test('viewer insert failure is reported (db.addViewerFailed), not silent', () async {
      when(() => viewers.createViewer(any())).thenThrow(Exception('insert'));
      await expectLater(
        container.read(viewerNotifierProvider.notifier).invite(
            email: 'a@b.de', firstName: 'Ann', lastName: 'B'),
        throwsA(isA<AccountFlowException>().having(
            (e) => e.message, 'message', l10nWithoutContext.dbAddViewerFailed)),
      );
    });

    test('parent: row inserted and tenantUsers.parent_id linked', () async {
      when(() => parents.createParent(any())).thenAnswer(
          (inv) async => (inv.positionalArguments.first as ParentModel).copyWith(id: 9));
      await container.read(parentNotifierProvider.notifier).invite(
            email: 'p@b.de',
            firstName: 'Paul',
            lastName: 'P',
          );
      verify(() => registration.registerUser(
          email: 'p@b.de', name: 'Paul', role: Role.parent)).called(1);
      verify(() => registration.linkParentToTenantUser('uid-1', 9)).called(1);
    });

    test('parent insert failure throws db.addParentFailed and skips the link', () async {
      when(() => parents.createParent(any())).thenThrow(Exception('insert'));
      await expectLater(
        container.read(parentNotifierProvider.notifier).invite(
            email: 'p@b.de', firstName: 'Paul', lastName: 'P'),
        throwsA(isA<AccountFlowException>().having(
            (e) => e.message, 'message', l10nWithoutContext.dbAddParentFailed)),
      );
      verifyNever(() => registration.linkParentToTenantUser(any(), any()));
    });

    test('all three pages use the shared flow', () {
      for (final path in [
        'lib/features/settings/presentation/pages/viewers_page.dart',
        'lib/features/settings/presentation/pages/parents_page.dart',
        'lib/features/settings/presentation/pages/user_management_page.dart',
      ]) {
        final src = _read(path);
        expect(src, contains('.invite('), reason: path);
        expect(src, isNot(contains('.createViewer(')), reason: path);
        expect(src, isNot(contains('.createParent(')), reason: path);
        expect(src, isNot(contains('linkParentToTenantUser')), reason: path);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // #9 shared plan editor writes the ISO end
  // ---------------------------------------------------------------------------
  test('#9 shared_plan_page stores plan.end like planning_page (computeEndIso)', () {
    final src = _read('lib/features/planning/presentation/pages/shared_plan_page.dart');
    // SOL_FIX12: ad-hoc plans base the end on their own date (endBase).
    expect(src, contains('PlanUtils.computeEndIso(endBase, _fields)'));
    expect(src, isNot(contains('PlanUtils.computeEnd(')));
  });
}
