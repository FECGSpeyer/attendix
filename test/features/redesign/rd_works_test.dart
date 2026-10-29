import 'dart:async';
import 'dart:io';

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/debug_providers.dart';
import 'package:attendix/core/providers/group_providers.dart';
import 'package:attendix/core/providers/redesign_providers.dart';
import 'package:attendix/core/providers/self_service_providers.dart';
import 'package:attendix/core/providers/song_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/router/redesign_routes.dart';
import 'package:attendix/core/services/audio_player/audio_player_service.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/data/models/song/song.dart';
import 'package:attendix/features/redesign/data/rd_works_logic.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_work_page.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_works_page.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../factories/test_factories.dart';

class _TenantNotifier extends CurrentTenantNotifier {
  _TenantNotifier(super.ref) {
    state = TestFactories.createTenant(id: 7, shortName: 'SO', longName: 'Stadtorchester');
  }
}

/// Player without a platform: records the URL, plays at once.
class _FakePlayer implements AudioPlayer {
  final _playing = StreamController<bool>.broadcast();
  String? url;
  final speeds = <double>[];

  @override
  Stream<bool> get playingStream => _playing.stream;
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Stream<Duration?> get durationStream => const Stream.empty();
  @override
  Stream<ProcessingState> get processingStateStream => const Stream.empty();
  @override
  Duration get position => Duration.zero;

  @override
  Future<Duration?> setUrl(String url,
      {Map<String, String>? headers, Duration? initialPosition, bool preload = true, dynamic tag}) async {
    this.url = url;
    return const Duration(minutes: 3, seconds: 28);
  }

