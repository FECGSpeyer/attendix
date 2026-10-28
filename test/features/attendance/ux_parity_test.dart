import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/attendance_providers.dart';
import 'package:attendix/data/models/instrument/instrument.dart';
import 'package:attendix/features/attendance/presentation/widgets/attendance_detail/attendance_grid.dart';
import 'package:attendix/features/attendance/presentation/widgets/attendance_detail/status_chip.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../factories/test_factories.dart';

// UX_ATT: Ionic parity helpers of the Termine screens.
void main() {
  const n = AttendanceStatus.neutral;
  const p = AttendanceStatus.present;
  const e = AttendanceStatus.excused;
  const l = AttendanceStatus.late;
  const le = AttendanceStatus.lateExcused;
  const a = AttendanceStatus.absent;

  group('nextClickStatus (Ionic ATTENDANCE_STATUS_MAPPING)', () {
    test('DEFAULT cycle with all statuses', () {
      const all = [n, p, e, l, a];
      expect(nextClickStatus(n, all), p);
      expect(nextClickStatus(p, all), e);
      expect(nextClickStatus(e, all), l);
      expect(nextClickStatus(l, all), a);
      expect(nextClickStatus(le, all), a);
      expect(nextClickStatus(a, all), p);
    });

    test('NO_NEUTRAL cycle', () {
      const types = [p, e, l, a];
      expect(nextClickStatus(p, types), e);
      expect(nextClickStatus(a, types), p);
    });

    test('NO_LATE cycle skips Verspätet', () {
      const types = [n, p, e, a];
      expect(nextClickStatus(e, types), a);
    });

    test('ONLY_PRESENT_ABSENT toggles', () {
      const types = [p, a];
      expect(nextClickStatus(p, types), a);
      expect(nextClickStatus(a, types), p);
    });

    test('no matching mapping returns null', () {
      expect(nextClickStatus(p, const [p]), isNull);
    });
  });

  test('ionicSelectableStatuses keeps Ionic order and adds lateExcused with late', () {
    expect(ionicSelectableStatuses(const [a, l, p, n, e]), [n, p, e, l, le, a]);
    expect(ionicSelectableStatuses(const [p, a]), [p, a]);
  });

  test('ionicStatusBadge letters', () {
    expect(ionicStatusBadge(n).text, 'N');
    expect(ionicStatusBadge(p).text, '✓');
    expect(ionicStatusBadge(e).text, 'E');
    expect(ionicStatusBadge(l).text, 'L');
    expect(ionicStatusBadge(le).text, 'LE');
    expect(ionicStatusBadge(a).text, 'A');
  });

  test('sortPersonsByGroup: main group first, then sort_order, then name', () {
    final groups = [
      const Group(id: 1, name: 'Bass', sortOrder: 2),
      const Group(id: 2, name: 'Alt', sortOrder: 1),
      const Group(id: 3, name: 'Dirigent', sortOrder: 9),
    ];
    final persons = [
      TestFactories.createPerson(id: 1, lastName: 'Zeller').copyWith(instrument: 1, groupName: 'Bass'),
      TestFactories.createPerson(id: 2, lastName: 'Adler').copyWith(instrument: 1, groupName: 'Bass'),
      TestFactories.createPerson(id: 3, lastName: 'Meier').copyWith(instrument: 2, groupName: 'Alt'),
      TestFactories.createPerson(id: 4, lastName: 'Bach').copyWith(instrument: 3, groupName: 'Dirigent'),
    ];
    final sorted = sortPersonsByGroup(persons, groups: groups, mainGroupId: 3);
    expect(sorted.map((p) => p.id), [4, 3, 2, 1]);
  });

  test('AttendanceStatusCounts counts total and Ionic buckets', () {
    final counts = AttendanceStatusCounts.fromStatuses(const [p, l, e, le, a, n]);
    expect(counts.present, 2);
    expect(counts.excused, 2);
    expect(counts.absent, 1);
    expect(counts.total, 6);
  });
}
