import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:attendix/core/services/song_file_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/storage_upload_body.dart';

Map<String, Object?> _file(String name, {int? instrumentId}) => {
  'storageName': '${name}_123.pdf',
  'fileName': '$name.pdf',
  'fileType': 'application/pdf',
  'url':
      'http://127.0.0.1:1/storage/v1/object/public/songs/songs/7/5/${name}_123.pdf',
  'instrumentId': instrumentId,
};

/// The real Supabase client talks only to this local HTTP boundary. Both
/// database and storage state reflect each accepted request, including
/// updates whose answer is lost. Unrecognised requests fail the test.
class _Backend {
  _Backend(List<Map<String, Object?>> files)
    : files = [for (final file in files) Map<String, Object?>.from(file)],
      objects = {
        for (final file in files)
          'songs/7/5/${file['storageName']}': Uint8List.fromList([1, 2, 3]),
      };

  List<Map<String, Object?>> files;
  final Map<String, Uint8List> objects;
  final requests = <String>[];
  List<int> instrumentIds = [];
  int databaseFailures = 0;
  int storageFailures = 0;
  bool loseUpdateAnswer = false;
  bool updateMatchesRow = true;
  bool rowExists = true;
  Completer<void>? updateStarted;
  Completer<void>? allowUpdate;
  Completer<void>? deleteStarted;
  Completer<void>? allowDelete;
  String uploadContentType = 'application/octet-stream';
  final uploadOverwriteFlags = <String?>[];

  late final client = SupabaseClient(
    'http://127.0.0.1:1',
    'local-files-test-only',
    httpClient: MockClient(reply),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );

  http.Response _json(http.Request request, Object body, [int status = 200]) =>
      http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
        request: request,
      );

  Future<http.Response> reply(http.Request request) async {
    requests.add('${request.method} ${request.url.path}');
    if (request.url.path == '/rest/v1/songs') {
      expect(request.url.queryParameters['id'], 'eq.5');
      expect(request.url.queryParameters['tenantId'], 'eq.7');
      if (request.method == 'GET') {
        return _json(
          request,
          rowExists
              ? [
                {'id': 5, 'files': files},
              ]
              : [],
        );
      }
      if (request.method == 'PATCH') {
        updateStarted?.complete();
        await allowUpdate?.future;
        if (databaseFailures > 0) {
          databaseFailures--;
          return _json(request, {
            'message': 'database unavailable',
            'code': 'XX000',
          }, 503);
        }
        final wantsObject =
            request.headers['accept'] == 'application/vnd.pgrst.object+json';
        if (!rowExists || !updateMatchesRow) {
          return wantsObject
              ? _json(request, {
                'code': 'PGRST116',
                'details':
                    'Results contain 0 rows, application/vnd.pgrst.object+json requires 1 row',
                'hint': null,
                'message':
                    'JSON object requested, multiple (or no) rows returned',
              }, 406)
              : _json(request, []);
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        files = [
          for (final file in body['files'] as List)
            Map<String, Object?>.from(file as Map),
        ];
        if (body['instrument_ids'] != null) {
          instrumentIds = List<int>.from(body['instrument_ids'] as List);
        }
        if (loseUpdateAnswer) {
          loseUpdateAnswer = false;
          throw http.ClientException(
            'Connection closed after commit',
            request.url,
          );
        }
        return _json(
          request,
          wantsObject
              ? {'id': 5}
              : request.url.queryParameters.containsKey('select')
              ? [
                {'id': 5},
              ]
              : [],
        );
      }
    }
    if (request.method == 'DELETE' &&
        request.url.path == '/storage/v1/object/songs') {
      if (deleteStarted != null && !deleteStarted!.isCompleted) {
        deleteStarted!.complete();
      }
      await allowDelete?.future;
      if (storageFailures > 0) {
        storageFailures--;
        return _json(request, {
          'message': 'storage unavailable',
          'statusCode': '503',
        }, 503);
      }
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      for (final path in List<String>.from(body['prefixes'] as List)) {
        expect(path, startsWith('songs/7/5/'));
        objects.remove(path);
      }
      return _json(request, []);
    }
    if (request.method == 'POST' &&
        request.url.path.startsWith('/storage/v1/object/songs/songs/7/5/')) {
      final path = request.url.path.substring(
        '/storage/v1/object/songs/'.length,
      );
      final upload = storageUploadBody(request);
      uploadOverwriteFlags.add(request.headers['x-upsert']);
      if (objects.containsKey(path) && request.headers['x-upsert'] != 'true') {
        return _json(request, {
          'message': 'Object already exists',
          'statusCode': '409',
          'error': 'Duplicate',
        }, 409);
      }
      objects[path] = upload.bytes;
      expect(upload.contentType, uploadContentType);
      return _json(request, {'Key': 'songs/$path'});
    }
    throw StateError(
      'Unexpected local request ${request.method} ${request.url}',
    );
  }

  SongFileService get service => SongFileService(client, 7);

  /// Exposes the same controlled state over loopback so another Dart
  /// isolate can use its own genuine client and its own service lock map.
  Future<HttpServer> serve() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((incoming) async {
      try {
        final request = http.Request(
          incoming.method,
          Uri(
            scheme: 'http',
            host: server.address.address,
            port: server.port,
            path: incoming.uri.path,
            query: incoming.uri.query,
          ),
        );
        incoming.headers.forEach(
          (name, values) => request.headers[name] = values.join(','),
        );
        request.bodyBytes = await incoming.fold<List<int>>(
          [],
          (body, chunk) => body..addAll(chunk),
        );
        final response = await reply(request);
        incoming.response.statusCode = response.statusCode;
        response.headers.forEach(
          (name, value) => incoming.response.headers.set(name, value),
        );
        incoming.response.add(response.bodyBytes);
      } catch (error, stack) {
        incoming.response.statusCode = 500;
        incoming.response.headers.contentType = ContentType.json;
        incoming.response.write(
          jsonEncode({'message': 'fixture failure: $error', 'stack': '$stack'}),
        );
      }
      await incoming.response.close();
    });
    return server;
  }
}

