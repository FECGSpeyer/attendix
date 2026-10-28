import 'package:attendix/core/providers/history_providers.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _att(String date, List<String> songIds,
        {String type = 'uebung', List<List<String>> extra = const []}) =>
    {
      'date': date,
      'type': type,
      'plan': {
        'fields': [for (final id in songIds) {'id': id}],
      },
      'extra_plans': [
        for (final e in extra)
          {
            'fields': [for (final id in e) {'id': id}],
          },
      ],
    };

void main() {
  group('countRehearsals (Ionic isSongInPlan)', () {
    test('counts rehearsals within the 4 months before the date', () {
      final atts = [
        _att('2026-05-01T00:00:00Z', ['7']),
        _att('2026-04-01T00:00:00Z', ['7', '8']),
        _att('2026-01-01T00:00:00Z', ['7']), // older than 4 months
        _att('2026-06-02T00:00:00Z', ['7']), // after the date
      ];
      expect(countRehearsals(atts, 7, '2026-06-01T00:00:00Z'), 2);
    });

    test('ignores non-rehearsal types and other songs', () {
      final atts = [
        _att('2026-05-01T00:00:00Z', ['7'], type: 'vortrag'),
        _att('2026-05-02T00:00:00Z', ['9']),
      ];
      expect(countRehearsals(atts, 7, '2026-06-01T00:00:00Z'), 0);
    });

    test('also looks into extra plans (multi-day Termine)', () {
      final atts = [
        _att('2026-05-01T00:00:00Z', ['1'], extra: [
          ['7'],
        ]),
      ];
      expect(countRehearsals(atts, 7, '2026-06-01T00:00:00Z'), 1);
    });

    test('invalid date yields 0', () {
      expect(countRehearsals([_att('2026-05-01', ['7'])], 7, ''), 0);
    });
  });
}
