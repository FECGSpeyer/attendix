import 'dart:io';

import 'package:attendix/features/redesign/data/import/rd_import_drive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_drive.dart';

void main() {
  group('links', () {
    test('Drive folder links in their usual forms', () {
      const id = '1aBcDeFgHiJkLmNoPqRsTuV';
      expect(rdParseDriveLink('https://drive.google.com/drive/folders/$id?usp=sharing'), const RdDriveRef(id));
      expect(rdParseDriveLink(' drive.google.com/drive/u/0/folders/$id '), const RdDriveRef(id));
      expect(rdParseDriveLink('https://drive.google.com/open?id=$id'), const RdDriveRef(id));
      expect(
        rdParseDriveLink('https://drive.google.com/drive/folders/$id?resourcekey=0-AbC_12&usp=link'),
        const RdDriveRef(id, '0-AbC_12'),
      );
    });

    test('files, documents, Dropbox and other text are no folder links', () {
      const id = '1aBcDeFgHiJkLmNoPqRsTuV';
      expect(rdParseDriveLink('https://drive.google.com/file/d/$id/view'), isNull);
      expect(rdIsDriveLink('https://drive.google.com/file/d/$id/view'), isTrue);
      expect(rdParseDriveLink('https://docs.google.com/document/d/$id/edit'), isNull);
      expect(rdIsDriveLink('https://docs.google.com/document/d/$id/edit'), isTrue);
      expect(rdParseDriveLink('https://www.dropbox.com/scl/fo/abc/xyz?dl=0'), isNull);
      expect(rdIsDropboxLink('https://www.dropbox.com/scl/fo/abc/xyz?dl=0'), isTrue);
      expect(rdParseDriveLink('Noten Speyer'), isNull);
      expect(rdParseDriveLink('https://evil.example/drive.google.com/drive/folders/$id'), isNull);
      expect(rdParseDriveLink('https://drive.google.com.evil.example/drive/folders/$id'), isNull);
      expect(rdParseDriveLink("https://drive.google.com/drive/folders/abc'or'1=1"), isNull);
    });

    test('opens the folder again (with its resource key)', () {
      expect(rdDriveFolderUrl(const RdDriveRef('1aBcDeFgHiJk')).toString(), 'https://drive.google.com/drive/folders/1aBcDeFgHiJk');
      expect(
        rdDriveFolderUrl(const RdDriveRef('1aBcDeFgHiJk', '0-x')).toString(),
        'https://drive.google.com/drive/folders/1aBcDeFgHiJk?resourcekey=0-x',
      );
    });
  });

  test('errors of the function; a missing function is "not set up"', () {
    expect(RdDriveApi.errorOf(404, {'error': 'not_found'}), RdDriveError.notFound);
    expect(RdDriveApi.errorOf(404, {'code': 'NOT_FOUND', 'message': 'Requested function was not found'}), RdDriveError.notSetUp);
    expect(RdDriveApi.errorOf(503, {'error': 'not_configured'}), RdDriveError.notSetUp);
    expect(RdDriveApi.errorOf(429, {'error': 'limit'}), RdDriveError.limit);
    expect(RdDriveApi.errorOf(429, {'error': 'drive_busy'}), RdDriveError.busy);
    expect(RdDriveApi.errorOf(400, {'error': 'not_folder'}), RdDriveError.notFolder);
    expect(RdDriveApi.errorOf(403, {'error': 'forbidden'}), RdDriveError.forbidden);
    expect(RdDriveApi.errorOf(500, 'boom'), RdDriveError.failed);
  });

  group('source', () {
    test('walks the folder level by level, 25 folders per request', () async {
      final werke = [for (var i = 1; i <= 30; i++) folder('werk${i.toString().padLeft(8, '0')}', '$i Werk $i')];
      final drive = FakeDrive({
        'root00000001': [
          ...werke,
          file('ds00000001', '.DS_Store'),
          {'id': 'short0000001', 'name': 'Verknüpfung', 'mimeType': 'application/vnd.google-apps.shortcut'},
        ],
        for (final w in werke.skip(1)) w['id'] as String: [file('${w['id']}v', 'Viola.pdf', md5: 'm${w['id']}')],
        'werk00000001': [
          file('a000000001', 'Viola.pdf', md5: 'same'),
          file('a000000002', 'Viola.pdf', md5: 'other', modified: '2024-03-12T10:00:00Z'),
          {'id': 'doc0000001', 'name': 'Liedtext', 'mimeType': 'application/vnd.google-apps.document'},
          folder('alt0000001', 'Alt/2019'),
        ],
        'alt0000001': [file('b000000001', 'Viola.pdf', md5: 'same')],
      });
      final progress = <int>[];
      final source = await RdDriveSource.load(
        RdDriveApi(drive.call),
        7,
        const RdDriveRef('root00000001'),
        'Noten (Speyer)',
        onProgress: progress.add,
      );
      final lists = drive.calls.where((c) => c['action'] == 'list').toList();
      // Root, then 30 Werke in two requests, then the sub-folder.
      expect(lists.map((c) => (c['folders'] as List).length), [1, 25, 5, 1]);
      expect(lists.every((c) => c['tenantId'] == 7), isTrue);
      expect(source.name, 'Noten (Speyer)');
      expect(source.junk, 2);
      final paths = source.entries.map((e) => e.path).toList();
      expect(paths, containsAll([
        'Noten (Speyer)/1 Werk 1/Viola.pdf',
        'Noten (Speyer)/1 Werk 1/Viola (2).pdf',
        'Noten (Speyer)/1 Werk 1/Liedtext.gdoc',
        'Noten (Speyer)/1 Werk 1/Alt-2019/Viola.pdf',
        'Noten (Speyer)/30 Werk 30/Viola.pdf',
      ]));
      expect(paths, hasLength(29 + 4));
      expect(progress.last, paths.length);
      final second = source.entries.firstWhere((e) => e.path.endsWith('Viola (2).pdf'));
      expect(second.modified, DateTime.utc(2024, 3, 12, 10).toLocal());

      // Hashes are Drive's MD5 without reading; dates come from the PDF.
      final same1 = await source.inspect('Noten (Speyer)/1 Werk 1/Viola.pdf', hash: true, date: false);
      final same2 = await source.inspect('Noten (Speyer)/1 Werk 1/Alt-2019/Viola.pdf', hash: true, date: false);
      expect(same1.hash, same2.hash);
      expect(drive.calls.where((c) => c['action'] == 'head'), isEmpty);
    });

    test('reads the date inside a PDF from its ends', () async {
      final drive = FakeDrive({
        'root00000001': [file('a000000001', 'Viola.pdf', md5: 'x')],
      }, dates: {
        'a000000001': '%PDF-1.4 /CreationDate (D:20240501120000)',
      });
      final source = await RdDriveSource.load(RdDriveApi(drive.call), 7, const RdDriveRef('root00000001'), 'Noten');
      final r = await source.inspect('Noten/Viola.pdf', hash: false, date: true);
      expect(r.date, DateTime(2024, 5, 1, 12));
      expect(r.hash, isNull);
      expect(drive.calls.last, {'action': 'head', 'tenantId': 7, 'file': {'id': 'a000000001'}});
    });

    test('a folder that links back to itself is read once', () async {
      final drive = FakeDrive({
        'root00000001': [folder('sub0000001', 'Sub')],
        'sub0000001': [folder('root00000001', 'Noten'), file('a000000001', 'Viola.pdf')],
      });
      final source = await RdDriveSource.load(RdDriveApi(drive.call), 7, const RdDriveRef('root00000001'), 'Noten');
      expect(source.entries.map((e) => e.path), ['Noten/Sub/Viola.pdf']);
    });

    test('resource keys travel with every request', () async {
      final drive = FakeDrive({
        'root00000001': [
          {...folder('sub0000001', 'Sub'), 'resourceKey': '0-sub'},
        ],
        'sub0000001': [
          {...file('a000000001', 'Viola.pdf'), 'resourceKey': '0-file'},
        ],
      });
      final api = RdDriveApi(drive.call);
      final source = await RdDriveSource.load(api, 7, const RdDriveRef('root00000001', '0-root'), 'Noten');
      expect(drive.calls.first['folders'], [
        {'id': 'root00000001', 'resourceKey': '0-root'},
      ]);
      expect(drive.calls[1]['folders'], [
        {'id': 'sub0000001', 'resourceKey': '0-sub'},
      ]);
      await source.inspect('Noten/Sub/Viola.pdf', hash: false, date: true);
      expect(drive.calls.last['file'], {'id': 'a000000001', 'resourceKey': '0-file'});
    });

    test('a refused call becomes a Drive error', () async {
      final api = RdDriveApi((_) async => throw const FunctionException(status: 429, details: {'error': 'limit'}));
      await expectLater(
        RdDriveSource.load(api, 7, const RdDriveRef('root00000001'), 'Noten'),
        throwsA(isA<RdDriveException>().having((e) => e.error, 'error', RdDriveError.limit)),
      );
    });
  });

  test('the function only fetches Google, checks its input and never overwrites', () {
    final src = File('supabase/functions/werke-import/index.ts').readAsStringSync();
    // One outgoing host.
    final hosts = RegExp(r'https://([a-z0-9.-]+)').allMatches(src).map((m) => m[1]).toSet();
    expect(hosts, {'www.googleapis.com'});
    expect(src, contains('upsert: false'));
    expect(src, contains('.eq("tenantId", tenantId)'));
    expect(src, contains('auth.getUser()'));
    expect(src, contains('werke_import_take'));
    expect(src, contains('DRIVE_ID.test'));
    expect(src, contains('STORAGE_NAME.test'));
    // The song is looked up by id and tenant before a copy.
    final copy = src.substring(src.indexOf('case "copy"'));
    expect(copy.indexOf('.from("songs")'), lessThan(copy.indexOf('admin.storage')));
    expect(copy, contains('.eq("id", songId)'));
  });
}
