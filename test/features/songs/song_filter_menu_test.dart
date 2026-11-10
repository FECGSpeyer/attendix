// Parity (Ionic songs.page filter popover): one row per option with an icon,
// no headings; group filter only for orchestras.
import 'package:attendix/core/theme/app_icons.dart';
import 'package:attendix/core/providers/song_filter_providers.dart';
import 'package:attendix/core/providers/song_providers.dart';
import 'package:attendix/data/models/instrument/instrument.dart';
import 'package:attendix/data/models/song/song.dart';
import 'package:attendix/features/songs/presentation/widgets/song_filter_sheet.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

SongsListData _data(String type) => SongsListData(
      tenantId: 7,
      tenantType: type,
      songs: const [],
      categories: const [SongCategory(id: 'c1', name: 'Advent')],
      groups: const [Group(id: 5, name: 'Horn')],
      groupCategories: const [],
      currentSongs: const [],
      additionalFields: const [],
    );

Future<ProviderContainer> _open(WidgetTester tester, String type) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('de'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topRight,
          child: SongFilterMenu(
            data: _data(type),
            builder: (context, toggle) =>
                IconButton(icon: Icon(AppIcons.tune), onPressed: toggle),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.byIcon(AppIcons.tune));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('popover rows with icons, toggles switch in place', (tester) async {
    final container = await _open(tester, 'orchestra');
    for (final icon in [AppIcons.filterList, AppIcons.speed, AppIcons.people, AppIcons.person,
        AppIcons.sellOutlined, AppIcons.musicNote, AppIcons.visibility]) {
      expect(find.byIcon(icon), findsOneWidget);
    }
    expect(find.text('Sortierung'), findsNothing);

    await tester.tap(find.text('Chor & Orchester'));
    await tester.pumpAndSettle();
    expect(container.read(songFilterProvider(7)).withChoir, isTrue);
    expect(find.byIcon(AppIcons.people), findsOneWidget); // menu stays open
  });

  testWidgets('no group filter in choirs', (tester) async {
    await _open(tester, 'choir');
    expect(find.byIcon(AppIcons.musicNote), findsNothing);
  });
}
