import 'package:attendix/data/models/instrument/instrument.dart';
import 'package:attendix/features/instruments/data/catalog_selection.dart';
import 'package:attendix/features/instruments/data/instrument_catalog.dart';
import 'package:attendix/features/instruments/data/instrument_presets.dart';
import 'package:flutter_test/flutter_test.dart';

CatalogPreset _preset(String id) {
  expect(instrumentPresets.map((preset) => preset.id), contains(id));
  return instrumentPresets.singleWhere((preset) => preset.id == id);
}

CatalogInstrument _instrument(String id) =>
    instrumentCatalog.singleWhere((instrument) => instrument.id == id);

void main() {
  group('catalogue presets', () {
    test('symphony starts with fourteen rows and distinct violin parts', () {
      final preset = _preset('symphony_orchestra');
      final selected =
          preset.entries
              .where((entry) => entry.selectedByDefault)
              .map((entry) => draftFromPresetEntry(entry, languageCode: 'de'))
              .toList();
      expect(selected.map((draft) => draft.name), [
        '1. Violinen',
        '2. Violinen',
        'Bratschen',
        'Violoncelli',
        'Kontrabässe',
        'Querflöte',
        'Oboe',
        'Klarinette',
        'Fagott',
        'Horn',
        'Trompete',
        'Posaune',
        'Pauken',
        'Schlagwerk',
      ]);
      expect(selected.take(2).map((draft) => draft.instrumentId), [
        'violin',
        'violin',
      ]);
      expect(selected[0].key, isNot(selected[1].key));
      expect(
        preset.entries
            .where((entry) => !entry.selectedByDefault)
            .map((entry) => entry.instrumentId),
        [
          'piccolo',
          'english_horn',
          'bass_clarinet',
          'contrabassoon',
          'tuba',
          'harp',
          'piano',
          'celesta',
        ],
      );
    });

    test('numbered aliases identify only their own violin part', () {
      final rows =
          _preset('symphony_orchestra').entries
              .where((entry) => entry.instrumentId == 'violin')
              .map((entry) => draftFromPresetEntry(entry, languageCode: 'de'))
              .toList();
      expect(rows, hasLength(2));
      for (final name in [
        'Violine I',
        'Violine 1',
        'Erste Geige',
        'First violins',
        '1. Violinen',
      ]) {
        expect(
          draftMatchesGroup(rows[0], Group(name: name)),
          isTrue,
          reason: name,
        );
        expect(
          draftMatchesGroup(rows[1], Group(name: name)),
          isFalse,
          reason: name,
        );
      }
      for (final name in ['Violin II', 'Geige 2', 'Second violins']) {
        expect(
          draftMatchesGroup(rows[1], Group(name: name)),
          isTrue,
          reason: name,
        );
        expect(
          draftMatchesGroup(rows[0], Group(name: name)),
          isFalse,
          reason: name,
        );
      }
      for (final row in rows) {
        expect(draftMatchesGroup(row, const Group(name: 'Violine')), isFalse);
        expect(draftMatchesGroup(row, const Group(name: 'Geige')), isFalse);
      }
    });

    test(
      'SATB drafts create four voices without categories or music metadata',
      () {
        final drafts =
            _preset('mixed_choir_satb').entries
                .where((entry) => entry.selectedByDefault)
                .map((entry) => draftFromPresetEntry(entry, languageCode: 'en'))
                .toList();
        expect(drafts.map((draft) => draft.name), [
          'Soprano',
          'Alto',
          'Tenor',
          'Bass',
        ]);
        expect(drafts.map((draft) => draft.categoryName), everyElement(isNull));
        expect(drafts.map((draft) => draft.tuning), everyElement(isNull));
        expect(drafts.map((draft) => draft.clefs), everyElement(isNull));
      },
    );

    test('folk orchestra offers Eastern European instruments and mandolin', () {
      final folk = _preset('folk_orchestra');
      final selected = folk.entries
          .where((entry) => entry.selectedByDefault)
          .map((entry) => entry.instrumentId);
      expect(
        selected,
        containsAll([
          'domra',
          'alto_domra',
          'balalaika',
          'bayan',
          'accordion',
          'mandolin',
        ]),
      );
      expect(selected, isNot(contains('zither')));
      expect(selected, isNot(contains('hammered_dulcimer')));
      expect(
        folk.entries
            .where((entry) => !entry.selectedByDefault)
            .map((entry) => entry.instrumentId),
        containsAll(['bass_domra', 'bass_balalaika', 'contrabass_balalaika']),
      );
      expect(instrumentPresets.map((preset) => preset.id), [
        'symphony_orchestra',
        'string_orchestra',
        'wind_band',
        'folk_orchestra',
        'mixed_choir_satb',
      ]);
    });

    test('every preset row resolves to a catalogue type and a unique key', () {
      expect(instrumentPresets, isNotEmpty);
      for (final preset in instrumentPresets) {
        final drafts =
            preset.entries
                .map((entry) => draftFromPresetEntry(entry, languageCode: 'de'))
                .toList();
        expect(
          drafts.map((draft) => draft.key).toSet().length,
          drafts.length,
          reason: preset.id,
        );
        expect(
          drafts.map((draft) => draft.name).toSet().length,
          drafts.length,
          reason: preset.id,
        );
        expect(
          drafts.map((draft) => draft.instrumentId),
          everyElement(
            isIn(instrumentCatalog.map((instrument) => instrument.id)),
          ),
          reason: preset.id,
        );
      }
    });
  });

  group('merging selections', () {
    test('keeps renamed same-key drafts and their custom metadata', () {
      const renamed = CatalogGroupDraft(
        key: 'flute',
        instrumentId: 'flute',
        name: 'Querflöte solo',
        categoryName: 'Solisten',
        synonyms: ['Solo flute'],
        tuning: 'G',
        clefs: ['f'],
      );
      const custom = CatalogGroupDraft(
        key: 'custom:1',
        instrumentId: '',
        name: 'Nyckelharpa',
      );
      final current = [renamed, custom];
      final additions = [
        draftFromInstrument(_instrument('flute'), languageCode: 'de'),
        draftFromInstrument(_instrument('oboe'), languageCode: 'de'),
      ];

      final merged = mergeCatalogDrafts(current, additions);

      expect(merged.map((draft) => draft.name), [
        'Querflöte solo',
        'Nyckelharpa',
        'Oboe',
      ]);
      expect(merged.first, same(renamed));
      expect(merged[1], same(custom));
      expect(merged.first.categoryName, 'Solisten');
      expect(merged.first.synonyms, ['Solo flute']);
      expect(merged.first.tuning, 'G');
      expect(merged.first.clefs, ['f']);
      expect(current, hasLength(2));
      expect(additions, hasLength(2));
    });

    test('skips exact curated equivalents across different draft keys', () {
      const existing = CatalogGroupDraft(
        key: 'custom:1',
        instrumentId: '',
        name: '  GEIGE  ',
      );
      final merged = mergeCatalogDrafts(
        [existing],
        [
          draftFromInstrument(_instrument('violin'), languageCode: 'de'),
          const CatalogGroupDraft(
            key: 'english-flute',
            instrumentId: 'flute',
            name: 'Flute',
            synonyms: ['Querflöte'],
          ),
          const CatalogGroupDraft(
            key: 'german-flute',
            instrumentId: 'flute',
            name: 'Querflöte',
          ),
        ],
      );

      expect(merged.map((draft) => draft.key), ['custom:1', 'english-flute']);
      expect(merged.first, same(existing));
    });

    test('retains separate numbered parts and different flute types', () {
      const first = CatalogGroupDraft(
        key: 'existing-first',
        instrumentId: 'violin',
        name: 'Geige I',
      );
      final merged = mergeCatalogDrafts(
        [first],
        [
          for (final entry in _preset('string_orchestra').entries.take(2))
            draftFromPresetEntry(entry, languageCode: 'de'),
          draftFromInstrument(_instrument('flute'), languageCode: 'de'),
          draftFromInstrument(_instrument('bass_flute'), languageCode: 'de'),
          const CatalogGroupDraft(
            key: 'flute-two',
            instrumentId: 'flute',
            name: 'Querflöte 2',
          ),
        ],
      );

      expect(merged.map((draft) => draft.name), [
        'Geige I',
        '2. Violinen',
        'Querflöte',
        'Bassflöte',
        'Querflöte 2',
      ]);
    });
  });

  group('draft matching', () {
    test('draft equivalents use exact names and aliases from either draft', () {
      final flute = draftFromInstrument(
        _instrument('flute'),
        languageCode: 'de',
      );
      const customAlias = CatalogGroupDraft(
        key: 'custom:1',
        instrumentId: '',
        name: '  FLAUTO  ',
      );
      const selectedAlias = CatalogGroupDraft(
        key: 'another-flute',
        instrumentId: 'flute',
        name: 'Holzbläser Solo',
        synonyms: ['Querflöte'],
      );
      expect(draftMatchesDraft(flute, customAlias), isTrue);
      expect(draftMatchesDraft(customAlias, flute), isTrue);
      expect(draftMatchesDraft(flute, selectedAlias), isTrue);
      expect(draftMatchesDraft(selectedAlias, flute), isTrue);
    });

    test(
      'draft equivalents keep numbered parts and related types distinct',
      () {
        final violins =
            _preset('string_orchestra').entries
                .take(2)
                .map((entry) => draftFromPresetEntry(entry, languageCode: 'de'))
                .toList();
        expect(draftMatchesDraft(violins[0], violins[1]), isFalse);
        final flute = draftFromInstrument(
          _instrument('flute'),
          languageCode: 'de',
        );
        expect(
          draftMatchesDraft(flute, flute.copyWith(name: 'Querflöte 2')),
          isFalse,
        );
        expect(
          draftMatchesDraft(
            flute,
            draftFromInstrument(_instrument('bass_flute'), languageCode: 'de'),
          ),
          isFalse,
        );
      },
    );

    test(
      'German and English names plus precise aliases represent one type',
      () {
        final violin = draftFromInstrument(
          _instrument('violin'),
          languageCode: 'de',
        );
        expect(violin.name, 'Violine');
        expect(violin.categoryName, 'Streicher');
        expect(violin.clefs, ['g']);
        for (final name in ['Violine', 'Violin', 'Geige', '  GEIGE  ']) {
          expect(
            draftMatchesGroup(violin, Group(name: name)),
            isTrue,
            reason: name,
          );
        }
        final english = draftFromInstrument(
          _instrument('violin'),
          languageCode: 'en',
        );
        expect(english.name, 'Violin');
        expect(english.categoryName, 'Strings');
        expect(
          draftMatchesGroup(english, const Group(name: 'Violine')),
          isTrue,
        );
        final fallback = draftFromInstrument(
          _instrument('violin'),
          languageCode: 'fr',
        );
        expect(fallback.name, 'Violine');
        expect(fallback.categoryName, 'Streicher');
      },
    );

    test('custom renaming permits a deliberate additional voice', () {
      final original = draftFromInstrument(
        _instrument('flute'),
        languageCode: 'de',
      );
      final renamed = original.copyWith(name: 'Querflöte 3');
      expect(renamed.instrumentId, 'flute');
      expect(renamed.key, original.key);
      expect(renamed.tuning, 'C');
      expect(renamed.clefs, ['g']);
      expect(renamed.synonyms, isEmpty);
      expect(draftMatchesGroup(renamed, const Group(name: 'Flute')), isFalse);
      expect(
        draftMatchesGroup(renamed, const Group(name: 'Querflöte')),
        isFalse,
      );
      expect(
        draftMatchesGroup(renamed, const Group(name: 'Querflöte 3')),
        isTrue,
      );
      expect(original.synonyms, isNotEmpty);
      final named = draftFromInstrument(
        _instrument('flute'),
        languageCode: 'de',
        name: '  Flöte solo  ',
      );
      expect(named.name, 'Flöte solo');
      expect(named.synonyms, isEmpty);
      expect(draftMatchesGroup(named, const Group(name: 'Flute')), isFalse);
    });

    test('whitespace-only renaming retains aliases', () {
      final original = draftFromInstrument(
        _instrument('violin'),
        languageCode: 'de',
      );
      final renamed = original.copyWith(name: '  Violine  ');
      expect(renamed.name, 'Violine');
      expect(draftMatchesGroup(renamed, const Group(name: 'Geige')), isTrue);
    });

    test('matches exact existing aliases but excludes main groups', () {
      final flute = draftFromInstrument(
        _instrument('flute'),
        languageCode: 'de',
      );
      expect(
        draftMatchesGroup(
          flute,
          const Group(name: 'Woodwind solo', synonyms: 'other, Flute, another'),
        ),
        isTrue,
      );
      expect(
        draftMatchesGroup(flute, const Group(name: 'Flute', maingroup: true)),
        isFalse,
      );
      expect(
        draftMatchesGroup(
          flute,
          const Group(name: 'Leitung', maingroup: true, synonyms: 'Querflöte'),
        ),
        isFalse,
      );
    });

    test(
      'uses whole normalized names without substring or wildcard matches',
      () {
        final flute = draftFromInstrument(
          _instrument('flute'),
          languageCode: 'de',
        );
        for (final name in [
          'Bassflöte',
          'Altflöte',
          'Flute 2',
          'Fl*te',
          'Flute*',
          'Flöte solo',
        ]) {
          expect(
            draftMatchesGroup(flute, Group(name: name)),
            isFalse,
            reason: name,
          );
        }
        final marimba = draftFromInstrument(
          _instrument('marimba'),
          languageCode: 'de',
        );
        expect(
          draftMatchesGroup(marimba, const Group(name: 'Glockenspiel')),
          isFalse,
        );
        final balalaika = draftFromInstrument(
          _instrument('balalaika'),
          languageCode: 'de',
        );
        expect(
          draftMatchesGroup(balalaika, const Group(name: 'Bassbalalaika')),
          isFalse,
        );
        expect(
          draftMatchesGroup(balalaika, const Group(name: 'Mandoline')),
          isFalse,
        );
        expect(
          draftMatchesGroup(flute, const Group(name: '', synonyms: ', ')),
          isFalse,
        );
      },
    );

    test(
      'normalization folds German spelling and punctuation, retaining numbers',
      () {
        expect(normalizeCatalogName('  Kontrabässe  '), 'kontrabaesse');
        expect(normalizeCatalogName('Bass-Flöte'), 'bass floete');
        expect(normalizeCatalogName('1.  Violinen'), '1 violinen');
        expect(normalizeCatalogName('Straße'), 'strasse');
        expect(
          normalizeCatalogName('Violine I'),
          isNot(normalizeCatalogName('Violine II')),
        );
        expect(
          normalizeCatalogName('Violine 1'),
          isNot(normalizeCatalogName('Violine 2')),
        );
      },
    );
  });
}
