import 'dart:async';

import 'package:attendix/core/config/supabase_config.dart' show currentAuthUserIdProvider;
import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/admin_providers.dart';
import 'package:attendix/core/providers/parent_providers.dart';
import 'package:attendix/core/providers/realtime_providers.dart';
import 'package:attendix/core/providers/viewer_providers.dart';
import 'package:attendix/core/router/redesign_routes.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/data/models/parent/parent_model.dart';
import 'package:attendix/data/models/person/person.dart';
import 'package:attendix/data/models/viewer/viewer.dart';
import 'package:attendix/data/repositories/admin_repository.dart' show TenantAdmin;
import 'package:attendix/features/redesign/presentation/pages/rd_admins_page.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_archive_page.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_parents_page.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_pending_page.dart';
import 'package:attendix/features/redesign/presentation/widgets/manage/rd_manage_list.dart' show rdLoadedValue;
import 'package:attendix/features/settings/presentation/pages/left_players_page.dart' show leftPlayersProvider;
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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

Widget _app(Widget child, List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    locale: const Locale('de'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
    home: child,
  ),
);

void main() {
  group('Routes', () {
    test('Admins only for super admins, the other lists for leads', () {
      for (final route in [
        RedesignRoutes.parents,
        RedesignRoutes.viewers,
        RedesignRoutes.archive,
        RedesignRoutes.approvals,
      ]) {
        expect(RedesignRoutes.roleRedirect(route, Role.admin), isNull, reason: route);
        expect(RedesignRoutes.roleRedirect(route, Role.responsible), isNull, reason: route);
        expect(RedesignRoutes.roleRedirect(route, Role.helper), RedesignRoutes.manage, reason: route);
        expect(RedesignRoutes.roleRedirect(route, Role.player), RedesignRoutes.manage, reason: route);
        expect(RedesignRoutes.roleRedirect('$route/x', Role.viewer), RedesignRoutes.manage, reason: route);
        expect(RedesignRoutes.roleRedirect(route, Role.parent), RedesignRoutes.me, reason: route);
      }
      expect(RedesignRoutes.roleRedirect(RedesignRoutes.admins, Role.admin), isNull);
      expect(RedesignRoutes.roleRedirect(RedesignRoutes.admins, Role.responsible), RedesignRoutes.manage);
      expect(RedesignRoutes.roleRedirect(RedesignRoutes.admins, Role.helper), RedesignRoutes.manage);
      expect(RedesignRoutes.admins, '/ich/verwaltung/admins');
      expect(RedesignRoutes.parents, '/ich/verwaltung/eltern');
      expect(RedesignRoutes.viewers, '/ich/verwaltung/beobachter');
      expect(RedesignRoutes.archive, '/ich/verwaltung/archiv');
      expect(RedesignRoutes.approvals, '/ich/verwaltung/freigaben');
    });
  });

  testWidgets('Admins: list, own entry marked, a tap offers "Admin entfernen"', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      _app(const RdAdminsPage(), [
        adminsProvider.overrideWith(
          (ref) async => [
            TenantAdmin(userId: 'me', email: 'ich@test.de', createdAt: DateTime(2025, 3, 4)),
            const TenantAdmin(userId: 'u2', email: 'anna@test.de'),
          ],
        ),
        currentAuthUserIdProvider.overrideWithValue('me'),
      ]),
    );
    await _settle(tester);

    expect(find.text('Administratoren'), findsOneWidget);
    expect(find.text('ich@test.de'), findsOneWidget);
    expect(find.textContaining('Das bist du'), findsOneWidget);
    expect(find.text('anna@test.de'), findsOneWidget);
    expect(find.byKey(const Key('rd-manage-list-add')), findsOneWidget);

    await tester.tap(find.text('anna@test.de'));
    await _settle(tester);
    expect(find.text('Admin entfernen'), findsOneWidget);
  });

  testWidgets('Eltern: list and "Elternteil entfernen"', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      _app(const RdParentsPage(), [
        parentsProvider.overrideWith(
          (ref) async => const [
            ParentModel(id: 1, appId: 'a', email: 'eva@test.de', firstName: 'Eva', lastName: 'Muster'),
          ],
        ),
      ]),
    );
    await _settle(tester);
    expect(find.text('Eltern'), findsWidgets);
    expect(find.text('Eva Muster'), findsOneWidget);
    expect(find.text('eva@test.de'), findsOneWidget);
    await tester.tap(find.text('Eva Muster'));
    await _settle(tester);
    expect(find.text('Elternteil entfernen'), findsOneWidget);
  });

  testWidgets('Beobachter: empty state with invite', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      _app(const RdViewersPage(), [viewersProvider.overrideWith((ref) async => const <Viewer>[])]),
    );
    await _settle(tester);
    expect(find.text('Beobachter'), findsWidgets);
    expect(find.text('Noch keine Beobachter eingeladen.'), findsOneWidget);
    expect(find.text('Beobachter einladen'), findsOneWidget);
  });

  testWidgets('Archiv: group, leave date and the restore button', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      _app(const RdArchivePage(), [
        leftPlayersProvider.overrideWith(
          (ref) async => const [
            Person(id: 7, firstName: 'Max', lastName: 'Alt', groupName: 'Violine', left: '2024-05-01'),
          ],
        ),
      ]),
    );
    await _settle(tester);
    expect(find.text('Max Alt'), findsOneWidget);
    expect(find.textContaining('Violine · Ausgetreten: '), findsOneWidget);
    expect(find.byKey(const ValueKey('rd-archive-restore-7')), findsOneWidget);
    // Nothing to add to the archive.
    expect(find.byKey(const Key('rd-manage-list-add')), findsNothing);
  });

  testWidgets('Freigaben: waiting persons; back to the Verwaltung once the list is empty', (tester) async {
    _phone(tester);
    final controller = StreamController<List<Person>>();
    addTearDown(controller.close);
    final router = GoRouter(
      initialLocation: RedesignRoutes.manage,
      routes: [
        GoRoute(
          path: RedesignRoutes.manage,
          builder: (_, _) => const Scaffold(body: Text('Verwaltung-Start')),
          routes: [GoRoute(path: 'freigaben', builder: (_, _) => const RdPendingPage())],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [realtimePendingPlayersProvider.overrideWith((ref) => controller.stream)],
        child: MaterialApp.router(
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
          routerConfig: router,
        ),
      ),
    );
    router.push(RedesignRoutes.approvals);
    await _settle(tester);
    controller.add(const [Person(id: 3, firstName: 'Neu', lastName: 'Ling', email: 'neu@test.de')]);
    await _settle(tester);
    expect(find.text('Freigaben'), findsOneWidget);
    expect(find.text('Neu Ling'), findsOneWidget);
    expect(find.text('neu@test.de'), findsOneWidget);

    controller.add(const []);
    await _settle(tester);
    expect(find.text('Verwaltung-Start'), findsOneWidget);
    expect(find.byType(RdPendingPage), findsNothing);
  });

  test('rdLoadedValue: no value of the old group while reloading after a switch', () {
    const data = AsyncData<List<int>>([1]);
    expect(rdLoadedValue(data), [1]);
    // Pull-to-refresh / invalidate of the same list: the list stays.
    expect(rdLoadedValue(const AsyncLoading<List<int>>().copyWithPrevious(data)), [1]);
    // Rebuild after a dependency change (group/account switch): hidden.
    expect(rdLoadedValue(const AsyncLoading<List<int>>().copyWithPrevious(data, isRefresh: false)), isNull);
    // An error may carry the old value: hidden as well.
    expect(rdLoadedValue(AsyncError<List<int>>('x', StackTrace.empty).copyWithPrevious(data)), isNull);
    expect(rdLoadedValue(const AsyncLoading<List<int>>()), isNull);
  });

  testWidgets('Eltern: after a group switch no list and no "+" until the new group is loaded', (tester) async {
    _phone(tester);
    final tenant = StateProvider<int>((_) => 1);
    final second = Completer<List<ParentModel>>();
    await tester.pumpWidget(
      _app(const RdParentsPage(), [
        parentsProvider.overrideWith((ref) async {
          if (ref.watch(tenant) == 1) {
            return const [ParentModel(id: 1, appId: 'a', email: 'eva@test.de', firstName: 'Eva', lastName: 'Alt')];
          }
          return second.future;
        }),
      ]),
    );
    await _settle(tester);
    expect(find.text('Eva Alt'), findsOneWidget);
    expect(find.byKey(const Key('rd-manage-list-add')), findsOneWidget);

    final container = ProviderScope.containerOf(tester.element(find.byType(RdParentsPage)));
    container.read(tenant.notifier).state = 2;
    await _settle(tester);
    expect(find.text('Eva Alt'), findsNothing);
    expect(find.byKey(const Key('rd-manage-list-add')), findsNothing);

    second.complete(const [ParentModel(id: 2, appId: 'b', email: 'neu@test.de', firstName: 'Nina', lastName: 'Neu')]);
    await _settle(tester);
    expect(find.text('Nina Neu'), findsOneWidget);
    expect(find.byKey(const Key('rd-manage-list-add')), findsOneWidget);
  });

  testWidgets('Freigaben: leaving does not close a sheet of the root navigator', (tester) async {
    _phone(tester);
    final controller = StreamController<List<Person>>();
    addTearDown(controller.close);
    final rootKey = GlobalKey<NavigatorState>();
    final router = GoRouter(
      navigatorKey: rootKey,
      initialLocation: RedesignRoutes.manage,
      routes: [
        ShellRoute(
          builder: (_, _, child) => child,
          routes: [
            GoRoute(
              path: RedesignRoutes.manage,
              builder: (_, _) => const Scaffold(body: Text('Verwaltung-Start')),
              routes: [GoRoute(path: 'freigaben', builder: (_, _) => const RdPendingPage())],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [realtimePendingPlayersProvider.overrideWith((ref) => controller.stream)],
        child: MaterialApp.router(
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
          routerConfig: router,
        ),
      ),
    );
    router.push(RedesignRoutes.approvals);
    await _settle(tester);
    controller.add(const [Person(id: 3, firstName: 'Neu', lastName: 'Ling')]);
    await _settle(tester);
    expect(find.text('Neu Ling'), findsOneWidget);

    // E.g. the group switcher, above the shell.
    showModalBottomSheet<void>(
      context: rootKey.currentContext!,
      builder: (_) => const SizedBox(height: 200, child: Text('Gruppenwechsler')),
    );
    await _settle(tester);
    controller.add(const []);
    await _settle(tester);
    expect(find.text('Gruppenwechsler'), findsOneWidget);
    expect(find.byType(RdPendingPage), findsNothing);
  });
}
