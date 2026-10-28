import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/services/teams/teams_service.dart';
import 'package:attendix/data/models/tenant/tenant.dart';
import 'package:attendix/features/team_organization/presentation/pages/teams_config_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/services/teams_service_test.dart' show FakeTeamsSdk;

void main() {
  testWidgets('outside Teams shows the Ionic hint', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [isInTeamsProvider.overrideWithValue(false)],
      child: const MaterialApp(home: TeamsConfigPage()),
    ));
    expect(
      find.text('Diese Seite wird nur innerhalb von Microsoft Teams verwendet.'),
      findsOneWidget,
    );
  });

  testWidgets('in Teams: single tenant is preselected and saved', (tester) async {
    final sdk = FakeTeamsSdk();
    final svc = TeamsService(sdk: sdk);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        teamsServiceProvider.overrideWithValue(svc),
        isInTeamsProvider.overrideWithValue(true),
        userTenantsProvider.overrideWith((ref) async => const [
              Tenant(id: 3, shortName: 'BO', longName: 'Blasorchester'),
            ]),
      ],
      child: const MaterialApp(home: TeamsConfigPage()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Attendix-Tab einrichten'), findsOneWidget);
    expect(find.text('Blasorchester'), findsOneWidget);
    expect(sdk.validity.last, isTrue);
    final config = sdk.saveBuilder!();
    expect(config, TeamsService.tabConfigFor(tenantId: 3, shortName: 'BO'));
  });

  testWidgets('tenants arriving after an empty first load are used and '
      'auto-selected (handler registered once)', (tester) async {
    final sdk = FakeTeamsSdk();
    final svc = TeamsService(sdk: sdk);
    final tenants = StateProvider<List<Tenant>>((ref) => const []);
    final container = ProviderContainer(overrides: [
      teamsServiceProvider.overrideWithValue(svc),
      isInTeamsProvider.overrideWithValue(true),
      userTenantsProvider.overrideWith((ref) async => ref.watch(tenants)),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: TeamsConfigPage()),
    ));
    await tester.pumpAndSettle();
    expect(sdk.saveBuilder!(), isNull);
    final builder = sdk.saveBuilder;

    container.read(tenants.notifier).state = const [
      Tenant(id: 5, shortName: 'CH', longName: 'Chor'),
    ];
    await tester.pumpAndSettle();

    expect(find.text('Chor'), findsOneWidget);
    expect(identical(sdk.saveBuilder, builder), isTrue);
    expect(sdk.validity.last, isTrue);
    expect(sdk.saveBuilder!(),
        TeamsService.tabConfigFor(tenantId: 5, shortName: 'CH'));
  });
}
