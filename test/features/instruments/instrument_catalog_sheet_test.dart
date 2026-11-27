import 'dart:async';

import 'package:attendix/core/config/supabase_config.dart';
import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/debug_providers.dart';
import 'package:attendix/core/providers/group_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/router/redesign_routes.dart';
import 'package:attendix/core/services/offline_queue_service.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/data/models/instrument/instrument.dart';
import 'package:attendix/data/models/tenant/tenant.dart';
import 'package:attendix/data/repositories/group_repository.dart';
import 'package:attendix/features/instruments/data/catalog_selection.dart';
import 'package:attendix/features/instruments/presentation/widgets/instrument_catalog_sheet.dart';
import 'package:attendix/shared/widgets/redesign/rd_widgets.dart';
import 'package:attendix/features/instruments/presentation/pages/rd_groups_page.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _firstViolins = CatalogGroupDraft(
  key: 'violin-first',
  instrumentId: 'violin',
  name: '1. Violinen',
  categoryName: 'Streicher',
  synonyms: ['Violine I', 'Violin I'],
  tuning: 'C',
  clefs: ['treble'],
);
const _secondViolins = CatalogGroupDraft(
  key: 'violin-second',
  instrumentId: 'violin',
  name: '2. Violinen',
  categoryName: 'Streicher',
  synonyms: ['Violine II', 'Violin II'],
  tuning: 'C',
  clefs: ['treble'],
);
const _renamedPresetVoice = CatalogGroupDraft(
  key: 'violin_1',
  instrumentId: 'violin',
  name: 'Violine solo I',
  categoryName: 'Solisten',
  tuning: 'G',
  clefs: ['f'],
);
const _customInstrument = CatalogGroupDraft(
  key: 'custom:1',
  instrumentId: '',
  name: 'Nyckelharpa',
);

