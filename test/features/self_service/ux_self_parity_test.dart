import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/data/models/song/song.dart';
import 'package:attendix/features/duty/presentation/widgets/self_service_duty_section.dart';
import 'package:attendix/features/self_service/presentation/widgets/self_service_event_actions.dart';
import 'package:attendix/features/self_service/presentation/widgets/upcoming_songs_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('hasSongNotesForPlayer', () {
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

  test('open duties tile subtitle matches expected texts', () {
    expect(openDutiesTileSubtitle(0), 'alles besetzt');
    expect(openDutiesTileSubtitle(1), '1 offen');
    expect(openDutiesTileSubtitle(4), '4 offen');
  });

  testWidgets('single registration field opens an alert', (tester) async {
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
    expect(find.text('Abbrechen'), findsNothing);
    await tester.tap(find.text('Ja'));
    await tester.tap(find.text('Anmelden'));
    await tester.pumpAndSettle();
    expect(result, {'f1': true});
  });
}