  @override
  Future<void> play() async => _playing.add(true);
  @override
  Future<void> pause() async => _playing.add(false);
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<void> setSpeed(double speed) async => speeds.add(speed);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

const _konzert = SongCategory(id: 'k', name: 'Konzert', index: 0);
const _kirche = SongCategory(id: 'c', name: 'Kirche', index: 1);

final _groups = [
  TestFactories.createGroup(id: 11, name: 'Klarinette'),
  TestFactories.createGroup(id: 12, name: 'Flöte'),
];

const _pdf = 'application/pdf';

final _ouverture = Song(
  id: 5,
  name: 'Festliche Ouvertüre',
  number: 12,
  composer: 'D. Schostakowitsch',
  categoryIds: const ['k'],
  files: const [
    SongFile(fileName: 'klar.pdf', fileType: _pdf, url: 'https://x/klar.pdf', instrumentId: 11),
    SongFile(fileName: 'floete.pdf', fileType: _pdf, url: 'https://x/floete.pdf', instrumentId: 12),
    SongFile(fileName: 'partitur.pdf', fileType: _pdf, url: 'https://x/partitur.pdf', note: 'Partitur'),
    SongFile(
      fileName: 'probe.mp3',
      fileType: 'audio/mpeg',
      url: 'https://x/probe.mp3',
      instrumentId: 1,
      createdAt: '2026-10-23T19:00:00Z',
    ),
  ],
);
const _ave = Song(id: 6, name: 'Ave verum corpus', number: 41, composer: 'W. A. Mozart', categoryIds: ['c']);
const _abend = Song(
  id: 7,
  name: 'Abendlied',
  number: 3,
  composer: 'J. Rheinberger',
  categoryIds: ['c'],
  files: [SongFile(fileName: 'abend.pdf', fileType: _pdf, url: 'https://x/abend.pdf', instrumentId: 12)],
);

/// Bounded pumps: loading spinners never settle.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

MaterialApp _material(GoRouter router) => MaterialApp.router(
      locale: const Locale('de'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
      routerConfig: router,
    );

List<Override> _common(Role role) => [
      initialRedesignSettingsProvider.overrideWithValue(
        const RedesignSettings(enabled: true, world: RdFarbwelt.petrol),
      ),
      effectiveRoleProvider.overrideWithValue(role),
      currentTenantProvider.overrideWith((ref) => _TenantNotifier(ref)),
    ];

Widget _worksApp(Role role, {List<Song>? songs}) {
  final router = GoRouter(
    initialLocation: '/werke',
    routes: [
      GoRoute(
        path: '/werke',
        builder: (_, __) => const RdWorksPage(),
        routes: [
          GoRoute(path: ':id', builder: (_, s) => Scaffold(body: Text('page work ${s.pathParameters['id']}'))),
        ],
      ),
    ],
  );
  final list = songs ?? [_ouverture, _ave, _abend];
  return ProviderScope(
    overrides: [
      ..._common(role),
      songsRealtimeProvider.overrideWith((ref) {}),
      songsListDataProvider(null).overrideWith((ref) async => SongsListData(
            tenantId: 7,
            tenantType: 'orchestra',
            songs: list,
            categories: const [_kirche, _konzert],
            groups: _groups,
            groupCategories: const [],
            currentSongs: [
              (date: '2026-11-05', history: const [SongHistory(songId: 6)]),
              (date: '2026-11-03', history: const [SongHistory(songId: 5), SongHistory(songId: 6)]),
            ],
            additionalFields: const [],
          )),
    ],
    child: _material(router),
  );
}

Widget _workApp(Role role, {Song? song, int? instrument = 11, _FakePlayer? player}) {
  final router = GoRouter(
    initialLocation: '/werke/5',
    routes: [
      GoRoute(
        path: '/werke',
        builder: (_, __) => const Scaffold(body: Text('page works')),
        routes: [
          GoRoute(path: ':id', builder: (_, s) => RdWorkPage(songId: int.parse(s.pathParameters['id']!))),
        ],
      ),
      GoRoute(path: '/settings/songs/:id', builder: (_, s) => Scaffold(body: Text('page old ${s.pathParameters['id']}'))),
    ],
  );
  final readOnly = !(role.isAdmin || role.isResponsible);
  return ProviderScope(
    overrides: [
      ..._common(role),
      audioPlayerFactoryProvider.overrideWithValue(() => player ?? _FakePlayer()),
      songDetailDataProvider((songId: 5, sharingId: null)).overrideWith((ref) async => song == null
          ? null
          : SongDetailData(
              song: song,
              tenantType: 'orchestra',
              instruments: _groups,
              categories: const [_konzert, _kirche],
              additionalFields: const [],
              history: const [],
              readOnly: readOnly,
              songSharingId: 'abc',
            )),
      songsProvider.overrideWith((ref) async => [
            if (song != null) song.copyWith(lastSung: '2026-10-20', conductor: 'Lea Berg', nextPlanned: '2026-11-03'),
          ]),
      groupsProvider.overrideWith((ref) async => _groups),
      currentSelfServicePlayerProvider.overrideWith(
        (ref) async => TestFactories.createPerson(id: 3, tenantId: 7, instrument: instrument),
      ),
    ],
    child: _material(router),
  );
}

/// REDESIGN: tab "Werke" and the work page (canvas "WerkeListe",
/// "WerkDetail").
void main() {
  setUpAll(() async {
    await initializeDateFormatting('de_DE');
    await initializeDateFormatting('de');
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('logic', () {
    test('search over title, composer and number', () {
      expect(rdWorkMatches(_ave, 'mozart'), isTrue);
      expect(rdWorkMatches(_ave, 'ave corpus'), isTrue);
      expect(rdWorkMatches(_ave, '41'), isTrue);
      expect(rdWorkMatches(_ave, 'rheinberger'), isFalse);
    });

    test('current works: soonest Termin first, each once', () {
      final current = rdCurrentWorks([
        (date: '2026-11-05', history: const [SongHistory(songId: 6), SongHistory(songId: 7)]),
        (date: '2026-11-03', history: const [SongHistory(songId: 5), SongHistory(songId: 6)]),
      ], [_ouverture, _ave, _abend]);
      expect(current.map((s) => s.id), [5, 6, 7]);
    });

    test('files: badges, own part, recording, score, categories', () {
      expect(rdHasPdf(_ouverture), isTrue);
      expect(rdHasAudio(_ouverture), isTrue);
      expect(rdHasAudio(_abend), isFalse);
      expect(rdPartFiles(_ouverture, 11).single.fileName, 'klar.pdf');
      expect(rdPartFiles(_ouverture, 1), isEmpty);
      expect(rdPartFiles(_ouverture, null), isEmpty);
      expect(rdRecording(_ouverture)?.fileName, 'probe.mp3');
      expect(rdScore(_ouverture)?.fileName, 'partitur.pdf');
      expect(rdCategoryNames(_ouverture, const [_kirche, _konzert]), ['Konzert']);
      expect(rdFileKind(_ouverture.files![3]), 'MP3');
      expect(rdFileKind(_ouverture.files![0]), 'PDF');
    });

    test('Werke routes follow the /songs-tab guard', () {
      for (final role in [Role.parent, Role.applicant]) {
        expect(RedesignRoutes.roleRedirect('/werke', role), '/heute', reason: role.name);
        expect(RedesignRoutes.roleRedirect('/werke/5', role), '/heute', reason: role.name);
      }
      for (final role in [Role.admin, Role.viewer, Role.helper, Role.player, Role.voiceLeader, Role.none]) {
        expect(RedesignRoutes.roleRedirect('/werke/5', role), isNull, reason: role.name);
      }
      expect(RedesignRoutes.work(5), '/werke/5');
    });
  });

  group('RdWorksPage', () {
    testWidgets('current works, categories, rows with badges', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_worksApp(Role.player));
      await _settle(tester);

      expect(find.text('Werke'), findsOneWidget);
      expect(find.text('Gerade geprobt'), findsOneWidget);
      expect(find.text('Alle · 3'), findsOneWidget);
      expect(find.text('Konzert'), findsOneWidget);
      expect(find.text('Kirche'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('PDF'), findsNWidgets(2));
      expect(find.text('Audio'), findsOneWidget);
      // Players get no "Werk hinzufügen".
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.bySemanticsLabel('Dateien der Gruppe'), findsOneWidget);
      // Sorted by number like the old list.
      expect(
        tester.getTopLeft(find.text('Abendlied').last).dy,
        lessThan(tester.getTopLeft(find.text('Ave verum corpus').last).dy),
      );
    });

    testWidgets('category chips and search filter the list', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_worksApp(Role.player));
      await _settle(tester);

      await tester.tap(find.text('Kirche'));
      await _settle(tester);
      expect(find.text('Festliche Ouvertüre'), findsNothing);
      expect(find.text('Gerade geprobt'), findsNothing);
      expect(find.text('Abendlied'), findsOneWidget);

      await tester.tap(find.text('Alle · 3'));
      await _settle(tester);
      await tester.enterText(find.byType(TextField), 'mozart');
      await _settle(tester);
      expect(find.text('Ave verum corpus'), findsOneWidget);
      expect(find.text('Abendlied'), findsNothing);

      await tester.enterText(find.byType(TextField), 'zzz');
      await _settle(tester);
      expect(find.text('Kein Werk passt zur Suche.'), findsOneWidget);
    });

    testWidgets('a row and a current card open the work', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_worksApp(Role.player));
      await _settle(tester);
      await tester.tap(find.text('Abendlied'));
      await _settle(tester);
      expect(find.text('page work 7'), findsOneWidget);
    });

