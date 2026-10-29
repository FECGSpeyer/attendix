import 'package:attendix/features/history/history_utils.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _rehearsal(String date, List<int> songIds,
        {String type = 'uebung', List<int> extra = const []}) =>
    {
      'date': date,
      'type': type,
      'plan': {
        'fields': [
          for (final id in songIds) {'id': '$id', 'name': 'Song $id'},
        ],
      },
      if (extra.isNotEmpty)
        'extra_plans': [
          {
            'fields': [
              for (final id in extra) {'id': '$id'},
            ],
          },
        ],
    };

void main() {
  group('countRehearsalsForSong', () {
    final rehearsals = [
      _rehearsal('2026-05-01T18:00:00Z', [1, 2]),
      _rehearsal('2026-04-01T18:00:00Z', [1]),
      _rehearsal('2026-01-01T18:00:00Z', [1]), // older than 4 months
      _rehearsal('2026-06-15T18:00:00Z', [1]), // after the performance
      _rehearsal('2026-05-10T18:00:00Z', [1], type: 'vortrag'),
      _rehearsal('2026-05-20T18:00:00Z', [3], extra: [1]),
    ];

    test('counts rehearsals within four months before the performance', () {
      expect(countRehearsalsForSong(rehearsals, 1, '2026-06-01T18:00:00Z'), 3);
      expect(countRehearsalsForSong(rehearsals, 2, '2026-06-01T18:00:00Z'), 1);
      expect(countRehearsalsForSong(rehearsals, 99, '2026-06-01T18:00:00Z'), 0);
    });

    test('ignores attendances without plan or invalid dates', () {
      expect(
        countRehearsalsForSong(
          [
            {'date': '2026-05-01', 'type': 'uebung', 'plan': null},
            {'date': 'kaputt', 'type': 'uebung', 'plan': {}},
          ],
          1,
          '2026-06-01',
        ),
        0,
      );
      expect(countRehearsalsForSong(rehearsals, 1, 'kein Datum'), 0);
    });
  });

  test('rehearsalsLabel uses German plural', () {
    expect(rehearsalsLabel(1), '1 Probe');
    expect(rehearsalsLabel(3), '3 Proben');
  });
}
