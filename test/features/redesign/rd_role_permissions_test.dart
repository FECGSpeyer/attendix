import 'package:attendix/core/config/supabase_config.dart';
import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/debug_providers.dart';
import 'package:attendix/core/providers/duty_providers.dart';
import 'package:attendix/core/providers/group_providers.dart';
import 'package:attendix/core/providers/parent_providers.dart';
import 'package:attendix/core/providers/player_providers.dart';
import 'package:attendix/core/providers/role_permission_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/providers/viewer_providers.dart';
import 'package:attendix/core/router/redesign_routes.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/data/models/role_permission/tenant_role_permission.dart';
import 'package:attendix/data/repositories/role_permission_repository.dart';
import 'package:attendix/features/redesign/data/rd_manage_logic.dart';
import 'package:attendix/features/redesign/data/rd_roles_logic.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_role_permissions_page.dart';
import 'package:attendix/features/redesign/presentation/widgets/manage/rd_manage_entries.dart';
import 'package:attendix/features/redesign/presentation/widgets/rd_widgets.dart';
import 'package:attendix/features/settings/presentation/pages/user_management_page.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../factories/test_factories.dart';

class _TenantNotifier extends CurrentTenantNotifier {
  _TenantNotifier(super.ref) {
    state = TestFactories.createTenant(id: 7, type: 'orchestra');
  }
}

/// Records the saves instead of calling Supabase.
class _FakeNotifier extends RolePermissionNotifier {
  _FakeNotifier(this.saves, this.result, [this.results]);

  final List<List<TenantRolePermission>> saves;
  final bool result;

  /// Results per save in order (then [result]).
  final List<bool>? results;

  @override
  Future<bool> save(
    List<TenantRolePermission> permissions, {
    bool? filesShared,
    RolePermissionRepository? repo,
  }) async {
    saves.add(permissions);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final i = saves.length - 1;
    return results != null && i < results!.length ? results![i] : result;
  }
}

/// The signed-in account; a test switches it while a save runs.
final _account = StateProvider<String?>((ref) => 'a');

final _permissions = [
  for (final role in [Role.helper, Role.voiceLeaderHelper, Role.voiceLeader, Role.player, Role.viewer, Role.parent])
    TenantRolePermission(id: role.value, tenantId: 7, role: role.value),
];

/// Accounts of the group: one Admin, two Helfer (one also Stimmführer),
/// two Mitglieder; "a-helper" has a person in the group.
const _users = [
  TenantUser(id: '1', tenantId: 7, userId: 'a-admin', role: 1, email: 'admin@example.org'),
  TenantUser(id: '2', tenantId: 7, userId: 'a-helper', role: 4),
  TenantUser(id: '3', tenantId: 7, userId: 'a-leader', role: 9, email: 'leader@example.org'),
  TenantUser(id: '4', tenantId: 7, userId: 'a-member', role: 2),
  TenantUser(id: '5', tenantId: 7, userId: 'a-member2', role: 2),
];

