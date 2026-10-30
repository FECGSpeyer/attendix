import 'dart:io';

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/debug_providers.dart';
import 'package:attendix/core/providers/group_providers.dart';
import 'package:attendix/core/providers/redesign_providers.dart';
import 'package:attendix/core/providers/self_service_providers.dart';
import 'package:attendix/core/providers/song_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/services/song_file_service.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/data/models/song/song.dart';
import 'package:attendix/features/redesign/data/rd_work_files_controller.dart';
import 'package:attendix/features/redesign/data/rd_work_files_logic.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_work_page.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../factories/test_factories.dart';

class _TenantNotifier extends CurrentTenantNotifier {
  _TenantNotifier(super.ref) {
    state = TestFactories.createTenant(id: 7, shortName: 'SO', longName: 'Stadtorchester');
  }
}

/// Records the writes; [active] / [maxActive] show whether two ran at once.
class _FakeFiles implements SongFileService {
  final calls = <String>[];
  final failing = <String>{};
  int active = 0;
  int maxActive = 0;

  Future<void> _step(String call) async {
    active++;
    if (active > maxActive) maxActive = active;
    calls.add(call);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    active--;
  }

  @override
  Future<String> uploadFile({
    required int songId,
    required PlatformFile file,
    int? instrumentId,
    String? note,
    int? mainGroupId,
  }) async {
    await _step('upload ${file.name} $instrumentId ${note ?? '-'}');
    if (failing.remove(file.name)) throw Exception('kaputt');
    return 'https://x/${file.name}';
  }

  @override
  Future<void> deleteFile({
    required int songId,
    required String url,
    String? storageName,
    String? fileName,
    int? mainGroupId,
  }) =>
      _step('delete $fileName');

  @override
  Future<void> updateFileCategory({
    required int songId,
    required String url,
    String? storageName,
    int? instrumentId,
    String? note,
    int? mainGroupId,
  }) =>
      _step('category $url $instrumentId ${note ?? '-'}');

