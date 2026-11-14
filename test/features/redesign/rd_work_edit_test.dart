import 'dart:async';

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/connectivity_provider.dart';
import 'package:attendix/core/providers/debug_providers.dart';
import 'package:attendix/core/providers/redesign_providers.dart';
import 'package:attendix/core/providers/song_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/router/redesign_routes.dart';
import 'package:attendix/core/services/offline_queue_service.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/data/models/song/song.dart';
import 'package:attendix/data/models/song/song_additional_field.dart';
import 'package:attendix/data/repositories/song_repository.dart';
import 'package:attendix/features/redesign/data/rd_works_logic.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_work_create_page.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_work_edit_page.dart';
import 'package:attendix/features/redesign/presentation/widgets/rd_widgets.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../factories/test_factories.dart';

class _TenantNotifier extends CurrentTenantNotifier {
  _TenantNotifier(super.ref) {
    state = TestFactories.createTenant(id: 7, shortName: 'SO', longName: 'Stadtorchester');
  }
}

/// Records the writes instead of calling Supabase.
class _FakeSongRepo extends SongRepository {
  _FakeSongRepo(super.ref) {
    setTenantId(7);
  }

  final updates = <Map<String, dynamic>>[];
  final created = <Song>[];
  bool deleted = false;

  /// The next writes that fail (offline).
  int failures = 0;

  @override
  Future<Song> createSong(Song song) async {
    created.add(song);
    return song.copyWith(id: 99);
  }

  @override
  Future<Song> updateSong(int id, Map<String, dynamic> updates) async {
    if (failures > 0) {
      failures--;
      throw Exception('offline');
    }
    this.updates.add(Map.of(updates));
    return _song;
  }

  @override
  Future<void> deleteSong(int id) async => deleted = true;
}

const _song = Song(id: 5, name: 'Festliche Ouvertüre', number: 12, categoryIds: ['k'], difficulty: 2);
const _ave = Song(id: 6, name: 'Ave verum corpus', number: 41);

