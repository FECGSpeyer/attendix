import 'dart:async';
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
import 'package:attendix/features/redesign/data/import/rd_import_ai.dart';
import 'package:attendix/features/redesign/data/import/rd_import_controller.dart';
import 'package:attendix/features/redesign/data/import/rd_import_drive.dart';
import 'package:attendix/features/redesign/data/import/rd_import_logic.dart';
import 'package:attendix/features/redesign/data/import/rd_import_source.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_import_page.dart';
import 'package:attendix/features/redesign/presentation/widgets/rd_widgets.dart' show RdChoiceChip, RdPrimaryButton;
import 'package:attendix/l10n/l10n.dart';
import 'package:attendix/shared/widgets/layout/route_leave_guard.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;

import '../../factories/test_factories.dart';
import 'fake_drive.dart';

/// Records the uploads.
class _FakeFiles implements SongFileService {
  final uploads = <String>[];

  /// keepBesetzung of every upload.
  final keeps = <bool>[];

  /// Paths that fail.
  final failing = <String>{};

  @override
  Future<String> uploadFile({
    required int songId,
    required PlatformFile file,
    int? instrumentId,
    String? note,
    int? mainGroupId,
    bool keepBesetzung = false,
  }) async {
    if (failing.contains(file.name)) throw Exception('Speicher voll');
    keeps.add(keepBesetzung);
    uploads.add('$songId ${file.name} ${file.bytes?.length} $instrumentId ${note ?? '-'}');
    return 'https://x/${file.name}';
  }

