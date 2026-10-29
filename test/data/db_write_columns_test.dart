// DB_FIX: every key a write sends must be a column of the target table.
//
// Unknown keys make PostgREST reject the WHOLE statement (PGRST204), e.g.
// `telegramId` on player inserts, `show_members_list` on tenants updates,
// `composer` on songs inserts, `shortName` on instruments updates.
//
// Column lists: test/fixtures/db_columns.dart, generated from the Ionic
// schema by `dart run tool/db/extract_db_columns.dart`.
import 'dart:io';

import 'package:attendix/core/services/telegram_service.dart';
import 'package:attendix/core/utils/db_helpers.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/data/models/parent/parent_model.dart';
import 'package:attendix/data/models/person/person.dart';
import 'package:attendix/data/models/plan/plan.dart';
import 'package:attendix/data/models/shift/shift_plan.dart';
import 'package:attendix/data/models/tenant/tenant.dart';
import 'package:attendix/data/models/usage_event.dart';
import 'package:attendix/data/models/viewer/viewer.dart';
import 'package:attendix/data/repositories/attendance_repository.dart';
import 'package:attendix/data/repositories/attendance_type_repository.dart';
import 'package:attendix/features/registration/data/providers/registration_providers.dart';
import 'package:attendix/features/team_organization/presentation/widgets/quick_create_attendance.dart';
import 'package:attendix/features/tenant_selection/tenant_defaults.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/db_columns.dart';

void expectColumns(String table, Iterable<String> keys, {String? reason}) {
  final cols = kDbColumns[table];
  expect(cols, isNotNull, reason: 'table $table missing in db_columns.dart');
  final unknown = keys.where((k) => !cols!.contains(k)).toList()..sort();
  expect(unknown, isEmpty,
      reason: '${reason ?? table}: keys not in $table schema: $unknown');
}

String _read(String path) => File(path).readAsStringSync();

/// A Person with every field set, so toJson emits every key.
Person _fullPerson() => Person(
      id: 1,
      createdAt: DateTime(2024),
      firstName: 'A',
      lastName: 'B',
      birthday: '2000-01-01',
      joined: '2020-01-01',
      left: '',
      email: 'a@b.c',
      appId: 'uid',
      globalPersonId: 'g',
      notes: 'n',
      img: 'https://x/y.png',
      telegramId: '123',
      paused: true,
      pausedUntil: '2025-01-01',
      tenantId: 42,
      additionalFields: const {'f': 1},
      phone: '1',
      shiftId: 's',
      shiftStart: '2024-01-01',
      shiftName: 'S',
      pending: true,
      selfRegister: true,
      instrument: 3,
      hasTeacher: true,
      playsSince: '2010-01-01',
      isLeader: true,
      teacher: 4,
      isCritical: true,
      criticalReason: '2',
      lastSolve: '2024-01-01',
      correctBirthday: true,
      otherOrchestras: const ['x'],
      otherExercise: 'o',
      testResult: 't',
      examinee: true,
      range: 'r',
      instruments: 'i',
      parentId: 5,
      sortOrder: 6,
      legacyId: 7,
      legacyConductorId: 8,
      groupName: 'G',
      teacherName: 'T',
      criticalReasonText: 'C',
      percentage: 50,
    );

