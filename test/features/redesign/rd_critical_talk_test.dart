// Beta "Aktuelle Problemfälle": grouped by the rule that hits, "Regeln
// bearbeiten", and "Gespräch eintragen" right in the list (with undo).
import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/attendance_providers.dart';
import 'package:attendix/core/providers/debug_providers.dart';
import 'package:attendix/core/providers/player_providers.dart';
import 'package:attendix/core/providers/realtime_providers.dart';
import 'package:attendix/core/providers/redesign_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/data/models/person/person.dart';
import 'package:attendix/data/models/tenant/tenant.dart';
import 'package:attendix/features/redesign/data/providers/rd_critical_providers.dart';
import 'package:attendix/features/redesign/data/rd_critical_logic.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_critical_members_page.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../factories/test_factories.dart';
import '../../mocks/repository_mocks.dart';

const _rules = [
  CriticalRule(
    id: 'r1',
    name: 'Fehlt oft',
    attendanceTypeIds: [],
    statuses: [4],
    thresholdType: CriticalRuleThresholdType.count,
    thresholdValue: 3,
    periodType: CriticalRulePeriodType.days,
    periodDays: 30,
    operator: CriticalRuleOperator.or,
  ),
  CriticalRule(
    id: 'r2',
    name: 'Oft zu spät',
    attendanceTypeIds: [],
    statuses: [3, 5],
    thresholdType: CriticalRuleThresholdType.count,
    thresholdValue: 5,
    periodType: CriticalRulePeriodType.days,
    periodDays: 60,
    operator: CriticalRuleOperator.or,
  ),
];

class _TenantNotifier extends CurrentTenantNotifier {
  _TenantNotifier(super.ref) {
    state = TestFactories.createTenant(id: 7, shortName: 'SO', longName: 'Stadtorchester').copyWith(criticalRules: _rules);
  }
}

Person _person(int id, String first, String last) =>
    TestFactories.createPerson(id: id, firstName: first, lastName: last, tenantId: 7).copyWith(isCritical: true);

final _ben = _person(2, 'Ben', 'Krause');
final _lea = _person(3, 'Lea', 'Wolf');
final _mia = _person(4, 'Mia', 'Hoffmann');

List<RdCriticalEntry> _entries(int id, int status, int count) => [
  for (var i = 0; i < count; i++)
    RdCriticalEntry(personId: id, status: status, date: DateTime.now().subtract(Duration(days: 2 + i * 5))),
];

Widget _app(Role role, MockPlayerRepository repo) {
  final router = GoRouter(
    initialLocation: '/mitglieder/problemfaelle',
    routes: [
      GoRoute(path: '/mitglieder/problemfaelle', builder: (_, __) => const RdCriticalMembersPage()),
      GoRoute(path: '/ich/verwaltung/problemfaelle', builder: (_, __) => const Scaffold(body: Text('page rules'))),
    ],
  );
  return ProviderScope(
    overrides: [
      initialRedesignSettingsProvider.overrideWithValue(const RedesignSettings(enabled: true, world: RdFarbwelt.petrol)),
      currentTenantProvider.overrideWith((ref) => _TenantNotifier(ref)),
      effectiveRoleProvider.overrideWithValue(role),
      playerRepositoryWithTenantProvider.overrideWithValue(repo),
      realtimePlayersProvider.overrideWith((ref) => Stream.value([_ben, _lea, _mia])),
      playerAttendancePercentagesProvider.overrideWith((ref) async => const {2: 58, 3: 66, 4: 81}),
      criticalPlayersProvider.overrideWith((ref) async => [_ben, _lea, _mia]),
      rdCriticalContextProvider.overrideWith(
        (ref) async => RdCriticalContext(
          tenantId: 7,
          rules: _rules,
          entries: {2: [..._entries(2, 4, 4), ..._entries(2, 3, 5)], 3: _entries(3, 4, 3), 4: _entries(4, 3, 5)},
        ),
      ),
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

/// Bounded pumps: loading spinners never settle.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  testWidgets('grouped by rule; "Gespräch eintragen" saves with a note (id + tenant repository) and can be undone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var stored = _ben;
    final writes = <Map<String, dynamic>>[];
    final repo = MockPlayerRepository();
    when(() => repo.hasTenantId).thenReturn(true);
    when(() => repo.getPlayerById(2)).thenAnswer((_) async => stored);
    when(() => repo.updatePlayerFields(2, any())).thenAnswer((i) async {
      final columns = i.positionalArguments[1] as Map<String, dynamic>;
      writes.add(columns);
      stored = Person.fromJson({...stored.toJson(), ...columns});
    });

    await tester.pumpWidget(_app(Role.admin, repo));
    await _settle(tester);
    expect(find.text('Fehlt oft · 2'), findsOneWidget);
    expect(find.text('Oft zu spät · 1'), findsOneWidget);
    expect(find.text('Regeln bearbeiten'), findsOneWidget);
    // Ben hits both rules: listed under the first, the second named.
    expect(find.textContaining('auch „Oft zu spät“'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('rd-critical-talk-2')));
    await _settle(tester);
    expect(find.text('Mit Ben Krause gesprochen'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('rd-talk-note')), 'Hat Prüfungen');
    await tester.tap(find.byKey(const Key('rd-talk-save')));
    await _settle(tester);

    expect(writes, hasLength(1));
    expect(writes.single['isCritical'], isFalse);
    expect(writes.single['lastSolve'], isNotNull);
    final entry = (writes.single['history'] as List).single as Map<String, dynamic>;
    expect(entry['text'], 'Hat Prüfungen');
    expect(entry['type'], PlayerHistoryType.criticalPerson.value);
    // The row leaves the list at once.
    expect(find.text('Ben Krause'), findsNothing);
    expect(find.text('Fehlt oft · 1'), findsOneWidget);

    // The md toast writes its action in capitals.
    await tester.tap(find.textContaining(RegExp('Rückgängig', caseSensitive: false)));
    await _settle(tester);
    expect(writes, hasLength(2));
    expect(writes.last['isCritical'], isTrue);
    expect(writes.last['lastSolve'], isNull);
    expect(writes.last['history'], isEmpty);
    expect(find.text('Ben Krause'), findsOneWidget);
    await tester.pump(const Duration(seconds: 7));
  });

  testWidgets('Beobachter: the reasons, but no "Gespräch eintragen" and no rules link', (tester) async {
    final repo = MockPlayerRepository();
    when(() => repo.hasTenantId).thenReturn(true);
    await tester.pumpWidget(_app(Role.viewer, repo));
    await _settle(tester);
    expect(find.text('Fehlt oft · 2'), findsOneWidget);
    expect(find.byKey(const ValueKey('rd-critical-talk-2')), findsNothing);
    expect(find.text('Regeln bearbeiten'), findsNothing);
  });
}
