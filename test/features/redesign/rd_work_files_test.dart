import 'dart:io';

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/debug_providers.dart';
import 'package:attendix/core/providers/group_providers.dart';
import 'package:attendix/core/providers/redesign_providers.dart';
import 'package:attendix/core/providers/self_service_providers.dart';
import 'package:attendix/core/providers/song_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/services/part_vision_service.dart';
import 'package:attendix/core/services/song_file_service.dart';
import 'package:attendix/core/utils/instrument_matcher.dart';
import 'package:attendix/core/services/zip_service.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/data/models/song/song.dart';
import 'package:attendix/features/redesign/data/rd_work_files_controller.dart';
import 'package:attendix/features/redesign/data/rd_work_files_logic.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_work_page.dart';
import 'package:attendix/features/redesign/presentation/widgets/work/rd_work_files.dart' show rdVisionBudget;
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
  final failingDeletes = <String>{};
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
  }) async {
    await _step('delete $fileName');
    if (failingDeletes.remove(fileName)) throw Exception('kaputt');
  }

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
  Future<List<PlatformFile>?> pickMultipleFiles() async {
    calls.add('pick');
    return picked;
  }

  /// Files "Hochladen" picks.
  List<PlatformFile>? picked;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Reads "page 1" from a fixed answer per file name.
class _FakeVision extends PartVisionService {
  _FakeVision(this.answers) : super(() => throw UnimplementedError(), () => 1);

  final Map<String, PartMatch> answers;
  final asked = <String>[];
  final limits = <Duration?>[];
  final tenants = <int?>[];
  final stillWanted = <bool>[];

  @override
  Future<PartMatch?> detect(PlatformFile file, List<InstrumentInfo> instruments, {Duration? limit, bool Function()? cancelled, int? tenantId}) async {
    asked.add(file.name);
    limits.add(limit);
    tenants.add(tenantId);
    stillWanted.add(cancelled?.call() == false);
    return answers[file.name];
  }
}

/// Records the terms the upload wants to remember.
class _FakeGroupNotifier extends GroupNotifier {
  final learned = <Map<int, List<String>>>[];

