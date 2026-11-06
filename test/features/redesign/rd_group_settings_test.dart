import 'package:attendix/core/providers/attendance_type_providers.dart';
import 'package:attendix/core/providers/duty_providers.dart';
import 'package:attendix/core/providers/files_providers.dart';
import 'package:attendix/core/providers/group_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/data/models/organisation/organisation.dart';
import 'package:attendix/features/redesign/data/rd_manage_logic.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_branding_page.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_general_settings_page.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_org_settings_page.dart';
import 'package:attendix/core/providers/organisation_providers.dart';
import 'package:attendix/core/providers/debug_providers.dart';
import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:attendix/core/config/supabase_config.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../factories/test_factories.dart';
import '../../mocks/supabase_mocks.dart';

/// No signed-in user: the tenant notifier's restore finds nothing to load.
final _auth = () {
  final auth = MockGoTrueClient();
  when(() => auth.currentUser).thenReturn(null);
  when(() => auth.onAuthStateChange).thenAnswer((_) => const Stream.empty());
  return auth;
}();

class _TenantNotifier extends CurrentTenantNotifier {
  _TenantNotifier(super.ref) {
    state = TestFactories.createTenant(id: 7, shortName: 'SC', longName: 'Stephanus Chor');
  }
}

Widget _app(Widget home, {Organisation? org}) => ProviderScope(
  overrides: [
    supabaseAuthProvider.overrideWithValue(_auth),
    currentTenantProvider.overrideWith((ref) => _TenantNotifier(ref)),
    groupsProvider.overrideWith((ref) async => [TestFactories.createGroup(id: 1, name: 'Sopran')]),
    attendanceTypesProvider.overrideWith((ref) async => const []),
    hasDutyTypesProvider.overrideWithValue(false),
    brandingOrganisationProvider.overrideWith((ref) async => org),
    currentOrganisationProvider.overrideWith((ref) async => org),
    effectiveRoleProvider.overrideWithValue(Role.admin),
  ],
  child: MaterialApp(
    locale: const Locale('de'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
    home: home,
  ),
);

/// REDESIGN: Verwaltung › Gruppe › Allgemein and Branding (package G1).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Allgemein shows the settings without a save button', (tester) async {
    tester.view.physicalSize = const Size(390, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(const RdGeneralSettingsPage()));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
    expect(find.text('Stephanus Chor'), findsOneWidget);
    expect(find.text('Saisonbeginn'), findsOneWidget);
    expect(find.text('Speichern'), findsNothing);
  });

  testWidgets('Branding without an organisation points to the organisation', (tester) async {
    await tester.pumpWidget(_app(const RdBrandingPage()));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
    expect(find.text('Zur Organisation'), findsOneWidget);
  });

  testWidgets('Branding offers nothing to edit while another group reloads', (tester) async {
    final slowB = Completer<Organisation?>();
    late _TenantNotifier tenants;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseAuthProvider.overrideWithValue(_auth),
          currentTenantProvider.overrideWith((ref) => tenants = _TenantNotifier(ref)),
          brandingOrganisationProvider.overrideWith((ref) async {
            if (ref.watch(currentTenantIdProvider) == 7) {
              return const Organisation(id: 1, name: 'Org A', brandingText: 'Text A');
            }
            return slowB.future;
          }),
        ],
        child: MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
          home: const RdBrandingPage(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Text A'), findsOneWidget);

    tenants.state = TestFactories.createTenant(id: 8, shortName: 'B', longName: 'Gruppe B');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Text A'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    slowB.complete(const Organisation(id: 2, name: 'Org B', brandingText: 'Text B'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Text B'), findsOneWidget);
  });

  testWidgets('Organisation without one offers to create or link it', (tester) async {
    await tester.pumpWidget(_app(const RdOrgSettingsPage()));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
    expect(find.text('Organisation erstellen oder verknüpfen'), findsOneWidget);
  });

  test('"Dashboard konfigurieren" is not listed in the Beta Verwaltung', () {
    expect(rdManageVisible(RdManageEntry.dashboard, const RdManageAccess(isAdmin: true)), isFalse);
    expect(rdManageVisible(RdManageEntry.general, const RdManageAccess(isAdmin: true)), isTrue);
  });
}
