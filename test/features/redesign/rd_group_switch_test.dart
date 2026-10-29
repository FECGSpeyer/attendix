import 'dart:async';

import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/providers/user_preferences_provider.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/data/models/tenant/tenant.dart';
import 'package:attendix/features/redesign/presentation/widgets/rd_group_switch.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../factories/test_factories.dart';

final _home = TestFactories.createTenant(id: 7, shortName: 'SO', longName: 'Stadtorchester');
final _other = TestFactories.createTenant(id: 8, shortName: 'JC', longName: 'Jugendchor');

/// Starts in [_home]; switching only sets the state (no SharedPreferences).
class _TenantNotifier extends CurrentTenantNotifier {
  _TenantNotifier(super.ref) {
    state = _home;
  }

  @override
  Future<void> setTenantLocal(Tenant? tenant) async => state = tenant;
}

class _Prefs extends UserPreferencesNotifier {
  _Prefs(this.saved);

  final List<int> saved;

  @override
  void updateCurrentTenantId(int tenantId) => saved.add(tenantId);
}

/// Page routes popped (the sheet's own route is not a page).
class _Pops extends NavigatorObserver {
  final pages = <String?>[];

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute || route.settings is Page) pages.add(route.settings.name);
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// REDESIGN: "Gruppe wechseln" (canvas E4).
void main() {
  testWidgets('the sheet stays open while switching; closed anyway, the switch finishes without popping the page below',
      (tester) async {
    final role = Completer<TenantUser?>();
    final saved = <int>[];
    final pops = _Pops();
    final router = GoRouter(
      initialLocation: '/termine',
      observers: [pops],
      routes: [
        GoRoute(path: '/heute', builder: (_, __) => const Scaffold(body: Text('page heute'))),
        GoRoute(
          path: '/termine',
          builder: (_, __) => const Scaffold(body: Text('page termine')),
          routes: [
            GoRoute(
              path: 'detail',
              builder: (context, __) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => showRdGroupSwitchSheet(context),
                    child: const Text('open sheet'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentTenantProvider.overrideWith(_TenantNotifier.new),
        userTenantsProvider.overrideWith((ref) async => [_home, _other]),
        // The role of the new group is still loading.
        currentTenantUserProvider.overrideWith((ref) {
          ref.watch(currentTenantProvider);
          return role.future;
        }),
        userPreferencesNotifierProvider.overrideWith(() => _Prefs(saved)),
      ],
      child: MaterialApp.router(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
        routerConfig: router,
      ),
    ));
    router.push('/termine/detail');
    await _settle(tester);
    await tester.tap(find.text('open sheet'));
    await _settle(tester);
    expect(find.text('Gruppe wechseln'), findsOneWidget);

    await tester.tap(find.text('Jugendchor'));
    await _settle(tester);

    // Barrier and "Fertig" do not close it while the switch runs.
    await tester.tapAt(const Offset(20, 20));
    await _settle(tester);
    expect(find.text('Gruppe wechseln'), findsOneWidget);
    await tester.tap(find.text('Fertig'));
    await _settle(tester);
    expect(find.text('Gruppe wechseln'), findsOneWidget);

    // Dragged closed anyway and the role arrives while the sheet still
    // animates out: the switch finishes, nothing below the sheet is popped.
    pops.pages.clear();
    await tester.fling(find.text('Gruppe wechseln'), const Offset(0, 60), 1500);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('Gruppe wechseln'), findsOneWidget, reason: 'still animating out');
    expect(saved, isEmpty);

    role.complete(null);
    await _settle(tester);
    expect(find.text('Gruppe wechseln'), findsNothing);
    expect(pops.pages, isEmpty);
    expect(find.text('page heute'), findsOneWidget);
    expect(saved, [8]);
    expect(tester.takeException(), isNull);
  });
}
