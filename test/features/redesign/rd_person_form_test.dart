// Beta Paket A: "Neue Person" and "Person bearbeiten" of the new design.
import 'package:attendix/core/config/supabase_config.dart';
import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/church_providers.dart';
import 'package:attendix/core/providers/debug_providers.dart';
import 'package:attendix/core/providers/duty_providers.dart';
import 'package:attendix/core/providers/group_providers.dart';
import 'package:attendix/core/providers/organisation_providers.dart';
import 'package:attendix/core/providers/parent_providers.dart';
import 'package:attendix/core/providers/player_absence_providers.dart';
import 'package:attendix/core/providers/player_providers.dart';
import 'package:attendix/core/providers/shift_providers.dart';
import 'package:attendix/core/providers/teacher_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/data/models/person/person.dart';
import 'package:attendix/data/models/tenant/tenant.dart';
import 'package:attendix/features/people/presentation/pages/person_detail_page.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_person_create_page.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_person_edit_page.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../factories/test_factories.dart';
import '../../mocks/repository_mocks.dart';
import '../../mocks/supabase_mocks.dart';

class _TenantNotifier extends CurrentTenantNotifier {
  _TenantNotifier(super.ref);

  @override
  Future<void> setTenant(Tenant? tenant) async {}
}

final _person = TestFactories.createPerson(id: 1, tenantId: 42, firstName: 'Anna', lastName: 'Beispiel')
    .copyWith(phone: '0176 1234567');

Future<MockPlayerRepository> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(430, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final auth = MockGoTrueClient();
  when(() => auth.currentUser).thenReturn(null);
  when(() => auth.onAuthStateChange).thenAnswer((_) => const Stream.empty());
  final repo = MockPlayerRepository();
  when(() => repo.hasTenantId).thenReturn(true);
  when(() => repo.currentTenantId).thenReturn(42);
  when(() => repo.updatePlayerFields(any(), any())).thenAnswer((_) async {});
  when(() => repo.findPlayersByName(any(), any())).thenAnswer((_) async => const <Person>[]);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentTenantProvider.overrideWith((ref) => _TenantNotifier(ref)),
      supabaseAuthProvider.overrideWithValue(auth),
      currentUserProvider.overrideWith((ref) => Stream.value(null)),
      currentAuthUserIdProvider.overrideWithValue(null),
      playerRepositoryWithTenantProvider.overrideWithValue(repo),
      groupsProvider.overrideWith((ref) async => const []),
      groupsMapProvider.overrideWith((ref) async => const {}),
      mainGroupProvider.overrideWith((ref) async => null),
      churchesProvider.overrideWith((ref) async => const []),
      teachersProvider.overrideWith((ref) async => const []),
      parentsProvider.overrideWith((ref) async => const []),
      shiftsProvider.overrideWith((ref) async => const []),
      currentOrganisationProvider.overrideWith((ref) async => null),
      hasDutyTypesProvider.overrideWithValue(false),
      playerAbsencesByPersonIdProvider(1).overrideWith((ref) async => const []),
      currentRoleProvider.overrideWithValue(Role.admin),
      effectiveRoleProvider.overrideWithValue(Role.admin),
      personProvider(1).overrideWith((ref) async => _person),
      personAttendanceStatsProvider(1).overrideWith(
          (ref) async => {'total': 0, 'attended': 0, 'percentage': 0, 'lateCount': 0, 'lateCountExcused': 0}),
    ],
    child: MaterialApp(
      theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
      locale: const Locale('de'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  ));
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
  return repo;
}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(const Person());
    registerFallbackValue(Role.player);
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Neue Person: Anlegen without names asks for them and saves nothing', (tester) async {
    final repo = await _pump(tester, const RdPersonCreatePage());
    expect(find.text('Neue Person'), findsOneWidget);
    expect(find.text('Bekommt damit Zugang zur App'), findsOneWidget);

    await tester.tap(find.byKey(const Key('rd-person-create')));
    await tester.pump();

    expect(find.text(lookupAppLocalizations(const Locale('de')).peopleFlutterFirstNameRequired), findsOneWidget);
    expect(find.text(lookupAppLocalizations(const Locale('de')).peopleFlutterLastNameRequired), findsOneWidget);
    verifyNever(() => repo.findPlayersByName(any(), any()));
    verifyNever(() => repo.addPlayer(any(), register: any(named: 'register'), role: any(named: 'role')));
  });

  testWidgets('Person bearbeiten: a changed phone number is saved right away (id + tenant repository)',
      (tester) async {
    final repo = await _pump(tester, const RdPersonEditPage(personId: 1));
    expect(find.text('Anna Beispiel bearbeiten'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('rd-person-phone')), '0176 999');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    verify(() => repo.updatePlayerFields(1, {'phone': '0176 999'})).called(1);
    expect(find.text('Gespeichert ✓'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}