void main() {
  test('fixture contains the core tables', () {
    for (final t in ['player', 'tenants', 'songs', 'instruments', 'attendance']) {
      expect(kDbColumns.containsKey(t), isTrue, reason: t);
    }
    expect(kDbColumns['tenants'], contains('showMembersList'));
    expect(kDbColumns['tenants'], isNot(contains('show_members_list')));
    expect(kDbColumns['player'], isNot(contains('telegramId')));
    expect(kDbColumns['songs'], isNot(contains('composer')));
    expect(kDbColumns['instruments'], isNot(contains('shortName')));
  });

  group('player (pickPersonFields)', () {
    test('keeps only player columns of a full Person', () {
      final picked = pickPersonFields(_fullPerson().toJson());
      expectColumns('player', picked.keys);
      expect(picked.containsKey('telegramId'), isFalse);
      expect(picked.containsKey('img'), isFalse);
      expect(picked.containsKey('sort_order'), isFalse);
    });

    test('whitelist itself is a subset of the schema', () {
      expectColumns('player', kPlayerWritableColumns);
    });

    test('normalises blank timestamps and coerces criticalReason', () {
      final picked = pickPersonFields(_fullPerson().toJson());
      expect(picked['left'], isNull);
      expect(picked['criticalReason'], 2);
      expect(pickPersonFields({'birthday': '', 'notes': ''}),
          {'birthday': null, 'notes': ''});
    });

    test('generateIonicId is in Ionic Utils.getId range', () {
      for (var i = 0; i < 200; i++) {
        final id = generateIonicId();
        expect(id, inInclusiveRange(1000000000, 999999999999));
      }
    });

    test('player_repository never sends Person.toJson() unfiltered', () {
      final src = _read('lib/data/repositories/player_repository.dart');
      final raw = RegExp(r'= (player|person)\.toJson\(\)').allMatches(src);
      expect(raw, isEmpty);
      expect(src, contains('pickPersonFields(player.toJson())'));
      // insert: random id like Ionic, nulls not sent
      final ins = src.substring(src.indexOf('Map<String, dynamic> _personInsertData('));
      final body = ins.substring(0, ins.indexOf('\n  }\n'));
      expect(body, contains("data['id'] = generateIonicId()"));
      expect(body, contains('removeWhere((_, v) => v == null)'));
    });

    test('registration rows are player columns', () {
      final data = buildRegistrationPlayerData(
        tenantId: 1,
        appId: 'u',
        formData: RegistrationFormData(firstName: 'a', lastName: 'b'),
        email: 'a@b.c',
        pending: true,
        hasBirthDate: false,
        phone: null,
        todayIso: '2024-01-01',
      );
      expectColumns('player', data.keys);
      expectColumns('player', reactivationPlayerData(data).keys);
    });
  });

  group('tenants', () {
    test('general settings writes showMembersList (camelCase)', () {
      final src = _read(
          'lib/features/settings/presentation/pages/general_settings_page.dart');
      expect(src, isNot(contains("'show_members_list'")));
      expect(src, contains("'showMembersList': _showMembersList"));
    });

    test('Tenant reads showMembersList from the DB column', () {
      final t = Tenant.fromJson(
          {'shortName': 'a', 'longName': 'b', 'showMembersList': true});
      expect(t.showMembersList, isTrue);
      expect(t.toJson().containsKey('show_members_list'), isFalse);
    });

    test('new tenant payload uses tenants columns', () {
      expectColumns(
          'tenants',
          buildNewTenantPayload(
            shortName: 'a',
            longName: 'b',
            type: 'orchestra',
            timezone: 'Europe/Berlin',
          ).keys);
      for (final row in buildNewTenantUsers(tenantId: 1, userId: 'u', email: 'e')) {
        expectColumns('tenantUsers', row.keys);
      }
      expectColumns('instruments',
          buildMainGroupPayload(tenantId: 1, name: 'Dirigenten').keys);
      for (final row in buildDefaultAttendanceTypes(tenantId: 1, type: 'orchestra')) {
        expectColumns('attendance_types', row.keys);
      }
    });
  });

  group('songs', () {
    test('createSong builds an explicit map (no Song.toJson / composer)', () {
      final src = _read('lib/data/repositories/song_repository.dart');
      final start = src.indexOf('Future<Song> createSong(');
      final body = src.substring(start, src.indexOf('Future<Song> updateSong(', start));
      expect(body, isNot(contains('toJson()')));
      expect(body, isNot(contains("'composer'")));
      final keys = RegExp(r"'(\w+)':").allMatches(body).map((m) => m.group(1)!);
      expectColumns('songs', keys);
    });
  });

  group('instruments (pickGroupFields)', () {
    test('drops non-columns like shortName', () {
      final picked = pickGroupFields({
        'name': 'Geige',
        'shortName': 'Vl',
        'categoryData': {},
        'count': 3,
        'tuning': 'C',
      });
      expect(picked, {'name': 'Geige', 'tuning': 'C'});
      expectColumns('instruments', kGroupWritableColumns);
    });
  });

  group('attendance_types', () {
    test('type save never rewrites Termine (Ionic updateAttendanceType)', () {
      final src = _read('lib/core/providers/attendance_type_providers.dart');
      expect(src, isNot(contains('updateFutureAttendanceTimes')));
      expect(_read('lib/data/repositories/attendance_repository.dart'),
          isNot(contains('updateFutureAttendanceTimes')));
    });

    test('insert payload uses attendance_types columns', () {
      expectColumns('attendance_types',
          AttendanceTypeRepository.buildInsertData(const AttendanceType(name: 'P'), 1).keys);
    });
  });

  group('models written via toJson', () {
    test('attendance insert', () {
      final att = Attendance(
        id: 1,
        tenantId: 1,
        createdAt: DateTime(2024),
        date: '2024-01-01',
        percentage: 50,
        lateExcused: const ['1'],
        excused: const ['2'],
        typeInfo: 'x',
        notes: 'n',
        img: 'i',
        plan: const {},
        songs: const [1],
        criticalPlayers: const [1],
        playerNotes: const {},
        startTime: '19:00',
        endTime: '20:00',
        deadline: 'd',
        durationDays: 1,
        conductors: const [1],
        players: const {},
        place: 'p',
        filesFolder: 'f',
        description: 'd',
        attachmentUrl: 'u',
        attachmentName: 'n',
        dutyRequired: 1,
        createdBy: 'u',
        type: 't',
        typeId: 'tid',
      );
      final data = AttendanceRepository.buildInsertData(att);
      expectColumns('attendance', data.keys);
      expect(data.containsKey('percentage'), isFalse);
      expect(data.containsKey('lateExcused'), isFalse);
      expectColumns('attendance', AttendanceRepository.insertColumns);
    });

    test('quick-create attendance row', () {
      expectColumns(
          'attendance',
          newAttendanceRow(const AttendanceType(id: 't', name: 'P'), DateTime(2024),
                  isOrgPlan: true)
              .keys);
    });

    test('attendance inserts write no created_by like Ionic (PARITY_A D9)', () {
      final row = newAttendanceRow(
          const AttendanceType(id: 't', name: 'P'), DateTime(2024));
      expect(row.containsKey('created_by'), isFalse);
      for (final path in const [
        'lib/features/attendance/presentation/pages/attendance_create_page.dart',
        'lib/features/attendance/presentation/attendance_create_writes.dart',
      ]) {
        expect(File(path).readAsStringSync(), isNot(contains("'created_by':")));
      }
    });

    test('viewers / parents insert', () {
      const v = Viewer(appId: 'a', email: 'e', firstName: 'f', lastName: 'l', tenantId: 1);
      expectColumns('viewers', (v.toJson()..remove('id')..remove('created_at')).keys);
      const p = ParentModel(appId: 'a', email: 'e', firstName: 'f', lastName: 'l', tenantId: 1);
      expectColumns('parents', (p.toJson()..remove('id')..remove('created_at')).keys);
    });

    test('shifts insert/update', () {
      const s = ShiftPlan(name: 'n', tenantId: 1);
      expectColumns('shifts', s.toJson().keys);
    });

    test('shared_plans insert', () {
      const sp = SharedPlan(
        id: 'k',
        editKey: 'e',
        planTitle: 't',
        date: 'd',
        time: '1',
        endTime: '2',
        brandingId: 'b',
        creatorUserId: 'u',
        createdAt: 'c',
        orgId: 1,
      );
      expectColumns('shared_plans', sp.toJson().keys);
    });

    test('usage_events insert', () {
      const e = UsageEvent(eventName: 'x', tenantId: 1, deviceType: 'web');
      expectColumns('usage_events', e.toJson().keys);
    });

    test('notifications insert/update', () {
      final c = NotificationConfig(id: 'u', duties: true, liveActivity: true, enabledTenants: const [1]);
      expectColumns('notifications', c.toJson().keys);
    });
  });
}