  @override
  Future<void> renameFile({
    required int songId,
    required String url,
    required String storageName,
    required String fileName,
  }) =>
      _step('rename $url $fileName');

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

PlatformFile _file(String name, {int size = 10}) => PlatformFile(name: name, size: size);

const _pdf = 'application/pdf';

final _groups = [
  TestFactories.createGroup(id: 11, name: 'Klarinette'),
  TestFactories.createGroup(id: 12, name: 'Flöte'),
];

const _klar = SongFile(
  storageName: 'klar_101.pdf',
  fileName: 'klar.pdf',
  fileType: _pdf,
  url: 'https://x/klar.pdf',
  instrumentId: 11,
);
const _floete = SongFile(
  storageName: 'floete_102.pdf',
  fileName: 'floete.pdf',
  fileType: _pdf,
  url: 'https://x/floete.pdf',
  instrumentId: 12,
);
const _partitur = SongFile(fileName: 'partitur.pdf', fileType: _pdf, url: 'https://x/partitur.pdf', note: 'Partitur');

const _song = Song(id: 5, name: 'Festliche Ouvertüre', number: 12, files: [_klar, _floete, _partitur]);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _desktop(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _app(Role role, _FakeFiles files, {Song song = _song}) {
  final router = GoRouter(
    initialLocation: '/werke/5',
    routes: [
      GoRoute(
        path: '/werke',
        builder: (_, __) => const Scaffold(body: Text('page works')),
        routes: [GoRoute(path: ':id', builder: (_, s) => RdWorkPage(songId: int.parse(s.pathParameters['id']!)))],
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      initialRedesignSettingsProvider.overrideWithValue(const RedesignSettings(enabled: true, world: RdFarbwelt.petrol)),
      effectiveRoleProvider.overrideWithValue(role),
      currentTenantProvider.overrideWith((ref) => _TenantNotifier(ref)),
      readySongFileServiceProvider.overrideWith((ref) async => files),
      songDetailDataProvider((songId: 5, sharingId: null)).overrideWith((ref) async => SongDetailData(
            song: song,
            tenantType: 'orchestra',
            instruments: _groups,
            categories: const [],
            additionalFields: const [],
            history: const [],
            readOnly: !(role.isAdmin || role.isResponsible),
          )),
      songsProvider.overrideWith((ref) async => [song]),
      groupsProvider.overrideWith((ref) async => _groups),
      currentSelfServicePlayerProvider.overrideWith(
        (ref) async => TestFactories.createPerson(id: 3, tenantId: 7, instrument: 11),
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

Future<void> _withCtrl(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

/// REDESIGN: desktop file workspace of a Werk (table, drop / upload queue,
/// selection, ZIP, keys).
void main() {
  setUpAll(() async {
    await initializeDateFormatting('de_DE');
    await initializeDateFormatting('de');
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('logic', () {
    test('conflicts: same name always, same part for parts, free text only by name', () {
      expect(rdUploadConflicts('neu.pdf', 11, const [_klar, _floete, _partitur]), [_klar]);
      expect(rdUploadConflicts('floete.pdf', null, const [_klar, _floete, _partitur]), [_floete]);
      expect(rdUploadConflicts('anderes.pdf', null, const [_klar, _floete, _partitur]), isEmpty);
    });

    test('rename keeps the extension and ignores empty or equal names', () {
      expect(rdRenamedFileName('Stimme 1.pdf', 'Klarinette 1'), 'Klarinette 1.pdf');
      expect(rdRenamedFileName('Stimme 1.pdf', 'Klarinette.v2.pdf'), 'Klarinette.v2.pdf');
      expect(rdRenamedFileName('Stimme 1.pdf', '  '), isNull);
      expect(rdRenamedFileName('Stimme 1.pdf', 'Stimme 1'), isNull);
      expect(rdRenamedFileName('a.pdf', 'x/y'), 'x-y.pdf');
      expect(rdCanRename(_klar), isTrue);
      expect(rdCanRename(_partitur), isFalse);
    });

    test('keyboard rows and ranges', () {
      expect(rdNextIndex(null, 1, 3), 0);
      expect(rdNextIndex(null, -1, 3), 2);
      expect(rdNextIndex(2, 1, 3), 2);
      expect(rdNextIndex(1, -1, 3), 0);
      expect(rdRangeSelection(['a', 'b', 'c', 'd'], 'c', 'a'), {'a', 'b', 'c'});
      expect(rdRangeSelection(['a', 'b'], 'x', 'b'), {'b'});
    });
  });

  group('controller', () {
    late _FakeFiles files;
    late ProviderContainer container;

    setUp(() {
      files = _FakeFiles();
      container = ProviderContainer(overrides: [
        readySongFileServiceProvider.overrideWith((ref) async => files),
      ]);
      addTearDown(container.dispose);
      container.listen(rdWorkFilesProvider(5), (_, __) {});
    });

    RdWorkFilesController controller() => container.read(rdWorkFilesProvider(5).notifier);
    RdWorkFilesState state() => container.read(rdWorkFilesProvider(5));

    test('uploads run one after the other, replaced files are removed first', () async {
      controller().enqueue([
        (file: _file('a.pdf'), instrumentId: 11, note: null, replace: const [_klar]),
        (file: _file('b.pdf'), instrumentId: null, note: 'Partitur', replace: const <SongFile>[]),
      ]);
      expect(state().busy, isTrue);
      expect(state().total, 2);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(files.calls, ['delete klar.pdf', 'upload a.pdf 11 -', 'upload b.pdf null Partitur']);
      expect(files.maxActive, 1);
      expect(state().doneCount, 2);
      expect(state().busy, isFalse);
    });

    test('a failed upload can be retried; done rows make room for the next batch', () async {
      files.failing.add('a.pdf');
      controller().enqueue([(file: _file('a.pdf'), instrumentId: 11, note: null, replace: const <SongFile>[])]);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(state().failedCount, 1);
      expect(state().uploads.single.error, isNotEmpty);

      controller().retry(state().uploads.single.id);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(state().doneCount, 1);

      controller().enqueue([(file: _file('c.pdf'), instrumentId: 12, note: null, replace: const <SongFile>[])]);
      expect(state().uploads.map((u) => u.file.name), ['c.pdf']);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      controller().dismissFinished();
      expect(state().uploads, isEmpty);
    });

    test('delete hides at once, Rückgängig brings it back without a write', () async {
      controller().delete(const [_klar], notice: 'weg');
      expect(state().hidden, {_klar.url});
      expect(state().notice, 'weg');
      expect(controller().canUndoDelete, isTrue);
      expect(controller().undoDelete(notice: 'zurück'), isTrue);
      expect(state().hidden, isEmpty);
      expect(state().notice, 'zurück');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(files.calls, isEmpty);
    });

    test('a second delete stores the first one; category and rename run in line', () async {
      controller().delete(const [_klar]);
      controller().delete(const [_floete]);
      await controller().setCategory(_partitur, 12, 'egal');
      await controller().rename(_floete, 'Flöte 1.pdf');
      await controller().rename(_partitur, 'nope.pdf'); // no storageName: left alone
      expect(files.calls, [
        'delete klar.pdf',
        'category https://x/partitur.pdf 12 -',
        'rename https://x/floete.pdf Flöte 1.pdf',
      ]);
      expect(files.maxActive, 1);
      expect(controller().undoDelete(), isTrue);
      expect(state().hidden, {_klar.url});
    });
  });

  group('RdWorkPage workspace', () {
    testWidgets('editor on a wide screen: table instead of "Alle Stimmen"', (tester) async {
      _desktop(tester);
      await tester.pumpWidget(_app(Role.admin, _FakeFiles()));
      await _settle(tester);
      expect(find.text('Dateien · 3'), findsOneWidget);
      expect(find.text('Hochladen'), findsOneWidget);
      expect(find.text('Alle als ZIP'), findsOneWidget);
      expect(find.text('klar.pdf'), findsOneWidget);
      expect(find.text('Flöte'), findsWidgets);
      expect(find.text('Alle Stimmen'), findsNothing);
    });

    testWidgets('players and narrow screens keep the old page', (tester) async {
      _desktop(tester);
      await tester.pumpWidget(_app(Role.player, _FakeFiles()));
      await _settle(tester);
      expect(find.text('Hochladen'), findsNothing);
      expect(find.text('Alle Stimmen'), findsOneWidget);

      tester.view.physicalSize = const Size(393, 852);
      await tester.pumpWidget(_app(Role.admin, _FakeFiles()));
      await _settle(tester);
      expect(find.text('Hochladen'), findsNothing);
    });

    testWidgets('keys: select all, delete with Rückgängig, ↓ and Entf', (tester) async {
      _desktop(tester);
      final files = _FakeFiles();
      await tester.pumpWidget(_app(Role.admin, files));
      await _settle(tester);

      await tester.tap(find.text('klar.pdf'));
      await _settle(tester);
      await _withCtrl(tester, LogicalKeyboardKey.keyA);
      expect(find.text('3 ausgewählt'), findsOneWidget);
      expect(find.text('Als ZIP laden'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pump();
      expect(find.text('3 Dateien gelöscht'), findsOneWidget);
      expect(find.text('klar.pdf'), findsNothing);

      await _withCtrl(tester, LogicalKeyboardKey.keyZ);
      expect(find.text('Wiederhergestellt'), findsOneWidget);
      expect(find.text('klar.pdf'), findsOneWidget);

      // Escape clears, ↓ picks the first row, Entf deletes only that one.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(find.text('1 ausgewählt'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pump();
      expect(find.text('Dateien · 2'), findsOneWidget);

      await tester.pump(rdFileUndoDelay + const Duration(seconds: 1));
      await _settle(tester);
      expect(files.calls, hasLength(1));
      expect(files.calls.single, startsWith('delete '));
    });

    testWidgets('Stimme menu moves a file to another part', (tester) async {
      _desktop(tester);
      final files = _FakeFiles();
      await tester.pumpWidget(_app(Role.admin, files));
      await _settle(tester);

      await tester.tap(find.byTooltip('Kategorie ändern').first);
      await _settle(tester);
      await tester.tap(find.text('Aufnahme').last);
      await _settle(tester);
      expect(files.calls.single, startsWith('category '));
      expect(files.calls.single, endsWith(' 1 -'));
    });

    testWidgets('an empty Werk offers the drop frame', (tester) async {
      _desktop(tester);
      await tester.pumpWidget(_app(Role.admin, _FakeFiles(), song: const Song(id: 5, name: 'Leer')));
      await _settle(tester);
      expect(find.text('Dateien hierher ziehen oder „Hochladen“ wählen.'), findsOneWidget);
    });
  });

  group('security (source)', () {
    test('no direct Supabase access in the workspace', () {
      for (final path in [
        'lib/features/redesign/presentation/widgets/work/rd_work_files.dart',
        'lib/features/redesign/data/rd_work_files_controller.dart',
        'lib/features/redesign/data/rd_work_files_logic.dart',
      ]) {
        final src = File(path).readAsStringSync();
        expect(src, isNot(contains('supabase')), reason: path);
        expect(src, isNot(contains('.from(')), reason: path);
      }
    });

    test('renameFile filters by song id and tenant', () {
      final src = File('lib/core/services/song_file_service.dart').readAsStringSync();
      final start = src.indexOf('Future<void> renameFile(');
      final body = src.substring(start, src.indexOf('/// Pick multiple files', start));
      expect(".eq('tenantId', _tenantId)".allMatches(body).length, 2);
      expect(".eq('id', songId)".allMatches(body).length, 2);
    });
  });
}
