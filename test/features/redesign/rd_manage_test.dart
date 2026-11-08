import 'package:attendix/core/config/supabase_config.dart';
import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/admin_providers.dart';
import 'package:attendix/core/providers/attendance_type_providers.dart';
import 'package:attendix/core/providers/group_providers.dart';
import 'package:attendix/core/providers/parent_providers.dart';
import 'package:attendix/core/providers/player_providers.dart';
import 'package:attendix/core/providers/shift_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/providers/viewer_providers.dart';
import 'package:attendix/core/router/redesign_routes.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/data/models/person/person.dart';
import 'package:attendix/features/redesign/data/rd_manage_logic.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_manage_page.dart';
import 'package:attendix/features/redesign/presentation/shell/rd_destinations.dart';
import 'package:attendix/features/redesign/presentation/widgets/manage/rd_manage_entries.dart';
import 'package:attendix/features/redesign/presentation/widgets/rd_widgets.dart' show rdBack;
import 'package:attendix/features/settings/presentation/pages/left_players_page.dart'
    show leftPlayersProvider;
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../factories/test_factories.dart';
import '../../mocks/supabase_mocks.dart';

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

final _auth = () {
  final auth = MockGoTrueClient();
  when(() => auth.currentUser).thenReturn(null);
  when(() => auth.onAuthStateChange).thenAnswer((_) => const Stream.empty());
  return auth;
}();

class _TenantNotifier extends CurrentTenantNotifier {
  _TenantNotifier(super.ref) {
    state = TestFactories.createTenant(id: 7, shortName: 'ATTX', longName: 'Attendix Test');
  }
}

/// A conductor of an orchestra (Vorkurs tenant, organisation linked).
const _admin = RdManageAccess(
  isAdmin: true,
  isSuperAdmin: true,
  canAccessFiles: true,
  hasOrganisation: true,
  isVorkurs: true,
);