    testWidgets('admin may add works; no group files, no Dateien', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_worksApp(Role.admin, songs: const [_ave]));
      await _settle(tester);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.bySemanticsLabel('Dateien der Gruppe'), findsNothing);
      expect(find.bySemanticsLabel('Mehr'), findsOneWidget);
    });
  });

  group('RdWorkPage', () {
    testWidgets('your part, recording, all parts, score, last played', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_workApp(Role.player, song: _ouverture));
      await _settle(tester);

      expect(find.text('Nr. 12 · Konzert'), findsOneWidget);
      expect(find.text('Festliche Ouvertüre'), findsOneWidget);
      expect(find.text('D. Schostakowitsch'), findsOneWidget);
      expect(find.text('DEINE STIMME'), findsOneWidget);
      expect(find.text('Klarinette'), findsOneWidget);
      expect(find.text('Öffnen'), findsOneWidget);
      expect(find.textContaining('Aufnahme vom'), findsOneWidget);
      expect(find.text('Alle Stimmen'), findsOneWidget);
      expect(find.text('4 Dateien'), findsOneWidget);
      expect(find.text('Partitur'), findsOneWidget);
      expect(find.text('Zuletzt gespielt'), findsOneWidget);
      expect(find.textContaining('Lea Berg'), findsOneWidget);
      expect(find.text('Geplant'), findsOneWidget);
      // Players read only.
      expect(find.text('Bearbeiten'), findsNothing);
    });

    testWidgets('recording plays inline and 0,8× slows it down', (tester) async {
      _phone(tester);
      final player = _FakePlayer();
      await tester.pumpWidget(_workApp(Role.player, song: _ouverture, player: player));
      await _settle(tester);

      await tester.tap(find.bySemanticsLabel('Abspielen'));
      await _settle(tester);
      expect(player.url, 'https://x/probe.mp3');
      expect(find.bySemanticsLabel('Anhalten'), findsOneWidget);
      expect(find.text('3:28'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Langsamer abspielen'));
      await _settle(tester);
      expect(player.speeds, [0.8]);
      expect(find.text('0,8×'), findsOneWidget);
      expect(find.bySemanticsLabel('Normal abspielen'), findsOneWidget);
    });

    testWidgets('no part for my instrument: hint instead of the card', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_workApp(Role.player, song: _ouverture, instrument: 99));
      await _settle(tester);
      expect(find.text('DEINE STIMME'), findsNothing);
      expect(find.text('Für deine Stimme gibt es noch keine Noten.'), findsOneWidget);
    });

    testWidgets('admin: Bearbeiten opens the existing page', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_workApp(Role.admin, song: _ouverture));
      await _settle(tester);
      await tester.tap(find.text('Bearbeiten'));
      await _settle(tester);
      expect(find.text('page old 5'), findsOneWidget);
    });

    testWidgets('a work without files says so', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_workApp(Role.player, song: _ave));
      await _settle(tester);
      expect(find.text('Zu diesem Werk gibt es noch keine Dateien.'), findsOneWidget);
      expect(find.text('Alle Stimmen'), findsNothing);
    });

    testWidgets('unknown work shows a hint', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_workApp(Role.player));
      await _settle(tester);
      expect(find.text('Dieses Werk gibt es hier nicht mehr.'), findsOneWidget);
    });
  });

  group('security (source)', () {
    test('no direct Supabase access in the new pages', () {
      for (final path in [
        'lib/features/redesign/presentation/pages/rd_works_page.dart',
        'lib/features/redesign/presentation/pages/rd_work_page.dart',
      ]) {
        final src = File(path).readAsStringSync();
        expect(src, isNot(contains('supabase')), reason: path);
        expect(src, isNot(contains('.from(')), reason: path);
      }
    });

    test('router: Werke routes', () {
      final router = File('lib/core/router/app_router.dart').readAsStringSync();
      expect(router, contains("name: 'redesignWorks'"));
      expect(router, contains("name: 'redesignWork'"));
    });
  });
}
