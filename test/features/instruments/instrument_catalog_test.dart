import 'package:attendix/features/instruments/data/instrument_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('instrument catalogue search', () {
    test('finds German synonyms and English names', () {
      expect(searchInstrumentCatalog('Geige').firstOrNull?.id, 'violin');
      expect(searchInstrumentCatalog('Bratsche').firstOrNull?.id, 'viola');
      expect(
        searchInstrumentCatalog('  BASS FLUTE  ').firstOrNull?.id,
        'bass_flute',
      );
      expect(searchInstrumentCatalog('Floete').firstOrNull?.id, 'flute');
    });

    test('applies family and voice filters to the search', () {
      expect(
        searchInstrumentCatalog(
          'sax',
          family: InstrumentFamily.woodwinds,
        ).map((instrument) => instrument.id),
        containsAll(['alto_saxophone', 'tenor_saxophone']),
      );
      expect(
        searchInstrumentCatalog('sax', family: InstrumentFamily.brass),
        isEmpty,
      );
      final voices = searchInstrumentCatalog('', voicesOnly: true);
      expect(
        voices.map((instrument) => instrument.id),
        containsAll(['soprano', 'alto', 'tenor', 'bass']),
      );
      expect(
        voices.every(
          (instrument) => instrument.family == InstrumentFamily.voices,
        ),
        isTrue,
      );
      expect(searchInstrumentCatalog('Geige', voicesOnly: true), isEmpty);
      expect(
        searchInstrumentCatalog(
          '',
          family: InstrumentFamily.strings,
          voicesOnly: true,
        ),
        isEmpty,
      );
    });

    test('returns distinct flute variants with an exact result first', () {
      for (final (query, id) in [
        ('Querflöte', 'flute'),
        ('Piccolo', 'piccolo'),
        ('Altflöte', 'alto_flute'),
        ('Bassflöte', 'bass_flute'),
        ('Kontrabassflöte', 'contrabass_flute'),
      ]) {
        expect(
          searchInstrumentCatalog(query).firstOrNull?.id,
          id,
          reason: query,
        );
      }
    });

    test('keeps tuned woodwinds and mallet instruments distinct', () {
      for (final (query, id) in [
        ('Es-Klarinette', 'eb_clarinet'),
        ('A-Klarinette', 'a_clarinet'),
        ('Bassklarinette', 'bass_clarinet'),
        ('Marimba', 'marimba'),
        ('Glockenspiel', 'glockenspiel'),
        ('Xylophon', 'xylophone'),
        ('Xilofono', 'xylophone'),
        ('Vibraphon', 'vibraphone'),
        ('Chimes', 'tubular_bells'),
      ]) {
        expect(
          searchInstrumentCatalog(query).firstOrNull?.id,
          id,
          reason: query,
        );
      }
    });

    test('offers uncommon Eastern European and alpine instruments', () {
      for (final (query, id, family) in [
        ('Domra', 'domra', InstrumentFamily.plucked),
        ('Altdomra', 'alto_domra', InstrumentFamily.plucked),
        ('Bassdomra', 'bass_domra', InstrumentFamily.plucked),
        ('Balalaika', 'balalaika', InstrumentFamily.plucked),
        ('Bayan', 'bayan', InstrumentFamily.keyboards),
        ('Mandoline', 'mandolin', InstrumentFamily.plucked),
        ('Zither', 'zither', InstrumentFamily.plucked),
        (
          'Steirische Harmonika',
          'styrian_accordion',
          InstrumentFamily.keyboards,
        ),
        ('Hackbrett', 'hammered_dulcimer', InstrumentFamily.folk),
        ('Alphorn', 'alphorn', InstrumentFamily.brass),
      ]) {
        expect(
          searchInstrumentCatalog(query, family: family).firstOrNull?.id,
          id,
          reason: query,
        );
      }
    });

    test('an empty query offers at least sixty stable distinct types', () {
      final all = searchInstrumentCatalog('');
      expect(all.length, greaterThanOrEqualTo(60));
      expect(all.map((instrument) => instrument.id).toSet().length, all.length);
      expect(
        all.map((instrument) => instrument.family.index).toList(),
        orderedEquals(
          all.map((instrument) => instrument.family.index).toList()..sort(),
        ),
      );
      expect(searchInstrumentCatalog('not an instrument'), isEmpty);
    });
  });

  test(
    'metadata fits the existing editor without guessing unsupported keys',
    () {
      expect(instrumentCatalog, isNotEmpty);
      for (final instrument in instrumentCatalog) {
        if (instrument.tuning != null) {
          expect(
            ['C', 'Es', 'B', 'F'],
            contains(instrument.tuning),
            reason: instrument.id,
          );
        }
        if (instrument.clefs != null) {
          expect(
            instrument.clefs,
            everyElement(isIn(['g', 'f', 'c'])),
            reason: instrument.id,
          );
        }
      }
      expect(searchInstrumentCatalog('Altflöte').first.tuning, isNull);
      expect(searchInstrumentCatalog('A-Klarinette').first.tuning, isNull);
      expect(searchInstrumentCatalog('Snare drum').first.clefs, isNull);
      expect(searchInstrumentCatalog('Es-Klarinette').first.tuning, 'Es');
    },
  );
}
