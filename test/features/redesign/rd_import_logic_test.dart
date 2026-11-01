import 'package:attendix/core/utils/instrument_matcher.dart';
import 'package:attendix/data/models/song/song.dart';
import 'package:attendix/features/redesign/data/import/rd_import_logic.dart';
import 'package:flutter_test/flutter_test.dart';

const _instruments = [
  InstrumentInfo(id: 10, name: 'Violine 1'),
  InstrumentInfo(id: 11, name: 'Violine 2'),
  InstrumentInfo(id: 12, name: 'Viola'),
  InstrumentInfo(id: 13, name: 'Violoncello'),
  InstrumentInfo(id: 14, name: 'Flöte 1'),
  InstrumentInfo(id: 15, name: 'Flöte 2'),
  InstrumentInfo(id: 16, name: 'Trompete'),
];

RdImportEntry _e(String path, {int size = 1000, DateTime? modified}) => RdImportEntry(path: path, size: size, modified: modified);

RdImportPlan _plan(
  List<RdImportEntry> entries, {
  List<RdImportSong> songs = const [],
  Map<String, String> hashes = const {},
  Map<String, DateTime> dates = const {},
}) =>
    rdBuildImportPlan(entries, songs: songs, instruments: _instruments, isChoir: false, hashes: hashes, dates: dates);

