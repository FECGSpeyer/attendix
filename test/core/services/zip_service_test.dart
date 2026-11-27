import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:archive/archive.dart';
import 'package:attendix/core/services/zip_service.dart';
import 'package:attendix/core/utils/error_message.dart';
import 'package:attendix/data/models/song/song.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

class _Path extends PathProviderPlatform {
  _Path(this.directory);
  final String directory;

  @override
  Future<String?> getTemporaryPath() async => directory;
}

class _Share extends SharePlatform {
  Uint8List? archive;
  int calls = 0;

  @override
  Future<ShareResult> shareXFiles(
    List<XFile> files, {
    String? subject,
    String? text,
    Rect? sharePositionOrigin,
    List<String>? fileNameOverrides,
  }) async {
    calls++;
    archive = await files.single.readAsBytes();
    return const ShareResult('local-test', ShareResultStatus.success);
  }
}

const _first = SongFile(
  fileName: 'first.pdf',
  fileType: 'application/pdf',
  url: 'https://files.invalid/first.pdf',
);
const _second = SongFile(
  fileName: 'second.pdf',
  fileType: 'application/pdf',
  url: 'https://files.invalid/second.pdf',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late PathProviderPlatform previousPath;
  late SharePlatform previousShare;
  late _Share share;

  setUp(() async {
    previousPath = PathProviderPlatform.instance;
    previousShare = SharePlatform.instance;
    directory = await Directory.systemTemp.createTemp('attendix_zip_test_');
    share = _Share();
    PathProviderPlatform.instance = _Path(directory.path);
    SharePlatform.instance = share;
  });

  tearDown(() async {
    PathProviderPlatform.instance = previousPath;
    SharePlatform.instance = previousShare;
    await directory.delete(recursive: true);
  });

  Future<Object?> export(
    List<SongFile> files,
    Future<http.Response> Function(http.Request) reply, {
    void Function()? onPacked,
  }) async {
    Object? failure;
    await http.runWithClient(
      () => ZipService()
          .downloadSongFilesAsZip(
            files: files,
            songName: 'Ouvertüre',
            onPacked: onPacked,
          )
          .then<void>(
            (_) {},
            onError: (Object error) {
              failure = error;
            },
          ),
      () => MockClient(reply),
    );
    return failure;
  }

  test(
    'a failed HTTP member blocks the ZIP and names the missing file',
    () async {
      var packed = false;
      final failure = await export(
        const [_first, _second],
        (request) async => http.Response(
          request.url.path == '/first.pdf' ? '%PDF-local' : 'unavailable',
          request.url.path == '/first.pdf' ? 200 : 503,
        ),
        onPacked: () => packed = true,
      );

      expect(
        failure,
        isNotNull,
        reason: 'An incomplete archive must not be reported as success',
      );
      expect(friendlyErrorMessage(failure), contains('second.pdf'));
      expect(packed, isFalse);
      expect(share.calls, 0);
      expect(directory.listSync(), isEmpty);
    },
  );

  test(
    'a transport failure identifies its member and shares no partial ZIP',
    () async {
      final failure = await export(const [_first, _second], (request) async {
        if (request.url.path == '/second.pdf') {
          throw http.ClientException('Connection refused', request.url);
        }
        return http.Response('%PDF-local', 200);
      });

      expect(failure, isNotNull);
      expect(friendlyErrorMessage(failure), contains('second.pdf'));
      expect(share.calls, 0);
    },
  );

  test(
    'a selected file without a URL is reported instead of omitted',
    () async {
      const missing = SongFile(
        fileName: 'missing.pdf',
        fileType: 'application/pdf',
        url: '',
      );
      final requested = <String>[];
      final failure = await export(const [_first, missing], (request) async {
        requested.add(request.url.toString());
        return http.Response('%PDF-local', 200);
      });

      expect(failure, isNotNull);
      expect(friendlyErrorMessage(failure), contains('missing.pdf'));
      expect(requested, ['https://files.invalid/first.pdf']);
      expect(share.calls, 0);
    },
  );

  test(
    'a complete ZIP preserves all bytes and resolves duplicate names in list order',
    () async {
      const duplicate = SongFile(
        fileName: 'first.pdf',
        fileType: 'application/pdf',
        url: 'https://files.invalid/second.pdf',
      );
      final failure = await export(
        const [_first, duplicate],
        (request) async => http.Response(
          request.url.path == '/first.pdf' ? 'first bytes' : 'second bytes',
          200,
        ),
      );

      expect(failure, isNull);
      expect(share.calls, 1);
      final archive = ZipDecoder().decodeBytes(share.archive!);
      expect(archive.files.map((file) => file.name), [
        'first.pdf',
        'first (2).pdf',
      ]);
      expect(archive.files.map((file) => String.fromCharCodes(file.content)), [
        'first bytes',
        'second bytes',
      ]);
    },
  );
}
