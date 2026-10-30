import 'dart:io';

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/admin_providers.dart';
import 'package:attendix/core/providers/parent_providers.dart';
import 'package:attendix/core/providers/viewer_providers.dart';
import 'package:attendix/core/router/redesign_routes.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/data/models/person/person.dart';
import 'package:attendix/features/redesign/data/rd_manage_logic.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_manage_page.dart';
import 'package:attendix/features/redesign/presentation/widgets/manage/rd_manage_entries.dart';
import 'package:attendix/features/settings/presentation/pages/left_players_page.dart'
    show leftPlayersProvider;
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../factories/test_factories.dart';

/// Bounded pumps: loading spinners never settle.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await _settle(tester);
}

/// A conductor of an orchestra (Vorkurs tenant, organisation linked).
const _admin = RdManageAccess(
  isAdmin: true,
  isSuperAdmin: true,
  canOpenWorks: true,
  canAccessFiles: true,
  hasOrganisation: true,
  hasPending: true,
  isVorkurs: true,
);

const _helper = RdManageAccess(isHelper: true, canOpenWorks: true);

const _player = RdManageAccess(canOpenWorks: true);

Widget _app(
  RdManageAccess access, {
  String initial = RedesignRoutes.manage,
  List<Person> pending = const [],
  List<Person> left = const [],
}) {
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/ich',
        builder: (_, __) => const Scaffold(body: Text('page me')),
        routes: [
          GoRoute(
            path: 'verwaltung',
            builder: (_, __) => const RdManagePage(),
            routes: [
              GoRoute(
                path: ':area',
                builder: (_, s) =>
                    RdManageAreaPage(area: RdManageArea.fromKey(s.pathParameters['area'])),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const Scaffold(body: Text('page old settings')),
        routes: [
          GoRoute(path: 'types', builder: (_, __) => const Scaffold(body: Text('page types'))),
        ],
      ),
      GoRoute(path: '/werke', builder: (_, __) => const Scaffold(body: Text('page works'))),
    ],
  );
  return ProviderScope(
    overrides: [
      rdManageAccessProvider.overrideWith((ref) => access),
      rdManagePendingProvider.overrideWith((ref) => pending),
      rdMissingAccountsProvider.overrideWith((ref) => const []),
      adminsProvider.overrideWith((ref) async => const []),
      parentsProvider.overrideWith((ref) async => const []),
      viewersProvider.overrideWith((ref) async => const []),
      leftPlayersProvider.overrideWith((ref) async => left),
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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('visibility (same rules as the old settings page)', () {
    test('a conductor sees all six areas', () {
      expect(rdManageAreas(_admin), RdManageArea.values);
      final entries = rdManageEntries(_admin);
      expect(entries, containsAll([
        RdManageEntry.approvals,
        RdManageEntry.admins,
        RdManageEntry.rolesPermissions,
        RdManageEntry.attendanceTypes,
        RdManageEntry.planningTemplates,
        RdManageEntry.workCategories,
        RdManageEntry.certificates,
        RdManageEntry.organisation,
      ]));
      // Tenant features that are off.
      expect(entries, isNot(contains(RdManageEntry.parents)));
      expect(entries, isNot(contains(RdManageEntry.teachers)));
      expect(entries, isNot(contains(RdManageEntry.missingAccounts)));
      expect(entries, isNot(contains(RdManageEntry.myVoice)));
      expect(entries, isNot(contains(RdManageEntry.teamOrg)));
    });

    test('Administratoren only for admins outside the demo', () {
      const responsible = RdManageAccess(isAdmin: true);
      expect(rdManageVisible(RdManageEntry.admins, responsible), isFalse);
      expect(rdManageVisible(RdManageEntry.admins, const RdManageAccess(isAdmin: true, isSuperAdmin: true)), isTrue);
      expect(
        rdManageVisible(RdManageEntry.admins, const RdManageAccess(isAdmin: true, isSuperAdmin: true, isDemo: true)),
        isFalse,
      );
    });

    test('tenant features switch entries on', () {
      const a = RdManageAccess(isAdmin: true, parentsEnabled: true, maintainTeachers: true, hasMissingAccounts: true);
      expect(rdManageEntries(a, area: RdManageArea.members), [
        RdManageEntry.bulkMembers,
        RdManageEntry.rolesPermissions,
        RdManageEntry.parents,
        RdManageEntry.viewers,
        RdManageEntry.teachers,
        RdManageEntry.missingAccounts,
        RdManageEntry.archive,
      ]);
      expect(rdManageVisible(RdManageEntry.planningTemplates, a), isFalse);
      expect(rdManageVisible(RdManageEntry.certificates, a), isFalse);
      expect(rdManageVisible(RdManageEntry.approvals, a), isFalse);
    });

    test('a general tenant has no Werke entries, but its Dateiablage', () {
      const a = RdManageAccess(isAdmin: true, isGeneral: true, canOpenWorks: true, canAccessFiles: true);
      final works = rdManageEntries(a, area: RdManageArea.works);
      expect(works, [RdManageEntry.groups, RdManageEntry.fileStorage]);
      const voice = RdManageAccess(isVoiceLeader: true, isGeneral: true);
      expect(rdManageVisible(RdManageEntry.myVoice, voice), isFalse);
      expect(rdManageVisible(RdManageEntry.myVoice, const RdManageAccess(isVoiceLeader: true)), isTrue);
    });

    test('helpers keep the Werkhistorie, players only what has a place elsewhere', () {
      expect(rdManageEntries(_helper), [
        RdManageEntry.works,
        RdManageEntry.workHistory,
        RdManageEntry.calendar,
      ]);
      expect(rdShowsManage(_helper), isTrue);
      expect(rdManageEntries(_player), [RdManageEntry.works, RdManageEntry.calendar]);
      expect(rdShowsManage(_player), isFalse);
      expect(rdShowsManage(const RdManageAccess(isAdmin: true)), isTrue);
    });

    test('applicants see nothing', () {
      const a = RdManageAccess(isApplicant: true, canAccessFiles: true);
      expect(rdManageEntries(a), isEmpty);
      expect(rdShowsManage(a), isFalse);
      // Even an applicant admin gets no planning, statistics or archive.
      const lead = RdManageAccess(isApplicant: true, isAdmin: true);
      for (final e in [
        RdManageEntry.runSheets,
        RdManageEntry.statistics,
        RdManageEntry.export,
        RdManageEntry.archive,
        RdManageEntry.bulkMembers,
        RdManageEntry.workHistory,
      ]) {
        expect(rdManageVisible(e, lead), isFalse, reason: e.name);
      }
    });

    test('team organisation: leader, circle and own tasks', () {
      const leader = RdManageAccess(teamOrgEnabled: true, isTeamLeader: true);
      expect(rdManageEntries(leader, area: RdManageArea.communication), [RdManageEntry.teamOrg]);
      const circle = RdManageAccess(teamOrgEnabled: true, inTeamCircle: true);
      expect(rdManageEntries(circle, area: RdManageArea.communication), [
        RdManageEntry.myTasks,
        RdManageEntry.suggestTopic,
        RdManageEntry.protocols,
      ]);
      const tasks = RdManageAccess(teamOrgEnabled: true, hasOwnTasks: true);
      expect(rdManageEntries(tasks, area: RdManageArea.communication), [RdManageEntry.myTasks]);
      expect(rdShowsManage(tasks), isTrue);
      const off = RdManageAccess(inTeamCircle: true, isTeamLeader: true);
      expect(rdManageEntries(off, area: RdManageArea.communication), isEmpty);
    });
  });

  group('search and recent entries', () {
    test('matches title, area and hint, every word', () {
      expect(rdManageMatches('urk', 'Urkunden generieren', 'Auswertung & Daten'), isTrue);
      expect(rdManageMatches('daten export', 'Export', 'Auswertung & Daten'), isTrue);
      expect(rdManageMatches('saison', 'Allgemeine Einstellungen', 'Gruppe', 'Name, Saison'), isTrue);
      expect(rdManageMatches('xyz', 'Export', 'Auswertung & Daten'), isFalse);
      expect(rdManageMatches('  ', 'Export', 'Auswertung & Daten'), isTrue);
    });

    test('recent: newest first, no duplicates, at most three', () {
      var recent = <RdManageEntry>[];
      recent = rdPushRecent(recent, RdManageEntry.export);
      recent = rdPushRecent(recent, RdManageEntry.statistics);
      recent = rdPushRecent(recent, RdManageEntry.export);
      expect(recent, [RdManageEntry.export, RdManageEntry.statistics]);
      recent = rdPushRecent(recent, RdManageEntry.groups);
      recent = rdPushRecent(recent, RdManageEntry.general);
      expect(recent, [RdManageEntry.general, RdManageEntry.groups, RdManageEntry.export]);
    });

    test('area keys are the path segments', () {
      expect(RdManageArea.fromKey('termine'), RdManageArea.events);
      expect(RdManageArea.fromKey('gruppe'), RdManageArea.group);
      expect(RdManageArea.fromKey('x'), isNull);
      expect(RedesignRoutes.manageArea('daten'), '/ich/verwaltung/daten');
    });
  });

  group('Verwaltung page', () {
    testWidgets('areas, waiting approvals and the footer', (tester) async {
      _phone(tester);
      final pending = [TestFactories.createPerson(id: 1), TestFactories.createPerson(id: 2)];
      await tester.pumpWidget(_app(_admin, pending: pending));
      await _settle(tester);

      expect(find.text('Verwaltung'), findsOneWidget);
      expect(find.text('Einstellung suchen'), findsOneWidget);
      expect(find.text('2 Personen warten auf Freigabe'), findsOneWidget);
      for (final area in [
        'Mitglieder & Rollen',
        'Termine & Planung',
        'Werke, Register & Dateien',
        'Auswertung & Daten',
        'Kommunikation',
        'Gruppe',
      ]) {
        expect(find.text(area), findsOneWidget, reason: area);
      }
      expect(find.text('Anwesenheits-Typen, Schichtpläne, Zusatzfelder, Ablaufpläne …'), findsOneWidget);
      final count = rdManageEntries(_admin).length;
      await tester.ensureVisible(find.textContaining('bisherigen Einträge'));
      expect(find.text('Alle $count bisherigen Einträge stecken in diesen Bereichen und sind über die Suche direkt erreichbar.'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an area lists its entries and opens the old page', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(_admin));
      await _settle(tester);

      await _tapVisible(tester, find.text('Termine & Planung'));
      expect(find.text('Anwesenheits-Typen'), findsOneWidget);
      expect(find.text('Schichtpläne'), findsOneWidget);
      expect(find.text('Ablaufpläne'), findsOneWidget);
      expect(find.text('Planvorlagen & Felder'), findsOneWidget);

      await _tapVisible(tester, find.text('Anwesenheits-Typen'));
      expect(find.text('page types'), findsOneWidget);
    });

    testWidgets('Mitglieder & Rollen shows the counts', (tester) async {
      _phone(tester);
      final pending = [TestFactories.createPerson(id: 1), TestFactories.createPerson(id: 2)];
      final left = TestFactories.createPersonList(4, tenantId: 7);
      await tester.pumpWidget(_app(_admin, initial: '/ich/verwaltung/mitglieder', pending: pending, left: left));
      await _settle(tester);

      expect(find.text('Mitglieder & Rollen'), findsOneWidget);
      expect(find.text('Freigaben'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Archiv'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('Administratoren'), findsOneWidget);
      expect(find.text('Eltern'), findsNothing);
    });

    testWidgets('search finds entries across areas', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(_admin));
      await _settle(tester);

      await tester.enterText(find.byType(TextField), 'urk');
      await _settle(tester);
      expect(find.text('Urkunden generieren'), findsOneWidget);
      expect(find.text('Auswertung & Daten'), findsOneWidget);
      expect(find.text('Kommunikation'), findsNothing);

      await tester.enterText(find.byType(TextField), 'kommunikation');
      await _settle(tester);
      expect(find.text('Mitteilungen'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'xyz');
      await _settle(tester);
      expect(find.text('Keine Einstellung passt zur Suche.'), findsOneWidget);
    });

    testWidgets('search shows the recently opened entries', (tester) async {
      _phone(tester);
      SharedPreferences.setMockInitialValues({
        rdManageRecentStorageKey: ['export', 'unknown', 'statistics'],
      });
      await tester.pumpWidget(_app(_admin));
      await _settle(tester);
      expect(find.text('ZULETZT GEÖFFNET'), findsNothing);

      await tester.tap(find.byType(TextField));
      await _settle(tester);
      expect(find.text('ZULETZT GEÖFFNET'), findsOneWidget);
      expect(find.text('Export'), findsOneWidget);
      expect(find.text('Statistiken'), findsOneWidget);
    });

    testWidgets('opening an entry remembers it', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(_admin));
      await _settle(tester);

      await tester.enterText(find.byType(TextField), 'werke');
      await _settle(tester);
      await _tapVisible(tester, find.text('Werke'));
      expect(find.text('page works'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(rdManageRecentStorageKey), ['works']);
    });

    testWidgets('a helper sees only the Werke area and the data area', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(_helper));
      await _settle(tester);

      expect(find.text('Werke, Register & Dateien'), findsOneWidget);
      expect(find.text('Auswertung & Daten'), findsOneWidget);
      expect(find.text('Mitglieder & Rollen'), findsNothing);
      expect(find.textContaining('warten auf Freigabe'), findsNothing);
    });

    testWidgets('the previous settings stay reachable', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(_admin));
      await _settle(tester);

      await _tapVisible(tester, find.text('Alle Einstellungen (bisherige Ansicht)'));
      expect(find.text('page old settings'), findsOneWidget);
    });

    testWidgets('an unknown area shows a hint', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(_admin, initial: '/ich/verwaltung/gibtsnicht'));
      await _settle(tester);
      expect(find.text('Keine Einstellung passt zur Suche.'), findsOneWidget);
    });
  });

  group('wiring', () {
    test('Ich, the sidebar and the router lead to the Verwaltung', () {
      final me = File('lib/features/redesign/presentation/pages/rd_me_page.dart').readAsStringSync();
      expect(me, contains('context.push(RedesignRoutes.manage)'));
      expect(me, contains('rdShowsManage('));
      final shell = File('lib/features/redesign/presentation/shell/rd_shell.dart').readAsStringSync();
      expect(shell, contains('RedesignRoutes.manage'));
      final router = File('lib/core/router/app_router.dart').readAsStringSync();
      expect(router, contains('RdManagePage()'));
      expect(router, contains('RdManageAreaPage('));
    });

    test('applicants and parents are sent back from the Verwaltung', () {
      expect(RedesignRoutes.roleRedirect('/ich/verwaltung', Role.applicant), RedesignRoutes.me);
      expect(RedesignRoutes.roleRedirect('/ich/verwaltung/daten', Role.parent), RedesignRoutes.me);
      expect(RedesignRoutes.roleRedirect('/ich/verwaltung', Role.admin), isNull);
      expect(RedesignRoutes.roleRedirect('/ich/verwaltung', Role.helper), isNull);
      expect(RedesignRoutes.roleRedirect('/ich', Role.applicant), isNull);
    });
  });
}
