import 'dart:async';
import 'dart:io';

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/debug_providers.dart';
import 'package:attendix/core/providers/group_providers.dart';
import 'package:attendix/core/providers/player_providers.dart';
import 'package:attendix/core/providers/redesign_providers.dart';
import 'package:attendix/core/providers/self_service_providers.dart';
import 'package:attendix/core/providers/song_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/router/redesign_routes.dart';
import 'package:attendix/core/services/audio_player/audio_player_service.dart';
import 'package:attendix/core/services/song_file_service.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/data/models/song/song.dart';
import 'package:attendix/features/redesign/data/rd_works_logic.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_work_page.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_works_page.dart';
import 'package:attendix/features/redesign/presentation/widgets/rd_overview.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:attendix/features/songs/presentation/utils/song_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  TestFactories.createGroup(id: 13, name: 'Dirigent', maingroup: true),
];

const _pdf = 'application/pdf';

/// Only the download is used by "teilen".
class _BytesFiles implements SongFileService {
  _BytesFiles(this.bytes, {this.gate});

  final Uint8List? bytes;

  /// Holds the download until completed.
  final Completer<void>? gate;
  final downloads = <String>[];

  @override
  Future<Uint8List?> downloadFileBytes(String url) async {
    downloads.add(url);
    await gate?.future;
    return bytes;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records the calls on the share_plus channel.
List<MethodCall> _mockShare(WidgetTester tester) {
  const channel = MethodChannel('dev.fluttercommunity.plus/share');
  final calls = <MethodCall>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
    calls.add(call);
    return 'net.whatsapp.WhatsApp.ShareExtension';
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
  return calls;
}

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

/// A number tile of the overview, by its spoken label.
Finder _stat(String label) => find.byWidgetPredicate((w) => w is Semantics && w.properties.label == label);

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

Widget _worksApp(Role role, {List<Song>? songs, bool twoLists = false, bool overview = false}) {
  final router = GoRouter(
    initialLocation: '/werke',
    routes: [
      GoRoute(
        path: '/werke',
        builder: (_, __) => overview
            ? const RdWorksOverviewPanel()
            : twoLists
            ? const Row(children: [
                Expanded(child: RdWorksPage(key: ValueKey('first'))),
                Expanded(child: RdWorksPage(key: ValueKey('second'))),
              ])
            : const RdWorksPage(),
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

Widget _workApp(
  Role role, {
  Song? song,
  int? instrument = 11,
  _FakePlayer? player,
  List<Override> overrides = const [],
}) {
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
      ...overrides,
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

    test('top card: own part, else score or all parts for conductors', () {
      expect(rdWorkLead(_ouverture, 11, isMainGroup: false), RdWorkLead.part);
      expect(rdWorkLead(_ouverture, 99, isMainGroup: false), RdWorkLead.noPart);
      // Main group (Dirigent) and persons without a group: never "no part".
      expect(rdWorkLead(_ouverture, 13, isMainGroup: true), RdWorkLead.score);
      expect(rdWorkLead(_ouverture, null, isMainGroup: false), RdWorkLead.score);
      expect(rdWorkLead(_abend, 13, isMainGroup: true), RdWorkLead.allParts);
      expect(rdWorkLead(_abend, null, isMainGroup: false), RdWorkLead.allParts);
      expect(rdWorkLead(_ave, 13, isMainGroup: true), RdWorkLead.none);
      expect(rdWorkLead(_ave, 11, isMainGroup: false), RdWorkLead.none);
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

    testWidgets('the search is shared by every copy of the list (split view, back)', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_worksApp(Role.player, twoLists: true));
      await _settle(tester);

      await tester.enterText(find.byType(TextField).first, 'mozart');
      await _settle(tester);
      expect(find.widgetWithText(TextField, 'mozart'), findsNWidgets(2));
      expect(find.text('Abendlied'), findsNothing);

      // Changed in the other copy: the first one follows (text and filter).
      await tester.enterText(find.byType(TextField).last, 'abend');
      await _settle(tester);
      expect(find.widgetWithText(TextField, 'abend'), findsNWidgets(2));
      expect(find.text('Abendlied'), findsNWidgets(2));
      expect(find.text('Ave verum corpus'), findsNothing);
    });

    testWidgets('a row and a current card open the work', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_worksApp(Role.player));
      await _settle(tester);
      await tester.tap(find.text('Abendlied'));
      await _settle(tester);
      expect(find.text('page work 7'), findsOneWidget);
    });

    testWidgets('empty split column: overview with counts, next plan, missing sheet music', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final planned = DateTime.now().add(const Duration(days: 3));
      final songs = [
        _ouverture.copyWith(lastSung: '2025-01-10T19:00:00Z'),
        _ave.copyWith(nextPlanned: planned.toIso8601String(), lastSung: '2024-05-01T19:00:00Z'),
        _abend.copyWith(lastSung: '2026-06-01T19:00:00Z'),
      ];
      await tester.pumpWidget(_worksApp(Role.admin, songs: songs, overview: true));
      await _settle(tester);

      expect(find.text('Überblick'), findsOneWidget);
      expect(_stat('3 Werke'), findsOneWidget);
      expect(_stat('2 mit Noten'), findsOneWidget);
      expect(_stat('1 ohne Noten'), findsOneWidget);
      expect(find.textContaining('ALS NÄCHSTES GEPLANT'), findsOneWidget);
      expect(find.text('NOCH OHNE NOTEN'), findsOneWidget);
      expect(find.text('Werk hinzufügen'), findsOneWidget);
      // Ave is planned again: not "long ago"; the oldest comes first.
      expect(find.text('AM LÄNGSTEN NICHT DRAN'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('12  Festliche Ouvertüre')).dy,
        lessThan(tester.getTopLeft(find.text('3  Abendlied')).dy),
      );

      await tester.tap(find.text('41  Ave verum corpus').first);
      await _settle(tester);
      expect(find.text('page work 6'), findsOneWidget);
    });

    testWidgets('overview for players: no missing sheet music, no add button', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_worksApp(Role.player, overview: true));
      await _settle(tester);
      expect(find.text('Überblick'), findsOneWidget);
      expect(find.text('NOCH OHNE NOTEN'), findsNothing);
      expect(find.text('Werk hinzufügen'), findsNothing);
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

    testWidgets('small phone with large text: Deine Stimme keeps its layout', (tester) async {
      tester.view.physicalSize = const Size(320, 852);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(_workApp(Role.player, song: _ouverture));
      await _settle(tester);

      // No overflow (the test would fail on one); the buttons sit below the
      // title instead of next to it.
      expect(find.text('DEINE STIMME'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Öffnen')).dy,
        greaterThan(tester.getBottomLeft(find.text('Klarinette')).dy),
      );
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

    testWidgets('conductor (main group): the score on top, no "no part" hint', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_workApp(Role.admin, song: _ouverture, instrument: 13));
      await _settle(tester);
      expect(find.text('Für deine Stimme gibt es noch keine Noten.'), findsNothing);
      expect(find.text('DEINE STIMME'), findsNothing);
      expect(find.text('PARTITUR'), findsOneWidget);
      expect(find.text('partitur.pdf'), findsOneWidget);
      expect(find.text('Öffnen'), findsOneWidget);
      // The score is not listed twice; all parts stay in the list.
      expect(find.text('Partitur'), findsNothing);
      expect(find.text('Alle Stimmen'), findsOneWidget);
    });

    testWidgets('conductor without a score: all parts on top', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_workApp(Role.admin, song: _abend, instrument: 13));
      await _settle(tester);
      expect(find.text('Für deine Stimme gibt es noch keine Noten.'), findsNothing);
      expect(find.text('ALLE STIMMEN'), findsOneWidget);
      expect(find.text('1 Datei'), findsOneWidget);
      expect(find.text('Alle Stimmen'), findsNothing);

      await tester.tap(find.text('Öffnen'));
      await _settle(tester);
      expect(find.text('abend.pdf'), findsOneWidget);
    });

    testWidgets('no own person entry: like a conductor', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_workApp(Role.admin, song: _ouverture, instrument: null));
      await _settle(tester);
      expect(find.text('Für deine Stimme gibt es noch keine Noten.'), findsNothing);
      expect(find.text('PARTITUR'), findsOneWidget);
    });

