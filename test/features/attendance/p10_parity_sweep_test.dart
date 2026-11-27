import 'package:attendix/core/providers/statistics_providers.dart';
import 'package:attendix/core/utils/attendance_logic_utils.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/features/songs/data/history_utils.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../factories/test_factories.dart';

void main() {
  group('showSongsForType (manageSongs && !isGeneral)', () {
    const withSongs = AttendanceType(name: 'Probe', manageSongs: true);
    const noSongs = AttendanceType(name: 'Sitzung');

    test('shown for song types of non-general tenants', () {
      expect(showSongsForType(withSongs, 'orchestra'), isTrue);
      expect(showSongsForType(withSongs, null), isTrue);
    });

    test('hidden for general tenants and types without songs', () {
      expect(showSongsForType(withSongs, 'general'), isFalse);
      expect(showSongsForType(noSongs, 'orchestra'), isFalse);
      expect(showSongsForType(null, 'orchestra'), isFalse);
    });
  });

  group('history: default conductor (activeConductors[0])', () {
    test('first conductor who has not left', () {
      final conductors = [
        TestFactories.createPerson(id: 1, left: '2024-01-01'),
        TestFactories.createPerson(id: 2),
        TestFactories.createPerson(id: 3),
      ];
      expect(defaultHistoryConductorId(conductors), 2);
    });

    test('null without active conductors', () {
      expect(defaultHistoryConductorId(const []), isNull);
      expect(
        defaultHistoryConductorId(
            [TestFactories.createPerson(id: 1, left: '2024-01-01')]),
        isNull,
      );
    });
  });

  group('stats: default period (seasonStart || 2023-01-01)', () {
    test('uses the season start when set', () {
      final n = StatisticsDateRangeNotifier()
        ..resetToDefault(seasonStart: '2025-09-01');
      expect(n.state.start, DateTime(2025, 9, 1));
    });

    test('falls back to 2023-01-01 without season start', () {
      final n = StatisticsDateRangeNotifier()..resetToDefault();
      expect(n.state.start, DateTime(2023, 1, 1));
      final m = StatisticsDateRangeNotifier()
        ..resetToDefault(seasonStart: 'kein Datum');
      expect(m.state.start, DateTime(2023, 1, 1));
    });
  });
}