Widget _app(
  List<List<TenantRolePermission>> saves, {
  bool result = true,
  List<bool>? results,
  Role role = Role.admin,
  RdRoleView view = RdRoleView.list,
}) {
  final router = GoRouter(
    initialLocation: view == RdRoleView.list ? RedesignRoutes.rolePermissions : RedesignRoutes.role(view.key),
    routes: [
      GoRoute(
        path: RedesignRoutes.rolePermissions,
        builder: (_, __) => const RdRolePermissionsPage(),
        routes: [
          GoRoute(
            path: ':role',
            // Keyed like in the app's router: every role is a page of its own.
            builder: (_, state) {
              final view = RdRoleView.fromKey(state.pathParameters['role'])!;
              return RdRolePermissionsPage(key: ValueKey(view), view: view);
            },
          ),
        ],
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      effectiveRoleProvider.overrideWithValue(role),
      currentAuthUserIdProvider.overrideWith((ref) => ref.watch(_account)),
      currentTenantProvider.overrideWith((ref) => _TenantNotifier(ref)),
      currentTenantIdProvider.overrideWithValue(7),
      rolePermissionsProvider.overrideWith((ref) async => _permissions),
      hasDutyTypesProvider.overrideWithValue(false),
      rolePermissionNotifierProvider.overrideWith(() => _FakeNotifier(saves, result, results)),
      rdManageAccessProvider.overrideWithValue(const RdManageAccess(isAdmin: true, isOrchestra: true)),
      tenantUsersProvider.overrideWith((ref) async => _users),
      playersProvider.overrideWith(
        (ref) async => [
          TestFactories.createPerson(id: 11, tenantId: 7, firstName: 'Anna', lastName: 'Becker', appId: 'a-helper', instrument: 3),
        ],
      ),
      groupsProvider.overrideWith((ref) async => [TestFactories.createGroup(id: 3, tenantId: 7, name: 'Sopran')]),
      parentsProvider.overrideWith((ref) async => const []),
      viewersProvider.overrideWith((ref) async => const []),
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

Switch _switchOf(WidgetTester tester, String title) => tester.widget<Switch>(
  find.descendant(of: find.widgetWithText(RdListRow, title), matching: find.byType(Switch)),
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {

  group('RdRolePermissionsPage', () {
    testWidgets('a list of roles with their accounts; a role opens its page', (tester) async {
      tester.view.physicalSize = const Size(393, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app([]));
      await _settle(tester);

      // No switches of a role on the list, only what applies to everyone.
      expect(find.text('Sich selbst pausieren'), findsNothing);
      expect(find.text('Dateiablage für alle lesbar'), findsOneWidget);
      // Helfer and Stimmführer both count the Stimmführer-Helfer.
      String? count(String role) => tester.widget<RdListRow>(find.widgetWithText(RdListRow, role)).value;
      expect(count('Admin'), '1');
      expect(count('Helfer'), '2');
      expect(count('Stimmführer'), '1');
      expect(count('Mitglied'), '2');
      expect(count('Eltern'), 'Aus');

      await tester.tap(find.text('Helfer'));
      await _settle(tester);
      expect(find.text('DARF IMMER'), findsOneWidget);
      expect(find.text('Termine anlegen'), findsOneWidget);
      // The persons with the role: name and Register, or the e-mail.
      expect(find.text('Anna Becker'), findsOneWidget);
      expect(find.text('Sopran'), findsOneWidget);
      expect(find.text('leader@example.org'), findsOneWidget);
    });

    testWidgets('the switches of a role, each saved right away', (tester) async {
      tester.view.physicalSize = const Size(393, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final saves = <List<TenantRolePermission>>[];
      await tester.pumpWidget(_app(saves, view: RdRoleView.member));
      await _settle(tester);

      // What members see sits with the role; Helfer switches do not.
      expect(find.text('Alle Termine zeigen'), findsOneWidget);
      expect(find.text('Termine anlegen'), findsNothing);
      expect(find.text('Speichern'), findsNothing);

      await tester.tap(find.text('Sich selbst pausieren'));
      await _settle(tester);
      expect(saves.single.single.role, Role.player.value);
      expect(saves.single.single.playerSelfPause, isTrue);
      expect(_switchOf(tester, 'Sich selbst pausieren').value, isTrue);
    });

    testWidgets('Mitglied switches also set the Stimmführer role; Stimmführer have their own', (tester) async {
      tester.view.physicalSize = const Size(393, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final saves = <List<TenantRolePermission>>[];
      await tester.pumpWidget(_app(saves, view: RdRoleView.member));
      await _settle(tester);

      await tester.tap(find.text('Abwesenheit selbst eintragen'));
      await _settle(tester);
      expect(saves.map((s) => s.single.role), [Role.player.value, Role.voiceLeader.value]);
      expect(saves.every((s) => s.single.playerPlannedAbsence), isTrue);

      // Only Stimmführer-Helfer are limited to their own Stimme.
      saves.clear();
      await tester.pumpWidget(_app(saves, view: RdRoleView.leader));
      await _settle(tester);
      await tester.tap(find.text('Stimmführer nur ihre Stimme'));
      await _settle(tester);
      expect(saves.single.single.role, Role.voiceLeaderHelper.value);
      expect(saves.single.single.attendanceAllGroups, isFalse);
    });

    testWidgets('a save of another role page is not overwritten', (tester) async {
      tester.view.physicalSize = const Size(393, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final saves = <List<TenantRolePermission>>[];
      await tester.pumpWidget(_app(saves, view: RdRoleView.helper));
      await _settle(tester);

      // Helfer page: writes Helfer and Stimmführer-Helfer. Before that is
      // saved, the Stimmführer page writes the Stimmführer-Helfer too.
      await tester.tap(find.text('Termine anlegen'));
      await tester.pump();
      GoRouter.of(tester.element(find.text('Termine anlegen'))).go(RedesignRoutes.role(RdRoleView.leader.key));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Stimmführer nur ihre Stimme'));
      await _settle(tester);

      final last = saves.last.single;
      expect(last.role, Role.voiceLeaderHelper.value);
      expect(last.attendanceAllGroups, isFalse);
      // "Termine anlegen" is on by default: the row keeps it switched off.
      expect(saves.first.single.attendanceCreate, isFalse);
      expect(last.attendanceCreate, isFalse);
    });

    testWidgets('failed saves put the switch back to the saved value', (tester) async {
      tester.view.physicalSize = const Size(393, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final saves = <List<TenantRolePermission>>[];
      await tester.pumpWidget(_app(saves, result: false, view: RdRoleView.member));
      await _settle(tester);

      // On, off again while the first save still runs; both saves fail.
      await tester.tap(find.text('Sich selbst pausieren'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Sich selbst pausieren'));
      await _settle(tester);
      expect(saves, hasLength(2));
      expect(_switchOf(tester, 'Sich selbst pausieren').value, isFalse);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a failed early save does not undo later saved changes', (tester) async {
      tester.view.physicalSize = const Size(393, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final saves = <List<TenantRolePermission>>[];
      await tester.pumpWidget(_app(saves, results: [false, true, true], view: RdRoleView.member));
      await _settle(tester);

      // On, off, on again; only the first save fails.
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Sich selbst pausieren'));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await _settle(tester);
      expect(saves, hasLength(3));
      expect(_switchOf(tester, 'Sich selbst pausieren').value, isTrue);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a failed Helfer+Stimmführer save does not ride along a later one', (tester) async {
      tester.view.physicalSize = const Size(393, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final saves = <List<TenantRolePermission>>[];
      await tester.pumpWidget(_app(saves, results: [false, true], view: RdRoleView.helper));
      await _settle(tester);

      // "Termine anlegen" (Helfer + Stimmführer-Helfer) fails, "Notizen"
      // (Helfer only) queued right after is saved without it.
      final create = _switchOf(tester, 'Termine anlegen').value;
      await tester.tap(find.text('Termine anlegen'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Notizen zu Personen sehen'));
      await _settle(tester);
      expect(saves, hasLength(2));
      expect(saves.last.single.role, Role.helper.value);
      expect(saves.last.single.attendanceCreate, create);
      expect(saves.last.single.playerNotesView, isTrue);
      expect(_switchOf(tester, 'Termine anlegen').value, create);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a partly saved Helfer+Stimmführer change shows as such', (tester) async {
      tester.view.physicalSize = const Size(393, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final saves = <List<TenantRolePermission>>[];
      await tester.pumpWidget(_app(saves, results: [true, false, true], view: RdRoleView.helper));
      await _settle(tester);

      // Helfer row lands, Stimmführer-Helfer row fails; "Notizen" right
      // after builds on the landed Helfer row.
      final create = _switchOf(tester, 'Termine anlegen').value;
      await tester.tap(find.text('Termine anlegen'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Notizen zu Personen sehen'));
      await _settle(tester);
      expect(saves.map((s) => s.single.role), [Role.helper.value, Role.voiceLeaderHelper.value, Role.helper.value]);
      expect(saves.last.single.attendanceCreate, !create);
      expect(_switchOf(tester, 'Termine anlegen').value, !create);
      expect(find.textContaining('Bei Stimmführern ist es noch anders'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('after an account switch the Stimmführer row is not written any more', (tester) async {
      tester.view.physicalSize = const Size(393, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final saves = <List<TenantRolePermission>>[];
      await tester.pumpWidget(_app(saves, view: RdRoleView.helper));
      await _settle(tester);

      // Switched to another account while the Helfer row is written.
      await tester.tap(find.text('Termine anlegen'));
      await tester.pump(const Duration(milliseconds: 50));
      ProviderScope.containerOf(tester.element(find.byType(RdRolePermissionsPage))).read(_account.notifier).state = 'b';
      await _settle(tester);
      expect(saves.map((s) => s.single.role), [Role.helper.value]);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('only admins change the Dateiablage', (tester) async {
      tester.view.physicalSize = const Size(393, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app([], role: Role.responsible));
      await _settle(tester);
      expect(_switchOf(tester, 'Dateiablage für alle lesbar').onChanged, isNull);
    });
  });

  test('accounts of a role and their persons', () {
    expect(rdRoleAccounts(_users, RdRoleView.helper).map((u) => u.userId), ['a-helper', 'a-leader']);
    expect(rdRoleAccounts(_users, RdRoleView.leader).map((u) => u.userId), ['a-leader']);
    final people = rdRolePeople(
      rdRoleAccounts(_users, RdRoleView.helper),
      [TestFactories.createPerson(id: 11, firstName: 'Anna', lastName: 'Becker', appId: 'a-helper')],
    );
    // Persons first, accounts without a person by their e-mail.
    expect(people.map((p) => p.name), ['Anna Becker', 'leader@example.org']);
    expect(RdRoleView.fromKey('helfer'), RdRoleView.helper);
    expect(RdRoleView.fromKey(''), isNull);
  });

  test('only Admins and Verantwortliche reach the page', () {
    expect(RedesignRoutes.roleRedirect(RedesignRoutes.role(RdRoleView.helper.key), Role.helper), RedesignRoutes.me);
    expect(RedesignRoutes.roleRedirect(RedesignRoutes.rolePermissions, Role.helper), RedesignRoutes.me);
    expect(RedesignRoutes.roleRedirect(RedesignRoutes.rolePermissions, Role.viewer), RedesignRoutes.me);
    expect(RedesignRoutes.roleRedirect(RedesignRoutes.rolePermissions, Role.responsible), isNull);
  });
}
