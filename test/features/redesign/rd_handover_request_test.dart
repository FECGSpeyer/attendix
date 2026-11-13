import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/debug_providers.dart';
import 'package:attendix/core/providers/group_providers.dart';
import 'package:attendix/core/providers/organisation_providers.dart';
import 'package:attendix/core/providers/player_providers.dart';
import 'package:attendix/core/providers/redesign_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_handover_page.dart';
import 'package:attendix/features/redesign/presentation/widgets/rd_widgets.dart' show RdPrimaryButton;
import 'package:attendix/features/settings/presentation/pages/handover_page.dart' show HandoverData;
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../factories/test_factories.dart';

class _TenantNotifier extends CurrentTenantNotifier {
  _TenantNotifier(super.ref) {
    state = TestFactories.createTenant(id: 7, shortName: 'SO', longName: 'Stadtorchester');
  }
}

HandoverData? _opened;

/// Beta "Personen übergeben", step 1 for an Admin of "Stadtorchester";
/// [roleInTarget]: the viewer's role in the target "Jugendorchester" (null:
/// no member there).
Widget handoverApp({Role? roleInTarget, TextButtonThemeData? textButtons}) {
  final target = TestFactories.createTenant(id: 8, shortName: 'JO', longName: 'Jugendorchester');
  final router = GoRouter(
    initialLocation: '/settings/handover',
    routes: [
      GoRoute(path: '/settings/handover', builder: (_, __) => const RdHandoverPage()),
      GoRoute(
        path: '/settings/handover/detail',
        builder: (_, state) {
          _opened = state.extra as HandoverData?;
          return const Scaffold(body: Text('step 2'));
        },
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      initialRedesignSettingsProvider.overrideWithValue(const RedesignSettings(enabled: true, world: RdFarbwelt.petrol)),
      effectiveRoleProvider.overrideWithValue(Role.admin),
      currentTenantProvider.overrideWith((ref) => _TenantNotifier(ref)),
      userTenantsProvider.overrideWith((ref) async => [
            TestFactories.createTenant(id: 7, longName: 'Stadtorchester').copyWith(role: Role.admin.value),
            if (roleInTarget != null) target.copyWith(role: roleInTarget.value),
          ]),
      linkedTenantsProvider.overrideWith((ref) async => [target]),
      groupsProvider.overrideWith((ref) async => [
            TestFactories.createGroup(id: 1, name: 'Flöte'),
            TestFactories.createGroup(id: 2, name: 'Klarinette'),
          ]),
      mainGroupProvider.overrideWith((ref) async => null),
      playersProvider.overrideWith((ref) async => [
            TestFactories.createPerson(id: 31, firstName: 'Anna', lastName: 'Berg', instrument: 1, birthday: '2010-03-04'),
            TestFactories.createPerson(id: 32, firstName: 'Ben', lastName: 'Krause', instrument: 1, birthday: '2011-07-19'),
            TestFactories.createPerson(id: 33, firstName: 'Carla', lastName: 'Wolf', instrument: 2, birthday: '2009-11-02'),
          ]),
    ],
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      locale: const Locale('de'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light).copyWith(textButtonTheme: textButtons),
      routerConfig: router,
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// REDESIGN: handing people over asks what happens to them here (no
/// default), and says when the target group decides (Z6).
void main() {
  setUpAll(() async {
    await initializeDateFormatting('de_DE');
    await initializeDateFormatting('de');
  });

  testWidgets('no lead of the target: the note says so, "Weiter" waits for the answer', (tester) async {
    tester.view.physicalSize = const Size(393, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    _opened = null;
    await tester.pumpWidget(handoverApp(roleInTarget: Role.player));
    await _settle(tester);

    expect(find.textContaining('Du bist in „Jugendorchester“ nicht Leitung'), findsOneWidget);
    expect(find.text('Was passiert hier mit den Personen?'), findsOneWidget);
    await tester.tap(find.text('Anna Berg'));
    await _settle(tester);
    RdPrimaryButton next() => tester.widget<RdPrimaryButton>(find.byType(RdPrimaryButton));
    expect(next().label, 'Weiter (1)');
    expect(next().onPressed, isNull, reason: 'nothing chosen yet');
    expect(find.textContaining('sobald die Ziel-Gruppe sie aufgenommen hat'), findsOneWidget);

    await tester.tap(find.byKey(const Key('rd-handover-stay')));
    await _settle(tester);
    expect(next().onPressed, isNotNull);
    await tester.tap(find.byType(RdPrimaryButton));
    await _settle(tester);
    expect(find.text('step 2'), findsOneWidget);
    expect(_opened?.stayInInstance, isTrue);
    expect(_opened?.persons.map((p) => p.id), [31]);
  });

  testWidgets('Admin of the target: no note, the plain archive hint', (tester) async {
    tester.view.physicalSize = const Size(393, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(handoverApp(roleInTarget: Role.admin));
    await _settle(tester);

    expect(find.textContaining('nicht Leitung'), findsNothing);
    expect(find.text('Sie werden hier archiviert'), findsOneWidget);
  });
}
