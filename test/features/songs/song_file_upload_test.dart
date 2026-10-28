import 'package:attendix/core/utils/instrument_matcher.dart';
import 'package:attendix/data/models/song/song.dart';
import 'package:attendix/features/songs/presentation/widgets/file_drop/file_drop_target.dart';
import 'package:attendix/features/songs/presentation/widgets/file_upload_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SongFile _file(String name, {int? instrumentId, String? note}) => SongFile(
      fileName: name,
      fileType: 'application/pdf',
      url: 'https://example.com/$name',
      instrumentId: instrumentId,
      note: note,
    );

void main() {
  group('detectFileCategory (Ionic addFiles)', () {
    const instruments = [
      InstrumentInfo(id: 10, name: 'Trompete'),
      InstrumentInfo(id: 11, name: 'Posaune'),
    ];

    test('matches a group by file name', () {
      final cat = detectFileCategory('Werk_Trompete.pdf', instruments: instruments, isChoir: false);
      expect(cat.instrumentId, 10);
    });

    test('detects recordings as "Aufnahme" (1)', () {
      final cat = detectFileCategory('probe.mp3', instruments: instruments, isChoir: false);
      expect(cat.instrumentId, 1);
    });

    test('detects scores as free text "Partitur"', () {
      final cat = detectFileCategory('Partitur.pdf', instruments: const [], isChoir: false);
      expect(cat.instrumentId, isNull);
      expect(cat.note, 'Partitur');
    });

    test('falls back to "Chor" for PDFs in a choir', () {
      final cat = detectFileCategory('Lied.pdf', instruments: const [], isChoir: true);
      expect(cat.instrumentId, isNull);
      expect(cat.note, 'Chor');
    });
  });

  group('conflicts and replace selection', () {
    final existing = [
      _file('a.pdf', instrumentId: 10),
      _file('b.pdf', instrumentId: 10),
      _file('c.pdf', note: 'Partitur'),
    ];

    test('findConflictingFiles by group and by free text', () {
      expect(findConflictingFiles(existing, 10, null).length, 2);
      expect(findConflictingFiles(existing, null, 'Partitur').single.fileName, 'c.pdf');
      expect(findConflictingFiles(existing, 11, null), isEmpty);
    });

    test('preselects the same-named file, otherwise all conflicts', () {
      final conflicts = findConflictingFiles(existing, 10, null);
      expect(defaultReplaceSelection(conflicts, 'b.pdf'), {'https://example.com/b.pdf'});
      expect(defaultReplaceSelection(conflicts, 'new.pdf').length, 2);
    });
  });

  testWidgets('FileDropZone shows the Ionic hint and opens the picker on tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FileDropZone(onTap: () => taps++, onFiles: (_) {}),
      ),
    ));
    expect(find.text('Dateien hierher ziehen oder tippen zum Auswählen'), findsOneWidget);
    await tester.tap(find.byType(FileDropZone));
    expect(taps, 1);
  });
}
