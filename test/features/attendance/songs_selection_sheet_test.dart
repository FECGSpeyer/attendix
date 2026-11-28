import 'package:attendix/core/providers/conductor_providers.dart';
import 'package:attendix/core/providers/song_providers.dart';
import 'package:attendix/core/theme/app_palette.dart';
import 'package:attendix/core/theme/design_theme.dart';
import 'package:attendix/data/models/person/person.dart';
import 'package:attendix/data/models/song/song.dart';
import 'package:attendix/features/attendance/presentation/widgets/songs_selection_sheet.dart';
import 'package:attendix/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Werke hinzufügen: Dirigent unter dem Werk, ein abweichender in der Link-Farbe', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    List<SongHistoryEntry>? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeConductorsProvider.overrideWith(
            (_) async => const [
              Person(id: 1, firstName: 'Anna', lastName: 'Admin'),
              Person(id: 2, firstName: 'Vera', lastName: 'Verantwortlich'),
            ],
          ),
          songsProvider.overrideWith(
            (_) async => const [
              Song(id: 1, number: 1, name: 'Ode an die Freude'),
              Song(id: 2, number: 2, name: 'Restwert'),
            ],
          ),
          songCollectionsProvider.overrideWith((_) async => null),
        ],
        child: MaterialApp(
          theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('de'),
          home: Builder(
            builder:
                (context) => TextButton(
                  onPressed: () async => result = await SongsSelectionSheet.show(context, existingEntries: const []),
                  child: const Text('go'),
                ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 Ode an die Freude'));
    await tester.tap(find.text('2 Restwert'));
    await tester.tap(find.byKey(const Key('rd-songs-picker-apply')));
    await tester.pumpAndSettle();

    // The Werke are chosen, the sheet asks for the Dirigent; the count is on the button only.
    expect(find.text('Wer dirigiert?'), findsOneWidget);
    expect(find.text('2 Werke hinzufügen'), findsOneWidget);

    Text conductor(int songId, String name) =>
        tester.widget<Text>(find.descendant(of: find.byKey(Key('rd-songs-row-$songId')), matching: find.text(name)));
    final p = tester.element(find.byKey(const Key('rd-songs-row-1'))).rd;
    expect(conductor(1, 'Anna Admin').style?.color, p.text2);

    await tester.tap(find.byKey(const Key('rd-songs-row-1')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byKey(const Key('rd-songs-row-1')), matching: find.text('Vera Verantwortlich')),
    );
    await tester.pumpAndSettle();

    expect(conductor(1, 'Vera Verantwortlich').style?.color, p.link);
    expect(conductor(2, 'Anna Admin').style?.color, p.text2);

    await tester.tap(find.byKey(const Key('rd-songs-add')));
    await tester.pumpAndSettle();
    expect(result!.map((e) => '${e.songId}:${e.conductorId}'), ['1:2', '2:1']);
  });
}
