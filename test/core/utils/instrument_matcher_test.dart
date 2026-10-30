import 'package:attendix/core/providers/group_providers.dart' show mergeSynonyms;
import 'package:attendix/core/utils/instrument_matcher.dart';
import 'package:attendix/features/songs/presentation/widgets/file_upload_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

const _orchestra = [
  'Flöte', 'Oboe', 'Klarinette', 'Fagott', 'Horn', 'Trompete', 'Posaune', 'Tuba',
  'Violine 1', 'Violine 2', 'Viola', 'Cello', 'Kontrabass', 'Schlagzeug', 'Pauke', 'Klavier',
];

List<InstrumentInfo> _groups(List<String> names, {Map<String, String> synonyms = const {}}) => [
      for (var i = 0; i < names.length; i++)
        InstrumentInfo(id: 10 + i, name: names[i], synonyms: synonyms[names[i]]),
    ];

String? _label(String file, List<String> names, {Map<String, String> synonyms = const {}, bool isChoir = false}) {
  final guess = guessFileCategory(file, instruments: _groups(names, synonyms: synonyms), isChoir: isChoir);
  if (guess.instrumentId == null) return guess.note;
  if (guess.instrumentId == 1) return 'Aufnahme';
  if (guess.instrumentId == 2) return 'Liedtext';
  return names[guess.instrumentId! - 10];
}

MatchConfidence _confidence(String file, List<String> names, {Map<String, String> synonyms = const {}}) =>
    guessFileCategory(file, instruments: _groups(names, synonyms: synonyms), isChoir: false).confidence;

