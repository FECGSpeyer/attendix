import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/debug_providers.dart';
import 'package:attendix/core/providers/realtime_providers.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/data/models/person/person.dart';
import 'package:attendix/data/models/song/song.dart';
import 'package:attendix/features/redesign/data/rd_overview_logic.dart';
import 'package:attendix/features/redesign/presentation/widgets/rd_overview.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../factories/test_factories.dart';

const _pdf = SongFile(fileName: 'a.pdf', fileType: 'application/pdf', url: 'https://x/a.pdf');

void main() {
  final now = DateTime(2026, 10, 31, 20);

  group('rdWorksOverview', () {
    test('counts, the nearest planned day, missing files, longest ago', () {
      final o = rdWorksOverview([
        const Song(id: 1, name: 'A', files: [_pdf], lastSung: '2026-01-01', nextPlanned: '2026-11-08'),
        const Song(id: 2, name: 'B', lastSung: '2025-03-01', nextPlanned: '2026-11-03'),
        const Song(id: 3, name: 'C', files: [_pdf], nextPlanned: '2026-11-03'),
        const Song(id: 4, name: 'D', files: [], lastSung: '2024-02-01'),
        const Song(id: 5, name: 'E', files: [_pdf], lastSung: '2026-10-01', nextPlanned: '2026-10-20'),
      ], now: now);
      expect(o.total, 5);
      expect(o.withFiles, 3);
      expect(o.withoutFiles, 2);
      expect(o.nextDate, DateTime(2026, 11, 3));
      expect(o.next.map((s) => s.id), [2, 3]);
      expect(o.missing.map((s) => s.id), [2, 4]);
      // 1 and 2 are planned again; 5's plan is in the past.
      expect(o.longAgo.map((s) => s.id), [4, 5]);
    });

    test('nothing planned, nothing played', () {
      final o = rdWorksOverview(const [Song(id: 1, name: 'A')], now: now);
      expect(o.nextDate, isNull);
      expect(o.next, isEmpty);
      expect(o.longAgo, isEmpty);
    });
  });

  group('rdMembersOverview', () {
    test('active / paused, birthdays within 30 days nearest first, critical active only', () {
      final people = [
        TestFactories.createPerson(id: 1, firstName: 'Anna', lastName: 'Zeller').copyWith(birthday: '1990-11-20'),
        TestFactories.createPerson(
          id: 2,
          firstName: 'Ben',
          lastName: 'Adam',
        ).copyWith(birthday: '1985-10-31', isCritical: true),
        TestFactories.createPerson(id: 3, firstName: 'Cleo', lastName: 'Berg').copyWith(birthday: '2000-01-15'),
        TestFactories.createPausedPerson(id: 4).copyWith(birthday: '1999-11-01', isCritical: true),
      ];
      final o = rdMembersOverview(people, now: now);
      expect(o.active, 3);
      expect(o.paused, 1);
      expect(o.birthdays.map((b) => (b.person.id, b.days)), [(2, 0), (1, 20)]);
      expect(o.critical.map((x) => x.id), [2]);
    });
  });

  group('RdMembersOverviewPanel', () {
    Widget app(Role role, List<Person> people, List<Person> pending) {
      final router = GoRouter(
        initialLocation: '/mitglieder',
        routes: [
          GoRoute(
            path: '/mitglieder',
            builder: (_, __) => const RdMembersOverviewPanel(),
            routes: [GoRoute(path: ':id', builder: (_, s) => Scaffold(body: Text('person ${s.pathParameters['id']}')))],
          ),
        ],
      );
      return ProviderScope(
        overrides: [
          effectiveRoleProvider.overrideWithValue(role),
          realtimePlayersProvider.overrideWith((ref) => Stream.value(people)),
          realtimePendingPlayersProvider.overrideWith((ref) => Stream.value(pending)),
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

    Finder stat(String label) => find.byWidgetPredicate((w) => w is Semantics && w.properties.label == label);

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    final today = DateTime.now();
    final soon = DateTime(1990, today.month, today.day).add(const Duration(days: 2));
    final people = [
      TestFactories.createPerson(
        id: 1,
        firstName: 'Anna',
        lastName: 'Zeller',
      ).copyWith(birthday: soon.toIso8601String(), isCritical: true),
      TestFactories.createPausedPerson(id: 2),
    ];

    testWidgets('leads: counts with requests, birthdays, critical; a row opens the person', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(Role.admin, people, [TestFactories.createPerson(id: 9)]));
      await settle(tester);
      expect(find.text('Überblick'), findsOneWidget);
      expect(stat('1 aktiv'), findsOneWidget);
      expect(stat('1 pausiert'), findsOneWidget);
      expect(stat('1 Anfragen'), findsOneWidget);
      expect(find.text('NÄCHSTE GEBURTSTAGE'), findsOneWidget);
      expect(find.text('AUFFÄLLIGE ANWESENHEIT'), findsOneWidget);
      await tester.tap(find.text('Anna Zeller').first);
      await settle(tester);
      expect(find.text('person 1'), findsOneWidget);
    });

    testWidgets('players: no requests, no attendance warnings', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(Role.player, people, const []));
      await settle(tester);
      expect(stat('1 aktiv'), findsOneWidget);
      expect(find.textContaining('Anfragen'), findsNothing);
      expect(find.text('AUFFÄLLIGE ANWESENHEIT'), findsNothing);
      expect(find.text('NÄCHSTE GEBURTSTAGE'), findsOneWidget);
    });
  });
}
