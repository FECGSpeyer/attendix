import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/debug_providers.dart';
import 'package:attendix/core/providers/group_providers.dart';
import 'package:attendix/core/providers/redesign_providers.dart';
import 'package:attendix/core/providers/song_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/services/song_file_service.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/data/models/instrument/instrument.dart';
import 'package:attendix/data/models/song/song.dart';
import 'package:attendix/data/repositories/song_repository.dart';
import 'package:attendix/features/redesign/data/import/rd_import_controller.dart';
import 'package:attendix/features/redesign/data/import/rd_import_logic.dart';
import 'package:attendix/features/redesign/data/import/rd_import_source.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_import_page.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../factories/test_factories.dart';

/// Records the uploads.
class _FakeFiles implements SongFileService {
  final uploads = <String>[];

  @override
  Future<String> uploadFile({
    required int songId,
    required PlatformFile file,
    int? instrumentId,
    String? note,
    int? mainGroupId,
  }) async {
    uploads.add('$songId ${file.name} ${file.bytes?.length} $instrumentId ${note ?? '-'}');
    return 'https://x/${file.name}';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Werke: creates new ones, reports the Besetzung before/after the upload.
class _FakeSongs implements SongRepository {
  final created = <Song>[];
  final updates = <int, Map<String, dynamic>>{};
  int _reads = 0;

  @override
  Future<Song> createSong(Song song) async {
    created.add(song);
    return song.copyWith(id: 900 + created.length);
  }

  @override
  Future<Song?> getSongById(int id) async {
    _reads++;
    // Before: Viola + Harfe (no file); after the upload only Viola.
    return Song(id: id, name: 'Wie wunderbar', instrumentIds: _reads == 1 ? const [12, 30] : const [12]);
  }

  @override
  Future<Song> updateSong(int id, Map<String, dynamic> updates) async {
    this.updates[id] = updates;
    return Song(id: id, name: 'x');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeGroupNotifier extends GroupNotifier {
  final created = <String>[];
  final learned = <Map<int, List<String>>>[];

  @override
  Future<Group?> createGroup(Map<String, dynamic> data) async {
    created.add(data['name'] as String);
    return Group(id: 99, name: data['name'] as String);
  }

  @override
  Future<bool> addSynonyms(Map<int, List<String>> terms) async {
    learned.add(terms);
    return true;
  }
}

final _groups = [
  TestFactories.createGroup(id: 1, name: 'Orchester', maingroup: true),
  TestFactories.createGroup(id: 10, name: 'Violine 1'),
  TestFactories.createGroup(id: 12, name: 'Viola'),
  TestFactories.createGroup(id: 30, name: 'Harfe'),
];

const _wunderbar = Song(id: 3, number: 120, name: 'Wie wunderbar', files: [
  SongFile(fileName: 'Violine 1 (2019).pdf', fileType: 'application/pdf', url: 'u', instrumentId: 10),
]);
const _via = Song(id: 4, number: 26, name: 'Via dolorosa');
const _gott = Song(id: 5, number: 66, name: 'Du großer Gott');

Uint8List _zip(Map<String, String> files) {
  final archive = Archive();
  for (final e in files.entries) {
    final bytes = Uint8List.fromList(e.value.codeUnits);
    archive.addFile(ArchiveFile(e.key, bytes.length, bytes));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

final _zipBytes = _zip({
  'Noten/120 Wie wunderbar/Viola.pdf': '%PDF viola',
  'Noten/120 Wie wunderbar/Sax 1.pdf': '%PDF sax eins',
  'Noten/157 Jesus ruft dich/Sax 2.pdf': '%PDF sax zwei',
  'Noten/157 Jesus ruft dich/Violine 1.pdf': '%PDF violine',
  'Noten/157 Jesus ruft dich/Kopie/Violine 1.pdf': '%PDF violine',
  'Noten/.DS_Store': 'x',
  '__MACOSX/Noten/._Viola.pdf': 'x',
});

List<Override> _overrides(_FakeFiles files, _FakeSongs songs, _FakeGroupNotifier groups) => [
      initialRedesignSettingsProvider.overrideWithValue(const RedesignSettings(enabled: true, world: RdFarbwelt.petrol)),
      effectiveRoleProvider.overrideWithValue(Role.admin),
      currentTenantIdProvider.overrideWithValue(7),
      readySongFileServiceProvider.overrideWith((ref) async => files),
      songFileServiceProvider.overrideWithValue(files),
      songRepositoryWithTenantProvider.overrideWithValue(songs),
      groupNotifierProvider.overrideWith(() => groups),
      groupsProvider.overrideWith((ref) async => _groups),
      songsProvider.overrideWith((ref) async => const [_wunderbar, _via, _gott]),
      songsListDataProvider(null).overrideWith((ref) async => SongsListData(
            tenantId: 7,
            tenantType: 'orchestra',
            songs: const [_wunderbar, _via, _gott],
            categories: const [],
            groups: _groups,
            groupCategories: const [],
            currentSongs: const [],
            additionalFields: const [],
          )),
    ];

/// A ZIP with Fassungen, a known Werk, a new one and unknown names.
PlatformFile _richZip() {
  final bytes = _zip({
    'Noten (Speyer)/SOS-Spieler PDF/120 Wie wunderbar/Viola.pdf': '%PDF viola /CreationDate (D:20240312)',
    'Noten (Speyer)/SOS-Spieler PDF/120 Wie wunderbar/Sax 1.pdf': '%PDF sax eins',
    'Noten (Speyer)/SOS-Spieler PDF/120 Wie wunderbar/Violine 1.pdf': '%PDF v1',
    'Noten (Speyer)/Dirigenten/120 Wie wunderbar/Partitur.pdf': '%PDF partitur',
    'Noten (Speyer)/Dirigenten/26 Via dolorosa/Viola.pdf': '%PDF /CreationDate (D:20190101)',
    'Noten (Speyer)/Dirigenten/26 Via dolorosa/Violine 1.pdf': '%PDF /CreationDate (D:20190101) v',
    'Noten (Speyer)/Dirigenten/26 Via dolorosa/Fassung 2024/Viola.pdf': '%PDF /CreationDate (D:20240501) vv',
    'Noten (Speyer)/Dirigenten/26 Via dolorosa/Fassung 2024/Violine 1.pdf': '%PDF /CreationDate (D:20240501) vvv',
    'Noten (Speyer)/Dirigenten/26 Via dolorosa/Fassung 2024/Harfe.pdf': '%PDF /CreationDate (D:20240501) h',
    'Noten (Speyer)/Dirigenten/26 Via dolorosa/Alt/Viola.pdf': '%PDF /CreationDate (D:20150101) alt',
    'Noten (Speyer)/Dirigenten/26 Via dolorosa/Liedtext.docx': 'docx',
    'Noten (Speyer)/Dirigenten/26 Via dolorosa/Liedtext.pdf': '%PDF text',
    'Noten (Speyer)/SOS-Spieler PDF/157 Jesus ruft dich/Sax 2.pdf': '%PDF sax zwei',
    'Noten (Speyer)/SOS-Spieler PDF/157 Jesus ruft dich/Violine 1.pdf': '%PDF violine',
    'Noten (Speyer)/SOS-Spieler PDF/157 Jesus ruft dich/Kopie/Violine 1.pdf': '%PDF violine',
    'Noten (Speyer)/SOS-Spieler PDF/80 Du Großer Gott Nikita/Viola.pdf': '%PDF dgg',
    'Noten (Speyer)/SOS-Spieler PDF/80 Du Großer Gott Nikita/Gitarre.pdf': '%PDF dgg g',
    'Noten (Speyer)/SOS-Spieler PDF/80 Du Großer Gott Nikita/Archiv.zip': 'zip',
  });
  return PlatformFile(name: 'Noten (Speyer)-20261031T174501Z-001.zip', size: bytes.length, bytes: bytes);
}

PlatformFile _zipFile() => PlatformFile(name: 'Noten-20261031T174501Z-001.zip', size: _zipBytes.length, bytes: _zipBytes);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('ZIP name without the Drive date and part number', () {
    expect(RdImportSource.zipStem('Noten (Speyer)-20261031T174501Z-001.zip'), 'Noten (Speyer)');
    expect(RdImportSource.zipStem('Stille Nacht.zip'), 'Stille Nacht');
  });

  test('reads the ZIP, asks once, creates Werk and group, keeps the Besetzung', () async {
    final files = _FakeFiles();
    final songs = _FakeSongs();
    final groups = _FakeGroupNotifier();
    final c = ProviderContainer(overrides: _overrides(files, songs, groups));
    addTearDown(c.dispose);
    final sub = c.listen(rdImportProvider, (_, __) {});
    addTearDown(sub.close);
    final controller = c.read(rdImportProvider.notifier);

    expect(await controller.read([_zipFile()]), isNull);
    final state = c.read(rdImportProvider);
    expect(state.step, RdImportStep.questions);
    final plan = state.plan!;
    expect(plan.works.map((w) => w.title), ['Wie wunderbar', 'Jesus ruft dich']);
    // System files are not shown; the copy in "Kopie" is a duplicate.
    expect(plan.fileCount, 5);
    final jesus = plan.works.last;
    expect(jesus.files.where((f) => f.hardSkip == RdSkipReason.duplicate), hasLength(1));
    expect(plan.questions.map((q) => q.key), ['sax']);

    controller.answer('sax', const RdImportCategory(newGroup: 'Saxophon'));
    final summary = rdImportSummary(plan, c.read(rdImportProvider).decisions);
    expect(summary.open, 0);
    expect(summary.take, 4);

    await controller.upload();
    final done = c.read(rdImportProvider);
    expect(done.step, RdImportStep.done);
    expect(done.upload!.failures, isEmpty);
    expect(groups.created, ['Saxophon']);
    expect(songs.created.single.name, 'Jesus ruft dich');
    expect(songs.created.single.number, 157);
    expect(files.uploads, unorderedEquals([
      '3 Viola.pdf 10 12 -',
      '3 Sax 1.pdf 13 99 -',
      '901 Sax 2.pdf 13 99 -',
      '901 Violine 1.pdf 12 10 -',
    ]));
    // Harfe has no file, but stays in the Besetzung.
    expect(songs.updates[3], {'instrument_ids': [12, 30]});
  });

  test('reads dates inside the PDFs for Fassungen; title match with another number is unsure', () async {
    final c = ProviderContainer(overrides: _overrides(_FakeFiles(), _FakeSongs(), _FakeGroupNotifier()));
    addTearDown(c.dispose);
    final sub = c.listen(rdImportProvider, (_, __) {});
    addTearDown(sub.close);
    expect(await c.read(rdImportProvider.notifier).read([_richZip()]), isNull);
    final plan = c.read(rdImportProvider).plan!;
    final via = plan.work('song:4')!;
    expect(via.defaultFassung, 'Fassung 2024');
    expect(via.fassungen.firstWhere((f) => f.key == 'Fassung 2024').newest, DateTime(2024, 5, 1));
    final gott = plan.work('song:5')!;
    expect(gott.match.kind, RdMatchKind.titleOnly);
    final d = c.read(rdImportProvider).decisions;
    // Lyrics stay although their folder is not the chosen Fassung; Word next
    // to the PDF is left out.
    final state = rdWorkState(plan, d, via);
    expect(state.files.entries.where((e) => e.value.take).map((e) => e.key.split('/').last), unorderedEquals([
      'Viola.pdf',
      'Violine 1.pdf',
      'Harfe.pdf',
      'Liedtext.pdf',
    ]));
  });

  testWidgets('steps: source, questions, review with a Werk to check', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final files = _FakeFiles();
    await tester.pumpWidget(ProviderScope(
      overrides: _overrides(files, _FakeSongs(), _FakeGroupNotifier()),
      child: MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
        home: const RdImportPage(),
      ),
    ));
    await tester.pump();
    expect(find.text('Noten importieren'), findsOneWidget);
    expect(find.text('ZIP-Datei wählen'), findsOneWidget);
    expect(find.text('Schritt 1 von 4 · Quelle'), findsOneWidget);

    final container = ProviderScope.containerOf(tester.element(find.byType(RdImportPage)));
    final error = await tester.runAsync(() => container.read(rdImportProvider.notifier).read([_zipFile()]));
    expect(error, isNull);
    await tester.pump();
    expect(find.text('Schritt 2 von 4 · Einlesen'), findsOneWidget);
    expect(find.text('„Sax“ gehört zu …'), findsOneWidget);
    await tester.tap(find.text('Neue Gruppe „Sax“'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Saxophon');
    await tester.tap(find.text('Neue Gruppe anlegen').last);
    await tester.pumpAndSettle();
    expect(find.text('Neue Gruppe „Saxophon“'), findsOneWidget);

    await tester.tap(find.text('Zur Prüfung'));
    await tester.pump();
    expect(find.text('Schritt 3 von 4 · Prüfen'), findsOneWidget);
    // Nothing open: every Werk is listed, the new one marked.
    expect(find.text('157 Jesus ruft dich'), findsOneWidget);
    expect(find.text('Neu'), findsOneWidget);
    expect(find.text('4 Dateien übernehmen'), findsOneWidget);

    await tester.tap(find.text('157 Jesus ruft dich'));
    await tester.pumpAndSettle();
    expect(find.text('Ziel in Attendix'), findsOneWidget);
    expect(find.text('Doppelt vorhanden'), findsOneWidget);
    expect(find.text('Passt so'), findsOneWidget);
  });
}