    testWidgets('Teilen opens the system share sheet with name and link', (tester) async {
      _phone(tester);
      const channel = MethodChannel('dev.fluttercommunity.plus/share');
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return 'net.whatsapp.WhatsApp.ShareExtension';
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
      await tester.pumpWidget(_workApp(Role.player, song: _ouverture));
      await _settle(tester);

      await tester.tap(find.byTooltip('Teilen'));
      await _settle(tester);
      expect(calls.single.method, 'share');
      final args = Map<String, dynamic>.from(calls.single.arguments as Map);
      expect(args['text'], 'Festliche Ouvertüre\n${SongUtils.shareLink('abc', 5)}');
      expect(args['subject'], 'Festliche Ouvertüre');
      expect(args['originX'], isNotNull);
      expect(find.text('Link kopiert'), findsNothing);
    });

    testWidgets('without a share sheet the link is copied', (tester) async {
      _phone(tester);
      const channel = MethodChannel('dev.fluttercommunity.plus/share');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async => null);
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await tester.pumpWidget(_workApp(Role.player, song: _ouverture));
      await _settle(tester);

      await tester.tap(find.byTooltip('Teilen'));
      await _settle(tester);
      expect(copied, SongUtils.shareLink('abc', 5));
    });

    testWidgets('your part: teilen sends the file itself', (tester) async {
      _phone(tester);
      final calls = _mockShare(tester);
      final temp = Directory.systemTemp.createTempSync('rd_share');
      addTearDown(() => temp.deleteSync(recursive: true));
      const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(pathChannel, (call) async => temp.path);
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(pathChannel, null));
      final files = _BytesFiles(Uint8List.fromList([1, 2, 3]));
      await tester.pumpWidget(_workApp(
        Role.player,
        song: _ouverture,
        overrides: [songFileServiceProvider.overrideWithValue(files)],
      ));
      await _settle(tester);

      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('Klarinette teilen'));
        for (var i = 0; i < 20 && calls.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      });
      await _settle(tester);
      expect(files.downloads, ['https://x/klar.pdf']);
      expect(calls.single.method, 'shareFiles');
      final args = Map<String, dynamic>.from(calls.single.arguments as Map);
      expect(args['subject'], 'Festliche Ouvertüre · Klarinette');
      expect((args['paths'] as List).single, endsWith('klar.pdf'));
      expect(args['mimeTypes'], ['application/pdf']);
    });

    testWidgets('a part that cannot be downloaded: its link is shared', (tester) async {
      _phone(tester);
      final calls = _mockShare(tester);
      await tester.pumpWidget(_workApp(
        Role.player,
        song: _ouverture,
        overrides: [songFileServiceProvider.overrideWithValue(_BytesFiles(null))],
      ));
      await _settle(tester);

      await tester.tap(find.text('Alle Stimmen'));
      await _settle(tester);
      await tester.tap(find.byTooltip('Flöte teilen'));
      await _settle(tester);
      expect(calls.single.method, 'share');
      final args = Map<String, dynamic>.from(calls.single.arguments as Map);
      expect(args['text'], 'Festliche Ouvertüre · Flöte\nhttps://x/floete.pdf');
    });

    testWidgets('sheet closed during the download: no share sheet', (tester) async {
      _phone(tester);
      final calls = _mockShare(tester);
      final temp = Directory.systemTemp.createTempSync('rd_share');
      addTearDown(() => temp.deleteSync(recursive: true));
      const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(pathChannel, (call) async => temp.path);
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(pathChannel, null));
      final gate = Completer<void>();
      final files = _BytesFiles(Uint8List.fromList([1, 2, 3]), gate: gate);
      await tester.pumpWidget(_workApp(
        Role.player,
        song: _ouverture,
        overrides: [songFileServiceProvider.overrideWithValue(files)],
      ));
      await _settle(tester);

      await tester.tap(find.text('Alle Stimmen'));
      await _settle(tester);
      // Real async: the share sheet writes the file to the temp folder.
      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('Flöte teilen'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      expect(files.downloads, ['https://x/floete.pdf']);
      Navigator.of(tester.element(find.byTooltip('Flöte teilen'))).pop();
      await _settle(tester);
      expect(find.byTooltip('Flöte teilen'), findsNothing);

      await tester.runAsync(() async {
        gate.complete();
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await _settle(tester);
      expect(calls, isEmpty);
    });

    testWidgets('players do not get Gruppen-PDFs drucken', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_workApp(Role.player, song: _ouverture));
      await _settle(tester);
      expect(find.text('Gruppen-PDFs drucken'), findsNothing);
    });

    testWidgets('admin: Gruppen-PDFs drucken asks for the copies', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_workApp(
        Role.admin,
        song: _ouverture,
        overrides: [playerCountByInstrumentProvider.overrideWith((ref) async => {11: 4, 12: 2})],
      ));
      await _settle(tester);
      await tester.tap(find.text('Gruppen-PDFs drucken'));
      await _settle(tester);
      expect(find.text('Druckoptionen'), findsOneWidget);
      expect(find.text('Wie viele Ausdrucke pro Gruppe?'), findsOneWidget);
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
