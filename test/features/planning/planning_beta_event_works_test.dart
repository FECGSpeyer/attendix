// REDESIGN: "Werke vom … übernehmen" in the Beta Ablauf editor. The Ablauf
// of a Probe offers the Werke planned for the next Auftritt (and those of
// the Termin itself), as a checklist with the nearest Termin ticked.
import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/branding_providers.dart';
import 'package:attendix/core/providers/conductor_providers.dart';
import 'package:attendix/core/providers/debug_providers.dart';
import 'package:attendix/core/providers/group_providers.dart';
import 'package:attendix/core/providers/organisation_providers.dart';
import 'package:attendix/core/providers/plan_providers.dart';
import 'package:attendix/core/providers/redesign_providers.dart';
import 'package:attendix/core/providers/song_providers.dart';
import 'package:attendix/core/providers/team_org_providers.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/data/models/plan/plan.dart';
import 'package:attendix/data/models/song/song.dart';
import 'package:attendix/data/repositories/plan_repository.dart';
import 'package:attendix/features/planning/presentation/pages/planning_page.dart';
import 'package:attendix/features/planning/presentation/widgets/plan_song_helper.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../factories/test_factories.dart';
import '../../helpers/test_helpers.dart';

class _MockPlanRepository extends Mock implements PlanRepository {}

String _day(int offset) => DateTime.now().add(Duration(days: offset)).toIso8601String().substring(0, 10);

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  const types = [
    PlanAttendanceType(id: 'probe', name: 'Probe'),
    PlanAttendanceType(id: 'vortrag', name: 'Vortrag', highlight: true),
  ];
  final probe = PlanAttendance(id: 7, tenantId: 1, date: _day(2), typeId: 'probe', startTime: '19:00');
  final nextProbe = PlanAttendance(id: 8, tenantId: 1, date: _day(9), typeId: 'probe');
  final concert = PlanAttendance(id: 9, tenantId: 1, date: _day(12), typeId: 'vortrag', typeInfo: 'Adventskonzert');
  final later = PlanAttendance(id: 10, tenantId: 1, date: _day(40), typeId: 'vortrag');
  const songs = [
    Song(id: 1, name: 'Machet die Tore weit', number: 12),
    Song(id: 2, name: 'Tochter Zion', number: 31),
    Song(id: 3, name: 'Stille Nacht', number: 47),
  ];
  const history = [
    SongHistory(id: 5, songId: 2, attendanceId: 9, conductorName: 'Ben Kurz'),
    SongHistory(id: 4, songId: 1, attendanceId: 9, conductorName: 'Anna Meier'),
    SongHistory(id: 6, songId: 3, attendanceId: 8),
    SongHistory(id: 7, songId: 3, attendanceId: 10),
    SongHistory(id: 8, songId: 1, attendanceId: 10),
  ];

  test('a Probe takes the Werke of the next Auftritte, not those of the next Probe', () {
    final sources = PlanSongHelper.eventWorks(
      probe,
      attendances: [later, concert, nextProbe, probe],
      types: types,
      history: history,
      songs: songs,
    );
    expect([for (final s in sources) s.att.id], [9, 10]);
    expect(sources.first.own, false);
    // In the order they were planned, with the conductor planned there.
    expect([for (final w in sources.first.works) w.song.id], [1, 2]);
    expect(sources.first.works.first.conductor, 'Anna Meier');
    // A Werk of both Auftritte is listed once, at the nearer one.
    expect([for (final w in sources.last.works) w.song.id], [3]);
    // The Werke of the Termin itself come first.
    final own = PlanSongHelper.eventWorks(
      nextProbe,
      attendances: [later, concert, nextProbe, probe],
      types: types,
      history: history,
      songs: songs,
    );
    expect([for (final s in own) (s.att.id, s.own)], [(8, true), (9, false)]);
  });

  testWidgets('empty Ablauf: "Werke vom …" adds the ticked Werke with their conductors', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final calls = <Map<String, dynamic>>[];
    var row = probe;
    final repo = _MockPlanRepository();
    when(() => repo.hasTenantId).thenReturn(true);
    when(() => repo.updateAttendancePlanFields(any(), any())).thenAnswer((inv) async {
      final update = inv.positionalArguments[1] as Map<String, dynamic>;
      calls.add(update);
      row = PlanAttendance.fromJson({...row.toJson(), ...update});
      return row;
    });
    final container = createTestContainer(
      tenant: TestFactories.createTenant(id: 1),
      overrides: [
        redesignEnabledProvider.overrideWithValue(true),
        planRepositoryWithTenantProvider.overrideWithValue(repo),
        planAttendancesProvider.overrideWith((ref) async => [later, concert, nextProbe, probe]),
        orgPlansProvider.overrideWith((ref) async => const []),
        planAttendanceTypesProvider.overrideWith((ref) async => types),
        planBlockTemplatesProvider.overrideWith((ref) async => const []),
        planSongsProvider.overrideWith((ref) async => songs),
        songCollectionsProvider.overrideWith((ref) async => null),
        currentSongsProvider.overrideWith((ref) async => [(date: 'x', history: history)]),
        groupsProvider.overrideWith((ref) async => const []),
        groupCategoriesProvider.overrideWith((ref) async => const []),
        protocolTypesProvider.overrideWith((ref) async => const []),
        currentOrganisationProvider.overrideWith((ref) async => null),
        conductorsProvider.overrideWith((ref) async => const []),
        hasBrandingProvider.overrideWithValue(false),
        effectiveRoleProvider.overrideWithValue(Role.admin),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const PlanningPage(attendanceId: 7),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Adventskonzert · 2 Werke'), findsOneWidget);
    await tester.tap(find.byKey(const Key('rd-plan-event-works')));
    await tester.pumpAndSettle();
    // The nearest Auftritt is ticked, the later one is not.
    expect(find.text('2 Werke hinzufügen'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rd-plan-event-work-0-2'))); // without Tochter Zion
    await tester.tap(find.byKey(const ValueKey('rd-plan-event-work-1-3'))); // plus Stille Nacht
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rd-plan-event-works-add')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    final stored = [
      for (final f in ((calls.last['plan'] as Map<String, dynamic>)['fields'] as List)) f as Map<String, dynamic>,
    ];
    expect([for (final f in stored) f['name']], ['12. Machet die Tore weit', '47. Stille Nacht']);
    expect([for (final f in stored) f['songId']], [1, 3]);
    expect(stored.first['conductor'], 'Anna Meier');
    // Still offered under "Hinzufügen", now marked as in the Ablauf.
    await tester.tap(find.byKey(const Key('rd-plan-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rd-plan-event-works')), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
