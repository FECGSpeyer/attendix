// REDESIGN: "Werke vom … übernehmen" in the Beta Ablauf editor. The Ablauf
// of a Probe offers the Werke planned for the next Auftritt (and those of
// the Termin itself), as a checklist with the nearest Termin ticked.
import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/attendance_detail_providers.dart';
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
import 'package:attendix/features/attendance/presentation/attendance_song_history.dart';
import 'package:attendix/features/attendance/presentation/widgets/songs_selection_sheet.dart' show SongHistoryEntry;
import 'package:attendix/features/planning/presentation/widgets/plan_song_helper.dart';
import 'package:attendix/features/planning/presentation/widgets/rd_plan_start.dart';
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
  // The Termin as the Termin page loads it, its Terminart (with Werke) and
  // the Termine from its day on.
  List<Override> termine() => [
        attendanceDetailProvider.overrideWith((ref, id) async => TestFactories.createAttendance(
              id: id,
              tenantId: 1,
              date: (id == 9 ? concert : probe).date,
              typeId: id == 9 ? 'vortrag' : 'probe',
              startTime: id == 9 ? null : '19:00',
            )),
        attendanceTypeForAttendanceProvider.overrideWith((ref, id) async => TestFactories.createAttendanceType(
              id: id == 9 ? 'vortrag' : 'probe',
              name: id == 9 ? 'Vortrag' : 'Probe',
              tenantId: 1,
            ).copyWith(manageSongs: true, highlight: id == 9)),
        comingPlanAttendancesProvider.overrideWith((ref, from) async => [probe, nextProbe, concert, later]),
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

  test('a Vorlage takes the Werke at "Chor/Orchester", spread evenly and in order', () {
    const fields = [
      PlanField(id: 'a', name: 'Gemeinsamer Gesang', time: '25'),
      PlanField(id: 'b', name: 'Chor/Orchester', time: '7'),
      PlanField(id: 'c', name: 'Predigt', time: '15'),
      PlanField(id: 'd', name: 'Chor/Orchester', time: '7'),
    ];
    PlanField row(Song song, String time) => PlanField(id: 's${song.id}', name: song.name, time: time, songId: song.id);

    final three = rdFillWorkSlots(fields, songs, row: row);
    expect(three.placed, 3);
    expect([for (final f in three.fields) f.songId], [null, 1, 2, null, 3]);
    // Two Werke share a place with 5 minutes each; one alone keeps the place's time.
    expect([for (final f in three.fields) f.time], ['25', '5', '5', '15', '7']);

    // Fewer Werke than places: the rest stays as it is.
    final one = rdFillWorkSlots(fields, songs.take(1).toList(), row: row);
    expect([for (final f in one.fields) f.name], ['Gemeinsamer Gesang', 'Machet die Tore weit', 'Predigt', 'Chor/Orchester']);
    expect(rdFillWorkSlots(fields, const [], row: row).placed, 0);
  });

  testWidgets('"Mit den Werken dieser Probe" adds them with their conductors; "+ Werke" offers them again',
      (tester) async {
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
        songsProvider.overrideWith((ref) async => songs),
        attendanceSongEntriesProvider.overrideWith((ref, id) async => const []),
        songCollectionsProvider.overrideWith((ref) async => null),
        currentSongsProvider.overrideWith((ref) async => [(date: 'x', history: history)]),
        groupsProvider.overrideWith((ref) async => const []),
        groupCategoriesProvider.overrideWith((ref) async => const []),
        protocolTypesProvider.overrideWith((ref) async => const []),
        currentOrganisationProvider.overrideWith((ref) async => null),
        conductorsProvider.overrideWith((ref) async => const []),
        hasBrandingProvider.overrideWithValue(false),
        effectiveRoleProvider.overrideWithValue(Role.admin),
        ...termine(),
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

    // A Probe without Werke of its own starts with those of the next Auftritt.
    expect(find.text('Mit den Werken dieser Probe'), findsOneWidget);
    expect(find.text('2 Werke, je 5 Min'), findsOneWidget);
    await tester.tap(find.byKey(const Key('rd-plan-start-works')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    final stored = [
      for (final f in ((calls.last['plan'] as Map<String, dynamic>)['fields'] as List)) f as Map<String, dynamic>,
    ];
    expect([for (final f in stored) f['name']], ['12. Machet die Tore weit', '31. Tochter Zion']);
    expect([for (final f in stored) f['songId']], [1, 2]);
    expect(stored.first['conductor'], 'Anna Meier');
    // A Werk enters the Ablauf with 5 minutes.
    expect([for (final f in stored) f['time']], ['5', '5']);
    // "Hinzufügen" > "Programmpunkt" > "+ Werke" offers them first, with
    // "Anderes Werk" for the Werk list.
    await tester.tap(find.byKey(const Key('rd-plan-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rd-plan-add-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rd-plan-quick-works')));
    // No pumpAndSettle: "Hinzufügen" behind the sheet shows its spinner.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('rd-plan-event-work-0-2')), findsOneWidget);
    expect(find.byKey(const Key('rd-plan-event-works-other')), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('"Aus einer Vorlage": Gottesdienst takes the Werke of the Auftritt; Rückgängig leaves the Vorlage',
      (tester) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final calls = <Map<String, dynamic>>[];
    var row = concert;
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
        songsProvider.overrideWith((ref) async => songs),
        attendanceSongEntriesProvider.overrideWith((ref, id) async => const [
              SongHistoryEntry(songId: 1, songName: '12 - Machet die Tore weit', conductorName: 'Anna Meier'),
              SongHistoryEntry(songId: 2, songName: '31 - Tochter Zion'),
            ]),
        songCollectionsProvider.overrideWith((ref) async => null),
        currentSongsProvider.overrideWith((ref) async => [(date: 'x', history: history)]),
        groupsProvider.overrideWith((ref) async => const []),
        groupCategoriesProvider.overrideWith((ref) async => const []),
        protocolTypesProvider.overrideWith((ref) async => const []),
        currentOrganisationProvider.overrideWith((ref) async => null),
        conductorsProvider.overrideWith((ref) async => const []),
        hasBrandingProvider.overrideWithValue(false),
        effectiveRoleProvider.overrideWithValue(Role.admin),
        ...termine(),
      ],
    );
    addTearDown(container.dispose);
    // Chosen in the Reiter Programm of the Termin page.
    container.read(rdPlanStartProvider.notifier).state = (attendanceId: 9, action: 'tpl:builtin:gottesdienst');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const PlanningPage(attendanceId: 9),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    List<Map<String, dynamic>> stored() => [
          for (final f in ((calls.last['plan'] as Map<String, dynamic>)['fields'] as List)) f as Map<String, dynamic>,
        ];
    // 15 rows: the first two "Chor/Orchester" hold the two Werke, the third stays.
    expect(stored(), hasLength(15));
    expect([for (final f in stored()) if (f['songId'] != null) f['name']], ['12. Machet die Tore weit', '31. Tochter Zion']);
    expect(stored().where((f) => f['name'] == 'Chor/Orchester'), hasLength(1));
    expect(stored()[6]['conductor'], 'Anna Meier');
    expect(find.text('2 Werke eingesetzt'), findsOneWidget);

    await tester.tap(find.text('Rückgängig'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(stored().where((f) => f['name'] == 'Chor/Orchester'), hasLength(3));
    expect(stored().any((f) => f['songId'] != null), isFalse);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });
}
