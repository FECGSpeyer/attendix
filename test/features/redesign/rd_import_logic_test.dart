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

    test('typos and other spellings count by their letters', () {
      const more = [...songs, RdImportSong(id: 5, number: 30, name: 'Hallelujah')];
      final m = rdMatchWork('12 Halleluja', more);
      expect(m.kind, RdMatchKind.titleOnly);
      expect(m.songId, 5);
      // Same number, only the letters fit: to check, and the very title
      // under another number comes first.
      const blessing = [
        RdImportSong(id: 6, number: 12, name: 'Morgensegen'),
        RdImportSong(id: 7, number: 40, name: 'Abendsegen'),
      ];
      expect(rdMatchWork('12 Morgensegn', blessing).kind, RdMatchKind.numberOnly);
      expect(rdMatchWork('12 Abendsegen', blessing).songId, 7);
      expect(rdMatchWork('12 Abendsegen', blessing).kind, RdMatchKind.titleOnly);
    });

    test('the Werk the KI names for an unsure folder is to be checked', () {
      final entries = [_e('Noten/157 Jesus ruft dich/Viola.pdf'), _e('Noten/120 Wie wunderbar/Viola.pdf')];
      expect(rdImportWorksToAsk(_plan(entries, songs: songs)), ['157 Jesus ruft dich']);
      final plan = rdBuildImportPlan(entries,
          songs: songs, instruments: _instruments, isChoir: false, aiWorks: {'157 Jesus ruft dich': 2, '120 Wie wunderbar': 1});
      final byAi = plan.works.firstWhere((w) => w.folderName == '157 Jesus ruft dich');
      expect(byAi.match.kind, RdMatchKind.byAi);
      expect(byAi.match.songId, 2);
      expect(rdWorkState(plan, const RdImportDecisions(), byAi).flags, contains(RdWorkFlag.unsureMatch));
      // A sure match stays.
      expect(plan.works.firstWhere((w) => w.folderName == '120 Wie wunderbar').match.songId, 3);
      // Without the hint the key changes back; decisions follow the folder.
      final before = _plan(entries, songs: songs);
      final moved = rdImportMovedWorks(plan, before);
      expect(moved, {byAi.key: before.works.firstWhere((w) => w.folderName == '157 Jesus ruft dich').key});
    });

    test('several Werke fit as well: to check, not the first one', () {
      const twice = [
        RdImportSong(id: 1, number: 1, prefix: 'A', name: 'Stille Nacht'),
        RdImportSong(id: 2, number: 1, prefix: 'B', name: 'Stille Nacht'),
        RdImportSong(id: 3, number: 5, name: 'Großer Gott'),
        RdImportSong(id: 4, number: 9, name: 'Großer Gott'),
      ];
      expect(rdMatchWork('1 Stille Nacht', twice).kind, RdMatchKind.ambiguous);
      expect(rdMatchWork('1', twice).kind, RdMatchKind.ambiguous);
      expect(rdMatchWork('Großer Gott', twice).kind, RdMatchKind.ambiguous);
      // The prefix decides.
      expect(rdMatchWork('B1 Stille Nacht', twice).kind, RdMatchKind.sure);
      expect(rdMatchWork('B1 Stille Nacht', twice).songId, 2);
      expect(rdMatchWork('5 Großer Gott', twice).kind, RdMatchKind.sure);
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

    test('a known instrument without a group becomes a new group, whatever stands before it', () {
      final plan = _plan([
        _e('Noten/1 Erstes/SoS - Erstes bearbeitet - Oboe.pdf'),
        _e('Noten/2 Zweites/Oboe.pdf'),
        _e('Noten/3 Drittes/Alto Saxophone 1.pdf'),
      ]);
      expect({for (final q in plan.questions) q.key: q.newGroup}, {'oboe': 'Oboe', 'alto saxophone': 'Altsaxophon'});
      const d = RdImportDecisions();
      final file = rdWorkState(plan, d, plan.works.firstWhere((w) => w.title == 'Erstes')).files.values.single;
      expect(file.category, const RdImportCategory(newGroup: 'Oboe'));
      expect(file.unclear, isFalse);
      expect(rdImportPendingGroups(plan, d), ['Altsaxophon', 'Oboe']);
      // A choir: a voice without a group comes before "Chor" for any sheet.
      final choir = rdBuildImportPlan([_e('Noten/1 Erstes/Tenor.pdf'), _e('Noten/1 Erstes/Alle.pdf')],
          songs: const [], instruments: const [], isChoir: true);
      expect({for (final f in choir.works.single.files) f.name: f.guessed}, {
        'Alle.pdf': const RdImportCategory(note: 'Chor'),
        'Tenor.pdf': const RdImportCategory(newGroup: 'Tenor'),
      });
      // Answered with a group: Oboe is no new group any more.
      expect(rdImportPendingGroups(plan, const RdImportDecisions(answers: {'oboe': RdImportCategory(instrumentId: 16)})), ['Altsaxophon']);
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

    test('"Alt" next to Sopran, Tenor and Bass is the voice, not an old Fassung', () {
      final plan = _plan([
        for (final v in ['Sopran', 'Alt', 'Tenor', 'Bass']) _e('Noten/1 Stille Nacht/$v/Stille Nacht $v.pdf'),
      ]);
      final work = plan.works.single;
      expect(work.fassungen, isEmpty);
      final state = rdWorkState(plan, const RdImportDecisions(), work);
      expect(state.flags, isNot(contains(RdWorkFlag.fassungen)));
      expect(state.files.values.where((f) => f.take), hasLength(4));

      // A lone "Alt" folder still holds an old version, also in a choir.
      final choir = rdBuildImportPlan(
        [_e('Noten/1 Stille Nacht/Chor.pdf', modified: DateTime(2020)), _e('Noten/1 Stille Nacht/Alt/Chor.pdf', modified: DateTime(2026))],
        songs: const [],
        instruments: const [InstrumentInfo(id: 20, name: 'Sopran'), InstrumentInfo(id: 21, name: 'Alt')],
        isChoir: true,
      );
      expect(choir.works.single.fassungen.map((f) => (f.label, f.isOld)), [('', false), ('Alt', true)]);
      expect(choir.works.single.defaultFassung, '');

      final orchestra = _plan([
        _e('Noten/1 Stille Nacht/Viola.pdf'),
        _e('Noten/1 Stille Nacht/Alt/Viola.pdf'),
      ]);
      expect(orchestra.works.single.fassungen.map((f) => (f.label, f.isOld)), [('', false), ('Alt', true)]);

      // Voices count only next to "Alt", not deeper inside another folder.
      final nested = _plan([
        _e('Noten/1 Stille Nacht/Chor/Sopran/Sopran.pdf', modified: DateTime(2026)),
        _e('Noten/1 Stille Nacht/Alt/Chor/Sopran/Sopran.pdf', modified: DateTime(2020)),
      ]);
      expect(nested.works.single.fassungen.map((f) => (f.label, f.isOld)), [('Chor/Sopran', false), ('Alt/Chor/Sopran', true)]);
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

    test('an unsure folder is a Werk of its own, also next to a sure one', () {
      const songs = [RdImportSong(id: 3, number: 120, name: 'Wie wunderbar')];
      final plan = _plan([
        _e('Noten/120 Wie wunderbar/Viola.pdf'),
        _e('Noten/120 Anderes Lied/Violine 1.pdf'),
      ], songs: songs);
      expect(plan.works, hasLength(2));
      final sure = plan.work('song:3')!;
      expect(sure.match.kind, RdMatchKind.sure);
      final other = plan.works.firstWhere((w) => w != sure);
      expect(other.match.kind, RdMatchKind.numberOnly);
      expect(other.title, 'Anderes Lied');
      final state = rdWorkState(plan, const RdImportDecisions(), other);
      expect(state.flags, contains(RdWorkFlag.unsureMatch));
      expect(state.open, isTrue);
      // Not uploaded before it is checked.
      expect(rdImportUploads(plan, const RdImportDecisions()).map((i) => i.file.name), ['Viola.pdf']);
    });

    test('folders that only share a part after an answer are Fassungen too', () {
      final entries = [
        _e('Noten/1 Eins/Qfl1.pdf', size: 10),
        _e('Noten/1 Eins/Fassung B/Qfl1.pdf', size: 11),
      ];
      final before = _plan(entries);
      expect(before.works.single.fassungen, isEmpty);
      expect(before.questions.map((q) => q.key), ['qfl']);
      final after = rdBuildImportPlan(entries,
          songs: const [], instruments: _instruments, isChoir: false, answers: {'qfl': const RdImportCategory(instrumentId: 14)});
      expect(after.works.single.fassungen.map((f) => f.key), unorderedEquals(['', 'Fassung B']));
      final state = rdWorkState(after, RdImportDecisions(answers: {'qfl': const RdImportCategory(instrumentId: 14)}), after.works.single);
      expect(state.flags, contains(RdWorkFlag.fassungen));
    });

    test('files that are never uploaded are never read for duplicates', () {
      const big = 30 * 1024 * 1024;
      final paths = rdImportPathsToHash([
        _e('Noten/1/a.mp4', size: big),
        _e('Noten/1/b.mp4', size: big),
        _e('Noten/1/c.exe', size: 5),
        _e('Noten/1/d.exe', size: 5),
        _e('Noten/1/x.pdf', size: 5),
        _e('Noten/2/x.pdf', size: 5),
      ]);
      expect(paths, {'Noten/1/x.pdf', 'Noten/2/x.pdf'});
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

    test('into a Sammlung: new Werke get its Kürzel, numbers of the whole group count', () {
      final entries = [_e('Noten/157 Jesus ruft dich/Viola.pdf'), _e('Noten/12 Neu/Viola.pdf')];
      final plan = rdBuildImportPlan(entries,
          songs: const [],
          instruments: _instruments,
          isChoir: false,
          newPrefix: 'S',
          takenNumbers: {rdImportNumberKey('s', 12)});
      RdWorkTarget target(String title) => rdDefaultTarget(plan, plan.works.firstWhere((w) => w.title == title));
      expect((target('Jesus ruft dich').prefix, target('Jesus ruft dich').number), ('S', 157));
      expect((target('Neu').prefix, target('Neu').number), ('S', null));
    });
  });

  group('a part for several groups ("Posaune und Tuba")', () {
    const brass = [InstrumentInfo(id: 20, name: 'Posaune'), InstrumentInfo(id: 21, name: 'Tuba')];
    RdImportPlan plan(List<InstrumentInfo> instruments, {List<RdImportSong> songs = const []}) => rdBuildImportPlan(
          [_e('Noten/120 Wie wunderbar/Posaune und Tuba.pdf')],
          songs: songs,
          instruments: instruments,
          isChoir: false,
        );

    test('goes to each group, without a question when both exist', () {
      final p = plan(brass);
      final s = rdWorkState(p, const RdImportDecisions(), p.works.single).files.values.single;
      expect(s.category, const RdImportCategory.several([RdImportCategory(instrumentId: 20), RdImportCategory(instrumentId: 21)]));
      expect(s.unclear, isFalse);
      expect(p.questions, isEmpty);
      final items = rdImportUploads(p, RdImportDecisions(confirmed: {p.works.single.key}));
      expect(items.single.stores, [const RdImportCategory(instrumentId: 20), const RdImportCategory(instrumentId: 21)]);
      // "Nur Posaune" by hand is not learned as a term of Posaune.
      final onlyPosaune = RdImportDecisions(
        categories: {p.works.single.files.single.path: const RdImportCategory(instrumentId: 20)},
        confirmed: {p.works.single.key},
      );
      expect(rdImportLearnedTerms(p, onlyPosaune, rdImportUploads(p, onlyPosaune), instruments: brass), isEmpty);
    });

    test('a missing group is proposed as new and asked about; a combined group stays one', () {
      final p = plan([brass.first]);
      expect(p.questions.single.proposed,
          const RdImportCategory.several([RdImportCategory(instrumentId: 20), RdImportCategory(newGroup: 'Tuba')]));
      final items = rdImportUploads(p, RdImportDecisions(confirmed: {p.works.single.key}));
      expect(rdImportNewGroups(items), ['Tuba']);

      final combined = plan(const [InstrumentInfo(id: 23, name: 'Posaune/Tuba')]);
      expect(rdWorkState(combined, const RdImportDecisions(), combined.works.single).files.values.single.category,
          const RdImportCategory(instrumentId: 23));
    });

    test('the Werk in Attendix gets only the part it lacks; left out when it has both', () {
      SongFile file(int id) => SongFile(fileName: 'p$id.pdf', fileType: 'application/pdf', url: 'u', instrumentId: id);
      final half = plan(brass, songs: [RdImportSong(id: 1, number: 120, name: 'Wie wunderbar', files: [file(20)])]);
      final d = RdImportDecisions(confirmed: {half.works.single.key});
      expect(rdImportUploads(half, d).single.stores, [const RdImportCategory(instrumentId: 21)]);

      final full = plan(brass, songs: [RdImportSong(id: 1, number: 120, name: 'Wie wunderbar', files: [file(20), file(21)])]);
      expect(rdWorkState(full, const RdImportDecisions(), full.works.single).files.values.single.reason, RdSkipReason.partExists);
    });

    test('same name at one group only, part numbers, Fassungen and choir voices', () {
      // The file is at Posaune by name already: Tuba still gets it.
      final named = plan(brass, songs: [
        RdImportSong(id: 1, number: 120, name: 'Wie wunderbar', files: [
          SongFile(fileName: 'Posaune und Tuba.pdf', fileType: 'application/pdf', url: 'u', instrumentId: 20),
        ]),
      ]);
      expect(rdImportUploads(named, RdImportDecisions(confirmed: {named.works.single.key})).single.stores,
          [const RdImportCategory(instrumentId: 21)]);

      const numbered = [InstrumentInfo(id: 20, name: 'Posaune 1'), InstrumentInfo(id: 22, name: 'Posaune 2'), InstrumentInfo(id: 21, name: 'Tuba')];
      RdFileState only(String name, List<InstrumentInfo> instruments, {bool isChoir = false}) {
        final p = rdBuildImportPlan([_e('Noten/1 Eins/$name')], songs: const [], instruments: instruments, isChoir: isChoir);
        return rdWorkState(p, const RdImportDecisions(), p.works.single).files.values.single;
      }

      expect(only('Posaune 2 und Tuba.pdf', numbered).category,
          const RdImportCategory.several([RdImportCategory(instrumentId: 22), RdImportCategory(instrumentId: 21)]));
      // Which Posaune is not sure: asked, not given to one group.
      expect(only('Posaune und Tuba.pdf', numbered).unclear, isTrue);
      expect(only('Sopran und Tenor.pdf', const [], isChoir: true).category,
          const RdImportCategory.several([RdImportCategory(newGroup: 'Sopran'), RdImportCategory(newGroup: 'Tenor')]));

      final versions = rdBuildImportPlan(
        [_e('Noten/120 Wie wunderbar/A/Posaune und Tuba.pdf'), _e('Noten/120 Wie wunderbar/B/Posaune und Tuba.pdf', size: 2000)],
        songs: const [],
        instruments: brass,
        isChoir: false,
      );
      expect(versions.works.single.fassungen, hasLength(2));
    });
  });

  test('page 1 read by the KI: sure takes the file out of "Stimme unklar", unsure is proposed', () {
    final entries = [_e('Noten/Eins/Tag.pdf'), _e('Noten/Eins/Nacht.pdf'), _e('Noten/Eins/Viola.pdf')];
    const d = RdImportDecisions();
    expect(rdImportPagesToRead(_plan(entries), d), ['Noten/Eins/Nacht.pdf', 'Noten/Eins/Tag.pdf']);
    final plan = rdBuildImportPlan(entries, songs: const [], instruments: _instruments, isChoir: false, pageReads: const {
      'Noten/Eins/Tag.pdf': RdImportPageRead(RdImportCategory(instrumentId: 11), label: '2. Violine', sure: true),
      'Noten/Eins/Nacht.pdf': RdImportPageRead(RdImportCategory(newGroup: 'Oboe'), label: 'Oboe'),
    });
    final work = plan.works.single;
    RdFileState state(String name) => rdFileState(plan, d, work, work.files.firstWhere((f) => f.name == name));
    expect((state('Tag.pdf').category, state('Tag.pdf').unclear), (const RdImportCategory(instrumentId: 11), false));
    expect((state('Nacht.pdf').category, state('Nacht.pdf').unclear), (const RdImportCategory(newGroup: 'Oboe'), true));
    expect(rdImportPagesToRead(plan, d), isEmpty);
    // Chosen by hand, the read no longer counts.
    final byHand = RdImportDecisions(categories: {'Noten/Eins/Tag.pdf': RdImportCategory.other});
    final tag = rdFileState(plan, byHand, work, work.files.firstWhere((f) => f.name == 'Tag.pdf'));
    expect((tag.category, tag.pageRead), (RdImportCategory.other, null));
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
