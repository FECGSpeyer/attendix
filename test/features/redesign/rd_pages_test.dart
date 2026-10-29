import 'package:attendix/core/providers/redesign_providers.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_appearance_page.dart';
import 'package:attendix/features/redesign/presentation/widgets/today/rd_leader_today.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../factories/test_factories.dart';

/// Pumps [child] like main.dart does while the Beta is on.
class _App extends ConsumerWidget {
  const _App(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(redesignSettingsProvider);
    return MaterialApp(
      locale: const Locale('de'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildRdTheme(s.world, Brightness.light),
      darkTheme: buildRdTheme(s.world, Brightness.dark),
      themeMode: s.themeMode,
      home: child,
    );
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Darstellung: choosing a Farbwelt recolours the app', (tester) async {
    tester.view.physicalSize = const Size(393, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialRedesignSettingsProvider
              .overrideWithValue(const RedesignSettings(enabled: true)),
        ],
        child: const _App(RdAppearancePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Darstellung'), findsOneWidget);
    for (final name in ['Petrol', 'Konzertsaal', 'Nachtblau', 'Klar', 'Bühne']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    final petrol = rdPalette(RdFarbwelt.petrol, Brightness.light);
    expect(Theme.of(tester.element(find.text('Darstellung'))).scaffoldBackgroundColor, petrol.bg);

    await tester.tap(find.text('Konzertsaal'));
    await tester.pumpAndSettle();
    final context = tester.element(find.text('Darstellung'));
    expect(context.rd.primary, rdPalette(RdFarbwelt.konzertsaal, Brightness.light).primary);

    // Bühne: always dark, the brightness choice is locked.
    await tester.tap(find.text('Bühne'));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.text('Darstellung'))).brightness, Brightness.dark);
    expect(find.text('Bühne ist immer dunkel.'), findsOneWidget);
  });

  test('Heute: upcoming Termine soonest first, ended ones left out', () {
    final now = DateTime(2026, 10, 29, 12);
    final list = [
      TestFactories.createAttendance(id: 1, date: '2026-11-02', startTime: '19:00'),
      TestFactories.createAttendance(id: 2, date: '2026-10-29', startTime: '19:30'),
      TestFactories.createAttendance(id: 3, date: '2026-10-20'),
      TestFactories.createAttendance(id: 4, date: '2026-10-29', startTime: '09:00'),
    ];
    expect(RdLeaderToday.upcomingOf(list, now: now).map((a) => a.id), [4, 2, 1]);
  });
}
