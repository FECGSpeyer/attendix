import 'package:attendix/core/utils/type_circle.dart';
import 'package:attendix/features/redesign/data/rd_create_logic.dart';
import 'package:attendix/features/team_organization/presentation/widgets/quick_create_attendance.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../factories/test_factories.dart';

void main() {
  test('circle: nobody named = everyone, else group or named person', () {
    expect(typeCircleCovers(const [], const [], groupId: 3, personId: 9), isTrue);
    expect(typeCircleCovers(const [1], const [], groupId: 3, personId: 9), isFalse);
    expect(typeCircleCovers(const [1], const [9], groupId: 3, personId: 9), isTrue);
    // Only persons named: the others are not part of it.
    expect(typeCircleCovers(const [], const [9], groupId: 3, personId: 8), isFalse);
    expect(typeCirclePersonsFromJson(null), isEmpty);
    expect(typeCirclePersonsFromJson([4, 5.0, 'x']), [4, 5]);
  });

  test('a new Termin invites the groups plus the named persons', () {
    final type = TestFactories.createAttendanceType(id: 't', name: 'Besprechung', relevantGroups: [1]);
    final rows = [
      {'id': 1, 'instrument': 1},
      {'id': 2, 'instrument': 2},
      {'id': 3, 'instrument': 2},
    ];
    expect(personsForAttendanceType(rows, type, const []).map((p) => p['id']), [1]);
    expect(personsForAttendanceType(rows, type, const [], circlePersons: [3]).map((p) => p['id']), [1, 3]);

    final players = [
      TestFactories.createPerson(id: 1, instrument: 1),
      TestFactories.createPerson(id: 2, instrument: 2),
      TestFactories.createPerson(id: 3, instrument: 2),
    ];
    expect(rdInvitedPersons(players, type, const [], circlePersons: [3]).map((p) => p.id), [1, 3]);
  });
}