void main() {
  group('names', () {
    test('Cyrillic and Latin spellings of a title are the same words', () {
      expect(rdImportTitleWords('Мой Господь'), rdImportTitleWords("Moj Gospod'"));
      expect(rdImportTitleWords('Мой Господь'), rdImportTitleWords('Moy Gospod'));
      expect(rdImportTitleWords('Du großer Gott'), rdImportTitleWords('Du grosser Gott'));
      // Decomposed umlaut as written by macOS / Drive.
      expect(rdImportTitleWords('Herrlich verklärt'), rdImportTitleWords('Herrlich verklärt'));
    });

    test('number, prefix and title of a Werk folder', () {
      expect(rdParseWorkName('120 Wie wunderbar'), (prefix: null, number: 120, title: 'Wie wunderbar'));
      expect(rdParseWorkName('07_Мой Господь'), (prefix: null, number: 7, title: 'Мой Господь'));
      expect(rdParseWorkName('HZ 1 Die wahre Liebe'), (prefix: 'HZ', number: 1, title: 'Die wahre Liebe'));
      expect(rdParseWorkName('SOS-Spieler PDF').number, isNull);
      expect(rdParseWorkName('42').number, 42);
    });
  });

  group('Werk in Attendix', () {
    const songs = [
      RdImportSong(id: 1, number: 7, name: "Moj Gospod'"),
      RdImportSong(id: 2, number: 66, name: 'Du großer Gott'),
      RdImportSong(id: 3, number: 120, name: 'Wie wunderbar'),
      RdImportSong(id: 4, number: 113, name: 'Glaubend'),
    ];

    test('number and title fit: sure', () {
      final m = rdMatchWork('120 Wie wunderbar', songs);
      expect(m.kind, RdMatchKind.sure);
      expect(m.songId, 3);
      expect(rdMatchWork('07 Мой Господь', songs).songId, 1);
    });

    test('title fits with another number: unsure', () {
      final m = rdMatchWork('80 Du Großer Gott Nikita', songs);
      expect(m.kind, RdMatchKind.titleOnly);
      expect(m.songId, 2);
    });

    test('number fits, title not: unsure', () {
      final m = rdMatchWork('113 Вот, иду', songs);
      expect(m.kind, RdMatchKind.numberOnly);
      expect(m.songId, 4);
    });

    test('nothing fits: new Werk', () {
      expect(rdMatchWork('157 Jesus ruft dich', songs).kind, RdMatchKind.none);
    });
  });

  group('Werk folders', () {
    test('numbered folders below a shared root and a source folder', () {
      final folders = rdFindWorkFolders([
        _e('Noten (Speyer)/SOS-Spieler PDF/120 Wie wunderbar/Violine 1.pdf'),
        _e('Noten (Speyer)/SOS-Spieler PDF/120 Wie wunderbar/Stimmen/Viola.pdf'),
        _e('Noten (Speyer)/Dirigenten/120 Wie wunderbar/Partitur.pdf'),
        _e('Noten (Speyer)/Dirigenten/26 Via dolorosa/Alt/Viola.pdf'),
      ], songs: const [], instruments: _instruments);
      expect(folders['Noten (Speyer)/SOS-Spieler PDF/120 Wie wunderbar/Stimmen/Viola.pdf'], 'Noten (Speyer)/SOS-Spieler PDF/120 Wie wunderbar');
      expect(folders['Noten (Speyer)/Dirigenten/120 Wie wunderbar/Partitur.pdf'], 'Noten (Speyer)/Dirigenten/120 Wie wunderbar');
      expect(folders['Noten (Speyer)/Dirigenten/26 Via dolorosa/Alt/Viola.pdf'], 'Noten (Speyer)/Dirigenten/26 Via dolorosa');
    });

    test('without numbers: a category folder holds Werke, part folders do not', () {
      final folders = rdFindWorkFolders([
        _e('Weihnachten/Stille Nacht/Violine 1.pdf'),
        _e('Weihnachten/O du fröhliche/Violine 1.pdf'),
        _e('Weihnachten/Engel singen/Streicher/Viola.pdf'),
        _e('Weihnachten/Engel singen/Bläser/Trompete.pdf'),
      ], songs: const [], instruments: _instruments);
      expect(folders['Weihnachten/Stille Nacht/Violine 1.pdf'], 'Weihnachten/Stille Nacht');
      expect(folders['Weihnachten/Engel singen/Bläser/Trompete.pdf'], 'Weihnachten/Engel singen');
    });

    test('a ZIP of one new Werk with part folders', () {
      final folders = rdFindWorkFolders([
        _e('Jesus ruft dich/Violine 1/Seite 1.pdf'),
        _e('Jesus ruft dich/Viola/Seite 1.pdf'),
      ], songs: const [], instruments: _instruments);
      expect(folders['Jesus ruft dich/Viola/Seite 1.pdf'], 'Jesus ruft dich');
    });
  });

  group('plan', () {
    const songs = [
      RdImportSong(
        id: 3,
        number: 120,
        name: 'Wie wunderbar',
        files: [SongFile(fileName: 'Violine 1 alt.pdf', fileType: 'application/pdf', url: 'u', instrumentId: 10)],
      ),
    ];

    test('folders of the same Werk from two sources are one Werk; duplicates are left out', () {
      final plan = _plan([
        _e('Noten/SOS/120 Wie wunderbar/Viola.pdf', size: 5),
        _e('Noten/Dirigenten/120 Wie wunderbar/Viola.pdf', size: 5),
        _e('Noten/Dirigenten/120 Wie wunderbar/Partitur.pdf', size: 9),
      ], songs: songs, hashes: {
        'Noten/SOS/120 Wie wunderbar/Viola.pdf': 'a',
        'Noten/Dirigenten/120 Wie wunderbar/Viola.pdf': 'a',
      });
      expect(plan.works, hasLength(1));
      final work = plan.works.single;
      expect(work.match.songId, 3);
      expect(work.fassungen, isEmpty);
      final reasons = {for (final f in work.files) f.path: f.hardSkip};
      expect(reasons.values.where((r) => r == RdSkipReason.duplicate), hasLength(1));
    });

    test('a part already in Attendix is left out, a new one is taken', () {
      final plan = _plan([
        _e('Noten/120 Wie wunderbar/Violine 1.pdf'),
        _e('Noten/120 Wie wunderbar/Viola.pdf'),
        _e('Noten/7 Anderes/Viola.pdf'),
      ], songs: songs);
      final work = plan.work('song:3')!;
      final state = rdWorkState(plan, const RdImportDecisions(), work);
      expect(state.files['Noten/120 Wie wunderbar/Violine 1.pdf']!.reason, RdSkipReason.partExists);
      expect(state.files['Noten/120 Wie wunderbar/Viola.pdf']!.take, isTrue);
      expect(state.flags, contains(RdWorkFlag.partExists));
      // Not uploaded before someone looked at it.
      expect(state.open, isTrue);
      expect(rdImportUploads(plan, const RdImportDecisions()).map((u) => u.file.name), ['Viola.pdf']);
      final confirmed = RdImportDecisions(confirmed: {work.key});
      expect(rdImportUploads(plan, confirmed).map((u) => u.file.path), [
        'Noten/7 Anderes/Viola.pdf',
        'Noten/120 Wie wunderbar/Viola.pdf',
      ]);
    });

    test('Fassungen: the newest by the date inside the files, never an "Alt" folder', () {
      // The ZIP dates (upload to Drive) say the main folder is newest; the
      // dates inside the PDFs say Fassung B.
      final plan = _plan([
        _e('Noten/26 Via dolorosa/Viola.pdf', modified: DateTime(2025)),
        _e('Noten/26 Via dolorosa/Violine 1.pdf', modified: DateTime(2025)),
        _e('Noten/26 Via dolorosa/Fassung B/Viola.pdf', modified: DateTime(2018)),
        _e('Noten/26 Via dolorosa/Alt/Viola.pdf', modified: DateTime(2026)),
      ], dates: {
        'Noten/26 Via dolorosa/Viola.pdf': DateTime(2019),
        'Noten/26 Via dolorosa/Violine 1.pdf': DateTime(2019),
        'Noten/26 Via dolorosa/Fassung B/Viola.pdf': DateTime(2024, 3, 12),
        'Noten/26 Via dolorosa/Alt/Viola.pdf': DateTime(2015),
      });
      final work = plan.works.single;
      expect(work.fassungen.map((f) => f.label), ['Fassung B', '', 'Alt']);
      expect(work.defaultFassung, 'Fassung B');
      final state = rdWorkState(plan, const RdImportDecisions(), work);
      expect(state.flags, contains(RdWorkFlag.fassungen));
      expect(state.files['Noten/26 Via dolorosa/Viola.pdf']!.reason, RdSkipReason.otherFassung);
      expect(state.files['Noten/26 Via dolorosa/Alt/Viola.pdf']!.reason, RdSkipReason.otherFassung);
      expect(state.files['Noten/26 Via dolorosa/Fassung B/Viola.pdf']!.take, isTrue);

      // Chosen by hand: the main folder.
      final d = RdImportDecisions(fassungen: {work.key: ''}, confirmed: {work.key});
      final uploads = rdImportUploads(plan, d).map((u) => u.file.path).toList();
      expect(uploads, ['Noten/26 Via dolorosa/Viola.pdf', 'Noten/26 Via dolorosa/Violine 1.pdf']);
    });

    test('Fassungen without dates inside the files: the ZIP dates decide', () {
      final plan = _plan([
        _e('Noten/26 Via dolorosa/Viola.pdf', modified: DateTime(2020)),
        _e('Noten/26 Via dolorosa/Fassung B/Viola.pdf', modified: DateTime(2023)),
      ], dates: {
        'Noten/26 Via dolorosa/Viola.pdf': DateTime(2024),
      });
      expect(plan.works.single.defaultFassung, 'Fassung B');
    });

    test('lyrics of another Fassung are kept while the chosen one has none', () {
      final plan = _plan([
        _e('Noten/26 Via dolorosa/Viola.pdf', modified: DateTime(2020)),
        _e('Noten/26 Via dolorosa/Liedtext.pdf', modified: DateTime(2020)),
        _e('Noten/26 Via dolorosa/Fassung B/Viola.pdf', modified: DateTime(2023)),
      ]);
      final work = plan.works.single;
      final state = rdWorkState(plan, const RdImportDecisions(), work);
      expect(state.files['Noten/26 Via dolorosa/Liedtext.pdf']!.take, isTrue);
      expect(state.files['Noten/26 Via dolorosa/Viola.pdf']!.reason, RdSkipReason.otherFassung);
    });

    test('Word next to a PDF of the same name is left out (switch)', () {
      final plan = _plan([
        _e('Noten/5 Lied/Liedtext.pdf'),
        _e('Noten/5 Lied/Liedtext.docx'),
      ]);
      final work = plan.works.single;
      final on = rdWorkState(plan, const RdImportDecisions(), work);
      expect(on.files['Noten/5 Lied/Liedtext.docx']!.reason, RdSkipReason.wordNextToPdf);
      final off = rdWorkState(plan, const RdImportDecisions(skipWordBesidePdf: false), work);
      expect(off.files['Noten/5 Lied/Liedtext.docx']!.take, isTrue);
    });

    test('unknown part names become one question; the answer fits part numbers', () {
      final plan = _plan([
        _e('Noten/1 Eins/Qfl1.pdf'),
        _e('Noten/1 Eins/Qfl2.pdf'),
        _e('Noten/2 Zwei/Qfl1.pdf'),
        _e('Noten/2 Zwei/Bratschen-Solo xy.pdf'),
        _e('Noten/2 Zwei/Archiv.zip'),
      ]);
      expect(plan.questions.map((q) => q.key), ['qfl']);
      expect(plan.questions.single.fileCount, 3);
      final eins = plan.works.firstWhere((w) => w.title == 'Eins');
      final before = rdWorkState(plan, const RdImportDecisions(), eins);
      expect(before.flags, contains(RdWorkFlag.unclear));

      final d = RdImportDecisions(answers: {'qfl': const RdImportCategory(instrumentId: 14)});
      final after = rdWorkState(plan, d, eins);
      expect(after.files['Noten/1 Eins/Qfl1.pdf']!.category.instrumentId, 14);
      expect(after.files['Noten/1 Eins/Qfl2.pdf']!.category.instrumentId, 15);
      expect(after.flags, isEmpty);

      final zwei = plan.works.firstWhere((w) => w.title == 'Zwei');
      final zip = rdWorkState(plan, d, zwei).files['Noten/2 Zwei/Archiv.zip']!;
      expect(zip.reason, RdSkipReason.unsupported);
      expect(zip.canToggle, isFalse);

      // Learned per group with the file's own term.
      final items = rdImportUploads(plan, d.copyWith(confirmed: {zwei.key}));
      final terms = rdImportLearnedTerms(plan, d, items, instruments: _instruments);
      expect(terms[14], ['Qfl1']);
      expect(terms[15], ['Qfl2']);
    });

    test('new Werke keep their number when it is free; new groups are created once', () {
      final plan = _plan([
        _e('Noten/157 Jesus ruft dich/Saxophon 1.pdf'),
        _e('Noten/157 Jesus ruft dich/Saxophon 2.pdf'),
        _e('Noten/120 Anderes Werk/Violine 1.pdf'),
      ], songs: songs);
      final jesus = plan.works.firstWhere((w) => w.title == 'Jesus ruft dich');
      final target = rdDefaultTarget(plan, jesus);
      expect(target.isNew, isTrue);
      expect(target.number, 157);
      final d = RdImportDecisions(answers: {'saxophon': const RdImportCategory(newGroup: 'Saxophon')});
      final items = rdImportUploads(plan, d);
      expect(rdImportNewGroups(items), ['Saxophon']);
      final summary = rdImportSummary(plan, d);
      expect(summary.newWorks, 1);
      expect(summary.open, 1); // 120: number fits, title not
      expect(summary.openQuestions, 0);
    });
  });

  group('dates', () {
    test('creation date in the PDF info, else XMP', () {
      expect(rdPdfDate('%PDF-1.4 /CreationDate (D:20240312101500+01\'00\')'.codeUnits), DateTime(2024, 3, 12, 10, 15));
      expect(rdPdfDate('<xmp:CreateDate>2019-05-01T08:00:00Z</xmp:CreateDate>'.codeUnits), DateTime(2019, 5, 1, 8));
      expect(rdPdfDate('%PDF-1.4 nothing'.codeUnits), isNull);
    });

    test('MS-DOS date of a ZIP entry', () {
      // 2023-10-31 17:30:20
      final date = ((2023 - 1980) << 9) | (10 << 5) | 31;
      final time = (17 << 11) | (30 << 5) | 10;
      expect(rdZipDate(date << 16 | time), DateTime(2023, 10, 31, 17, 30, 20));
    });
  });

  test('system files are left out on reading', () {
    expect(rdImportIsJunk('__MACOSX/Noten/._Violine.pdf'), isTrue);
    expect(rdImportIsJunk('Noten/.DS_Store'), isTrue);
    expect(rdImportIsJunk('Noten/~\$Liedtext.docx'), isTrue);
    expect(rdImportIsJunk('Noten/Violine.pdf'), isFalse);
  });

  test('instrument families stay with the matcher', () {
    expect(InstrumentMatcher.tokenize('Flöte 2'), ['floete', '2']);
  });
}