void main() {
  group('InstrumentMatcher part numbers', () {
    for (final (file, expected) in [
      ('Violine 1.pdf', 'Violine 1'),
      ('Violine 2.pdf', 'Violine 2'),
      ('Violin II.pdf', 'Violine 2'),
      ('Vl2 - Ave Verum.pdf', 'Violine 2'),
      ('02 Vl2 - Ave Verum.pdf', 'Violine 2'),
      ('2. Violine.pdf', 'Violine 2'),
      ('Ave Verum_violin_1.pdf', 'Violine 1'),
      ('Violinen II.pdf', 'Violine 2'),
    ]) {
      test('$file → $expected', () => expect(_label(file, _orchestra), expected));
    }

    test('a number of the Werk is not the part', () {
      expect(_confidence('Sinfonie 2 - Violine.pdf', _orchestra), MatchConfidence.unsure);
      expect(_label('Sinfonie 5 - Violine.pdf', _orchestra), startsWith('Violine'));
      expect(_confidence('Sinfonie 5 - Violine.pdf', _orchestra), MatchConfidence.unsure);
      expect(_confidence('Sinfonie 2 Violine.pdf', _orchestra), MatchConfidence.unsure);
      expect(_label('Sinfonie 5 - 2. Violine.pdf', _orchestra), 'Violine 2');
      expect(_label('Sinfonie 5 - Violine 1.pdf', _orchestra), 'Violine 1');
    });

    test('missing number with two numbered groups is unsure', () {
      expect(_confidence('Violine.pdf', _orchestra), MatchConfidence.unsure);
    });

    test('number on an unnumbered group is fine', () {
      expect(_label('Klarinette in B 1.pdf', _orchestra), 'Klarinette');
      expect(_confidence('Klarinette in B 1.pdf', _orchestra), MatchConfidence.sure);
      expect(_label('Bb Clarinet 2.pdf', _orchestra), 'Klarinette');
      expect(_label('Horn in F 3+4.pdf', _orchestra), 'Horn');
    });

    test('tuning words before the number', () {
      final groups = ['Klarinette 1', 'Klarinette 2', 'Trompete 1', 'Trompete 2'];
      expect(_label('Klarinette in B 2.pdf', groups), 'Klarinette 2');
      expect(_label('Trompete in B II.pdf', groups), 'Trompete 2');
      expect(_label('2nd Trumpet in Bb.pdf', groups), 'Trompete 2');
    });
  });

  group('InstrumentMatcher whole words', () {
    test('no substring hits in other words', () {
      expect(_label('Soundtrack Medley - Flöte.pdf', _orchestra), 'Flöte');
      expect(_label('Kontext - Cello.pdf', _orchestra), 'Cello');
      expect(_label('Flügelhorn.pdf', _orchestra), isNot('Flöte'));
    });

    test('compound words are only unsure', () {
      expect(_label('Bassklarinette.pdf', _orchestra), 'Klarinette');
      expect(_confidence('Bassklarinette.pdf', _orchestra), MatchConfidence.unsure);
      expect(_confidence('Englischhorn.pdf', _orchestra), MatchConfidence.unsure);
      expect(_confidence('English Horn.pdf', _orchestra), MatchConfidence.unsure);
      expect(_confidence('Bass Clarinet.pdf', _orchestra), MatchConfidence.unsure);
      expect(_confidence('French Horn 2.pdf', _orchestra), MatchConfidence.sure);
    });

    test('a more specific group wins', () {
      final groups = ['Klarinette', 'Bassklarinette', 'Horn', 'Englischhorn', 'Saxophon', 'Altsaxophon'];
      expect(_label('Bassklarinette.pdf', groups), 'Bassklarinette');
      expect(_label('Bass Clarinet in Bb.pdf', groups), 'Bassklarinette');
      expect(_label('Klarinette 1.pdf', groups), 'Klarinette');
      expect(_label('Englischhorn.pdf', groups), 'Englischhorn');
      expect(_label('English Horn.pdf', groups), 'Englischhorn');
      expect(_label('Horn in F.pdf', groups), 'Horn');
      expect(_label('Alto Sax 1.pdf', groups), 'Altsaxophon');
      expect(_confidence('Alto Sax 1.pdf', groups), MatchConfidence.sure);
    });

    test('translations and abbreviations', () {
      expect(_label('Timpani.pdf', _orchestra), 'Pauke');
      expect(_label('Pauken.pdf', _orchestra), 'Pauke');
      expect(_label('Trombone 1.pdf', _orchestra), 'Posaune');
      expect(_label('Violoncello.pdf', _orchestra), 'Cello');
      expect(_label('Tpt 2.pdf', _orchestra), 'Trompete');
      expect(_label('Floete.pdf', _orchestra), 'Flöte');
      expect(_label('Euphonium.pdf', ['Tuba', 'Euphonium']), 'Euphonium');
      expect(_label('Glockenspiel.pdf', ['Schlagzeug', 'Glockenspiel']), 'Glockenspiel');
    });

    test('ambiguous abbreviation is unsure', () {
      expect(_confidence('Kl 1.pdf', _orchestra), MatchConfidence.unsure);
      expect(_confidence('Bass.pdf', _orchestra), MatchConfidence.unsure);
    });

    test('choir voices', () {
      final choir = ['Sopran', 'Alt', 'Tenor', 'Bass'];
      expect(_label('Ave Verum - Alto.pdf', choir, isChoir: true), 'Alt');
      expect(_label('Soprano.pdf', choir, isChoir: true), 'Sopran');
      expect(_label('Bass.pdf', choir, isChoir: true), 'Bass');
      expect(_label('Altsaxophon.pdf', choir, isChoir: true), 'Chor');
      expect(_label('Lied.pdf', choir, isChoir: true), 'Chor');
    });

    test('group synonyms incl. numbers', () {
      final syn = {'Violine 2': 'zweite geige, vl2b'};
      expect(_label('Zweite Geige.pdf', _orchestra, synonyms: syn), 'Violine 2');
      expect(_label('Vl2b.pdf', _orchestra, synonyms: syn), 'Violine 2');
    });
  });

  group('special types', () {
    test('score / lyrics / recording', () {
      expect(_label('Full Score.pdf', _orchestra), 'Partitur');
      expect(_label('Ave Verum Partitur.pdf', _orchestra), 'Partitur');
      expect(_label('Ave Verum Liedtext.pdf', _orchestra), 'Liedtext');
      expect(_label('Probe.mp3', _orchestra), 'Aufnahme');
      expect(_label('Track 3.m4a', _orchestra), 'Aufnahme');
      expect(_label('Klavierauszug.pdf', _orchestra), 'Klavierauszug');
      expect(_label('Scan_20231004.pdf', _orchestra), isNull);
      expect(_confidence('Scan_20231004.pdf', _orchestra), MatchConfidence.none);
    });
  });

  group('partTerm', () {
    test('removes werk name, numbers and extension', () {
      expect(InstrumentMatcher.partTerm('03 Ave Verum - Vl2.pdf', workName: 'Ave Verum'), 'Vl2');
      expect(InstrumentMatcher.partTerm('Zweite Geige.pdf'), 'Zweite Geige');
      expect(InstrumentMatcher.partTerm('Ave Verum.pdf', workName: 'Ave Verum'), isNull);
    });
  });

  group('learning synonyms', () {
    test('learnableTerm only for hand-assigned groups', () {
      final groups = _groups(_orchestra);
      final violine2 = 10 + _orchestra.indexOf('Violine 2');
      expect(learnableTerm('Ave Verum - Zweite.pdf', chosenId: violine2, instruments: groups, workName: 'Ave Verum'), 'Zweite');
      expect(learnableTerm('Violine 2.pdf', chosenId: violine2, instruments: groups), isNull);
      expect(learnableTerm('Probe.pdf', chosenId: InstrumentMatcher.recordingId, instruments: groups), isNull);
      expect(learnableTerm('Probe.pdf', chosenId: null, instruments: groups), isNull);
    });

    test('a remembered term is recognised next time', () {
      final syn = {'Violine 2': mergeSynonyms(null, ['Zweite'])!};
      expect(_label('Ave Verum - Zweite.pdf', _orchestra, synonyms: syn), 'Violine 2');
      expect(_confidence('Ave Verum - Zweite.pdf', _orchestra, synonyms: syn), MatchConfidence.sure);
    });

    test('mergeSynonyms appends once, several terms per group', () {
      expect(mergeSynonyms(null, ['Vl2']), 'vl2');
      expect(mergeSynonyms('geige 2, vl ii', ['VL2']), 'geige 2, vl ii, vl2');
      expect(mergeSynonyms('geige 2, vl2', ['Vl2']), isNull);
      expect(mergeSynonyms('a', [' ']), isNull);
      expect(mergeSynonyms('a', ['b', 'c', 'B']), 'a, b, c');
    });
  });
}
