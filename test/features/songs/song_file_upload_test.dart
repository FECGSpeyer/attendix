import 'package:attendix/core/utils/instrument_matcher.dart';
import 'package:attendix/data/models/song/song.dart';
import 'package:attendix/features/songs/presentation/widgets/file_drop/file_drop_target.dart';
import 'package:attendix/features/songs/presentation/widgets/file_upload_sheet.dart';
import 'package:attendix/features/songs/presentation/widgets/single_file_upload_sheet.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../factories/test_factories.dart';
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

  testWidgets('single upload: an unsure part offers "künftig so erkennen" unchecked', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleFileUploadSheet(
            songId: 5,
            file: PlatformFile(name: 'Kl 1.pdf', size: 10),
            groups: [
              TestFactories.createGroup(id: 11, name: 'Klarinette'),
              TestFactories.createGroup(id: 12, name: 'Klavier'),
            ],
            existingFiles: const [],
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(find.text('Unsicher erkannt – bitte prüfen'), findsOneWidget);
    final learn = find.text('„Kl 1“ künftig als Klarinette erkennen');
    expect(learn, findsOneWidget);
    expect(tester.widget<CheckboxListTile>(find.ancestor(of: learn, matching: find.byType(CheckboxListTile))).value, isFalse);
  });
}