Widget _app(
  RdManageAccess access, {
  String initial = RedesignRoutes.manage,
  List<Person> left = const [],
  GoRouter? router,
}) {
  router ??= GoRouter(
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
              GoRoute(path: 'terminarten', builder: (_, __) => const Scaffold(body: Text('page beta types'))),
              GoRoute(path: 'freigaben', builder: (_, __) => const Scaffold(body: Text('page approvals'))),
              GoRoute(
                path: ':area',
                builder: (_, s) => RdManageAreaPage(area: RdManageArea.fromKey(s.pathParameters['area'])),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      supabaseAuthProvider.overrideWithValue(_auth),
      currentTenantProvider.overrideWith((ref) => _TenantNotifier(ref)),
      rdManageAccessProvider.overrideWith((ref) => access),
      rdMissingAccountsProvider.overrideWith((ref) => const []),
      playersProvider.overrideWith((ref) async => TestFactories.createPersonList(42, tenantId: 7)),
      groupsProvider.overrideWith((ref) async => const []),
      attendanceTypesProvider.overrideWith((ref) async => const []),
      shiftsProvider.overrideWith((ref) async => const []),
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

  group('who sees what', () {
    test('only Dirigent and Verantwortliche have a Verwaltung', () {
      expect(rdShowsManage(const RdManageAccess(isAdmin: true)), isTrue);
      expect(rdShowsManage(const RdManageAccess(canAccessFiles: true, showTeam: true)), isFalse);
      expect(rdManageSearchable(const RdManageAccess(canAccessFiles: true)), isEmpty);
    });

    test('five sections; moved entries only in the search', () {
      expect(rdManageAreas(_admin), RdManageArea.values);
      final rows = rdManageEntries(_admin);
      expect(rows, isNot(contains(RdManageEntry.workHistory)));
      expect(rows, isNot(contains(RdManageEntry.export)));
      expect(rdManageSearchable(_admin), containsAll([RdManageEntry.workHistory, RdManageEntry.certificates]));
      expect(rdManageEntries(_admin, area: RdManageArea.access), [
        RdManageEntry.rolesPermissions,
        RdManageEntry.admins,
        RdManageEntry.viewers,
      ]);
    });

    test('tenant features and roles switch rows on', () {
      const a = RdManageAccess(isAdmin: true, parentsEnabled: true, maintainTeachers: true, hasMissingAccounts: true);
      expect(rdManageEntries(a, area: RdManageArea.members), [
        RdManageEntry.groups,
        RdManageEntry.extraFields,
        RdManageEntry.registration,
        RdManageEntry.critical,
        RdManageEntry.teachers,
        RdManageEntry.bulkMembers,
        RdManageEntry.missingAccounts,
        RdManageEntry.archive,
      ]);
      // Off: "Noch nicht genutzt" instead of a row, still found.
      const off = RdManageAccess(isAdmin: true, isOrchestra: true);
      expect(rdManageUnused(off), [RdManageEntry.teachers, RdManageEntry.parents, RdManageEntry.sharing]);
      expect(rdManageEntries(off), isNot(contains(RdManageEntry.parents)));
      expect(rdManageSearchable(off), containsAll([RdManageEntry.teachers, RdManageEntry.parents]));
      // Groups of type "Allgemein" have no Werke tab: sharing stays a row.
      const general = RdManageAccess(isAdmin: true, isGeneral: true);
      expect(rdManageUnused(general), [RdManageEntry.parents, RdManageEntry.sharing]);
      const shared = RdManageAccess(isAdmin: true, isGeneral: true, sharingEnabled: true);
      expect(rdManageEntries(shared, area: RdManageArea.group), contains(RdManageEntry.sharing));
      expect(rdManageEntries(const RdManageAccess(isAdmin: true, sharingEnabled: true)), isNot(contains(RdManageEntry.sharing)));
      // Admins only for super admins outside the demo.
      expect(rdManageVisible(RdManageEntry.admins, a), isFalse);
      expect(rdManageVisible(RdManageEntry.admins, const RdManageAccess(isAdmin: true, isSuperAdmin: true, isDemo: true)),
          isFalse);
      expect(rdManageVisible(RdManageEntry.parents, a), isTrue);
      expect(rdManageVisible(RdManageEntry.orgPlans, a), isFalse);
    });

    test('the Dateiablage lives in the Werke tab, without one under Ich', () {
      expect(rdManageHome(RdManageEntry.fileStorage, _admin), RdManageHome.works);
      const general = RdManageAccess(isAdmin: true, isGeneral: true, canAccessFiles: true);
      expect(rdManageHome(RdManageEntry.fileStorage, general), RdManageHome.me);
      expect(rdManageVisible(RdManageEntry.workHistory, general), isFalse);
      expect(rdMeShowsFiles(canAccessFiles: true, hasWorksTab: false), isTrue);
      expect(rdMeShowsFiles(canAccessFiles: true, hasWorksTab: true), isFalse);
    });
  });

  group('routes', () {
    test('only leads open the Verwaltung; helpers keep the Werkhistorie', () {
      expect(RedesignRoutes.roleRedirect(RedesignRoutes.manage, Role.responsible), isNull);
      expect(RedesignRoutes.roleRedirect(RedesignRoutes.admins, Role.responsible), RedesignRoutes.manage);
      for (final role in [Role.helper, Role.player, Role.voiceLeader, Role.viewer, Role.parent, Role.applicant]) {
        expect(RedesignRoutes.roleRedirect(RedesignRoutes.manage, role), RedesignRoutes.me, reason: role.name);
        expect(RedesignRoutes.roleRedirect(RedesignRoutes.stats, role), RedesignRoutes.me, reason: role.name);
      }
      expect(RedesignRoutes.roleRedirect(RedesignRoutes.workHistory, Role.helper), isNull);
      expect(RedesignRoutes.roleRedirect(RedesignRoutes.workHistory, Role.player), RedesignRoutes.me);
      expect(RedesignRoutes.roleRedirect(RedesignRoutes.teachers, Role.viewer), isNull);
      expect(RedesignRoutes.roleRedirect(RedesignRoutes.teacherEdit(3), Role.viewer), RedesignRoutes.teachers);
    });

    test('Werkhistorie belongs to the Werke tab; Ich pages are not the Verwaltung', () {
      expect(rdTabForLocation(RedesignRoutes.workHistory), RdTab.works);
      expect(rdTabForLocation(RedesignRoutes.workCategories), RdTab.works);
      expect(rdIsManageLocation(RedesignRoutes.groups), isTrue);
      expect(rdIsManageLocation('/settings/general'), isTrue);
      expect(rdIsManageLocation('/export'), isTrue);
      expect(rdIsManageLocation('/settings/team-organization'), isFalse);
      expect(rdIsManageLocation(RedesignRoutes.workHistory), isFalse);
      expect(rdIsManageLocation(RedesignRoutes.me), isFalse);
    });
  });

  testWidgets('back from a page opened by its URL leads to its tab, not to the routes beneath', (tester) async {
    GoRouter router(String initial) => GoRouter(
          initialLocation: initial,
          routes: [
            ShellRoute(
              builder: (_, __, child) => child,
              routes: [
                GoRoute(path: RedesignRoutes.works, builder: (_, __) => const Text('works')),
                GoRoute(
                  path: RedesignRoutes.me,
                  builder: (_, __) => const Text('me'),
                  routes: [
                    GoRoute(
                      path: 'verwaltung',
                      builder: (_, __) => const Text('manage'),
                      routes: [
                        GoRoute(
                          path: 'werkhistorie',
                          builder: (context, __) => GestureDetector(
                            onTap: () => rdBack(context, RedesignRoutes.works),
                            child: const Text('back'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
    // Reload or link: Ich › Verwaltung is built beneath, back still leads
    // to the Werke tab.
    await tester.pumpWidget(MaterialApp.router(routerConfig: router(RedesignRoutes.workHistory)));
    await tester.tap(find.text('back'));
    await tester.pumpAndSettle();
    expect(find.text('works'), findsOneWidget);

    // Pushed (from the Werke tab's "•••"): back returns where it came from.
    final pushed = router(RedesignRoutes.me);
    await tester.pumpWidget(MaterialApp.router(key: UniqueKey(), routerConfig: pushed));
    pushed.push(RedesignRoutes.workHistory);
    await tester.pumpAndSettle();
    await tester.tap(find.text('back'));
    await tester.pumpAndSettle();
    expect(find.text('me'), findsOneWidget);
  });

  group('Verwaltung page', () {
    testWidgets('the group on top, then the sections with their rows', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(_admin, left: TestFactories.createPersonList(4, tenantId: 7)));
      await _settle(tester);

      expect(find.text('Attendix Test'), findsOneWidget);
      expect(find.text('Orchester · 42 Mitglieder · ATTX'), findsOneWidget);
      expect(find.text('MITGLIEDER'), findsOneWidget);
      expect(find.text('Register'), findsOneWidget);
      expect(find.text('Archiv'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('Anmeldung per Link'), findsOneWidget);
      // What moved is not a row any more.
      expect(find.text('Gespielte Werke'), findsNothing);
      expect(find.text('Alle Einstellungen (bisherige Ansicht)'), findsNothing);
      final page = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.text('Organisation'), 300, scrollable: page);
      expect(find.text('Terminarten'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('Terminarten'));
      await tester.pump();
      await tester.tap(find.text('Terminarten'));
      await _settle(tester);
      expect(find.text('page beta types'), findsOneWidget);
    });

    testWidgets('search finds moved entries, old names and remembers them', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(_admin));
      await _settle(tester);

      await tester.enterText(find.byType(TextField), 'werkhistorie');
      await _settle(tester);
      expect(find.text('Gespielte Werke'), findsOneWidget);
      expect(find.text('Im Werke-Tab unter ••• · früher „Werkhistorie“'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'gruppen');
      await _settle(tester);
      expect(find.text('Register'), findsOneWidget);

      // A switch of the old "Allgemein" leads to its new place.
      await tester.enterText(find.byType(TextField), 'saisonbeginn');
      await _settle(tester);
      expect(find.text('Auswertung und Mitteilungen · Saisonbeginn'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'allgemein');
      await _settle(tester);
      expect(find.text('Termine · früher „Allgemeine Einstellungen“'), findsNWidgets(2));
      expect(find.text('Auswertung und Mitteilungen · Schalter aus „Allgemeine Einstellungen“'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'urk');
      await _settle(tester);
      expect(find.text('Urkunden'), findsOneWidget);
      expect(find.text('In der Auswertung · früher „Urkunden generieren“'), findsNothing);

      // Freigaben moved to the Mitglieder tab; the search still opens it.
      await tester.enterText(find.byType(TextField), 'freigaben');
      await _settle(tester);
      expect(find.text('Im Mitglieder-Tab'), findsOneWidget);
      await tester.tap(find.text('Freigaben'));
      await _settle(tester);
      expect(find.text('page approvals'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(rdManageRecentStorageKey), ['approvals']);
    });

    testWidgets('wide screens: every entry on the left, its page on the right', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Page<void> split(RdManageEntry entry, String text) => NoTransitionPage<void>(
            key: const ValueKey('rd-manage-split'),
            child: RdManageSplit(entry: entry, detail: Text(text)),
          );
      final router = GoRouter(
        initialLocation: RedesignRoutes.manage,
        routes: [
          GoRoute(
            path: '/ich',
            builder: (_, __) => const Scaffold(body: Text('page me')),
            routes: [
              GoRoute(
                path: 'verwaltung',
                builder: (_, __) => const RdManageSplit(),
                routes: [
                  GoRoute(path: 'gruppen', pageBuilder: (_, __) => split(RdManageEntry.groups, 'page groups')),
                  GoRoute(path: 'terminarten', pageBuilder: (_, __) => split(RdManageEntry.attendanceTypes, 'page types')),
                ],
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(_app(_admin, router: router));
      await _settle(tester);
      // Nothing chosen: the group on the right, all entries on the left.
      expect(find.text('Attendix Test'), findsOneWidget);
      expect(find.text('Wähle links einen Eintrag, er öffnet sich hier.'), findsOneWidget);
      expect(find.text('Terminarten'), findsOneWidget);
      expect(find.text('Rollen und Rechte'), findsOneWidget);

      await tester.tap(find.text('Register'));
      await _settle(tester);
      expect(find.text('page groups'), findsOneWidget);
      expect(find.text('Attendix Test'), findsNothing);

      // The list stays; the next entry replaces the page on the right.
      await tester.enterText(find.byType(TextField), 'termin');
      await _settle(tester);
      await tester.tap(find.text('Terminarten'));
      await _settle(tester);
      expect(find.text('page types'), findsOneWidget);
      expect(find.text('page groups'), findsNothing);
      expect(find.widgetWithText(TextField, 'termin'), findsOneWidget);
      expect(router.routerDelegate.currentConfiguration.uri.path, RedesignRoutes.attendanceTypes);
    });

    testWidgets('a section page (old link)', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(_admin, initial: '/ich/verwaltung/zugaenge'));
      await _settle(tester);
      expect(find.text('Zugänge und Rechte'), findsOneWidget);
      expect(find.text('Rollen und Rechte'), findsOneWidget);
      expect(find.text('Admins'), findsOneWidget);
      expect(find.text('Register'), findsNothing);

      await tester.pumpWidget(_app(_admin, initial: '/ich/verwaltung/gibtsnicht'));
      await _settle(tester);
      expect(find.text('Keine Einstellung passt zur Suche.'), findsOneWidget);
    });
  });
}
