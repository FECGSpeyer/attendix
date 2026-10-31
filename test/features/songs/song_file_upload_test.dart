import 'dart:async';

import 'package:attendix/core/services/part_vision_service.dart';
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

/// Page-1 reading that answers only when the test says so.
class _LateVision extends PartVisionService {
  _LateVision() : super(() => throw UnimplementedError(), () => 1);

  final answer = Completer<PartMatch?>();
  final asked = <String>[];

  @override
  Future<PartMatch?> detect(PlatformFile file, List<InstrumentInfo> instruments, {Duration? limit, bool Function()? cancelled, int? tenantId}) {
    asked.add(file.name);
    return answer.future;
  }
}

Widget _host(Widget sheet, {PartVisionService? vision}) => ProviderScope(
      overrides: [partVisionServiceProvider.overrideWithValue(vision ?? _LateVision())],
      child: MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: sheet),
      ),
    );

const _flute = PartMatch(instrumentId: 12, confidence: MatchConfidence.sure, term: 'Flute', byVision: true);

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
    await tester.pumpWidget(_host(SingleFileUploadSheet(
      songId: 5,
      file: PlatformFile(name: 'Kl 1.pdf', size: 10),
      groups: [
        TestFactories.createGroup(id: 11, name: 'Klarinette'),
        TestFactories.createGroup(id: 12, name: 'Klavier'),
      ],
      existingFiles: const [],
    ), vision: _LateVision()..answer.complete(null)));
    await tester.pump();
    expect(find.text('Unsicher erkannt – bitte prüfen'), findsOneWidget);
    final learn = find.text('„Kl 1“ künftig als Klarinette erkennen');
    expect(learn, findsOneWidget);
    expect(tester.widget<CheckboxListTile>(find.ancestor(of: learn, matching: find.byType(CheckboxListTile))).value, isFalse);
  });

  group('a late page-1 result keeps what was set by hand', () {
    final groups = [
      TestFactories.createGroup(id: 11, name: 'Klarinette'),
      TestFactories.createGroup(id: 12, name: 'Flöte'),
    ];

    testWidgets('upload sheet: typed free text', (tester) async {
      final vision = _LateVision();
      await tester.pumpWidget(_host(
        FileUploadSheet(songId: 5, groups: groups, initialFiles: [PlatformFile(name: 'Scan_0815.pdf', size: 10)]),
        vision: vision,
      ));
      await tester.pump();
      expect(find.text('Erste Seite wird gelesen …'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Partitur');
      await tester.pump();
      vision.answer.complete(_flute);
      await tester.pump();
      expect(find.text('Auf Seite 1 erkannt: Flute'), findsNothing);
      expect(find.widgetWithText(TextField, 'Partitur'), findsOneWidget);
    });

    testWidgets('upload sheet: an unticked file to replace', (tester) async {
      final vision = _LateVision();
      await tester.pumpWidget(_host(
        FileUploadSheet(
          songId: 5,
          groups: groups,
          existingFiles: [_file('a.pdf', instrumentId: 11), _file('b.pdf', instrumentId: 11)],
          initialFiles: [PlatformFile(name: 'Kl 1.pdf', size: 10)],
        ),
        vision: vision,
      ));
      await tester.pump();
      final a = find.ancestor(of: find.text('a.pdf'), matching: find.byType(CheckboxListTile));
      expect(tester.widget<CheckboxListTile>(a).value, isTrue);
      await tester.tap(a);
      await tester.pump();
      vision.answer.complete(const PartMatch(instrumentId: 11, confidence: MatchConfidence.sure, byVision: true));
      await tester.pump();
      expect(tester.widget<CheckboxListTile>(a).value, isFalse);
    });

    testWidgets('single upload: typed free text', (tester) async {
      final vision = _LateVision();
      await tester.pumpWidget(_host(
        SingleFileUploadSheet(songId: 5, file: PlatformFile(name: 'Scan_0815.pdf', size: 10), groups: groups, existingFiles: const []),
        vision: vision,
      ));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Partitur');
      await tester.pump();
      vision.answer.complete(_flute);
      await tester.pump();
      expect(find.text('Auf Seite 1 erkannt: Flute'), findsNothing);
      expect(find.widgetWithText(TextField, 'Partitur'), findsOneWidget);
    });

    testWidgets('single upload: an unticked file to replace', (tester) async {
      final vision = _LateVision();
      await tester.pumpWidget(_host(
        SingleFileUploadSheet(
          songId: 5,
          file: PlatformFile(name: 'Kl 1.pdf', size: 10),
          groups: groups,
          existingFiles: [_file('a.pdf', instrumentId: 11), _file('b.pdf', instrumentId: 11)],
        ),
        vision: vision,
      ));
      await tester.pump();
      final a = find.ancestor(of: find.text('a.pdf'), matching: find.byType(CheckboxListTile));
      expect(tester.widget<CheckboxListTile>(a).value, isTrue);
      await tester.ensureVisible(a);
      await tester.pump();
      await tester.tap(a);
      await tester.pump();
      expect(tester.widget<CheckboxListTile>(a).value, isFalse);
      vision.answer.complete(const PartMatch(instrumentId: 11, confidence: MatchConfidence.sure, byVision: true));
      await tester.pump();
      expect(tester.widget<CheckboxListTile>(a).value, isFalse);
    });

    for (final single in [false, true]) {
      testWidgets('${single ? 'single upload' : 'upload sheet'}: a confirmed "künftig so erkennen"', (tester) async {
        final vision = _LateVision();
        final file = PlatformFile(name: 'Kl 1.pdf', size: 10);
        await tester.pumpWidget(_host(
          single
              ? SingleFileUploadSheet(songId: 5, file: file, groups: groups, existingFiles: const [])
              : FileUploadSheet(songId: 5, groups: groups, initialFiles: [file]),
          vision: vision,
        ));
        await tester.pump();
        final learn = find.ancestor(of: find.text('„Kl 1“ künftig als Klarinette erkennen'), matching: find.byType(CheckboxListTile));
        await tester.ensureVisible(learn);
        await tester.tap(learn);
        await tester.pump();
        vision.answer.complete(_flute);
        await tester.pump();
        expect(find.text('Auf Seite 1 erkannt: Flute'), findsNothing);
        expect(tester.widget<CheckboxListTile>(learn).value, isTrue);
      });
    }

    testWidgets('upload sheet: a queued file changed by hand is not read any more', (tester) async {
      final vision = _LateVision();
      await tester.pumpWidget(_host(
        FileUploadSheet(songId: 5, groups: groups, initialFiles: [
          PlatformFile(name: 'Scan_0815.pdf', size: 10),
          PlatformFile(name: 'Scan_0816.pdf', size: 10),
        ]),
        vision: vision,
      ));
      await tester.pump();
      expect(vision.asked, ['Scan_0815.pdf']);
      await tester.enterText(find.byType(TextField).last, 'Partitur');
      await tester.pump();
      vision.answer.complete(null);
      await tester.pump();
      expect(vision.asked, ['Scan_0815.pdf']);
      expect(find.text('Erste Seite wird gelesen …'), findsNothing);
    });
  });
}
