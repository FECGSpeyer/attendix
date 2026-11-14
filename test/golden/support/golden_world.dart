// One small made-up group that all page images share.
//
// The app reads the clock directly (DateTime.now()), and a test cannot stop
// it. So nothing here depends on today: Termine lie far in the future or the
// past, and no page shows an age or a countdown.
import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/attendance_type_providers.dart';
import 'package:attendix/core/providers/debug_providers.dart';
import 'package:attendix/core/providers/group_providers.dart';
import 'package:attendix/core/providers/organisation_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/data/models/instrument/instrument.dart';
import 'package:attendix/data/models/person/person.dart';
import 'package:attendix/data/models/song/song.dart';
import 'package:attendix/data/models/tenant/tenant.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../factories/test_factories.dart';

const worldTenantId = 7;

class _TenantNotifier extends CurrentTenantNotifier {
  _TenantNotifier(super.ref) {
    state = TestFactories.createTenant(
      id: worldTenantId,
      shortName: 'SO',
      longName: 'Stadtorchester',
      showMembersList: true,
    );
  }
}

/// The groups of the signed-in account.
List<Tenant> worldTenants(Role role) => [
      TestFactories.createTenant(id: worldTenantId, shortName: 'SO', longName: 'Stadtorchester').copyWith(role: role.value),
      TestFactories.createTenant(id: 8, shortName: 'KC', longName: 'Kammerchor', type: 'choir').copyWith(role: Role.player.value),
    ];

final worldGroups = <Group>[
  TestFactories.createGroup(id: 1, tenantId: worldTenantId, name: 'Violine', index: 0).copyWith(sortOrder: 1),
  TestFactories.createGroup(id: 2, tenantId: worldTenantId, name: 'Flöte', index: 1).copyWith(sortOrder: 2),
  TestFactories.createGroup(id: 3, tenantId: worldTenantId, name: 'Trompete', index: 2).copyWith(sortOrder: 3),
  TestFactories.createGroup(id: 4, tenantId: worldTenantId, name: 'Schlagwerk', index: 3).copyWith(sortOrder: 4),
];

Person _person(int id, String first, String last, int group, {bool leader = false, bool paused = false, bool critical = false}) =>
    TestFactories.createPerson(
      id: id,
      firstName: first,
      lastName: last,
      tenantId: worldTenantId,
      instrument: group,
      isLeader: leader,
      isCritical: critical,
      paused: paused,
      email: '${first.toLowerCase()}@example.org',
      joined: '2019-09-01',
    ).copyWith(
      groupName: worldGroups[group - 1].name,
      // No birthdays: "Heute" lists the coming ones, which moves with the date.
      birthday: null,
    );

final worldPersons = <Person>[
  _person(1, 'Anna', 'Berg', 1, leader: true),
  _person(2, 'Ben', 'Claasen', 1),
  _person(3, 'Clara', 'Dorn', 1),
  _person(4, 'David', 'Engel', 2, leader: true),
  _person(5, 'Emma', 'Fischer', 2, paused: true),
  _person(6, 'Felix', 'Graf', 3),
  _person(7, 'Greta', 'Hahn', 3, critical: true),
  _person(8, 'Henri', 'Iser', 3),
  _person(9, 'Ida', 'Jung', 4),
  _person(10, 'Jonas', 'Kurz', 4),
];

/// Share of attended Termine per person id.
const worldPercentages = <int, int>{1: 96, 2: 88, 3: 74, 4: 100, 5: 61, 6: 92, 7: 38, 8: 81, 9: 85, 10: 79};

const worldTypes = <AttendanceType>[
  AttendanceType(id: 't-probe', name: 'Probe', startTime: '19:30', endTime: '21:30'),
  AttendanceType(id: 't-vortrag', name: 'Vortrag', startTime: '17:00', endTime: '19:00'),
];

/// Upcoming Termine first, then past ones.
final worldAttendances = <Attendance>[
  TestFactories.createAttendance(id: 21, tenantId: worldTenantId, date: '2099-03-05', typeId: 't-probe', typeInfo: 'Gesamtprobe', startTime: '19:30', endTime: '21:30'),
  TestFactories.createAttendance(id: 22, tenantId: worldTenantId, date: '2099-03-12', typeId: 't-probe', typeInfo: 'Registerprobe Streicher', startTime: '19:30', endTime: '21:30'),
  TestFactories.createAttendance(id: 23, tenantId: worldTenantId, date: '2099-03-21', typeId: 't-vortrag', typeInfo: 'Frühjahrskonzert', startTime: '17:00', endTime: '19:00'),
  TestFactories.createAttendance(id: 11, tenantId: worldTenantId, date: '2024-11-21', typeId: 't-probe', typeInfo: 'Gesamtprobe', percentage: 90, startTime: '19:30', endTime: '21:30'),
  TestFactories.createAttendance(id: 12, tenantId: worldTenantId, date: '2024-11-14', typeId: 't-probe', typeInfo: 'Gesamtprobe', percentage: 80, startTime: '19:30', endTime: '21:30'),
];

/// Answers to the Gesamtprobe (Termin 21).
final worldAnswers = <PersonAttendance>[
  for (final (index, status) in const [
    AttendanceStatus.present,
    AttendanceStatus.present,
    AttendanceStatus.excused,
    AttendanceStatus.present,
    AttendanceStatus.neutral,
    AttendanceStatus.present,
    AttendanceStatus.lateExcused,
    AttendanceStatus.present,
    AttendanceStatus.neutral,
    AttendanceStatus.present,
  ].indexed)
    TestFactories.createPersonAttendance(
      id: 'pa-${index + 1}',
      attendanceId: 21,
      personId: worldPersons[index].id,
      status: status,
      notes: switch (status) {
        AttendanceStatus.excused => 'Dienstreise',
        AttendanceStatus.lateExcused => 'komme um 20 Uhr',
        _ => null,
      },
      firstName: worldPersons[index].firstName,
      lastName: worldPersons[index].lastName,
      instrument: worldPersons[index].instrument,
      groupName: worldPersons[index].groupName,
    ),
];

const worldSongs = <Song>[
  Song(id: 1, name: 'Festliche Ouvertüre', number: 12, composer: 'D. Schostakowitsch'),
  Song(id: 2, name: 'Ave verum corpus', number: 41, composer: 'W. A. Mozart'),
  Song(id: 3, name: 'Abendlied', number: 3, composer: 'J. Rheinberger'),
  Song(id: 4, name: 'Ungarischer Tanz Nr. 5', number: 27, composer: 'J. Brahms'),
  Song(id: 5, name: 'Pavane', number: 8, composer: 'G. Fauré'),
];

/// What almost every page asks for: the group, the role and the lists above.
List<Override> worldOverrides({Role role = Role.admin}) => [
      effectiveRoleProvider.overrideWithValue(role),
      currentTenantProvider.overrideWith((ref) => _TenantNotifier(ref)),
      currentTenantIdProvider.overrideWithValue(worldTenantId),
      userTenantsProvider.overrideWith((ref) async => worldTenants(role)),
      groupsProvider.overrideWith((ref) async => worldGroups),
      groupsMapProvider.overrideWith((ref) async => {for (final group in worldGroups) group.id!: group.name}),
      attendanceTypesProvider.overrideWith((ref) async => worldTypes),
      allLinkedTenantsProvider.overrideWith((ref) async => const <Tenant>[]),
    ];
