import 'dart:io';

import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/data/models/song/song.dart';
import 'package:attendix/features/duty/presentation/widgets/self_service_duty_section.dart';
import 'package:attendix/features/self_service/presentation/widgets/self_service_absences.dart';
import 'package:attendix/features/self_service/presentation/widgets/self_service_event_actions.dart';
import 'package:attendix/features/self_service/presentation/widgets/upcoming_songs_sheet.dart';
import 'package:attendix/features/people/presentation/widgets/planned_absences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// UX_SELF: parity helpers of "Meine Termine" with the Ionic signout page.
void main() {
  group('hasSongNotesForPlayer (Ionic red rows in "Aktuelle Werke")', () {
    const song = Song(id: 1, name: 'Halleluja', instrumentIds: [5]);

    test('true when the song lists the player instrument', () {
      expect(hasSongNotesForPlayer(song, 5, isChoir: false), isTrue);
    });

    test('false when the instrument is missing or the list is empty', () {
      expect(hasSongNotesForPlayer(song, 7, isChoir: false), isFalse);
      expect(hasSongNotesForPlayer(const Song(id: 2, name: 'X'), 5, isChoir: false), isFalse);
      expect(hasSongNotesForPlayer(null, 5, isChoir: false), isFalse);
    });

    test('choir: a file noted "Chor" counts as notes', () {
      const choirSong = Song(
        id: 3,
        name: 'Choral',
        files: [SongFile(fileName: 'a.pdf', fileType: 'pdf', url: 'u', note: 'Chor')],
      );
      expect(hasSongNotesForPlayer(choirSong, 9, isChoir: true), isTrue);
      expect(hasSongNotesForPlayer(choirSong, 9, isChoir: false), isFalse);
    });
  });

  test('open duties tile subtitle matches Ionic texts', () {
    expect(openDutiesTileSubtitle(0), 'alles besetzt');
    expect(openDutiesTileSubtitle(1), '1 offen');
    expect(openDutiesTileSubtitle(4), '4 offen');
  });

  group('signout page element order', () {
    late String source;
    setUpAll(() {
      source = File('lib/features/self_service/presentation/pages/signout_page.dart')
          .readAsStringSync();
    });

    test('greeting, tiles, duty requests, tasks, absences, duty view, events', () {
      final order = [
        '_buildGreeting(player, data',
        'SelfServiceDutyPart.stats',
        '_buildTiles(player)',
        'SelfServiceDutyPart.requests',
        'const MyTasksCard()',
        'const SelfServicePlannedAbsences()',
        'SelfServiceDutyPart.dutyView',
        '_buildCurrent(data',
        '_buildUpcoming(data',
        '_buildPast(data',
      ];
      var last = -1;
      for (final marker in order) {
        final index = source.indexOf(marker, last + 1);
        expect(index, greaterThan(last), reason: '$marker out of order');
        last = index;
      }
    });

    test('pause / unpause are header buttons', () {
      final appBar = source.substring(source.indexOf('PreferredSizeWidget _buildAppBar'));
      expect(appBar.indexOf('selfServicePause'), lessThan(appBar.indexOf('tooltip: context.l10n.signoutLegend')));
      expect(appBar, contains('selfServiceUnpause'));
    });
  });

  testWidgets('single registration field opens an alert (Ionic showSingleFieldAlert)',
      (tester) async {
    Map<String, dynamic>? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showSingleRegistrationFieldDialog(
              context,
              field: const RegistrationField(
                id: 'f1',
                label: 'Mit Übernachtung?',
                type: RegistrationFieldType.boolean,
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Mit Übernachtung?'), findsOneWidget);
    // Sign-in mode: no "Abbrechen", only "Anmelden"
    expect(find.text('Abbrechen'), findsNothing);
    await tester.tap(find.text('Ja'));
    await tester.tap(find.text('Anmelden'));
    await tester.pumpAndSettle();
    expect(result, {'f1': true});
  });

  testWidgets('absence sheet needs reason and range before saving', (tester) async {
    AbsenceInput? input;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            input = await showModalBottomSheet<AbsenceInput>(
              context: context,
              isScrollControlled: true,
              builder: (_) => const SelfServiceAbsenceSheet(),
            );
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Abwesenheit melden'), findsOneWidget);
    expect(find.text('Starttag wählen'), findsOneWidget);
    final button = find.ancestor(
      of: find.text('Abwesenheit eintragen'),
      matching: find.byWidgetPredicate((w) => w is FilledButton),
    );
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(input, isNull);
  });
}