  @override
  Future<bool> addSynonyms(Map<int, List<String>> terms) async {
    learned.add(terms);
    return true;
  }
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

Widget _app(Role role, _FakeFiles files, {Song song = _song, _FakeGroupNotifier? groupNotifier, _FakeVision? vision}) {
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
      songFileServiceProvider.overrideWithValue(files),
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
      if (groupNotifier != null) groupNotifierProvider.overrideWith(() => groupNotifier),
      partVisionServiceProvider.overrideWithValue(vision ?? _FakeVision(const {})),
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

    test('uploads run one after the other, replaced files are removed after the new one is stored', () async {
      controller().enqueue([
        (file: _file('a.pdf'), instrumentId: 11, note: null, replace: const [_klar]),
        (file: _file('b.pdf'), instrumentId: null, note: 'Partitur', replace: const <SongFile>[]),
      ]);
      expect(state().busy, isTrue);
      expect(state().total, 2);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(files.calls, ['upload a.pdf 11 -', 'delete klar.pdf', 'upload b.pdf null Partitur']);
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

    test('"Ersetzen": a failed upload keeps the old file; a retry does not upload twice', () async {
      files.failing.add('a.pdf');
      controller().enqueue([(file: _file('a.pdf'), instrumentId: 11, note: null, replace: const [_klar])]);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(files.calls, ['upload a.pdf 11 -']);
      expect(state().failedCount, 1);

      controller().retry(state().uploads.single.id);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(files.calls, ['upload a.pdf 11 -', 'upload a.pdf 11 -', 'delete klar.pdf']);
      expect(state().doneCount, 1);
    });

    test('"Ersetzen": a failed delete after the upload is retried without uploading again', () async {
      files.failingDeletes.add('klar.pdf');
      controller().enqueue([(file: _file('a.pdf'), instrumentId: 11, note: null, replace: const [_klar])]);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(state().failedCount, 1);
      controller().retry(state().uploads.single.id);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(files.calls, ['upload a.pdf 11 -', 'delete klar.pdf', 'delete klar.pdf']);
      expect(state().doneCount, 1);
    });

    test('"Ersetzen" never deletes the file it just stored', () async {
      const same = SongFile(fileName: 'a.pdf', fileType: _pdf, url: 'https://x/a.pdf', instrumentId: 11);
      controller().enqueue([(file: _file('a.pdf'), instrumentId: 11, note: null, replace: const [same, _klar])]);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(files.calls, ['upload a.pdf 11 -', 'delete klar.pdf']);
    });

    test('the tenant (service) is taken when a write is queued', () async {
      final other = _FakeFiles();
      var current = files;
      final c = ProviderContainer(overrides: [
        readySongFileServiceProvider.overrideWith((ref) async => current),
      ]);
      addTearDown(c.dispose);
      c.listen(rdWorkFilesProvider(5), (_, __) {});
      final ctl = c.read(rdWorkFilesProvider(5).notifier);
      await c.read(readySongFileServiceProvider.future);
      ctl.delete(const [_klar]);
      current = other;
      c.invalidate(readySongFileServiceProvider);
      ctl.delete(const [_floete]); // stores the first delete
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(files.calls, ['delete klar.pdf']);
      expect(other.calls, isEmpty);
      ctl.undoDelete();
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

    testWidgets('a held Entf deletes only once', (tester) async {
      _desktop(tester);
      await tester.pumpWidget(_app(Role.admin, _FakeFiles()));
      await _settle(tester);
      await tester.tap(find.text('klar.pdf'));
      await _settle(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.delete);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.delete);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.delete);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.delete);
      await tester.pump();
      expect(find.text('Dateien · 2'), findsOneWidget);
      await tester.pump(rdFileUndoDelay + const Duration(seconds: 1));
      await _settle(tester);
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

    testWidgets('an empty Werk offers the frame; a click opens the file picker', (tester) async {
      _desktop(tester);
      final service = _FakeFiles();
      await tester.pumpWidget(_app(Role.admin, service, song: const Song(id: 5, name: 'Leer')));
      await _settle(tester);
      // Native apps cannot take dropped files, so the frame only offers the click.
      expect(find.text('Dateien hierher ziehen oder „Hochladen“ wählen.'), findsNothing);
      await tester.tap(find.text('Klicken, um Dateien auszuwählen.'));
      await _settle(tester);
      expect(service.calls, ['pick']);
    });

    testWidgets('a clear part uploads at once, an unclear one is checked first', (tester) async {
      _desktop(tester);
      final service = _FakeFiles()..picked = [_file('Klarinette 2.pdf')];
      await tester.pumpWidget(_app(Role.admin, service, song: const Song(id: 5, name: 'Leer')));
      await _settle(tester);
      await tester.tap(find.text('Hochladen'));
      await _settle(tester);
      expect(find.text('Zuordnung prüfen'), findsNothing);
      expect(service.calls, ['pick', 'upload Klarinette 2.pdf 11 -']);

      service
        ..calls.clear()
        ..picked = [_file('Scan_0815.pdf')];
      await tester.tap(find.text('Hochladen'));
      await _settle(tester);
      expect(find.text('Zuordnung prüfen'), findsOneWidget);
      expect(find.text('Nicht erkannt – bitte zuordnen'), findsOneWidget);
      expect(service.calls, ['pick']);
      await tester.tap(find.text('Hochladen').last);
      await _settle(tester);
      expect(service.calls, ['pick', 'upload Scan_0815.pdf null -']);
    });

    testWidgets('an unsure part can be confirmed and remembered as it is', (tester) async {
      _desktop(tester);
      final service = _FakeFiles()..picked = [_file('Kl 1.pdf')];
      final groups = _FakeGroupNotifier();
      await tester.pumpWidget(_app(Role.admin, service, song: const Song(id: 5, name: 'Leer'), groupNotifier: groups));
      await _settle(tester);
      await tester.tap(find.text('Hochladen'));
      await _settle(tester);
      expect(find.text('Unsicher erkannt – bitte prüfen'), findsOneWidget);
      final learn = find.text('„Kl 1“ künftig als Klarinette erkennen');
      expect(learn, findsOneWidget);
      // Unchecked until confirmed.
      expect(tester.widget<CheckboxListTile>(find.ancestor(of: learn, matching: find.byType(CheckboxListTile))).value, isFalse);
      await tester.tap(learn);
      await _settle(tester);
      await tester.tap(find.text('Hochladen').last);
      await _settle(tester);
      expect(service.calls, ['pick', 'upload Kl 1.pdf 11 -']);
      expect(groups.learned, [
        {11: ['Kl 1']},
      ]);
    });

    testWidgets('page 1 decides when the name does not, and is always confirmed by hand', (tester) async {
      _desktop(tester);
      final service = _FakeFiles()..picked = [_file('Scan_0815.pdf'), _file('Scan_0816.pdf'), _file('Klarinette 1.pdf')];
      final vision = _FakeVision({
        'Scan_0815.pdf': const PartMatch(instrumentId: 12, confidence: MatchConfidence.sure, term: 'Flute', byVision: true),
        'Scan_0816.pdf': const PartMatch(instrumentId: 11, confidence: MatchConfidence.unsure, byVision: true),
      });
      await tester.pumpWidget(_app(Role.admin, service, song: const Song(id: 5, name: 'Leer'), vision: vision));
      await _settle(tester);
      await tester.tap(find.text('Hochladen'));
      await _settle(tester);
      // Only the unclear names are looked at.
      expect(vision.asked, ['Scan_0815.pdf', 'Scan_0816.pdf']);
      // Every file only gets what is left of the minute.
      expect(vision.limits.every((l) => l != null && l <= rdVisionBudget), isTrue);
      // Pinned to the tenant of the drop, stopped once the page is left.
      expect(vision.tenants, [1, 1]);
      expect(vision.stillWanted, [true, true]);
      // The model's own "sure" is no proof (text on the page): both are
      // shown, the clear file name is not.
      expect(find.text('Zuordnung prüfen'), findsOneWidget);
      expect(find.text('Scan_0815.pdf'), findsOneWidget);
      expect(find.text('Auf Seite 1 erkannt: Flute'), findsOneWidget);
      expect(find.text('Auf Seite 1 vermutet – bitte prüfen'), findsOneWidget);
      expect(find.text('Klarinette 1.pdf'), findsNothing);
      await tester.tap(find.text('Hochladen').last);
      await _settle(tester);
      expect(service.calls, [
        'pick',
        'upload Scan_0815.pdf 12 -',
        'upload Scan_0816.pdf 11 -',
        'upload Klarinette 1.pdf 11 -',
      ]);
    });

    testWidgets('the keyboard icon lists the shortcuts', (tester) async {
      _desktop(tester);
      await tester.pumpWidget(_app(Role.admin, _FakeFiles(), song: const Song(id: 5, name: 'Leer')));
      await _settle(tester);
      await tester.tap(find.byIcon(Icons.keyboard_outlined));
      await _settle(tester);
      expect(find.text('Tastenkürzel'), findsOneWidget);
      expect(find.text('F2 umbenennen'), findsOneWidget);
    });
  });

  group('names', () {
    test('storage names: Ionic format, never a taken one, also when all 900 are taken', () {
      expect(SongFileService.encodeFilename('Stimme 1 (Fl).pdf', 123), 'Stimme-1-Fl_123.pdf');
      final all = {for (var n = 100; n < 1000; n++) SongFileService.encodeFilename('a.pdf', n)};
      expect(SongFileService.freeStorageName('a.pdf', all), 'a_1000.pdf');
      final almost = {...all}..remove('a_555.pdf');
      expect(SongFileService.freeStorageName('a.pdf', almost), 'a_555.pdf');
      expect(SongFileService.freeStorageName('a.pdf', const {}), matches(RegExp(r'^a_[1-9]\d\d\.pdf$')));
    });

    test('ZIP: equal file names get " (2)", " (3)"', () {
      final used = <String>{};
      expect(ZipService.uniqueArchiveName('Stimme.pdf', used), 'Stimme.pdf');
      expect(ZipService.uniqueArchiveName('Stimme.pdf', used), 'Stimme (2).pdf');
      expect(ZipService.uniqueArchiveName('stimme.PDF', used), 'stimme (3).PDF');
      expect(ZipService.uniqueArchiveName('README', used), 'README');
      expect(ZipService.uniqueArchiveName('README', used), 'README (2)');
    });
  });

  group('security (source)', () {
    test('the per-song lock: same song waits (also after a failure), other songs do not', () async {
      final log = <String>[];
      Future<void> step(String name, {bool fail = false}) async {
        log.add('start $name');
        await Future<void>.delayed(const Duration(milliseconds: 20));
        log.add('end $name');
        if (fail) throw Exception(name);
      }

      final first = SongFileService.lockedForTest(7, 5, () => step('a', fail: true));
      final second = SongFileService.lockedForTest(7, 5, () => step('b'));
      final other = SongFileService.lockedForTest(7, 6, () => step('c'));
      final otherTenant = SongFileService.lockedForTest(8, 5, () => step('d'));
      await expectLater(first, throwsException);
      await Future.wait([second, other, otherTenant]);
      expect(log.indexOf('start b'), greaterThan(log.indexOf('end a')));
      expect(log.indexOf('start c'), lessThan(log.indexOf('end a')));
      expect(log.indexOf('start d'), lessThan(log.indexOf('end a')));
    });

    test('every write of songs.files goes through the per-song lock', () {
      final src = File('lib/core/services/song_file_service.dart').readAsStringSync();
      for (final name in ['uploadFile', 'deleteFile', 'deleteAllFiles', 'updateFileCategory', 'renameFile', 'uploadFileBytes']) {
        final start = src.indexOf(RegExp('Future<\\w+> $name\\('));
        expect(start, greaterThan(0), reason: name);
        final body = src.substring(start, src.indexOf(';', src.indexOf('=>', start)));
        expect(body, contains('_locked('), reason: name);
        expect(body, contains('_$name('), reason: name);
      }
    });

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
      final start = src.indexOf('Future<void> _renameFile(');
      final body = src.substring(start, src.indexOf('/// Pick multiple files', start));
      expect(".eq('tenantId', _tenantId)".allMatches(body).length, 2);
      expect(".eq('id', songId)".allMatches(body).length, 2);
    });
  });
}
