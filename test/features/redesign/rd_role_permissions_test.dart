import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/debug_providers.dart';
import 'package:attendix/core/providers/role_permission_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/router/redesign_routes.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/data/models/role_permission/tenant_role_permission.dart';
import 'package:attendix/data/repositories/role_permission_repository.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_role_permissions_page.dart';
import 'package:attendix/features/redesign/presentation/widgets/rd_widgets.dart';
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

final _permissions = [
  for (final role in [Role.helper, Role.voiceLeaderHelper, Role.voiceLeader, Role.player, Role.viewer, Role.parent])
    TenantRolePermission(id: role.value, tenantId: 7, role: role.value),
];

Widget _app(
  List<List<TenantRolePermission>> saves, {
  bool result = true,
  List<bool>? results,
  Role role = Role.admin,
}) {
  final router = GoRouter(
    initialLocation: RedesignRoutes.rolePermissions,
    routes: [GoRoute(path: RedesignRoutes.rolePermissions, builder: (_, __) => const RdRolePermissionsPage())],
  );
  return ProviderScope(
    overrides: [
      effectiveRoleProvider.overrideWithValue(role),
      currentTenantProvider.overrideWith((ref) => _TenantNotifier(ref)),
      rolePermissionsProvider.overrideWith((ref) async => _permissions),
      rolePermissionNotifierProvider.overrideWith(() => _FakeNotifier(saves, result, results)),
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
    testWidgets('the switches of the old page, each saved right away', (tester) async {
      tester.view.physicalSize = const Size(393, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final saves = <List<TenantRolePermission>>[];
      await tester.pumpWidget(_app(saves));
      await _settle(tester);

      // Roles without switches (Stimmführer, Beobachter, Eltern) are left out.
      expect(find.text('HELFER'), findsOneWidget);
      expect(find.text('STIMMFÜHRER-HELFER'), findsOneWidget);
      expect(find.text('MITGLIED'), findsOneWidget);
      expect(find.text('BEOBACHTER'), findsNothing);
      expect(find.text('Speichern'), findsNothing);

      await tester.tap(find.text('Eigene Pausierung erlauben'));
      await _settle(tester);
      expect(saves.single.single.role, Role.player.value);
      expect(saves.single.single.playerSelfPause, isTrue);
      expect(_switchOf(tester, 'Eigene Pausierung erlauben').value, isTrue);
    });

    testWidgets('failed saves put the switch back to the saved value', (tester) async {
      tester.view.physicalSize = const Size(393, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final saves = <List<TenantRolePermission>>[];
      await tester.pumpWidget(_app(saves, result: false));
      await _settle(tester);

      // On, off again while the first save still runs; both saves fail.
      await tester.tap(find.text('Eigene Pausierung erlauben'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Eigene Pausierung erlauben'));
      await _settle(tester);
      expect(saves, hasLength(2));
      expect(_switchOf(tester, 'Eigene Pausierung erlauben').value, isFalse);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a failed early save does not undo later saved changes', (tester) async {
      tester.view.physicalSize = const Size(393, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final saves = <List<TenantRolePermission>>[];
      await tester.pumpWidget(_app(saves, results: [false, true, true]));
      await _settle(tester);

      // On, off, on again; only the first save fails.
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Eigene Pausierung erlauben'));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await _settle(tester);
      expect(saves, hasLength(3));
      expect(_switchOf(tester, 'Eigene Pausierung erlauben').value, isTrue);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('only admins change the Dateiablage', (tester) async {
      tester.view.physicalSize = const Size(393, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app([], role: Role.responsible));
      await _settle(tester);
      expect(_switchOf(tester, 'Dateiablage für alle Mitglieder').onChanged, isNull);
    });
  });

  test('only Admins and Verantwortliche reach the page', () {
    expect(RedesignRoutes.roleRedirect(RedesignRoutes.rolePermissions, Role.helper), RedesignRoutes.manage);
    expect(RedesignRoutes.roleRedirect(RedesignRoutes.rolePermissions, Role.viewer), RedesignRoutes.manage);
    expect(RedesignRoutes.roleRedirect(RedesignRoutes.rolePermissions, Role.responsible), isNull);
  });
}
