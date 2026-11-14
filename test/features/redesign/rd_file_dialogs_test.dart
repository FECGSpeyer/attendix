import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/core/utils/choir_file_utils.dart';
import 'package:attendix/data/models/instrument/instrument.dart';
import 'package:attendix/features/redesign/data/rd_words.dart';
import 'package:attendix/features/redesign/presentation/widgets/work/rd_file_category_sheet.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// REDESIGN: "Für wen ist die Datei?" as a Beta sheet.
void main() {
  testWidgets('Stimme wählen und Sonstige mit Freitext', (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final results = <({int? instrumentId, String? note})?>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [rdGroupKindProvider.overrideWithValue('choir')],
        child: MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
          home: Builder(
            builder:
                (context) => TextButton(
                  onPressed: () async {
                    results.add(
                      await showRdFileCategorySheet(
                        context,
                        title: 'Sopran 1.pdf',
                        instruments: const [Group(id: 10, name: 'Sopran'), Group(id: 11, name: 'Alt')],
                        isChoir: true,
                        initialInstrumentId: kChoirAllOptionValue,
                        initialNote: '',
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Sopran 1.pdf'), findsOneWidget);
    expect(find.byKey(const Key('rd-file-category-note')), findsNothing);
    await tester.tap(find.text('Alt'));
    await tester.pump();
    await tester.tap(find.text('Fertig'));
    await tester.pumpAndSettle();
    expect(results.last, (instrumentId: 11, note: null));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rd-file-category-other')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('rd-file-category-note')), 'Klavier');
    await tester.tap(find.text('Fertig'));
    await tester.pumpAndSettle();
    expect(results.last, (instrumentId: null, note: 'Klavier'));
  });
}