  @override
  Future<String> uploadFileVia({
    required int songId,
    required String fileName,
    required Future<String> Function(int tenantId, String storageName, String contentType) store,
    int? instrumentId,
    String? note,
    int? mainGroupId,
    bool keepBesetzung = false,
  }) async {
    keeps.add(keepBesetzung);
    final dot = fileName.lastIndexOf('.');
    final storageName = '${fileName.substring(0, dot).replaceAll(' ', '-')}_100${fileName.substring(dot)}';
    final path = await store(7, storageName, 'application/pdf');
    uploads.add('$songId $fileName $path $instrumentId ${note ?? '-'}');
    return 'https://x/$path';
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

/// A file picked in the browser: only a stream, and `path` throws.
class _BrowserFile extends PlatformFile {
  _BrowserFile({required super.name, required super.size, super.readStream});

  @override
  String? get path => throw 'On web `path` is unavailable';
}

/// The KI without suggestions.
final _noAi = RdImportAi((_) async => {'answers': []});

List<Override> _overrides(_FakeFiles files, _FakeSongs songs, _FakeGroupNotifier groups,
        [FakeDrive? drive, bool groupsFail = false, RdImportAi? ai]) =>
    [
      if (drive != null) rdDriveApiProvider.overrideWithValue(RdDriveApi(drive.call)),
      rdImportAiProvider.overrideWithValue(ai ?? _noAi),
      initialRedesignSettingsProvider.overrideWithValue(const RedesignSettings(enabled: true, world: RdFarbwelt.petrol)),
      effectiveRoleProvider.overrideWithValue(Role.admin),
      currentTenantIdProvider.overrideWithValue(7),
      readySongFileServiceProvider.overrideWith((ref) async => files),
      songFileServiceProvider.overrideWithValue(files),
      songRepositoryWithTenantProvider.overrideWithValue(songs),
      groupNotifierProvider.overrideWith(() => groups),
      groupsProvider.overrideWith((ref) async => groupsFail ? throw Exception('Gruppen nicht geladen') : _groups),
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

const _driveLink = 'https://drive.google.com/drive/folders/root00000001?usp=sharing';

/// The same Noten as [_zipBytes], shared in Google Drive.
FakeDrive _drive() => FakeDrive({
      'root00000001': [
        folder('f120000001', '120 Wie wunderbar'),
        folder('f157000001', '157 Jesus ruft dich'),
        file('ds00000001', '.DS_Store'),
      ],
      'f120000001': [
        file('a000000001', 'Viola.pdf', size: 10, md5: 'viola'),
        file('a000000002', 'Sax 1.pdf', size: 13, md5: 'sax1'),
      ],
      'f157000001': [
        file('b000000001', 'Sax 2.pdf', size: 13, md5: 'sax2'),
        file('b000000002', 'Violine 1.pdf', size: 12, md5: 'violine'),
        {'id': 'doc0000001', 'name': 'Liedtext', 'mimeType': 'application/vnd.google-apps.document'},
        folder('k157000001', 'Kopie'),
      ],
      'k157000001': [
        file('c000000001', 'Violine 1.pdf', size: 12, md5: 'violine'),
      ],
    }, names: {
      'root00000001': 'Noten',
    });

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
    // Every upload keeps the Besetzung of its Werk (Harfe has no file).
    expect(files.keeps, everyElement(isTrue));
    expect(done.upload!.succeeded, 4);
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
    // Unsure: a Werk of its own with the folder's name, pointing to song 5.
    final gott = plan.works.firstWhere((w) => w.match.songId == 5);
    expect(gott.match.kind, RdMatchKind.titleOnly);
    expect(gott.key, isNot('song:5'));
    expect(gott.title, 'Du Großer Gott Nikita');
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

  test('reads a shared Drive folder and has the files copied, not downloaded', () async {
    final files = _FakeFiles();
    final songs = _FakeSongs();
    final groups = _FakeGroupNotifier();
    final drive = _drive();
    final c = ProviderContainer(overrides: _overrides(files, songs, groups, drive));
    addTearDown(c.dispose);
    final sub = c.listen(rdImportProvider, (_, __) {});
    addTearDown(sub.close);
    final controller = c.read(rdImportProvider.notifier);

    final check = await controller.checkLink(_driveLink);
    expect(check.error, isNull);
    expect(check.name, 'Noten');
    expect(await controller.readLink(check.folder!, check.name!), isNull);
    final state = c.read(rdImportProvider);
    expect(state.step, RdImportStep.questions);
    expect(state.driveFolder, const RdDriveRef('root00000001'));
    final plan = state.plan!;
    expect(plan.works.map((w) => w.title), ['Wie wunderbar', 'Jesus ruft dich']);
    final jesus = plan.works.last;
    // The copy in "Kopie" has the same MD5; the Google Doc cannot be copied.
    expect(jesus.files.where((f) => f.hardSkip == RdSkipReason.duplicate), hasLength(1));
    expect(jesus.files.firstWhere((f) => f.name == 'Liedtext.gdoc').hardSkip, RdSkipReason.unsupported);
    expect(plan.questions.map((q) => q.key), ['sax']);
    // Duplicates come from Drive's MD5; only the PDFs of the Werk with two
    // Fassungen (main folder and "Kopie") are read for their dates.
    final heads = drive.calls.where((c) => c['action'] == 'head').map((c) => (c['file'] as Map)['id']).toSet();
    expect(heads, isNotEmpty);
    expect(heads.difference({'b000000001', 'b000000002', 'c000000001'}), isEmpty);

    controller.answer('sax', const RdImportCategory(newGroup: 'Saxophon'));
    await controller.upload();
    final done = c.read(rdImportProvider);
    expect(done.upload!.failures, isEmpty);
    expect(files.uploads, unorderedEquals([
      '3 Viola.pdf songs/7/3/Viola_100.pdf 12 -',
      '3 Sax 1.pdf songs/7/3/Sax-1_100.pdf 99 -',
      '901 Sax 2.pdf songs/7/901/Sax-2_100.pdf 99 -',
      '901 Violine 1.pdf songs/7/901/Violine-1_100.pdf 10 -',
    ]));
    final copies = drive.calls.where((c) => c['action'] == 'copy').toList();
    expect(copies.map((c) => (c['file'] as Map)['id']), unorderedEquals(['a000000001', 'a000000002', 'b000000001', 'b000000002']));
    expect(copies.every((c) => c['tenantId'] == 7), isTrue);
    expect(files.keeps, everyElement(isTrue));
  });

  test('only uploaded files count; a stop before the first upload leaves every file to retry', () async {
    final files = _FakeFiles()..failing.add('Viola.pdf');
    final c = ProviderContainer(overrides: _overrides(files, _FakeSongs(), _FakeGroupNotifier()));
    addTearDown(c.dispose);
    final sub = c.listen(rdImportProvider, (_, __) {});
    addTearDown(sub.close);
    final controller = c.read(rdImportProvider.notifier);
    await controller.read([_zipFile()]);
    controller.answer('sax', const RdImportCategory(newGroup: 'Saxophon'));
    await controller.upload();
    var upload = c.read(rdImportProvider).upload!;
    expect(upload.succeeded, 3);
    expect(upload.failures.map((f) => f.path), ['Noten/120 Wie wunderbar/Viola.pdf']);

    final broken = ProviderContainer(overrides: _overrides(_FakeFiles(), _FakeSongs(), _FakeGroupNotifier(), null, true));
    addTearDown(broken.dispose);
    final sub2 = broken.listen(rdImportProvider, (_, __) {});
    addTearDown(sub2.close);
    await broken.read(rdImportProvider.notifier).read([_zipFile()]);
    broken.read(rdImportProvider.notifier).answer('sax', const RdImportCategory(newGroup: 'Saxophon'));
    await broken.read(rdImportProvider.notifier).upload();
    upload = broken.read(rdImportProvider).upload!;
    expect(upload.succeeded, 0);
    expect(upload.failures, hasLength(4));
    expect(upload.failures.every((f) => f.path.isNotEmpty), isTrue);
  });

  test('a part decided by an answer can make Fassungen before the review; their dates are read then', () async {
    final bytes = _zip({
      'Noten/1 Eins/Qfl1.pdf': '%PDF a /CreationDate (D:20190101)',
      'Noten/1 Eins/Fassung B/Qfl1.pdf': '%PDF bb /CreationDate (D:20250301)',
    });
    final c = ProviderContainer(overrides: _overrides(_FakeFiles(), _FakeSongs(), _FakeGroupNotifier()));
    addTearDown(c.dispose);
    final sub = c.listen(rdImportProvider, (_, __) {});
    addTearDown(sub.close);
    final controller = c.read(rdImportProvider.notifier);
    await controller.read([PlatformFile(name: 'Noten.zip', size: bytes.length, bytes: bytes)]);
    expect(c.read(rdImportProvider).plan!.works.single.fassungen, isEmpty);
    controller.answer('qfl', const RdImportCategory(instrumentId: 10));
    final going = controller.goTo(RdImportStep.review);
    // The dates inside the PDFs are read first.
    expect(c.read(rdImportProvider).step, RdImportStep.reading);
    await going;
    final state = c.read(rdImportProvider);
    expect(state.step, RdImportStep.review);
    final work = state.plan!.works.single;
    expect(work.fassungen, hasLength(2));
    expect(work.fassungen.firstWhere((f) => f.key == 'Fassung B').newest, DateTime(2025, 3, 1));
    expect(work.fassungen.firstWhere((f) => f.key == '').newest, DateTime(2019, 1, 1));
    expect(work.defaultFassung, 'Fassung B');
    expect(rdWorkState(state.plan!, state.decisions, work).open, isTrue);
  });

  test('ZIPs in the browser: the size is checked before reading', () async {
    final c = ProviderContainer(overrides: _overrides(_FakeFiles(), _FakeSongs(), _FakeGroupNotifier()));
    addTearDown(c.dispose);
    final sub = c.listen(rdImportProvider, (_, __) {});
    addTearDown(sub.close);
    final controller = c.read(rdImportProvider.notifier);
    var read = false;
    final huge = PlatformFile(
      name: 'Noten.zip',
      size: rdImportMaxWebBytes + 1,
      readStream: Stream.fromFuture(Future(() {
        read = true;
        return <int>[];
      })),
    );
    expect(await controller.read([huge]), RdImportReadError.tooLargeWeb);
    expect(read, isFalse);
    // In the browser file_picker's `path` throws.
    final small = _BrowserFile(name: 'Noten.zip', size: _zipBytes.length, readStream: Stream.value(_zipBytes));
    expect(await controller.read([small]), isNull);
    expect(c.read(rdImportProvider).plan!.works, hasLength(2));
  });

  test('a damaged file in the ZIP is refused, not uploaded', () {
    final archive = Archive()
      ..addFile(ArchiveFile.noCompress('Noten/1 Eins/Viola.pdf', 12, Uint8List.fromList('%PDF abcdefg'.codeUnits)));
    final bytes = Uint8List.fromList(ZipEncoder().encode(archive)!);
    // One byte of the content changed after packing.
    final at = String.fromCharCodes(bytes).indexOf('abcdefg');
    bytes[at] = 'X'.codeUnitAt(0);
    final source = RdImportSource.open([PlatformFile(name: 'Noten.zip', size: bytes.length, bytes: bytes)]);
    expect(() => source.read('Noten/1 Eins/Viola.pdf'), throwsFormatException);
  });

  test('the KI fills in sure answers, offers unsure ones and never overrides a person', () async {
    final calls = <Map<String, dynamic>>[];
    var reply = Completer<Map<String, dynamic>>();
    final ai = RdImportAi((body) {
      calls.add(body);
      return reply.future;
    });
    final c = ProviderContainer(overrides: _overrides(_FakeFiles(), _FakeSongs(), _FakeGroupNotifier(), null, false, ai));
    addTearDown(c.dispose);
    final sub = c.listen(rdImportProvider, (_, __) {});
    addTearDown(sub.close);
    final controller = c.read(rdImportProvider.notifier);
    await controller.read([_zipFile()]);
    expect(c.read(rdImportProvider).aiStatus, RdImportAiStatus.loading);
    expect(calls.single['tenantId'], 7);
    expect((calls.single['questions'] as List).single, {
      'key': 'sax',
      'label': 'Sax',
      'files': ['Sax 1.pdf', 'Sax 2.pdf'],
      'works': ['Wie wunderbar', 'Jesus ruft dich'],
    });
    reply.complete({
      'answers': [
        {'key': 'sax', 'kind': 'new', 'newGroup': 'Saxophon', 'confidence': 'high'},
      ],
    });
    await Future<void>.delayed(Duration.zero);
    var state = c.read(rdImportProvider);
    expect(state.aiStatus, RdImportAiStatus.done);
    expect(state.decisions.answers, {'sax': const RdImportCategory(newGroup: 'Saxophon')});
    expect(state.aiFilled, {'sax'});

    // Off takes the filled-in answer back, on puts it in again (no new request).
    controller.setUseAi(false);
    expect(c.read(rdImportProvider).decisions.answers, isEmpty);
    controller.setUseAi(true);
    expect(c.read(rdImportProvider).decisions.answers['sax'], const RdImportCategory(newGroup: 'Saxophon'));
    expect(calls, hasLength(1));

    // A person's answer stays, also when the KI is switched off.
    controller.answer('sax', const RdImportCategory(instrumentId: 12));
    expect(c.read(rdImportProvider).aiFilled, isEmpty);
    controller.setUseAi(false);
    expect(c.read(rdImportProvider).decisions.answers['sax'], const RdImportCategory(instrumentId: 12));

    // A late reply does not override an answer given meanwhile; an unsure one is only offered.
    controller.restart();
    controller.setUseAi(true);
    reply = Completer();
    await controller.read([_zipFile()]);
    controller.answer('sax', const RdImportCategory(instrumentId: 30));
    reply.complete({
      'answers': [
        {'key': 'sax', 'kind': 'group', 'groupId': 10, 'confidence': 'low'},
      ],
    });
    await Future<void>.delayed(Duration.zero);
    state = c.read(rdImportProvider);
    expect(state.decisions.answers['sax'], const RdImportCategory(instrumentId: 30));
    expect(state.ai['sax'], const RdImportAiAnswer(RdImportCategory(instrumentId: 10), sure: false));
    expect(state.aiFilled, isEmpty);
  });

  test('the KI\'s answers count only once the person takes them; late ones wait on the questions', () async {
    var reply = Completer<Map<String, dynamic>>();
    final ai = RdImportAi((_) => reply.future);
    final files = _FakeFiles();
    final c = ProviderContainer(overrides: _overrides(files, _FakeSongs(), _FakeGroupNotifier(), null, false, ai));
    addTearDown(c.dispose);
    final sub = c.listen(rdImportProvider, (_, __) {});
    addTearDown(sub.close);
    final controller = c.read(rdImportProvider.notifier);
    await controller.read([_zipFile()]);
    reply.complete({
      'answers': [
        {'key': 'sax', 'kind': 'new', 'newGroup': 'Saxophon', 'confidence': 'high'},
      ],
    });
    await Future<void>.delayed(Duration.zero);
    expect(c.read(rdImportProvider).aiFilled, {'sax'});
    // Not to the review (and so not uploaded or learned) before they are taken.
    await controller.goTo(RdImportStep.review);
    expect(c.read(rdImportProvider).step, RdImportStep.questions);
    await controller.upload();
    expect(files.uploads, isEmpty);
    controller.confirmAi();
    expect(c.read(rdImportProvider).aiFilled, isEmpty);
    expect(c.read(rdImportProvider).decisions.answers['sax'], const RdImportCategory(newGroup: 'Saxophon'));
    await controller.goTo(RdImportStep.review);
    expect(c.read(rdImportProvider).step, RdImportStep.review);

    // An answer that comes after the questions is only offered.
    controller.restart();
    reply = Completer();
    await controller.read([_zipFile()]);
    await controller.goTo(RdImportStep.review);
    expect(c.read(rdImportProvider).step, RdImportStep.review);
    reply.complete({
      'answers': [
        {'key': 'sax', 'kind': 'new', 'newGroup': 'Saxophon', 'confidence': 'high'},
      ],
    });
    await Future<void>.delayed(Duration.zero);
    final state = c.read(rdImportProvider);
    expect(state.ai['sax']?.sure, isTrue);
    expect(state.decisions.answers, isEmpty);
    expect(state.aiFilled, isEmpty);
  });

  test('"Passt so" and the upload wait for dates read after a change; a Werk whose Fassung changes is checked again', () async {
    final archive = Archive();
    void add(String path, String content, DateTime modified) {
      final bytes = Uint8List.fromList(content.codeUnits);
      archive.addFile(ArchiveFile(path, bytes.length, bytes)..lastModTime = modified.millisecondsSinceEpoch ~/ 1000);
    }

    // The file dates prefer the main folder, the dates inside "Fassung B".
    add('Noten/1 Eins/Viola.pdf', '%PDF a /CreationDate (D:20190101)', DateTime(2026, 1, 1));
    add('Noten/1 Eins/Fassung B/Qfl1.pdf', '%PDF bb /CreationDate (D:20250301)', DateTime(2020, 1, 1));
    add('Noten/2 Zwei/Viola.pdf', '%PDF c /CreationDate (D:20190101)', DateTime(2026, 1, 1));
    add('Noten/2 Zwei/Fassung B/Xyz1.pdf', '%PDF dd /CreationDate (D:20250301)', DateTime(2020, 1, 1));
    final bytes = Uint8List.fromList(ZipEncoder().encode(archive)!);
    final files = _FakeFiles();
    final c = ProviderContainer(overrides: _overrides(files, _FakeSongs(), _FakeGroupNotifier()));
    addTearDown(c.dispose);
    final sub = c.listen(rdImportProvider, (_, __) {});
    addTearDown(sub.close);
    final controller = c.read(rdImportProvider.notifier);
    await controller.read([PlatformFile(name: 'Noten.zip', size: bytes.length, bytes: bytes)]);
    await controller.goTo(RdImportStep.review);
    RdImportWork work(String title) => c.read(rdImportProvider).plan!.works.firstWhere((w) => w.title == title);
    final eins = work('Eins').key;
    final zwei = work('Zwei').key;
    expect(work('Eins').fassungen, isEmpty);

    // A decided part makes Fassungen; their dates are read now.
    controller.setCategory('Noten/1 Eins/Fassung B/Qfl1.pdf', const RdImportCategory(instrumentId: 12));
    expect(c.read(rdImportProvider).readingDates, isTrue);
    controller.confirm(eins);
    expect(c.read(rdImportProvider).decisions.confirmed, isEmpty);
    await controller.upload();
    expect(files.uploads, isEmpty);
    expect(c.read(rdImportProvider).step, RdImportStep.review);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    var state = c.read(rdImportProvider);
    expect(state.readingDates, isFalse);
    expect(rdFassungOf(state.decisions, work('Eins')), 'Fassung B');
    controller.confirm(eins);
    expect(c.read(rdImportProvider).decisions.confirmed, {eins});

    // Checked before, then a part makes Fassungen: check again, at once.
    controller.confirm(zwei);
    expect(c.read(rdImportProvider).decisions.confirmed, {eins, zwei});
    controller.setCategory('Noten/2 Zwei/Fassung B/Xyz1.pdf', const RdImportCategory(instrumentId: 12));
    expect(c.read(rdImportProvider).decisions.confirmed, {eins});
    expect(rdFassungOf(c.read(rdImportProvider).decisions, work('Zwei')), '');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    state = c.read(rdImportProvider);
    expect(rdFassungOf(state.decisions, work('Zwei')), 'Fassung B');
    expect(state.decisions.confirmed, {eins});
  });

  test('"Passt so" holds for what was shown: any change of the selection opens the Werk again', () async {
    final archive = Archive();
    void add(String path, String content, DateTime modified) {
      final bytes = Uint8List.fromList(content.codeUnits);
      archive.addFile(ArchiveFile(path, bytes.length, bytes)..lastModTime = modified.millisecondsSinceEpoch ~/ 1000);
    }

    add('Noten/1 Eins/Viola.pdf', '%PDF a /CreationDate (D:20250101)', DateTime(2026, 1, 1));
    add('Noten/1 Eins/Fassung B/Xyz1.pdf', '%PDF b /CreationDate (D:20190101)', DateTime(2026, 1, 1));
    add('Noten/2 Zwei/Viola.pdf', '%PDF c', DateTime(2026, 1, 1));
    add('Noten/2 Zwei/Qfl1.pdf', '%PDF d', DateTime(2026, 1, 1));
    final bytes = Uint8List.fromList(ZipEncoder().encode(archive)!);
    final files = _FakeFiles();
    final c = ProviderContainer(overrides: _overrides(files, _FakeSongs(), _FakeGroupNotifier()));
    addTearDown(c.dispose);
    final sub = c.listen(rdImportProvider, (_, __) {});
    addTearDown(sub.close);
    final controller = c.read(rdImportProvider.notifier);
    await controller.read([PlatformFile(name: 'Noten.zip', size: bytes.length, bytes: bytes)]);
    await controller.goTo(RdImportStep.review);
    RdImportState state() => c.read(rdImportProvider);
    RdImportWork work(String title) => state().plan!.works.firstWhere((w) => w.title == title);
    final eins = work('Eins').key;
    final zwei = work('Zwei').key;
    expect(work('Eins').fassungen, isEmpty);
    controller.confirm(eins);
    controller.confirm(zwei);
    expect(state().decisions.confirmed, {eins, zwei});

    // A part decided afterwards makes Fassungen and leaves files out: the
    // Werk is open again right away, even when no date changes later.
    controller.setCategory('Noten/1 Eins/Fassung B/Xyz1.pdf', const RdImportCategory(instrumentId: 12));
    expect(work('Eins').fassungen, hasLength(2));
    expect(state().decisions.confirmed, {zwei});
    expect(rdWorkState(state().plan!, state().decisions, work('Eins')).open, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(state().readingDates, isFalse);
    expect(rdFassungOf(state().decisions, work('Eins')), '');
    expect(state().decisions.confirmed, {zwei});

    // Checked again; another Werk's change keeps it.
    controller.confirm(eins);
    controller.setTake('Noten/2 Zwei/Qfl1.pdf', false);
    expect(state().decisions.confirmed, {eins});

    // An option that changes what is taken counts too.
    controller.setProposeFassung(false);
    expect(state().decisions.confirmed, isEmpty);

    // Back to the questions and an answer there: the same.
    controller.setProposeFassung(true);
    controller.setTake('Noten/2 Zwei/Qfl1.pdf', true);
    controller.confirm(eins);
    controller.confirm(zwei);
    await controller.goTo(RdImportStep.questions);
    controller.answer('qfl', const RdImportCategory(instrumentId: 10));
    await controller.goTo(RdImportStep.review);
    expect(state().decisions.confirmed, {eins});

    // A new import starts without any.
    controller.confirm(eins);
    controller.restart();
    expect(state().decisions.confirmed, isEmpty);
  });

  test('a Werk whose "Passt so" a change took back waits for another look, even without flags', () async {
    final bytes = _zip({
      'Noten/1 Eins/Viola.pdf': '%PDF a /CreationDate (D:20190101)',
      'Noten/1 Eins/Fassung B/Viola.pdf': '%PDF b /CreationDate (D:20250301)',
    });
    final files = _FakeFiles();
    final c = ProviderContainer(overrides: _overrides(files, _FakeSongs(), _FakeGroupNotifier()));
    addTearDown(c.dispose);
    final sub = c.listen(rdImportProvider, (_, __) {});
    addTearDown(sub.close);
    final controller = c.read(rdImportProvider.notifier);
    await controller.read([PlatformFile(name: 'Noten.zip', size: bytes.length, bytes: bytes)]);
    await controller.goTo(RdImportStep.review);
    RdImportState state() => c.read(rdImportProvider);
    RdWorkState ws() => rdWorkState(state().plan!, state().decisions, state().plan!.works.single);
    final key = state().plan!.works.single.key;
    expect(ws().flags, contains(RdWorkFlag.fassungen));
    controller.confirm(key);
    expect(rdImportUploads(state().plan!, state().decisions).map((u) => u.file.path), ['Noten/1 Eins/Fassung B/Viola.pdf']);

    // The file of the main folder becomes another part: no Fassungen and
    // no flag any more, both files would go up. Still open until checked.
    controller.setCategory('Noten/1 Eins/Viola.pdf', const RdImportCategory(instrumentId: 10));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(ws().flags, isEmpty);
    expect(ws().confirmed, isFalse);
    expect(ws().recheck, isTrue);
    expect(ws().open, isTrue);
    expect(rdImportUploads(state().plan!, state().decisions), isEmpty);
    await controller.upload();
    expect(files.uploads, isEmpty);

    // Checked again: both go up.
    controller.confirm(key);
    expect(ws().recheck, isFalse);
    expect(ws().open, isFalse);
    expect(rdImportUploads(state().plan!, state().decisions), hasLength(2));
  });

  test('back to the questions while their dates are read stays there', () async {
    final bytes = _zip({
      'Noten/1 Eins/Qfl1.pdf': '%PDF a /CreationDate (D:20190101)',
      'Noten/1 Eins/Fassung B/Qfl1.pdf': '%PDF bb /CreationDate (D:20250301)',
    });
    final c = ProviderContainer(overrides: _overrides(_FakeFiles(), _FakeSongs(), _FakeGroupNotifier()));
    addTearDown(c.dispose);
    final sub = c.listen(rdImportProvider, (_, __) {});
    addTearDown(sub.close);
    final controller = c.read(rdImportProvider.notifier);
    await controller.read([PlatformFile(name: 'Noten.zip', size: bytes.length, bytes: bytes)]);
    controller.answer('qfl', const RdImportCategory(instrumentId: 10));
    final going = controller.goTo(RdImportStep.review);
    expect(c.read(rdImportProvider).step, RdImportStep.reading);
    await controller.goTo(RdImportStep.questions);
    await going;
    expect(c.read(rdImportProvider).step, RdImportStep.questions);
    // The dates are there now: on to the review at once.
    await controller.goTo(RdImportStep.review);
    expect(c.read(rdImportProvider).step, RdImportStep.review);
    expect(c.read(rdImportProvider).plan!.works.single.defaultFassung, 'Fassung B');
  });

  test('link errors: Dropbox, a file, not shared, function missing', () async {
    final c = ProviderContainer(overrides: _overrides(_FakeFiles(), _FakeSongs(), _FakeGroupNotifier(), _drive()));
    addTearDown(c.dispose);
    final controller = c.read(rdImportProvider.notifier);
    expect((await controller.checkLink('https://www.dropbox.com/scl/fo/abc/x?dl=0')).error, RdImportReadError.dropbox);
    expect((await controller.checkLink('https://drive.google.com/file/d/1aBcDeFgHiJk/view')).error, RdImportReadError.notFolder);
    expect((await controller.checkLink('Noten')).error, RdImportReadError.badLink);
    expect(
      (await controller.checkLink('https://drive.google.com/drive/folders/unshared0001')).error,
      RdImportReadError.notFound,
    );

    final missing = ProviderContainer(overrides: [
      ..._overrides(_FakeFiles(), _FakeSongs(), _FakeGroupNotifier()),
      rdDriveApiProvider.overrideWithValue(RdDriveApi((_) async => throw const FunctionException(
            status: 404,
            details: {'code': 'NOT_FOUND', 'message': 'Requested function was not found'},
          ))),
    ]);
    addTearDown(missing.dispose);
    expect((await missing.read(rdImportProvider.notifier).checkLink(_driveLink)).error, RdImportReadError.notSetUp);
  });

  testWidgets('Drive: paste the link, read, and the reminder to stop sharing', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final drive = _drive();
    await tester.pumpWidget(ProviderScope(
      overrides: _overrides(_FakeFiles(), _FakeSongs(), _FakeGroupNotifier(), drive),
      child: MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
        home: const RdImportPage(),
      ),
    ));
    await tester.pump();
    await tester.tap(find.text('Google Drive'));
    await tester.pump();
    expect(find.text('Google Drive öffnen'), findsOneWidget);
    expect(find.text('Einlesen starten'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'https://www.dropbox.com/scl/fo/abc/x?dl=0');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pump();
    expect(find.textContaining('Dropbox-Links gehen noch nicht'), findsOneWidget);
    // An error comes with a way out; reading waits for a folder.
    expect(find.text('Stattdessen ZIP-Datei wählen'), findsOneWidget);
    expect(tester.widget<RdPrimaryButton>(find.widgetWithText(RdPrimaryButton, 'Einlesen starten')).onPressed, isNull);

    await tester.enterText(find.byType(TextField), _driveLink);
    await tester.pump();
    await tester.pump();
    expect(find.text('„Noten“ gefunden'), findsOneWidget);
    expect(find.text('Stattdessen ZIP-Datei wählen'), findsNothing);
    expect(tester.widget<RdPrimaryButton>(find.widgetWithText(RdPrimaryButton, 'Einlesen starten')).onPressed, isNotNull);

    final container = ProviderScope.containerOf(tester.element(find.byType(RdImportPage)));
    final error = await tester.runAsync(
      () => container.read(rdImportProvider.notifier).readLink(const RdDriveRef('root00000001'), 'Noten'),
    );
    expect(error, isNull);
    await tester.pump();
    expect(find.text('„Sax“ gehört zu …'), findsOneWidget);

    container.read(rdImportProvider.notifier).answer('sax', const RdImportCategory(newGroup: 'Saxophon'));
    await tester.runAsync(() => container.read(rdImportProvider.notifier).upload());
    await tester.pump();
    expect(find.text('Freigabe wieder aufheben'), findsOneWidget);
    expect(find.text('In Google Drive öffnen'), findsOneWidget);
    // Nothing left to retry or check: the link is no longer needed.
    expect(find.textContaining('Attendix braucht den Link nicht mehr'), findsOneWidget);
    // No back link while done; the way back is the button.
    expect(find.text('Werke'), findsNothing);
    expect(find.text('Zu den Werken'), findsOneWidget);
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
    expect(find.text('Wo liegen eure Noten?'), findsOneWidget);
    expect(find.text('Empfohlen'), findsOneWidget);
    expect(find.text('Schritt 1 von 4 · Quelle'), findsOneWidget);
    await tester.tap(find.text('ZIP-Datei'));
    await tester.pump();
    expect(find.text('ZIP-Datei wählen'), findsOneWidget);
    // Back goes to the choice, not out of the assistant.
    await tester.tap(find.text('Quelle'));
    await tester.pump();
    expect(find.text('Wo liegen eure Noten?'), findsOneWidget);

    final container = ProviderScope.containerOf(tester.element(find.byType(RdImportPage)));
    final error = await tester.runAsync(() => container.read(rdImportProvider.notifier).read([_zipFile()]));
    expect(error, isNull);
    await tester.pump();
    expect(find.text('Schritt 2 von 4 · Stimmen'), findsOneWidget);
    expect(find.text('„Sax“ gehört zu …'), findsOneWidget);
    await tester.tap(find.text('Neue Gruppe „Sax“'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Saxophon');
    await tester.tap(find.text('Neue Gruppe anlegen').last);
    await tester.pumpAndSettle();
    expect(find.text('Neue Gruppe „Saxophon“'), findsOneWidget);

    await tester.ensureVisible(find.text('Zur Prüfung'));
    await tester.tap(find.text('Zur Prüfung'));
    await tester.pump();
    expect(find.text('Schritt 3 von 4 · Prüfen'), findsOneWidget);
    // Every answer given: no hint about open questions.
    expect(find.text('Fragen beantworten'), findsNothing);
    // Nothing open: every Werk is listed, the new one marked.
    expect(find.text('157 Jesus ruft dich'), findsOneWidget);
    expect(find.text('Neu'), findsOneWidget);
    expect(find.text('4 Dateien übernehmen'), findsOneWidget);

    await tester.tap(find.text('157 Jesus ruft dich'));
    await tester.pumpAndSettle();
    expect(find.text('Ziel in Attendix'), findsOneWidget);
    expect(find.text('Doppelt vorhanden'), findsOneWidget);
    expect(find.text('Passt so'), findsOneWidget);

    // The part of a file is read out with what it is and can be changed
    // with a screen reader.
    final semantics = tester.ensureSemantics();
    await tester.pump();
    final link = find.bySemanticsLabel(RegExp(r'^Stimme ändern: '));
    expect(link, findsWidgets);
    expect(tester.getSemantics(link.first), containsSemantics(isButton: true, hasTapAction: true));
    semantics.dispose();
  });

  testWidgets('questions: the KI\'s answer is marked and can be switched off', (tester) async {
    tester.view.physicalSize = const Size(430, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final ai = RdImportAi((_) async => {
          'answers': [
            {'key': 'sax', 'kind': 'new', 'newGroup': 'Saxophon', 'confidence': 'high'},
          ],
        });
    await tester.pumpWidget(ProviderScope(
      overrides: _overrides(_FakeFiles(), _FakeSongs(), _FakeGroupNotifier(), null, false, ai),
      child: MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
        home: const RdImportPage(),
      ),
    ));
    await tester.pump();
    final container = ProviderScope.containerOf(tester.element(find.byType(RdImportPage)));
    await tester.runAsync(() async {
      await container.read(rdImportProvider.notifier).read([_zipFile()]);
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    expect(find.text('Die KI hat 1 Antwort ausgefüllt (✦), bitte kurz prüfen.'), findsOneWidget);
    final chip = find.ancestor(of: find.text('Neue Gruppe „Saxophon“'), matching: find.byType(RdChoiceChip));
    expect(tester.widget<RdChoiceChip>(chip).selected, isTrue);
    expect(tester.widget<RdChoiceChip>(chip).icon, Icons.auto_awesome);

    // The ✦ is read out, and the chip can still be tapped with a screen
    // reader.
    expect(tester.widget<RdChoiceChip>(chip).semanticLabel, 'Neue Gruppe „Saxophon“, Vorschlag der KI');
    final semantics = tester.ensureSemantics();
    await tester.pump();
    expect(
      tester.getSemantics(find.bySemanticsLabel('Neue Gruppe „Saxophon“, Vorschlag der KI')),
      containsSemantics(label: 'Neue Gruppe „Saxophon“, Vorschlag der KI', isButton: true, isSelected: true, hasTapAction: true),
    );
    semantics.dispose();

    // The KI's answers are confirmed before the review.
    await tester.ensureVisible(find.text('Zur Prüfung'));
    await tester.tap(find.text('Zur Prüfung'));
    await tester.pumpAndSettle();
    expect(find.text('Vorschläge der KI übernehmen?'), findsOneWidget);
    await tester.tap(find.text('Nochmal ansehen'));
    await tester.pumpAndSettle();
    expect(container.read(rdImportProvider).step, RdImportStep.questions);
    expect(container.read(rdImportProvider).aiFilled, {'sax'});

    await tester.ensureVisible(find.text('Vorschläge der KI'));
    await tester.tap(find.text('Vorschläge der KI'));
    await tester.pump();
    expect(find.text('Die KI hat 1 Antwort ausgefüllt (✦), bitte kurz prüfen.'), findsNothing);
    expect(find.text('Neue Gruppe „Saxophon“'), findsNothing);
    expect(find.text('Neue Gruppe „Sax“'), findsOneWidget);
    expect(container.read(rdImportProvider).decisions.answers, isEmpty);
  });

  testWidgets('review: open questions are named, with the way back to them', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: _overrides(_FakeFiles(), _FakeSongs(), _FakeGroupNotifier()),
      child: MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
        home: const RdImportPage(),
      ),
    ));
    await tester.pump();
    final container = ProviderScope.containerOf(tester.element(find.byType(RdImportPage)));
    await tester.runAsync(() => container.read(rdImportProvider.notifier).read([_zipFile()]));
    await tester.pump();
    expect(find.textContaining('Noch 1 Frage offen.'), findsOneWidget);
    await tester.runAsync(() => container.read(rdImportProvider.notifier).goTo(RdImportStep.review));
    await tester.pump();
    expect(find.textContaining('1 Stimmname ist noch offen.'), findsOneWidget);
    await tester.tap(find.text('Fragen beantworten'));
    await tester.pump();
    expect(find.text('„Sax“ gehört zu …'), findsOneWidget);
  });

  testWidgets('leaving while the dates of Fassungen are read after the questions asks too; back leads to them', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final drive = _GatedDrive({
      'root00000001': [folder('f001000001', '1 Eins')],
      'f001000001': [file('a000000001', 'Qfl1.pdf', size: 10, md5: 'a'), folder('fb00000001', 'Fassung B')],
      'fb00000001': [file('b000000001', 'Qfl1.pdf', size: 10, md5: 'b')],
    }, names: {
      'root00000001': 'Noten',
    });
    await tester.pumpWidget(ProviderScope(
      overrides: _overrides(_FakeFiles(), _FakeSongs(), _FakeGroupNotifier(), drive),
      child: MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
        home: const RdImportPage(),
      ),
    ));
    await tester.pump();
    final container = ProviderScope.containerOf(tester.element(find.byType(RdImportPage)));
    final guards = container.read(routeLeaveGuardRegistryProvider);
    final notifier = container.read(rdImportProvider.notifier);
    await tester.runAsync(() => notifier.readLink(const RdDriveRef('root00000001'), 'Noten'));
    await tester.pump();
    expect(container.read(rdImportProvider).step, RdImportStep.questions);
    notifier.answer('qfl', const RdImportCategory(instrumentId: 10));
    final going = notifier.goTo(RdImportStep.review);
    await tester.pump();
    expect(container.read(rdImportProvider).step, RdImportStep.reading);

    // A tab switch or browser back asks first.
    final leaving = guards.canLeave();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Import verwerfen?'), findsOneWidget);
    await tester.tap(find.text('Abbrechen').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(await leaving, isFalse);

    // The back link leads to the questions, where the answers still are.
    await tester.tap(find.text('Stimmen').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(container.read(rdImportProvider).step, RdImportStep.questions);
    expect(container.read(rdImportProvider).decisions.answers, contains('qfl'));
    drive.gate.complete();
    await tester.runAsync(() => going);
    await tester.pump();
    expect(container.read(rdImportProvider).step, RdImportStep.questions);
  });

  testWidgets('leaving: asks only while there are answers to lose', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: _overrides(_FakeFiles(), _FakeSongs(), _FakeGroupNotifier()),
      child: MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
        home: const RdImportPage(),
      ),
    ));
    await tester.pump();
    final container = ProviderScope.containerOf(tester.element(find.byType(RdImportPage)));
    final guards = container.read(routeLeaveGuardRegistryProvider);
    // Nothing to lose yet.
    expect(guards.hasGuards, isTrue);
    expect(await guards.canLeave(), isTrue);

    await tester.runAsync(() => container.read(rdImportProvider.notifier).read([_zipFile()]));
    await tester.pump();
    var leaving = guards.canLeave();
    await tester.pumpAndSettle();
    expect(find.text('Import verwerfen?'), findsOneWidget);
    await tester.tap(find.text('Abbrechen').last);
    await tester.pumpAndSettle();
    expect(await leaving, isFalse);

    leaving = guards.canLeave();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verwerfen').last);
    await tester.pumpAndSettle();
    expect(await leaving, isTrue);
  });
}

/// [FakeDrive] whose `head` (the dates inside the PDFs) waits for [gate].
class _GatedDrive extends FakeDrive {
  _GatedDrive(super.tree, {super.names});

  final gate = Completer<void>();

  @override
  Future<dynamic> call(Map<String, dynamic> body) async {
    if (body['action'] == 'head') await gate.future;
    return super.call(body);
  }
}