Widget _editApp(
  void Function(_FakeSongRepo) onRepo, {
  Future<List<Song>>? songs,
  List<SongAdditionalField> fields = const [],
  bool create = false,
}) {
  final router = GoRouter(
    initialLocation: create ? '/werke/neu' : '/werke/5/bearbeiten',
    routes: [
      GoRoute(
        path: '/werke',
        builder: (_, __) => const Scaffold(body: Text('page works')),
        routes: [
          GoRoute(path: 'neu', builder: (_, __) => const RdWorkCreatePage()),
          GoRoute(path: ':id', builder: (_, s) => Scaffold(body: Text('page work ${s.pathParameters['id']}'))),
          GoRoute(
            path: ':id/bearbeiten',
            builder: (_, s) => RdWorkEditPage(songId: int.parse(s.pathParameters['id']!)),
          ),
        ],
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      initialRedesignSettingsProvider.overrideWithValue(
        const RedesignSettings(enabled: true, world: RdFarbwelt.petrol),
      ),
      effectiveRoleProvider.overrideWithValue(Role.admin),
      currentTenantProvider.overrideWith((ref) => _TenantNotifier(ref)),
      currentTenantIdProvider.overrideWithValue(7),
      offlineQueueUserIdProvider.overrideWithValue(() => 'u1'),
      connectivityProvider.overrideWith((ref) => const Stream<bool>.empty()),
      offlineQueueSessionIdProvider.overrideWithValue(() => 's1'),
      songRepositoryWithTenantProvider.overrideWith((ref) {
        final repo = _FakeSongRepo(ref);
        onRepo(repo);
        return repo;
      }),
      songDetailDataProvider((songId: 5, sharingId: null)).overrideWith(
        (ref) async => SongDetailData(
          song: _song,
          tenantType: 'orchestra',
          instruments: const [],
          categories: const [
            SongCategory(id: 'k', name: 'Konzert', index: 0),
            SongCategory(id: 'c', name: 'Kirche', index: 1),
          ],
          additionalFields: fields,
          history: const [],
          readOnly: false,
        ),
      ),
      songsProvider.overrideWith((ref) => songs ?? Future.value(const [_song, _ave])),
      songCategoriesProvider.overrideWith((ref) async => const [SongCategory(id: 'k', name: 'Konzert', index: 0)]),
      songSyncedTenantNamesProvider.overrideWith((ref) async => const []),
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

/// REDESIGN: "Werk bearbeiten" (Werke Paket 2): master data only, saved
/// right away, no Besetzung, "Werk löschen" at the bottom.
void main() {
  group('RdWorkEditPage', () {
    testWidgets('saves every change right away, without a Besetzung choice', (tester) async {
      _phone(tester);
      late _FakeSongRepo repo;
      await tester.pumpWidget(_editApp((r) => repo = r));
      await _settle(tester);

      expect(find.text('Werk bearbeiten'), findsOneWidget);
      expect(find.text('Festliche Ouvertüre'), findsOneWidget);
      expect(find.text('Besetzung'.toUpperCase()), findsOneWidget);
      expect(find.textContaining('ergibt sich aus den hochgeladenen Noten'), findsOneWidget);

      await tester.tap(find.text('Schwer'));
      await tester.tap(find.text('Kirche'));
      await tester.tap(find.text('Mit Chor'));
      await tester.enterText(find.byKey(const Key('rd-work-edit-name')), 'Ouvertüre in D');
      await tester.tap(find.byKey(const Key('rd-work-edit-done')));
      await _settle(tester);

      expect(repo.updates, [
        {'difficulty': 3},
        {
          'category_ids': ['k', 'c'],
        },
        {'withChoir': true},
        {'name': 'Ouvertüre in D'},
      ]);
      expect(find.text('page works'), findsOneWidget); // "Fertig" closes the form
    });

    testWidgets('Dauer im Ablauf is kept with the Zusatzfelder', (tester) async {
      _phone(tester);
      late _FakeSongRepo repo;
      await tester.pumpWidget(_editApp((r) => repo = r));
      await _settle(tester);

      final minutes = find.byKey(const Key('rd-work-edit-minutes'));
      await tester.scrollUntilVisible(minutes, 200, scrollable: find.byType(Scrollable).first);
      await tester.enterText(minutes, '8');
      await tester.tap(find.byKey(const Key('rd-work-edit-done')));
      await _settle(tester);

      expect(repo.updates, [
        {
          'additional_fields': {'planMinutes': 8},
        },
      ]);
    });

    testWidgets('a number another Werk has is named and not saved', (tester) async {
      _phone(tester);
      late _FakeSongRepo repo;
      await tester.pumpWidget(_editApp((r) => repo = r));
      await _settle(tester);

      await tester.enterText(find.byKey(const Key('rd-work-edit-number')), '41');
      await tester.pump();
      expect(find.textContaining('Nr. 41 hat schon „Ave verum corpus“'), findsOneWidget);
      await tester.tap(find.byKey(const Key('rd-work-edit-name')));
      await _settle(tester);
      expect(repo.updates, isEmpty);

      await tester.enterText(find.byKey(const Key('rd-work-edit-number')), '42');
      await tester.tap(find.byKey(const Key('rd-work-edit-name')));
      await _settle(tester);
      expect(find.textContaining('hat schon'), findsNothing);
      expect(repo.updates, [
        {'prefix': '', 'number': 42},
      ]);
    });

    testWidgets('number locked until the Werke are loaded; a failed save is tried again', (tester) async {
      _phone(tester);
      late _FakeSongRepo repo;
      final songs = Completer<List<Song>>();
      await tester.pumpWidget(
        _editApp(
          (r) => repo = r,
          songs: songs.future,
          fields: const [SongAdditionalField(id: 'dauer', name: 'Dauer', type: 'text')],
        ),
      );
      await _settle(tester);

      bool locked() => tester.widget<TextField>(find.byKey(const Key('rd-work-edit-number'))).readOnly;
      expect(locked(), isTrue);
      songs.complete(const [_song, _ave]);
      await _settle(tester);
      expect(locked(), isFalse);

      repo.failures = 1;
      await tester.enterText(find.byKey(const Key('rd-work-edit-field-dauer')), '7 min');
      FocusManager.instance.primaryFocus?.unfocus(); // focus change: fails
      await _settle(tester);
      expect(repo.updates, isEmpty);
      await tester.pump(const Duration(seconds: 4)); // the error toast covers "Fertig"
      await _settle(tester);
      await tester.tap(find.byKey(const Key('rd-work-edit-done'))); // closing tries again
      await _settle(tester);
      expect(repo.updates, [
        {
          'additional_fields': {'dauer': '7 min'},
        },
      ]);
    });

    testWidgets('only switch fields: a failed save is tried again on close', (tester) async {
      _phone(tester);
      late _FakeSongRepo repo;
      await tester.pumpWidget(
        _editApp((r) => repo = r, fields: const [SongAdditionalField(id: 'orgel', name: 'Mit Orgel', type: 'boolean')]),
      );
      await _settle(tester);

      repo.failures = 1;
      await tester.ensureVisible(find.text('Mit Orgel'));
      await _settle(tester);
      await tester.tap(find.text('Mit Orgel'));
      await _settle(tester);
      expect(repo.updates, isEmpty);
      await tester.pump(const Duration(seconds: 4)); // the error toast covers "Fertig"
      await _settle(tester);
      await tester.tap(find.byKey(const Key('rd-work-edit-done')));
      await _settle(tester);
      // Switches start on (Ionic default), the tap turned it off.
      expect(repo.updates, [
        {
          'additional_fields': {'orgel': false},
        },
      ]);
    });

    testWidgets('Werk löschen asks first and returns to the list', (tester) async {
      _phone(tester);
      late _FakeSongRepo repo;
      await tester.pumpWidget(_editApp((r) => repo = r));
      await _settle(tester);

      await tester.ensureVisible(find.byKey(const Key('rd-work-edit-delete')));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('rd-work-edit-delete')));
      await _settle(tester);
      expect(find.textContaining('Das Werk wird mit seinen Dateien gelöscht.'), findsOneWidget);
      await tester.tap(find.text('Löschen'));
      await _settle(tester);

      expect(repo.deleted, isTrue);
      expect(find.text('page works'), findsOneWidget);
      expect(repo.updates, isEmpty);
    });
  });

  testWidgets('Neues Werk: next free number once the Werke are loaded, no Besetzung, then the Werk page', (
    tester,
  ) async {
    _phone(tester);
    late _FakeSongRepo repo;
    final songs = Completer<List<Song>>();
    await tester.pumpWidget(_editApp((r) => repo = r, create: true, songs: songs.future));
    await _settle(tester);
    await tester.enterText(find.byKey(const Key('rd-work-create-name')), 'Tochter Zion');
    await tester.pump();
    // No number and no Werk before the list is there to check against.
    await tester.tap(find.byKey(const Key('rd-work-create-submit')));
    await tester.pump();
    expect(repo.created, isEmpty);
    songs.complete(const [_song, _ave]);
    await _settle(tester);

    expect(find.widgetWithText(TextField, '42'), findsOneWidget);
    expect(find.textContaining('42 ist die nächste freie Nummer.'), findsOneWidget);
    await tester.tap(find.text('Mit Chor'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('rd-work-create-submit')));
    await _settle(tester);

    final song = repo.created.single;
    expect((song.name, song.number, song.prefix, song.withChoir), ('Tochter Zion', 42, '', true));
    expect(song.instrumentIds, isEmpty);
    expect(find.text('page work 99'), findsOneWidget);
  });

  test('old song links open the Werk pages, editing only for leads', () {
    expect(RedesignRoutes.oldSongTarget('/settings/songs/5'), '/werke/5');
    expect(RedesignRoutes.oldSongTarget('/songs-tab/5'), '/werke/5');
    expect(RedesignRoutes.oldSongTarget('/settings/songs/5/edit'), '/werke/5/bearbeiten');
    expect(RedesignRoutes.oldSongTarget('/settings/songs/new'), isNull);
    expect(RedesignRoutes.oldSongTarget('/settings/songs'), isNull);

    expect(RedesignRoutes.roleRedirect('/werke/5/bearbeiten', Role.admin), isNull);
    expect(RedesignRoutes.roleRedirect('/werke/5/bearbeiten', Role.responsible), isNull);
    expect(RedesignRoutes.roleRedirect('/werke/5/bearbeiten', Role.player), '/werke/5');
    expect(RedesignRoutes.roleRedirect('/werke/5', Role.player), isNull);
  });

  test('rdNumberTakenBy: same prefix and number on another Werk', () {
    const songs = [Song(id: 1, name: 'A', number: 12), Song(id: 2, name: 'B', number: 3, prefix: 'W')];
    expect(rdNumberTakenBy(songs, 1, '', 12), isNull); // the Werk itself
    expect(rdNumberTakenBy(songs, 9, '', 12)?.name, 'A');
    expect(rdNumberTakenBy(songs, 9, 'w ', 3)?.name, 'B');
    expect(rdNumberTakenBy(songs, 9, '', 3), isNull);
    expect(rdNumberTakenBy(songs, 9, '', null), isNull);
  });
}
