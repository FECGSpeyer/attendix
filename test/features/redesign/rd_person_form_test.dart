// Beta Paket A: "Neue Person" and "Person bearbeiten" of the new design.
import 'package:attendix/core/config/supabase_config.dart';
import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/church_providers.dart';
import 'package:attendix/core/providers/cross_tenant_person_providers.dart';
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
import 'package:attendix/data/models/parent/parent_model.dart';
import 'package:attendix/data/models/person/person.dart';
import 'package:attendix/data/models/tenant/tenant.dart';
import 'package:attendix/data/repositories/cross_tenant_person_repository.dart';
import 'package:attendix/features/people/presentation/pages/person_detail_page.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_person_create_page.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_person_edit_page.dart';
import 'package:attendix/features/redesign/presentation/widgets/members/rd_person_form.dart';
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

class _ParentsTenant extends StateNotifier<Tenant?> implements CurrentTenantNotifier {
  _ParentsTenant() : super(const Tenant(id: 42, shortName: 'X', longName: 'X', parents: true, type: 'orchestra'));
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _MockCrossTenantRepository extends Mock implements CrossTenantPersonRepository {}

Future<MockPlayerRepository> _pump(WidgetTester tester, Widget home, {Person? person, Person? stored}) async {
  tester.view.physicalSize = const Size(430, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final loaded = person ?? _person;
  final auth = MockGoTrueClient();
  when(() => auth.currentUser).thenReturn(null);
  when(() => auth.onAuthStateChange).thenAnswer((_) => const Stream.empty());
  final repo = MockPlayerRepository();
  when(() => repo.hasTenantId).thenReturn(true);
  when(() => repo.currentTenantId).thenReturn(42);
  when(() => repo.updatePlayerFields(any(), any())).thenAnswer((_) async {});
  when(() => repo.findPlayersByName(any(), any())).thenAnswer((_) async => const <Person>[]);
  when(() => repo.getPlayerById(any())).thenAnswer((_) async => stored ?? loaded);
  final crossTenant = _MockCrossTenantRepository();
  when(() => crossTenant.getPossiblePersonsByEmail(any(), linkedTenantIds: any(named: 'linkedTenantIds')))
      .thenAnswer((_) async => const <CrossTenantPersonCandidate>[]);

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
      personProvider(1).overrideWith((ref) async => loaded),
      crossTenantPersonRepositoryWithTenantProvider.overrideWithValue(crossTenant),
      linkedTenantIdsProvider.overrideWith((ref) async => const <int>[]),
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

  testWidgets('Person bearbeiten: a changed note adds to the stored history, not the one loaded with the page',
      (tester) async {
    PlayerHistoryEntry entry(String text) => PlayerHistoryEntry(date: '2026-01-01T00:00:00.000Z', text: text, type: 1);
    // Loaded with A and B; meanwhile A was deleted in "Verlauf" and C added
    // by "In andere Gruppe kopieren".
    final repo = await _pump(
      tester,
      const RdPersonEditPage(personId: 1),
      person: _person.copyWith(notes: 'alt', history: [entry('A'), entry('B')]),
      stored: _person.copyWith(notes: 'alt', history: [entry('B'), entry('C')]),
    );

    await tester.enterText(find.byKey(const Key('rd-person-notes')), 'neu');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final columns =
        verify(() => repo.updatePlayerFields(1, captureAny())).captured.single as Map<String, dynamic>;
    expect(columns['notes'], 'neu');
    final history = (columns['history'] as List).cast<Map<String, dynamic>>();
    expect(history.map((h) => h['text']), ['B', 'C', 'alt']);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Person bearbeiten: a failed write is written again on the next focus loss', (tester) async {
    final repo = await _pump(tester, const RdPersonEditPage(personId: 1));
    var fail = true;
    when(() => repo.updatePlayerFields(any(), any())).thenAnswer((_) async {
      if (fail) throw Exception('offline');
    });

    await tester.enterText(find.byKey(const Key('rd-person-phone')), '0176 999');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    verify(() => repo.updatePlayerFields(1, {'phone': '0176 999'})).called(1);

    fail = false;
    await tester.showKeyboard(find.byKey(const Key('rd-person-phone')));
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Written again (the failed write did not count as stored).
    verify(() => repo.updatePlayerFields(1, {'phone': '0176 999'})).called(1);

    // Stored now: another focus loss writes nothing.
    await tester.showKeyboard(find.byKey(const Key('rd-person-phone')));
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    verifyNever(() => repo.updatePlayerFields(any(), any()));
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('Person bearbeiten: a note is not written when the stored history cannot be loaded',
      (tester) async {
    final repo = await _pump(tester, const RdPersonEditPage(personId: 1), person: _person.copyWith(notes: 'alt'));
    when(() => repo.getPlayerById(any())).thenAnswer((_) async => throw Exception('offline'));

    await tester.enterText(find.byKey(const Key('rd-person-notes')), 'neu');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    verifyNever(() => repo.updatePlayerFields(any(), any()));
    final field = tester.widget<TextField>(find.byKey(const Key('rd-person-notes')));
    expect(field.controller!.text, 'alt');
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('Person bearbeiten: opening and closing writes nothing (stored note with a line break)',
      (tester) async {
    final repo = await _pump(tester, const RdPersonEditPage(personId: 1),
        person: _person.copyWith(notes: 'abc\n', phone: ' 0176 1234567 '));
    expect(find.byKey(const Key('rd-person-notes')), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));

    verifyNever(() => repo.updatePlayerFields(any(), any()));
  });

  testWidgets('Person bearbeiten: a pending person only gets "Prüfen und freigeben", nothing is written',
      (tester) async {
    final repo = await _pump(tester, const RdPersonEditPage(personId: 1), person: _person.copyWith(pending: true));

    expect(find.byKey(const Key('rd-person-review')), findsOneWidget);
    expect(find.byKey(const Key('rd-person-phone')), findsNothing);
    expect(find.byKey(const Key('rd-person-delete')), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
    verifyNever(() => repo.updatePlayerFields(any(), any()));
  });

  testWidgets('Person bearbeiten: "Abbrechen" at the account question saves no e-mail', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('de'));
    final repo = await _pump(tester, const RdPersonEditPage(personId: 1));

    await tester.enterText(find.byKey(const Key('rd-person-email')), 'anna@example.de');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(l10n.personEmailAdded), findsOneWidget);
    await tester.tap(find.text(l10n.commonCancel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    verifyNever(() => repo.updatePlayerFields(any(), any()));
    final field = tester.widget<TextField>(find.byKey(const Key('rd-person-email')));
    expect(field.controller!.text, _person.email ?? '');
  });

  testWidgets('Weitere Angaben: "Eltern" opens the parent list and links the chosen parent', (tester) async {
    tester.view.physicalSize = const Size(430, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Map<String, dynamic>? written;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentTenantProvider.overrideWith((ref) => _ParentsTenant()),
        groupsProvider.overrideWith((ref) async => const []),
        churchesProvider.overrideWith((ref) async => const []),
        teachersProvider.overrideWith((ref) async => const []),
        parentsProvider.overrideWith((ref) async =>
            const [ParentModel(id: 7, appId: 'a', email: 'e', firstName: 'Paula', lastName: 'Muster')]),
        shiftsProvider.overrideWith((ref) async => const []),
      ],
      child: MaterialApp(
        theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: RdPersonMoreFields(
              person: const Person(id: 1, firstName: 'A', lastName: 'B'),
              isMainGroup: false,
              additionalValues: const {},
              onColumns: (c, {typing = false}) => written = c,
              onExtra: (a, b, {typing = false}) {},
            ),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Eltern'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paula Muster'));
    await tester.pumpAndSettle();

    expect(written, {'parent_id': 7});
  });
}