void main() {
  testWidgets('setup accepts an intentional empty selection', (tester) async {
    CatalogPickerResult? result;
    await _open(
      tester,
      purpose: CatalogPickerPurpose.setup,
      onPickerResult: (value) => result = value,
    );
    expect(find.text('Auswahl übernehmen'), findsOneWidget);
    await _apply(tester);
    expect(result, isNotNull);
    expect(result!.drafts, isEmpty);
    expect(result!.presetId, isNull);
  });

  for (final scenario in [
    (kind: 'orchestra', label: '3 Instrumente hinzufügen'),
    (kind: 'choir', label: '3 Stimmen hinzufügen'),
  ]) {
    testWidgets('add action names the count for ${scenario.kind}', (
      tester,
    ) async {
      await _open(
        tester,
        tenantType: scenario.kind,
        initialSelection: const [
          CatalogGroupDraft(key: 'one', instrumentId: '', name: 'Eins'),
          CatalogGroupDraft(key: 'two', instrumentId: '', name: 'Zwei'),
          CatalogGroupDraft(key: 'three', instrumentId: '', name: 'Drei'),
        ],
      );
      expect(find.text(scenario.label), findsOneWidget);
      await _apply(tester);
    });
  }

  testWidgets('reopening restores the preset and renamed numbered row', (
    tester,
  ) async {
    CatalogPickerResult? result;
    await _open(
      tester,
      initialPresetId: 'symphony_orchestra',
      initialSelection: const [_renamedPresetVoice],
      onPickerResult: (value) => result = value,
    );
    expect(find.text('Sinfonieorchester'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('catalog-search')), 'Violine');
    await tester.pumpAndSettle();
    final row = find.byKey(const Key('catalog-entry-violin_1'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(RdListRow, 'Violine solo I'), findsOneWidget);
    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    await _apply(tester);
    expect(result!.presetId, 'symphony_orchestra');
    expect(result!.drafts.single, same(_renamedPresetVoice));
  });

  testWidgets('choosing the same preset retains edited and unselected rows', (
    tester,
  ) async {
    CatalogPickerResult? result;
    await _open(
      tester,
      initialPresetId: 'symphony_orchestra',
      initialSelection: const [_renamedPresetVoice, _customInstrument],
      onPickerResult: (value) => result = value,
    );
    await tester.tap(find.byKey(const Key('catalog-presets')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sinfonieorchester').last);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await _apply(tester);
    expect(result!.presetId, 'symphony_orchestra');
    expect(result!.drafts, [_renamedPresetVoice, _customInstrument]);
  });

  testWidgets('merging presets keeps custom names and adds missing defaults', (
    tester,
  ) async {
    CatalogPickerResult? result;
    await _open(
      tester,
      initialPresetId: 'string_orchestra',
      initialSelection: const [_renamedPresetVoice, _customInstrument],
      onPickerResult: (value) => result = value,
    );
    await tester.tap(find.byKey(const Key('catalog-presets')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sinfonieorchester'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ergänzen'));
    await tester.pumpAndSettle();
    await _apply(tester);
    expect(result!.presetId, 'symphony_orchestra');
    expect(result!.drafts, hasLength(15));
    expect(result!.drafts.first, same(_renamedPresetVoice));
    expect(result!.drafts[1], same(_customInstrument));
    expect(
      result!.drafts.map((draft) => draft.name),
      containsAll(['2. Violinen', 'Querflöte']),
    );
    expect(
      result!.drafts.map((draft) => draft.name),
      isNot(contains('1. Violinen')),
    );
  });

  for (final previousDraft in const [
    CatalogGroupDraft(key: 'flute', instrumentId: 'flute', name: 'Querflöte'),
    CatalogGroupDraft(key: 'custom:old', instrumentId: '', name: 'Flauto'),
  ]) {
    testWidgets(
      'merging an equivalent custom draft updates the stale ${previousDraft.key} row association',
      (tester) async {
        CatalogPickerResult? result;
        await _open(
          tester,
          initialSelection: [previousDraft],
          onPickerResult: (value) => result = value,
        );
        await tester.enterText(
          find.byKey(const Key('catalog-search')),
          'Querflöte',
        );
        await tester.pumpAndSettle();
        await _selectRow(tester, previousDraft.name);
        await tester.ensureVisible(find.byKey(const Key('catalog-custom')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('catalog-custom')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, 'Querflöte');
        await tester.tap(find.text('Fertig'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('catalog-presets')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('catalog-presets')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sinfonieorchester'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ergänzen'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('catalog-search')),
          'Querflöte',
        );
        await tester.pumpAndSettle();
        final row = find.widgetWithText(RdListRow, 'Querflöte');
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Checkbox>(
                find.descendant(of: row, matching: find.byType(Checkbox)),
              )
              .value,
          isTrue,
        );
        expect(find.text('14 Instrumente hinzufügen'), findsOneWidget);
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(find.text('13 Instrumente hinzufügen'), findsOneWidget);
        await _apply(tester);
        expect(result!.presetId, 'symphony_orchestra');
        expect(result!.drafts, hasLength(13));
        expect(
          result!.drafts.map((draft) => draft.key),
          isNot(contains(anyOf('custom:1', 'flute'))),
        );
      },
    );
  }

  testWidgets(
    'deselected renamed row stays separate from an equivalent custom draft',
    (tester) async {
      const renamed = CatalogGroupDraft(
        key: 'flute',
        instrumentId: 'flute',
        name: 'Querflöte 2',
        categoryName: 'Solisten',
        tuning: 'G',
        clefs: ['f'],
      );
      const custom = CatalogGroupDraft(
        key: 'custom:1',
        instrumentId: '',
        name: 'Querflöte',
      );
      CatalogPickerResult? result;
      await _open(
        tester,
        initialSelection: const [renamed, custom],
        onPickerResult: (value) => result = value,
      );
      await tester.enterText(
        find.byKey(const Key('catalog-search')),
        'Querflöte',
      );
      await tester.pumpAndSettle();
      await _selectRow(tester, 'Querflöte 2');
      final row = find.widgetWithText(RdListRow, 'Querflöte 2');
      expect(row, findsOneWidget);
      expect(
        tester
            .widget<Checkbox>(
              find.descendant(of: row, matching: find.byType(Checkbox)),
            )
            .value,
        isFalse,
      );
      expect(find.text('1 Instrument hinzufügen'), findsOneWidget);
      await _selectRow(tester, 'Querflöte 2');
      await _apply(tester);
      expect(result!.drafts, [custom, renamed]);
    },
  );

  for (final draft in const [
    CatalogGroupDraft(
      key: 'custom:exact-flute',
      instrumentId: '',
      name: 'Querflöte',
    ),
    CatalogGroupDraft(
      key: 'custom:alias-flute',
      instrumentId: '',
      name: 'Flauto',
      categoryName: 'Solisten',
      synonyms: ['Solo woodwind'],
      tuning: 'G',
      clefs: ['f'],
    ),
    CatalogGroupDraft(
      key: 'imported-flute',
      instrumentId: 'flute',
      name: 'Flauto',
      categoryName: 'Eigene Holzbläser',
      synonyms: ['Solo woodwind'],
      tuning: 'G',
      clefs: ['f'],
    ),
  ]) {
    testWidgets(
      'reopened equivalent draft ${draft.key} stays associated after deselection',
      (tester) async {
        CatalogPickerResult? result;
        await _open(
          tester,
          initialPresetId: 'symphony_orchestra',
          initialSelection: [draft],
          onPickerResult: (value) => result = value,
        );
        await tester.enterText(
          find.byKey(const Key('catalog-search')),
          'Querflöte',
        );
        await tester.pumpAndSettle();
        final row = find.widgetWithText(RdListRow, draft.name);
        expect(row, findsOneWidget);
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        final checkbox = find.descendant(
          of: row,
          matching: find.byType(Checkbox),
        );
        expect(tester.widget<Checkbox>(checkbox).value, isTrue);
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(tester.widget<Checkbox>(checkbox).value, isFalse);
        expect(find.text('0 Instrumente hinzufügen'), findsOneWidget);
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(find.text('1 Instrument hinzufügen'), findsOneWidget);
        await _apply(tester);
        expect(result!.drafts.single, same(draft));
        expect(result!.presetId, 'symphony_orchestra');

        await _open(
          tester,
          initialPresetId: result!.presetId,
          initialSelection: result!.drafts,
          onPickerResult: (value) => result = value,
        );
        await tester.enterText(
          find.byKey(const Key('catalog-search')),
          'Querflöte',
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        expect(tester.widget<Checkbox>(checkbox).value, isTrue);
        await tester.tap(row);
        await tester.pumpAndSettle();
        await _apply(tester);
        expect(result!.drafts, isEmpty);
      },
    );
  }

  testWidgets('catalog row removes an equivalent draft without a preset', (
    tester,
  ) async {
    CatalogPickerResult? result;
    await _open(
      tester,
      initialSelection: const [
        CatalogGroupDraft(key: 'custom:1', instrumentId: '', name: 'Flauto'),
      ],
      onPickerResult: (value) => result = value,
    );
    await tester.enterText(
      find.byKey(const Key('catalog-search')),
      'Querflöte',
    );
    await tester.pumpAndSettle();
    final row = find.widgetWithText(RdListRow, 'Flauto');
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Checkbox>(
            find.descendant(of: row, matching: find.byType(Checkbox)),
          )
          .value,
      isTrue,
    );
    await tester.tap(row);
    await tester.pumpAndSettle();
    await _apply(tester);
    expect(result!.drafts, isEmpty);
    expect(result!.presetId, isNull);
  });

  testWidgets('explicit replace starts from the new preset defaults', (
    tester,
  ) async {
    CatalogPickerResult? result;
    await _open(
      tester,
      initialPresetId: 'symphony_orchestra',
      initialSelection: const [_renamedPresetVoice, _customInstrument],
      onPickerResult: (value) => result = value,
    );
    await tester.ensureVisible(find.byKey(const Key('catalog-presets')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog-presets')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Streichorchester'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Streichorchester'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ersetzen'));
    await tester.pumpAndSettle();
    await _apply(tester);
    expect(result!.presetId, 'string_orchestra');
    expect(result!.drafts.map((draft) => draft.name), [
      '1. Violinen',
      '2. Violinen',
      'Bratschen',
      'Violoncelli',
      'Kontrabässe',
    ]);
  });

  testWidgets(
    'reopened renamed catalog draft retains its name and aliases after toggle off and on',
    (tester) async {
      List<CatalogGroupDraft>? result;
      await _open(
        tester,
        initialSelection: const [
          CatalogGroupDraft(
            key: 'flute',
            instrumentId: 'flute',
            name: 'Querflöte 3',
            categoryName: 'Eigenes Register',
          ),
        ],
        onResult: (value) => result = value,
      );
      await tester.enterText(
        find.byKey(const Key('catalog-search')),
        'Querflöte',
      );
      await tester.pumpAndSettle();
      final row = find.byKey(const Key('catalog-entry-flute'));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      await _apply(tester);
      expect(result?.map((draft) => draft.name), ['Querflöte 3']);
      expect(result!.single.synonyms, isEmpty);
      expect(result!.single.categoryName, 'Eigenes Register');
      expect(result!.single.tuning, isNull);
      expect(result!.single.clefs, isNull);
    },
  );

  testWidgets(
    'search hints distinguish instrument search from choir voice search',
    (tester) async {
      await _open(tester);
      expect(find.text('z. B. Geige oder Bassflöte'), findsOneWidget);
      await _apply(tester);
      await _open(tester, tenantType: 'choir');
      expect(find.text('z. B. Sopran oder Alt'), findsOneWidget);
      await _apply(tester);
    },
  );

  testWidgets('folk preset visibly offers and selects mandolin', (
    tester,
  ) async {
    List<CatalogGroupDraft>? result;
    await _open(tester, onResult: (value) => result = value);
    await tester.tap(find.byKey(const Key('catalog-presets')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Volksinstrumentenorchester'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(RdListRow, 'Mandoline'), findsOneWidget);
    await _apply(tester);
    expect(result?.map((draft) => draft.name), contains('Mandoline'));
  });

  testWidgets('list Plus stays blocked while the batch is being imported', (
    tester,
  ) async {
    final repositories = <int, _MemoryGroupRepo>{};
    await tester.pumpWidget(_listApp(repositories));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rd-manage-list-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('catalog-search')),
      'Bassflöte',
    );
    await tester.pumpAndSettle();
    await _selectRow(tester, 'Bassflöte');
    final gate = Completer<void>();
    repositories[7]!.holdNextBatch = gate.future;
    await _apply(tester);
    expect(find.byKey(const Key('rd-manage-list-add')), findsNothing);
    gate.complete();
    await tester.pumpAndSettle();
    expect(repositories[7]!.storedGroups.map((group) => group.name), [
      'Bassflöte',
    ]);
    expect(find.byKey(const Key('rd-manage-list-add')), findsOneWidget);
  });

  testWidgets('search aliases and family filters retain selected instruments', (
    tester,
  ) async {
    List<CatalogGroupDraft>? result;
    await _open(tester, onResult: (value) => result = value);
    expect(find.byKey(const Key('catalog-search')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('catalog-search')), 'Geige');
    await tester.pumpAndSettle();
    await _selectRow(tester, 'Violine');

    final woodwinds = find.byKey(const Key('catalog-family-woodwinds'));
    await tester.ensureVisible(woodwinds);
    await tester.pumpAndSettle();
    await tester.tap(woodwinds);
    await tester.enterText(find.byKey(const Key('catalog-search')), '');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(RdListRow, 'Violine'), findsNothing);
    expect(find.widgetWithText(RdListRow, 'Querflöte'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('catalog-search')),
      'Bassflöte',
    );
    await tester.pumpAndSettle();
    expect(find.text('Violine'), findsNothing);
    expect(find.text('Querflöte'), findsNothing);
    await _selectRow(tester, 'Bassflöte');
    await _apply(tester);

    expect(result?.map((draft) => draft.name), ['Violine', 'Bassflöte']);
  });

  testWidgets('cancel discards an edited selection', (tester) async {
    List<CatalogGroupDraft>? result = const [];
    await _open(tester, onResult: (value) => result = value);
    await tester.enterText(
      find.byKey(const Key('catalog-search')),
      'Bassflöte',
    );
    await tester.pumpAndSettle();
    await _selectRow(tester, 'Bassflöte');
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('two numbered voices of one instrument remain distinct', (
    tester,
  ) async {
    List<CatalogGroupDraft>? result;
    await _open(
      tester,
      initialSelection: const [_firstViolins, _secondViolins],
      onResult: (value) => result = value,
    );
    await tester.enterText(
      find.byKey(const Key('catalog-search')),
      'Bassflöte',
    );
    await tester.pumpAndSettle();
    await _apply(tester);
    expect(result?.map((draft) => draft.name), ['1. Violinen', '2. Violinen']);
    expect(result?.map((draft) => draft.key).toSet().length, 2);
  });

  testWidgets(
    'symphony preset selects fourteen entries with two violin sections',
    (tester) async {
      List<CatalogGroupDraft>? result;
      await _open(tester, onResult: (value) => result = value);
      await tester.tap(find.byKey(const Key('catalog-presets')));
      await tester.pumpAndSettle();
      expect(find.text('Big Band'), findsNothing);
      await tester.tap(find.text('Sinfonieorchester'));
      await tester.pumpAndSettle();
      await _apply(tester);
      expect(result, hasLength(14));
      expect(
        result?.map((draft) => draft.name),
        containsAll(['1. Violinen', '2. Violinen']),
      );
    },
  );

  testWidgets('without preset keeps the current selection', (tester) async {
    List<CatalogGroupDraft>? result;
    CatalogPickerResult? pickerResult;
    await _open(
      tester,
      initialPresetId: 'symphony_orchestra',
      initialSelection: const [_firstViolins],
      onResult: (value) => result = value,
      onPickerResult: (value) => pickerResult = value,
    );
    await tester.tap(find.byKey(const Key('catalog-presets')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ohne Vorlage').last);
    await tester.pumpAndSettle();
    await _apply(tester);
    expect(result?.map((draft) => draft.name), ['1. Violinen']);
    expect(result!.single, same(_firstViolins));
    expect(pickerResult!.presetId, isNull);
  });

  testWidgets(
    'changing a preset requires a choice before replacing custom drafts',
    (tester) async {
      List<CatalogGroupDraft>? result;
      CatalogPickerResult? pickerResult;
      await _open(
        tester,
        initialPresetId: 'symphony_orchestra',
        initialSelection: const [
          CatalogGroupDraft(
            key: 'custom:1',
            instrumentId: '',
            name: 'Nyckelharpa',
          ),
        ],
        onResult: (value) => result = value,
        onPickerResult: (value) => pickerResult = value,
      );
      await tester.tap(find.byKey(const Key('catalog-presets')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Streichorchester'));
      await tester.pumpAndSettle();
      expect(find.text('Ergänzen'), findsOneWidget);
      expect(find.text('Ersetzen'), findsOneWidget);
      await tester.tap(find.text('Abbrechen').last);
      await tester.pumpAndSettle();
      await _apply(tester);
      expect(result?.map((draft) => draft.name), ['Nyckelharpa']);
      expect(pickerResult!.presetId, 'symphony_orchestra');
    },
  );

  testWidgets(
    'custom entry returns only a free-name draft with no guessed metadata',
    (tester) async {
      List<CatalogGroupDraft>? result;
      await _open(tester, onResult: (value) => result = value);
      await tester.tap(find.byKey(const Key('catalog-custom')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).last,
        '  Nyckelharpa Bass  ',
      );
      await tester.tap(find.text('Fertig'));
      await tester.pumpAndSettle();
      await _apply(tester);
      expect(result, hasLength(1));
      expect(result!.single.name, 'Nyckelharpa Bass');
      expect(result!.single.instrumentId, isEmpty);
      expect(result!.single.tuning, isNull);
      expect(result!.single.clefs, isNull);
      expect(result!.single.categoryName, isNull);
    },
  );

  testWidgets(
    'adding a custom entry after reopening preserves earlier custom draft keys',
    (tester) async {
      List<CatalogGroupDraft>? result;
      await _open(
        tester,
        initialSelection: const [
          CatalogGroupDraft(
            key: 'custom:1',
            instrumentId: '',
            name: 'Erstes Instrument',
          ),
        ],
        onResult: (value) => result = value,
      );
      await tester.tap(find.byKey(const Key('catalog-custom')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Zweites Instrument');
      await tester.tap(find.text('Fertig'));
      await tester.pumpAndSettle();
      await _apply(tester);
      expect(result?.map((draft) => draft.name), [
        'Erstes Instrument',
        'Zweites Instrument',
      ]);
      expect(result?.map((draft) => draft.key).toSet().length, 2);
    },
  );

  testWidgets('existing aliases are marked and cannot be selected again', (
    tester,
  ) async {
    List<CatalogGroupDraft>? result;
    await _open(
      tester,
      existingGroups: const [Group(id: 7, tenantId: 3, name: 'Geige')],
      onResult: (value) => result = value,
    );
    await tester.enterText(find.byKey(const Key('catalog-search')), 'Violine');
    await tester.pumpAndSettle();
    expect(find.text('Bereits vorhanden'), findsOneWidget);
    final row = find.ancestor(
      of: find.text('Violine'),
      matching: find.byType(RdListRow),
    );
    expect(tester.widget<RdListRow>(row).onTap, isNull);
    await _apply(tester);
    expect(result, isEmpty);
  });

  testWidgets(
    'a different explicit name adds a further voice beside an existing alias',
    (tester) async {
      List<CatalogGroupDraft>? result;
      await _open(
        tester,
        existingGroups: const [Group(id: 7, tenantId: 3, name: 'Geige')],
        onResult: (value) => result = value,
      );
      await tester.enterText(
        find.byKey(const Key('catalog-search')),
        'Violine',
      );
      await tester.pumpAndSettle();
      final row = find.ancestor(
        of: find.text('Violine'),
        matching: find.byType(RdListRow),
      );
      expect(find.byTooltip('Weitere Stimme anlegen'), findsOneWidget);
      await tester.tap(
        find.descendant(of: row, matching: find.byType(IconButton)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Weitere Stimme anlegen'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Violine III');
      await tester.tap(find.text('Fertig'));
      await tester.pumpAndSettle();
      await _apply(tester);
      expect(result, hasLength(1));
      expect(result!.single.name, 'Violine III');
      expect(result!.single.instrumentId, 'violin');
      expect(result!.single.synonyms, isNot(contains('Geige')));
    },
  );

  testWidgets('choir uses voice wording and exposes the four SATB voices', (
    tester,
  ) async {
    List<CatalogGroupDraft>? result;
    await _open(
      tester,
      tenantType: 'choir',
      onResult: (value) => result = value,
    );
    expect(find.text('Stimmen auswählen'), findsOneWidget);
    expect(find.text('Querflöte'), findsNothing);
    await tester.tap(find.byKey(const Key('catalog-presets')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gemischter Chor (SATB)'));
    await tester.pumpAndSettle();
    await _apply(tester);
    expect(result?.map((draft) => draft.name), [
      'Sopran',
      'Alt',
      'Tenor',
      'Bass',
    ]);
    expect(result?.every((draft) => draft.categoryName == null), isTrue);
  });

  testWidgets(
    'list Plus offers the offline collection but cannot import offline',
    (tester) async {
      final repositories = <int, _MemoryGroupRepo>{};
      await tester.pumpWidget(_listApp(repositories, online: false));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rd-manage-list-add')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('catalog-search')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('catalog-search')),
        'Bassflöte',
      );
      await tester.pumpAndSettle();
      await _selectRow(tester, 'Bassflöte');
      await _apply(tester);
      expect(repositories[7]!.storedGroups, isEmpty);
      expect(
        find.textContaining('Zum Übernehmen brauchst du eine Verbindung.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'account change during a preset change discards the returned drafts',
    (tester) async {
      final repositories = <int, _MemoryGroupRepo>{};
      await tester.pumpWidget(_listApp(repositories));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(RdGroupsPage)),
      );
      await tester.tap(find.byKey(const Key('rd-manage-list-add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('catalog-search')),
        'Bassflöte',
      );
      await tester.pumpAndSettle();
      await _selectRow(tester, 'Bassflöte');
      await tester.tap(find.byKey(const Key('catalog-presets')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Streichorchester'));
      await tester.pumpAndSettle();
      expect(find.text('Ergänzen'), findsOneWidget);
      container.read(_accountProvider.notifier).state = 'account-b';
      await tester.tap(find.text('Ergänzen'));
      await tester.pumpAndSettle();
      await _apply(tester);
      expect(repositories[7]!.storedGroups, isEmpty);
      expect(find.text('1 Eintrag hinzugefügt'), findsNothing);
    },
  );

  testWidgets('tenant change during import reads prevents later batch writes', (
    tester,
  ) async {
    final repositories = <int, _MemoryGroupRepo>{};
    await tester.pumpWidget(_listApp(repositories));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(RdGroupsPage)),
    );
    await tester.tap(find.byKey(const Key('rd-manage-list-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('catalog-search')),
      'Bassflöte',
    );
    await tester.pumpAndSettle();
    await _selectRow(tester, 'Bassflöte');
    final gate = Completer<void>();
    repositories[7]!.holdNextRead = gate.future;
    await _apply(tester);
    (container.read(currentTenantProvider.notifier) as _ListTenantNotifier)
        .replace(
          const Tenant(
            id: 8,
            shortName: 'B',
            longName: 'Ensemble B',
            type: 'orchestra',
          ),
        );
    gate.complete();
    await tester.pumpAndSettle();
    expect(
      repositories.values.expand((repository) => repository.storedGroups),
      isEmpty,
    );
    expect(find.text('1 Eintrag hinzugefügt'), findsNothing);
    expect(
      find.textContaining('Die Auswahl konnte nicht übernommen werden.'),
      findsNothing,
    );
  });

  testWidgets('revoked permission during the picker prevents import', (
    tester,
  ) async {
    final repositories = <int, _MemoryGroupRepo>{};
    await tester.pumpWidget(_listApp(repositories));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(RdGroupsPage)),
    );
    await tester.tap(find.byKey(const Key('rd-manage-list-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('catalog-search')),
      'Bassflöte',
    );
    await tester.pumpAndSettle();
    await _selectRow(tester, 'Bassflöte');
    container.read(_roleProvider.notifier).state = Role.viewer;
    await _apply(tester);
    expect(repositories[7]!.storedGroups, isEmpty);
    expect(find.text('1 Eintrag hinzugefügt'), findsNothing);
  });

  testWidgets(
    'successful import refreshes the list map categories and neutral member counts',
    (tester) async {
      final repositories = <int, _MemoryGroupRepo>{};
      await tester.pumpWidget(_listApp(repositories));
      await tester.pumpAndSettle();
      final repository = repositories[7]!;
      final container = ProviderScope.containerOf(
        tester.element(find.byType(RdGroupsPage)),
      );
      expect(await container.read(groupsMapProvider.future), isEmpty);
      await tester.tap(find.byKey(const Key('rd-manage-list-add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('catalog-search')),
        'Bassflöte',
      );
      await tester.pumpAndSettle();
      await _selectRow(tester, 'Bassflöte');
      await _apply(tester);
      expect(repository.storedGroups.map((group) => group.name), ['Bassflöte']);
      expect(repository.storedGroups.single.tenantId, 7);
      expect(await container.read(groupsMapProvider.future), {
        100: 'Bassflöte',
      });
      expect(repository.groupsReads, greaterThanOrEqualTo(3));
      expect(repository.mapReads, greaterThanOrEqualTo(2));
      expect(repository.categoryReads, greaterThanOrEqualTo(3));
      expect(repository.countReads, greaterThanOrEqualTo(2));
      expect(find.text('–'), findsOneWidget);
      expect(find.text('1 Eintrag hinzugefügt'), findsOneWidget);
    },
  );

  testWidgets('failed import refreshes persisted data and allows a retry', (
    tester,
  ) async {
    final repositories = <int, _MemoryGroupRepo>{};
    await tester.pumpWidget(_listApp(repositories));
    await tester.pumpAndSettle();
    final repository = repositories[7]!;
    repository.failNextBatch = true;
    await tester.tap(find.byKey(const Key('rd-manage-list-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('catalog-search')),
      'Bassflöte',
    );
    await tester.pumpAndSettle();
    await _selectRow(tester, 'Bassflöte');
    await _apply(tester);
    expect(repository.storedGroups, isEmpty);
    expect(repository.groupsReads, greaterThanOrEqualTo(3));
    expect(
      find.textContaining('Bitte prüfe die Liste und versuche es erneut.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('rd-manage-list-add')), findsOneWidget);
  });

  testWidgets('a custom entry opens the existing editor after import', (
    tester,
  ) async {
    final repositories = <int, _MemoryGroupRepo>{};
    await tester.pumpWidget(_listApp(repositories));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rd-manage-list-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog-custom')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Seltene Stimme');
    await tester.tap(find.text('Fertig'));
    await tester.pumpAndSettle();
    await _apply(tester);
    expect(repositories[7]!.storedGroups.single.name, 'Seltene Stimme');
    expect(find.text('Editor 100'), findsOneWidget);
  });

  testWidgets('general groups retain the manual name sheet', (tester) async {
    final repositories = <int, _MemoryGroupRepo>{};
    await tester.pumpWidget(_listApp(repositories, tenantType: 'general'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rd-manage-list-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('catalog-search')), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(repositories[7]!.storedGroups, isEmpty);
  });

  testWidgets('preset change remains usable at 320px with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.reset);
    CatalogPickerResult? result;
    await _open(
      tester,
      textScale: 2,
      initialPresetId: 'symphony_orchestra',
      initialSelection: const [_renamedPresetVoice],
      onPickerResult: (value) => result = value,
    );
    await tester.ensureVisible(find.byKey(const Key('catalog-presets')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog-presets')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Streichorchester'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Streichorchester'));
    await tester.pumpAndSettle();
    expect(find.text('Ergänzen'), findsOneWidget);
    expect(find.text('Ersetzen'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Abbrechen').last);
    await tester.pumpAndSettle();
    await _apply(tester);
    expect(result!.drafts.single, same(_renamedPresetVoice));
    expect(result!.presetId, 'symphony_orchestra');
    expect(tester.takeException(), isNull);
  });

  for (final palette in RdFarbwelt.values) {
    for (final brightness in Brightness.values) {
      for (final width in [320.0, 393.0]) {
        testWidgets(
          'picker remains usable at $width, ${palette.name}, ${brightness.name}, large text',
          (tester) async {
            tester.view.physicalSize = Size(width, 844);
            tester.view.devicePixelRatio = 1;
            tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
            tester.view.viewInsets = const FakeViewPadding(bottom: 300);
            addTearDown(tester.view.reset);
            await _open(
              tester,
              palette: palette,
              brightness: brightness,
              textScale: 2,
            );
            final apply = find.byKey(const Key('catalog-apply'));
            expect(tester.getBottomLeft(apply).dy, lessThanOrEqualTo(544));
            expect(tester.takeException(), isNull);
            await _apply(tester);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}

Future<void> _open(
  WidgetTester tester, {
  String tenantType = 'orchestra',
  List<Group> existingGroups = const [],
  List<CatalogGroupDraft> initialSelection = const [],
  String? initialPresetId,
  CatalogPickerPurpose purpose = CatalogPickerPurpose.add,
  ValueChanged<List<CatalogGroupDraft>?>? onResult,
  ValueChanged<CatalogPickerResult?>? onPickerResult,
  RdFarbwelt palette = RdFarbwelt.petrol,
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('de'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildRdTheme(palette, brightness),
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
      home: Builder(
        builder:
            (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  final result = await showInstrumentCatalogSheet(
                    context,
                    tenantType: tenantType,
                    existingGroups: existingGroups,
                    initialSelection: initialSelection,
                    initialPresetId: initialPresetId,
                    purpose: purpose,
                  );
                  onResult?.call(result?.drafts);
                  onPickerResult?.call(result);
                },
                child: const Text('öffnen'),
              ),
            ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('öffnen'));
  await tester.pumpAndSettle();
}

Future<void> _apply(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('catalog-apply')));
  await tester.pumpAndSettle();
}

Future<void> _selectRow(WidgetTester tester, String name) async {
  final row = find.widgetWithText(RdListRow, name);
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  await tester.tap(row);
  await tester.pumpAndSettle();
}

final _accountProvider = StateProvider<String?>((ref) => 'account-a');
final _roleProvider = StateProvider<Role>((ref) => Role.admin);

class _ListTenantNotifier extends CurrentTenantNotifier {
  _ListTenantNotifier(super.ref, String type) {
    state = Tenant(id: 7, shortName: 'A', longName: 'Ensemble A', type: type);
  }

  void replace(Tenant tenant) => state = tenant;
}

/// Stores complete local rows; only the network boundary is replaced.
class _MemoryGroupRepo extends GroupRepository {
  _MemoryGroupRepo(super.ref, int tenantId) {
    bindTenantId(tenantId);
  }

  final storedGroups = <Group>[];
  final storedCategories = <GroupCategory>[];
  Future<void>? holdNextRead;
  Future<void>? holdNextBatch;
  bool failNextBatch = false;
  int groupsReads = 0;
  int mapReads = 0;
  int categoryReads = 0;
  int countReads = 0;

  @override
  Future<List<Group>> getGroups() async {
    groupsReads++;
    final gate = holdNextRead;
    holdNextRead = null;
    if (gate != null) await gate;
    return List.of(storedGroups);
  }

  @override
  Future<Map<int, String>> getGroupsMap() async {
    mapReads++;
    return {for (final group in storedGroups) group.id!: group.name};
  }

  @override
  Future<List<GroupCategory>> getGroupCategories() async {
    categoryReads++;
    return List.of(storedCategories);
  }

  @override
  Future<Map<int, int>> getPlayerCountsForGroups() async {
    countReads++;
    return {};
  }

  @override
  Future<GroupCategory> createGroupCategory({
    required String name,
    int? sortOrder,
  }) async {
    final category = GroupCategory(
      id: storedCategories.length + 10,
      tenantId: currentTenantId,
      name: name,
      sortOrder: sortOrder,
    );
    storedCategories.add(category);
    return category;
  }

  @override
  Future<List<Group>> createGroups(List<Map<String, dynamic>> rows) async {
    final gate = holdNextBatch;
    holdNextBatch = null;
    if (gate != null) await gate;
    if (failNextBatch) {
      failNextBatch = false;
      throw StateError('Controlled batch failure');
    }
    final result = [
      for (var i = 0; i < rows.length; i++)
        Group.fromJson({
          ...rows[i],
          'id': 100 + storedGroups.length + i,
          'tenantId': currentTenantId,
        }),
    ];
    storedGroups.addAll(result);
    return result;
  }
}

Widget _listApp(
  Map<int, _MemoryGroupRepo> repositories, {
  bool online = true,
  String tenantType = 'orchestra',
}) {
  final router = GoRouter(
    initialLocation: '/groups',
    routes: [
      GoRoute(path: '/groups', builder: (_, __) => const RdGroupsPage()),
      GoRoute(
        path: '${RedesignRoutes.groups}/:id',
        builder:
            (_, state) =>
                Scaffold(body: Text('Editor ${state.pathParameters['id']}')),
      ),
    ],
  );
  addTearDown(router.dispose);
  return ProviderScope(
    overrides: [
      currentTenantProvider.overrideWith(
        (ref) => _ListTenantNotifier(ref, tenantType),
      ),
      currentAuthUserIdProvider.overrideWith(
        (ref) => ref.watch(_accountProvider),
      ),
      effectiveRoleProvider.overrideWith((ref) => ref.watch(_roleProvider)),
      currentRoleProvider.overrideWith((ref) => ref.watch(_roleProvider)),
      connectivityCheckProvider.overrideWithValue(() async => online),
      groupRepositoryForTenantProvider.overrideWith((ref, tenantId) {
        return repositories.putIfAbsent(
          tenantId!,
          () => _MemoryGroupRepo(ref, tenantId),
        );
      }),
      groupsProvider.overrideWith(
        (ref) async => ref.watch(groupRepositoryWithTenantProvider).getGroups(),
      ),
      groupsMapProvider.overrideWith(
        (ref) async =>
            ref.watch(groupRepositoryWithTenantProvider).getGroupsMap(),
      ),
      groupCategoriesProvider.overrideWith(
        (ref) async =>
            ref.watch(groupRepositoryWithTenantProvider).getGroupCategories(),
      ),
      playerCountsForGroupsProvider.overrideWith(
        (ref) async =>
            ref
                .watch(groupRepositoryWithTenantProvider)
                .getPlayerCountsForGroups(),
      ),
    ],
    child: MaterialApp.router(
      locale: const Locale('de'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
      routerConfig: router,
    ),
  );
}