/// A separate app session, deliberately outside the main isolate's
/// _songLocks. Its only connection is HTTP to the local fake backend.
Future<void> _uploadInIndependentSession(Map<String, Object?> message) async {
  final reply = message['reply']! as SendPort;
  SupabaseClient? client;
  try {
    client = SupabaseClient(
      message['baseUrl']! as String,
      'local-other-session-only',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final url = await SongFileService(client, 7).uploadFile(
      songId: 5,
      file: PlatformFile(
        name: 'part.pdf',
        size: 3,
        bytes: Uint8List.fromList([9, 8, 7]),
      ),
    );
    reply.send({'url': url});
  } catch (error, stack) {
    reply.send({'error': '$error', 'stack': '$stack'});
  } finally {
    await client?.dispose();
  }
}

Future<void> _delete(_Backend backend, Map<String, Object?> file) =>
    backend.service.deleteFile(
      songId: 5,
      url: file['url']! as String,
      storageName: file['storageName'] as String?,
      fileName: file['fileName'] as String?,
      mainGroupId: 12,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a failed reference update keeps the selected storage object usable',
    () async {
      final selected = _file('part', instrumentId: 11);
      final backend = _Backend([selected])..databaseFailures = 1;
      addTearDown(backend.client.dispose);

      await expectLater(
        _delete(backend, selected),
        throwsA(
          isA<PostgrestException>().having(
            (error) => error.message,
            'user-visible database failure',
            'database unavailable',
          ),
        ),
      );

      expect(backend.files, hasLength(1));
      expect(backend.objects['songs/7/5/part_123.pdf'], [1, 2, 3]);
      expect(
        backend.requests.where((request) => request.startsWith('DELETE ')),
        isEmpty,
      );
    },
  );

  test(
    'retry after a database failure removes the reference and its object',
    () async {
      final selected = _file('part', instrumentId: 11);
      final backend = _Backend([selected])..databaseFailures = 1;
      addTearDown(backend.client.dispose);
      await expectLater(
        _delete(backend, selected),
        throwsA(isA<PostgrestException>()),
      );

      await _delete(backend, selected);

      expect(backend.files, isEmpty);
      expect(backend.objects, isEmpty);
      final successfulUpdate = backend.requests.lastIndexOf(
        'PATCH /rest/v1/songs',
      );
      expect(
        backend.requests.indexOf('DELETE /storage/v1/object/songs'),
        greaterThan(successfulUpdate),
      );
    },
  );

  test(
    'storage cleanup failure leaves no user-visible broken reference',
    () async {
      final selected = _file('part');
      final backend = _Backend([selected])..storageFailures = 1;
      addTearDown(backend.client.dispose);

      await _delete(backend, selected);

      expect(backend.files, isEmpty);
      expect(
        backend.objects,
        hasLength(1),
        reason:
            'An unused storage object is safer than restoring a deleted reference',
      );
      expect(
        backend.requests.indexOf('DELETE /storage/v1/object/songs'),
        greaterThan(backend.requests.indexOf('PATCH /rest/v1/songs')),
      );
    },
  );

  test(
    'an unconfirmed update with zero affected rows does not remove storage',
    () async {
      final selected = _file('part');
      final backend = _Backend([selected])..updateMatchesRow = false;
      addTearDown(backend.client.dispose);

      await expectLater(_delete(backend, selected), throwsException);

      expect(backend.files, hasLength(1));
      expect(backend.objects, hasLength(1));
      expect(
        backend.requests.where((request) => request.startsWith('DELETE ')),
        isEmpty,
      );
    },
  );

  test(
    'a lost database response keeps storage until deletion is confirmed',
    () async {
      final selected = _file('part');
      final backend = _Backend([selected])..loseUpdateAnswer = true;
      addTearDown(backend.client.dispose);

      await expectLater(
        _delete(backend, selected),
        throwsA(isA<http.ClientException>()),
      );

      expect(backend.files, isEmpty);
      expect(backend.objects, hasLength(1));
      expect(
        backend.requests.where((request) => request.startsWith('DELETE ')),
        isEmpty,
      );
      await _delete(backend, selected);
      expect(backend.files, isEmpty);
      expect(
        backend.objects,
        hasLength(1),
        reason: 'Retry with no reference must keep an unconfirmed orphan',
      );
    },
  );

  test(
    'deleting an already removed reference never deletes an unrelated object',
    () async {
      final stale = _file('stale');
      final current = _file('current', instrumentId: 11);
      final backend = _Backend([current]);
      backend.objects['songs/7/5/stale_123.pdf'] = Uint8List.fromList([
        4,
        5,
        6,
      ]);
      addTearDown(backend.client.dispose);

      await _delete(backend, stale);

      expect(backend.files.single['fileName'], 'current.pdf');
      expect(backend.objects['songs/7/5/stale_123.pdf'], [4, 5, 6]);
      expect(
        backend.requests.where((request) => request.startsWith('DELETE ')),
        isEmpty,
      );
    },
  );

  test(
    'delete reads the latest list and preserves the other files and their groups',
    () async {
      final selected = _file('part', instrumentId: 11);
      final remaining = _file('flute', instrumentId: 13);
      final backend = _Backend([selected, remaining]);
      addTearDown(backend.client.dispose);

      await _delete(backend, selected);

      expect(backend.files.single['fileName'], 'flute.pdf');
      expect(backend.instrumentIds, [13]);
      expect(backend.objects.keys, ['songs/7/5/flute_123.pdf']);
    },
  );

  test('another service instance waits while a delete is pending', () async {
    final selected = _file('part');
    final backend =
        _Backend([selected])
          ..updateStarted = Completer<void>()
          ..allowUpdate = Completer<void>();
    addTearDown(backend.client.dispose);
    final deleting = _delete(backend, selected);
    await backend.updateStarted!.future;
    final uploading = backend.service.uploadFile(
      songId: 5,
      file: PlatformFile(
        name: 'Noten',
        size: 3,
        bytes: Uint8List.fromList([4, 5, 6]),
      ),
      instrumentId: 13,
    );
    final readsBeforeRelease =
        backend.requests.where((request) => request.startsWith('GET ')).length;
    await Future<void>.delayed(Duration.zero);
    expect(
      backend.requests.where((request) => request.startsWith('GET ')).length,
      readsBeforeRelease,
    );
    backend.allowUpdate!.complete();
    backend.updateStarted = null;
    backend.allowUpdate = null;

    await deleting;
    await uploading;

    expect(backend.files.single['fileName'], 'Noten');
    expect(backend.instrumentIds, [13]);
    expect(backend.objects.values.single, [4, 5, 6]);
  });

  test(
    'delete-all keeps every object when clearing the references fails',
    () async {
      final backend = _Backend([_file('part'), _file('flute')])
        ..databaseFailures = 1;
      addTearDown(backend.client.dispose);

      await expectLater(
        backend.service.deleteAllFiles(songId: 5),
        throwsA(isA<PostgrestException>()),
      );

      expect(backend.files, hasLength(2));
      expect(backend.objects, hasLength(2));
      expect(
        backend.requests.where((request) => request.startsWith('DELETE ')),
        isEmpty,
      );
    },
  );

  test(
    'delete-all removes references before cleaning up all their objects',
    () async {
      final backend = _Backend([_file('part'), _file('flute')]);
      addTearDown(backend.client.dispose);

      await backend.service.deleteAllFiles(songId: 5);

      expect(backend.files, isEmpty);
      expect(backend.objects, isEmpty);
      expect(
        backend.requests.indexOf('DELETE /storage/v1/object/songs'),
        greaterThan(backend.requests.indexOf('PATCH /rest/v1/songs')),
      );
    },
  );

  test(
    'extensionless PlatformFile uploads its bytes under an extensionless storage name',
    () async {
      final backend = _Backend([]);
      addTearDown(backend.client.dispose);
      final url = await backend.service.uploadFile(
        songId: 5,
        file: PlatformFile(
          name: 'Noten',
          size: 3,
          bytes: Uint8List.fromList([4, 5, 6]),
        ),
        instrumentId: 11,
      );

      expect(
        backend.files.single['storageName'],
        matches(
          r'^Noten_[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      );
      expect(backend.files.single['fileName'], 'Noten');
      expect(backend.files.single['fileType'], '');
      expect(backend.files.single['url'], url);
      expect(backend.instrumentIds, [11]);
      expect(backend.objects.values.single, [4, 5, 6]);
      expect(backend.uploadOverwriteFlags, ['false']);
    },
  );

  test(
    'storage identity: a different session keeps its new bytes during delayed cleanup',
    () async {
      // All 900 legacy candidates make the old random-name collision
      // deterministic without replacing the production name generator.
      final legacy = <Map<String, Object?>>[
        for (var n = 100; n < 1000; n++)
          {
            'storageName': 'part_$n.pdf',
            'fileName': 'part.pdf',
            'fileType': 'application/pdf',
            'url':
                'http://127.0.0.1:1/storage/v1/object/public/songs/songs/7/5/part_$n.pdf',
            'instrumentId': null,
          },
      ];
      final backend =
          _Backend(legacy)
            ..uploadContentType = 'application/pdf'
            ..deleteStarted = Completer<void>()
            ..allowDelete = Completer<void>();
      addTearDown(backend.client.dispose);
      final server = await backend.serve();
      addTearDown(() => server.close(force: true));
      final received = ReceivePort();
      addTearDown(received.close);
      final deleting = backend.service.deleteAllFiles(songId: 5);
      await backend.deleteStarted!.future;
      expect(
        backend.files,
        isEmpty,
        reason: 'Session A has committed the reference removal',
      );
      final worker =
          await Isolate.spawn(_uploadInIndependentSession, <String, Object?>{
            'reply': received.sendPort,
            'baseUrl':
                Uri(
                  scheme: 'http',
                  host: server.address.address,
                  port: server.port,
                ).toString(),
          });
      addTearDown(() => worker.kill(priority: Isolate.immediate));
      late Map result;
      try {
        result =
            await received.first.timeout(const Duration(seconds: 15)) as Map;
      } finally {
        backend.allowDelete!.complete();
        backend.allowDelete = null;
        backend.deleteStarted = null;
      }
      await deleting;
      expect(
        result['error'],
        isNull,
        reason:
            'The independent upload must finish while session A is waiting: $result',
      );
      expect(backend.files.single['url'], result['url']);
      final storageName = backend.files.single['storageName'];
      expect(
        backend.objects['songs/7/5/$storageName'],
        [9, 8, 7],
        reason:
            'Cleanup of the old references must not delete the successful new upload',
      );
      expect(backend.uploadOverwriteFlags, ['false']);
    },
  );

  test(
    'storage identity: replacement never overwrites an existing unreferenced object',
    () async {
      final selected = _file('part', instrumentId: 11);
      final backend = _Backend([selected])
        ..uploadContentType = 'application/pdf';
      backend.objects['songs/7/5/part_pending.pdf'] = Uint8List.fromList([
        9,
        8,
        7,
      ]);
      addTearDown(backend.client.dispose);

      await expectLater(
        backend.service.replaceFileContent(
          songId: 5,
          url: selected['url']! as String,
          storageName: selected['storageName'] as String?,
          newStorageName: 'part_pending.pdf',
          bytes: Uint8List.fromList([4, 5, 6]),
        ),
        throwsA(isA<StorageException>()),
      );

      expect(backend.files.single['storageName'], 'part_123.pdf');
      expect(backend.objects['songs/7/5/part_123.pdf'], [1, 2, 3]);
      expect(backend.objects['songs/7/5/part_pending.pdf'], [9, 8, 7]);
    },
  );

  test(
    'storage identity: replacement retry after a lost answer preserves the name and part',
    () async {
      final selected = _file('part', instrumentId: 11)..['note'] = 'Solo';
      final other = _file('flute', instrumentId: 13);
      final backend =
          _Backend([selected, other])
            ..uploadContentType = 'application/pdf'
            ..instrumentIds = [11, 13]
            ..loseUpdateAnswer = true;
      addTearDown(backend.client.dispose);
      await expectLater(
        backend.service.replaceFileContent(
          songId: 5,
          url: selected['url']! as String,
          storageName: selected['storageName'] as String?,
          newStorageName: 'part_lost.pdf',
          bytes: Uint8List.fromList([4, 5, 6]),
        ),
        throwsA(isA<http.ClientException>()),
      );

      final replaced = await backend.service.replaceFileContent(
        songId: 5,
        url: selected['url']! as String,
        storageName: selected['storageName'] as String?,
        earlierNames: {'part_lost.pdf'},
        newStorageName: 'part_retry.pdf',
        bytes: Uint8List.fromList([7, 8, 9]),
      );

      expect(replaced?.fileName, 'part.pdf');
      expect(replaced?.instrumentId, 11);
      expect(replaced?.note, 'Solo');
      expect(backend.files.map((file) => file['fileName']), [
        'part.pdf',
        'flute.pdf',
      ]);
      expect(backend.instrumentIds, [11, 13]);
      expect(backend.objects['songs/7/5/part_retry.pdf'], [7, 8, 9]);
      expect(backend.objects['songs/7/5/part_lost.pdf'], isNull);
      expect(backend.objects['songs/7/5/flute_123.pdf'], [1, 2, 3]);
      expect(backend.uploadOverwriteFlags, ['false', 'false']);
    },
  );

  test(
    'encoding distinguishes real extensions from dotfiles and trailing dots',
    () {
      const names = {
        'Noten': 'Noten_123',
        '.notes': 'notes_123',
        'Noten.': 'Noten_123',
        'Stimme 1 (Fl).pdf': 'Stimme-1-Fl_123.pdf',
        'Stimme.v2.PDF': 'Stimme-v2_123.PDF',
      };
      for (final name in names.entries) {
        expect(
          SongFileService.encodeFilename(name.key, 123),
          name.value,
          reason: name.key,
        );
      }
    },
  );
}
